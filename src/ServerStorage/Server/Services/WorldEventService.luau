--!strict
--[[
	Hourly PvP world events.

	Every WorldEventConfig.Interval seconds one event of Modules.WorldEvents is picked,
	spawned players are invited for a few seconds and, with enough takers, the event
	module runs until it calls context.Finish(). Only one event exists at a time.

	This service owns everything the events share: the schedule, the invitation, the one
	1 Hz loop, the arena map, teams, rewards and the trip back. An event module only holds
	its own rules (see Types.WorldEventTypes).

	Client contract
		Invite (text, seconds)        show the invitation
		InviteClosed ()               hide it
		Respond (accept: boolean)     client -> server, the only input
		Score (eventName, score?)     scoreboard payload, nil hides it

	Legacy problems fixed
	- "Accept" was honoured during the whole event, not only while the invitation was up,
	  and from players who had never been invited (crewless players into Crew Wars).
	- Waiting / team highlights were Highlight instances made by the server, one with its
	  own blinking loop per player. They are replicated statuses drawn by each client.
	- Friendly fire in Crew Wars depended on a StringValue in the character that the old
	  damage module had to know about; teams now use CharacterEntity.Team.
	- An event that ended up with a single fighter in the arena never finished, and no
	  event could start again on that server.
	- Rewards were also paid in private servers, where two accounts could farm them.

	Also here: WorldEventService:GetMultiplier(kind), the weekend modifiers.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local World = require(ReplicatedStorage.Shared.Util.World)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local WorldEventConfig = require(ServerStorage.Server.Configs.WorldEventConfig)
local WorldAssets = require(ServerStorage.Server.Modules.WorldAssets)
local WorldEventTypes = require(ServerStorage.Server.Types.WorldEventTypes)

type CharacterEntity = CharacterEntity.CharacterEntity
type Context = WorldEventTypes.Context
type WorldEvent = WorldEventTypes.WorldEvent

type Team = { Name: string, Color: Color3? }

type Run = {
	Name: string,
	Definition: WorldEventConfig.EventDefinition,
	Phase: "Inviting" | "Running",
	Invited: { [Player]: boolean },
	Accepted: { Player },
	Teams: { [Player]: Team },
	PreviousTeams: { [CharacterEntity]: string },
	ScoreViewers: { [Player]: boolean },
	Ticks: { () -> () },
	Tracked: { any },
	Map: Instance?,
	Cleanup: (() -> ())?,
	Starting: boolean,
	Finished: boolean,
}

-- Replicated statuses, drawn by Client.Modules.Effects.Status.<Name>.
local STATUS_QUEUED = "EventQueued"
local STATUS_TEAM = "EventTeam"
local TEAM_PREFIX = "WorldEvent:"
local TICK_SECONDS = 1

local WorldEventService = Knit.CreateService({
	Name = "WorldEventService",
	Client = {
		Invite = Knit.CreateSignal(),
		InviteClosed = Knit.CreateSignal(),
		Respond = Knit.CreateSignal(),
		Score = Knit.CreateSignal(),
	},
})

-- (eventName, participants) when an event leaves the invitation and starts.
WorldEventService.Started = Signal.new() :: Signal.Signal<string, { Player }>
-- (eventName) when it is over, or was cancelled for lack of players.
WorldEventService.Ended = Signal.new() :: Signal.Signal<string>
-- (player, eventName) for each rewarded winner; for quests and challenges.
WorldEventService.Won = Signal.new() :: Signal.Signal<Player, string>

local DataService
local CharacterService
local NotifyService
local RewardService
local SeasonService
local ChestService
local BarrelService
-- Owned by the crew system; optional (see grantCrewXP).
local CrewService: any = nil

local events: { [string]: WorldEvent } = {}
local eventNames: { string } = {}
local current: Run? = nil
local respondLimiter = RateLimiter.new(4, 1)
local random = Random.new()

local function hasCrew(player: Player): boolean
	local data = DataService:GetData(player)
	local crewId = data and data.Data.Crew.Id
	return crewId ~= nil and crewId ~= "" and crewId ~= "0"
end

local function getFighter(player: Player): CharacterEntity?
	local entity = CharacterService:GetPlayerEntity(player)
	if entity and not entity.Dead and entity.Spawned then
		return entity
	end
	return nil
end

local function setQueued(player: Player, queued: boolean)
	local entity = CharacterService:GetPlayerEntity(player)
	if entity then
		entity:SetStatus(STATUS_QUEUED, queued, nil, true)
	end
end

local function resetTravel(player: Player)
	ChestService:ResetTravel(player)
	BarrelService:ResetTravel(player)
end

local function applyTeam(run: Run, entity: CharacterEntity, team: Team?)
	if team then
		if run.PreviousTeams[entity] == nil then
			run.PreviousTeams[entity] = entity.Team
		end
		entity.Team = TEAM_PREFIX .. team.Name
		entity:SetStatus(STATUS_TEAM, team.Color, nil, true)
	else
		local previous = run.PreviousTeams[entity]
		if previous ~= nil then
			entity.Team = previous
			run.PreviousTeams[entity] = nil
		end
		entity:ClearStatus(STATUS_TEAM)
	end
end

local function rollReward(rewards: { WorldEventConfig.Reward }): WorldEventConfig.Reward
	local roll = random:NextNumber() * 100
	local counter = 0
	for _, reward in rewards do
		counter += reward.Chance
		if roll <= counter then
			return reward
		end
	end
	return rewards[#rewards]
end

local function grantCrewXP(player: Player, amount: number)
	if amount <= 0 or not hasCrew(player) or not CrewService then
		return
	end
	local data = DataService:GetData(player)
	if data and type(CrewService.AddExp) == "function" then
		CrewService:AddExp(data.Data.Crew.Id, amount)
	end
end

local function reward(run: Run, player: Player)
	local data = DataService:GetData(player)
	local rewards = WorldEventConfig.Rewards[run.Definition.Rewards]
	if not data or not rewards then
		return
	end
	if not RewardService.Enabled then
		NotifyService:Send(player, `You won the {run.Name} event! Private servers give no reward.`, "Info")
		return
	end

	local rolled = rollReward(rewards)
	local amount = rolled.Amount or 1
	if rolled.Amounts then
		amount = rolled.Amounts[random:NextInteger(1, #rolled.Amounts)]
	end

	local description: string
	if rolled.Kind == "Beri" then
		data:Increment("Economy.Beri", amount)
		description = `B${amount}`
	elseif rolled.Kind == "Gems" then
		data:Increment("Economy.Gems", amount)
		description = `{amount} Gems`
	else
		local item = rolled.Item or ""
		WorldAssets.GiveItem(player, item, amount)
		description = `{amount}x {item}`
	end

	NotifyService:Send(player, `You won the {run.Name} event! Reward: {description}`, "Success", 8)
	grantCrewXP(player, run.Definition.CrewXP)
	WorldEventService.Won:Fire(player, run.Name)
end

local function returnToWorld(player: Player)
	-- A random spawn point of the map (WorldConfig.Spawns). A fighter who died in the
	-- arena has no character any more and simply picks a spawn on the spawn screen.
	local entity = getFighter(player)
	if not entity then
		return
	end

	CharacterService:Teleport(entity, WorldConfig.GetRandomSpawnCFrame(random, WorldEventConfig.SpawnHeight))
	resetTravel(player)
end

local function finalize(run: Run)
	if current ~= run then
		return
	end
	current = nil

	if run.Cleanup then
		local ok, problem = pcall(run.Cleanup)
		if not ok then
			warn(`[WorldEventService] cleanup of {run.Name} failed: {problem}`)
		end
	end

	for _, tracked in run.Tracked do
		if typeof(tracked) == "RBXScriptConnection" then
			tracked:Disconnect()
		elseif type(tracked) == "table" and type(tracked.Disconnect) == "function" then
			tracked:Disconnect()
		elseif typeof(tracked) == "Instance" then
			tracked:Destroy()
		elseif type(tracked) == "function" then
			task.spawn(tracked)
		end
	end

	for player in run.Teams do
		local entity = CharacterService:GetPlayerEntity(player)
		if entity then
			applyTeam(run, entity, nil)
		end
	end
	for _, player in run.Accepted do
		setQueued(player, false)
	end
	for player in run.ScoreViewers do
		WorldEventService.Client.Score:Fire(player, run.Name, nil)
	end
	if run.Phase == "Inviting" then
		WorldEventService.Client.InviteClosed:FireAll()
	end
	if run.Map then
		run.Map:Destroy()
	end

	WorldEventService.Ended:Fire(run.Name)
end

local function createContext(run: Run): Context
	local function finish()
		if run.Finished then
			return
		end
		run.Finished = true
		-- Called from inside Start: the service finalizes once Start has returned its cleanup.
		if not run.Starting then
			finalize(run)
		end
	end

	return {
		Name = run.Name,
		Config = run.Definition,
		Participants = table.clone(run.Accepted),

		IsFinished = function(): boolean
			return run.Finished
		end,
		Finish = finish,
		OnTick = function(fn: () -> ())
			table.insert(run.Ticks, fn)
		end,
		Track = function(connection: any)
			table.insert(run.Tracked, connection)
		end,

		LoadMap = function(): Instance?
			-- The arenas were Folders in the legacy place; accept a Model too.
			local template = WorldAssets.Find(run.Definition.Map, "Folder", true)
				or WorldAssets.Find(run.Definition.Map, "Model")
			if not template then
				return nil
			end
			local map = template:Clone()
			for _, descendant in map:GetDescendants() do
				if descendant:IsA("LuaSourceContainer") then
					descendant:Destroy()
				end
			end
			map.Parent = World.RuntimeParent()
			run.Map = map
			return map
		end,
		GetFighter = getFighter,
		Place = function(player: Player, spawn: BasePart, heal: boolean?)
			local entity = getFighter(player)
			if entity then
				if heal then
					entity:Heal(entity.MaxHealth)
				end
				CharacterService:Teleport(entity, spawn.CFrame + Vector3.new(0, WorldEventConfig.SpawnHeight, 0))
				resetTravel(player)
			end
		end,
		SetTeam = function(player: Player, teamName: string?, color: Color3?)
			local team: Team? = if teamName then { Name = teamName, Color = color } else nil
			run.Teams[player] = team
			local entity = CharacterService:GetPlayerEntity(player)
			if entity then
				applyTeam(run, entity, team)
			end
		end,
		Reward = function(player: Player)
			reward(run, player)
		end,
		ReturnToWorld = returnToWorld,
		SendScore = function(players: { Player }, score: { [string]: any }?)
			for _, player in players do
				run.ScoreViewers[player] = if score then true else nil
				WorldEventService.Client.Score:Fire(player, run.Name, score)
			end
		end,
		Notify = function(players: { Player }, text: string)
			for _, player in players do
				NotifyService:Send(player, text, "Announcement")
			end
		end,
	}
end

local function runTicks(run: Run)
	while current == run and not run.Finished do
		task.wait(TICK_SECONDS)
		for _, callback in run.Ticks do
			if current ~= run or run.Finished then
				return
			end
			callback()
		end
	end
end

local function invite(run: Run)
	for _, player in Players:GetPlayers() do
		if getFighter(player) and (not run.Definition.RequiresCrew or hasCrew(player)) then
			run.Invited[player] = true
			WorldEventService.Client.Invite:Fire(player, run.Definition.InviteText, WorldEventConfig.InviteSeconds)
		end
	end
end

local function onRespond(player: Player, accept: unknown)
	local run = current
	if type(accept) ~= "boolean" or not respondLimiter:Consume(player) then
		return
	end
	if not run or run.Phase ~= "Inviting" or not run.Invited[player] then
		return
	end

	local index = table.find(run.Accepted, player)
	if accept then
		if not index and getFighter(player) then
			table.insert(run.Accepted, player)
			setQueued(player, true)
		end
	elseif index then
		table.remove(run.Accepted, index)
		setQueued(player, false)
	end
end

-- Name of the event being invited to or played, if any.
function WorldEventService:GetActive(): string?
	return if current then current.Name else nil
end

function WorldEventService:GetEventNames(): { string }
	return table.clone(eventNames)
end

--[[
	Weekend modifier for `kind` ("Exp", "Beri", "CompassTokenTime", "GoldenCompassPrice"):
	multiply the normal value by it. 1 outside weekends and for unknown kinds.
]]
function WorldEventService:GetMultiplier(kind: string): number
	if SeasonService:IsActive("Weekend") then
		return WorldEventConfig.WeekendMultipliers[kind] or 1
	end
	return 1
end

--[[
	Runs one event from invitation to the end of its start-up; yields for the invitation.
	Without a name a random event is picked. Returns false when another event is active,
	the event is unknown, or too few players accepted. Used by the scheduler and by admin
	commands (wrap in task.spawn).
]]
function WorldEventService:StartEvent(name: string?): boolean
	if current or #eventNames == 0 then
		return false
	end

	local chosen = name or eventNames[random:NextInteger(1, #eventNames)]
	local module = events[chosen]
	local definition = WorldEventConfig.Events[chosen]
	if not module or not definition then
		return false
	end

	local run: Run = {
		Name = chosen,
		Definition = definition,
		Phase = "Inviting",
		Invited = {},
		Accepted = {},
		Teams = {},
		PreviousTeams = {},
		ScoreViewers = {},
		Ticks = {},
		Tracked = {},
		Map = nil,
		Cleanup = nil,
		Starting = false,
		Finished = false,
	}
	current = run

	invite(run)
	task.wait(WorldEventConfig.InviteSeconds)
	if current ~= run then
		return false
	end

	WorldEventService.Client.InviteClosed:FireAll()
	run.Phase = "Running"
	for _, player in run.Accepted do
		setQueued(player, false)
	end

	if #run.Accepted < WorldEventConfig.MinPlayers then
		for _, player in run.Accepted do
			NotifyService:Send(player, `Not enough players for {chosen}.`, "Info")
		end
		finalize(run)
		return false
	end

	local context = createContext(run)
	WorldEventService.Started:Fire(chosen, context.Participants)

	run.Starting = true
	local ok, result = pcall(module.Start, context)
	run.Starting = false
	if not ok then
		warn(`[WorldEventService] {chosen} failed to start: {result}`)
		run.Finished = true
	else
		run.Cleanup = result
	end

	if run.Finished then
		finalize(run)
		return ok
	end

	task.spawn(runTicks, run)
	return true
end

function WorldEventService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	NotifyService = Knit.GetService("NotifyService")
	RewardService = Knit.GetService("RewardService")
	SeasonService = Knit.GetService("SeasonService")
	ChestService = Knit.GetService("ChestService")
	BarrelService = Knit.GetService("BarrelService")

	for _, module in ServerStorage.Server.Modules.WorldEvents:GetChildren() do
		if module:IsA("ModuleScript") and WorldEventConfig.Events[module.Name] then
			events[module.Name] = (require :: any)(module)
			table.insert(eventNames, module.Name)
		end
	end
	table.sort(eventNames)
end

function WorldEventService:KnitStart()
	local hasCrewService, crewService = pcall(Knit.GetService, "CrewService")
	if hasCrewService then
		CrewService = crewService
	end

	WorldEventService.Client.Respond:Connect(onRespond)

	-- A team member who respawns gets a new entity: put it back on the team.
	CharacterService.EntityAdded:Connect(function(entity: CharacterEntity)
		local run = current
		local team = run and entity.Player and run.Teams[entity.Player]
		if run and team then
			applyTeam(run, entity, team)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		respondLimiter:Forget(player)
		local run = current
		if run then
			run.Invited[player] = nil
			run.Teams[player] = nil
			run.ScoreViewers[player] = nil
			local index = table.find(run.Accepted, player)
			if index then
				table.remove(run.Accepted, index)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(WorldEventConfig.Interval)
			if not current then
				WorldEventService:StartEvent()
			end
		end
	end)
end

return WorldEventService
