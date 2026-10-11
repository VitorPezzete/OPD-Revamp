--!strict
--[[
	Crew Wars: a deathmatch between crews in the colosseum. Only players in a crew are
	invited; at least two different crews must show up. Crew mates share a highlight
	colour and cannot hurt each other. The last crew with someone alive wins: every
	surviving member rolls the Crew Wars reward table and earns crew experience.

	After five minutes sudden death drains everybody. Fighters who leave the arena
	(500 studs from its centre) are put back on a spawn.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local WorldEventArena = require(ServerStorage.Server.Modules.WorldEventArena)
local WorldEventTypes = require(ServerStorage.Server.Types.WorldEventTypes)

type Context = WorldEventTypes.Context

local CrewWars = {}

local function countCrews(crews: { [string]: { Player } }): number
	local count = 0
	for _, members in crews do
		if #members > 0 then
			count += 1
		end
	end
	return count
end

function CrewWars.Start(context: Context): (() -> ())?
	local config = context.Config
	local DataService = Knit.GetService("DataService")

	-- Crew of each participant, read once: changing crew mid-event changes nothing.
	local crewOf: { [Player]: string } = {}
	local signedUp: { [string]: { Player } } = {}
	for _, player in context.Participants do
		local data = DataService:GetData(player)
		local crewId = data and data.Data.Crew.Id
		if crewId and crewId ~= "" and crewId ~= "0" then
			crewOf[player] = crewId
			signedUp[crewId] = signedUp[crewId] or {}
			table.insert(signedUp[crewId], player)
		end
	end

	if countCrews(signedUp) < config.MinCrews then
		context.Notify(context.Participants, "Crew Wars cancelled: at least two crews are needed.")
		context.Finish()
		return nil
	end

	local map = context.LoadMap()
	local spawns = if map then WorldEventArena.GetSpawns(map) else {}
	if #spawns == 0 then
		warn("[CrewWars] arena map or its Spawns are missing")
		context.Finish()
		return nil
	end
	local center = WorldEventArena.GetCenter(spawns)

	local fighters: { Player } = {}
	local alive: { [string]: { Player } } = {}
	local startedAt: number? = nil
	local suddenDeath = false

	local function resolve()
		if context.IsFinished() or not startedAt or countCrews(alive) > 1 then
			return
		end
		for _, members in alive do
			for _, winner in table.clone(members) do
				context.Reward(winner)
				context.ReturnToWorld(winner)
			end
		end
		context.Finish()
	end

	local function eliminate(player: Player)
		local index = table.find(fighters, player)
		if not index then
			return
		end
		table.remove(fighters, index)

		local members = alive[crewOf[player]]
		local memberIndex = members and table.find(members, player)
		if members and memberIndex then
			table.remove(members, memberIndex)
		end
		resolve()
	end

	context.Track(Players.PlayerRemoving:Connect(eliminate))

	task.delay(config.PrepareSeconds, function()
		if context.IsFinished() then
			return
		end

		local colorIndex = 0
		for crewId, members in signedUp do
			colorIndex = colorIndex % #config.Colors + 1
			local color = config.Colors[colorIndex]

			for _, player in members do
				local entity = context.GetFighter(player)
				if not entity then
					continue
				end
				context.SetTeam(player, crewId, color)
				context.Place(player, WorldEventArena.RandomSpawn(spawns), true)

				alive[crewId] = alive[crewId] or {}
				table.insert(alive[crewId], player)
				table.insert(fighters, player)
				context.Track(entity.Died:Connect(function()
					eliminate(player)
				end))
			end
		end

		if countCrews(alive) < config.MinCrews then
			context.Notify(fighters, "Crew Wars cancelled: at least two crews are needed.")
			for _, player in table.clone(fighters) do
				context.ReturnToWorld(player)
			end
			context.Finish()
			return
		end

		startedAt = os.clock()
		context.Notify(fighters, "Crew Wars! The last crew standing wins.")
	end)

	context.OnTick(function()
		if not startedAt then
			return
		end

		if not suddenDeath and os.clock() - startedAt >= config.SuddenDeathAfter then
			suddenDeath = true
			context.Notify(fighters, "Sudden death!")
		end
		if suddenDeath then
			WorldEventArena.SuddenDeath(context, fighters, config.SuddenDeathDamage)
			if context.IsFinished() then
				return
			end
		end

		for _, player in fighters do
			local entity = context.GetFighter(player)
			if entity and (entity.Root.Position - center).Magnitude > config.Boundary then
				context.Place(player, WorldEventArena.RandomSpawn(spawns))
			end
		end
	end)

	return nil
end

return CrewWars
