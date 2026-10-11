--!strict
--[[
	The AFK world (PlaceConfig.Role == "AFK"). Everywhere else this service is loaded and
	does nothing.

	A player in the AFK place has no body and nothing to do: it is paid for being there.
	Numbers are in AfkWorldConfig.

	1. Rolls. Every RollInterval seconds, counted per player from the moment its data is
	   loaded, one roll: Beri, Gems, a compass, or nothing. The time of the next roll is
	   the Player attribute AfkStateConfig.Attributes.NextRoll (server time), which is
	   what the screen counts down to and what this service compares against.
	2. Compass time. Seconds spent here add up across sessions (AFK_World.CompassTime);
	   CompassSeconds of them are worth a compass and the counter starts again.
	3. Rejoin. After RejoinAfter seconds the player is teleported to the AFK place again,
	   so that Roblox never kicks it for being idle.
	4. Return. The one thing a client can ask for: to be sent to the main place.

	Everything earned is added to data.AFK_World and stays there: the AFK NPC of the main
	place pays it out (AfkRewardService). Roblox Premium multiplies every amount.

	One loop serves every player. No remote grants anything and nothing a client sends
	is a number: Return takes no argument. Being in two AFK servers at once is not
	possible, the profile has one session (DataService): a player without loaded data is
	not in the loop.

	Compass time is kept in memory and written to the data every CompassFlushInterval
	seconds, when a compass is granted and when the session ends, always as the whole
	count: writing it twice changes nothing, and a second in memory is never added twice.

	Studio: no teleport (Return is refused, nobody is sent to rejoin); the Workspace
	attribute AfkWorldConfig.StudioSpeedAttribute speeds the timers up.

	Legacy problems fixed (place "AFK World": World)
	- It opened a second ProfileStore session of its own and wrote into the profile.
	- Three threads per player; the countdown shown was a guess of the client (60 s from
	  whenever the last event arrived) while the server rolled every 59 s.
	- The compass counter was written to the data every second.
	- The return teleport was the client's, with a place id of its own.
	- Every reward but Beri was posted to a Discord webhook whose address sat in the script.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AfkStateConfig = require(ReplicatedStorage.Shared.Configs.AfkStateConfig)
local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local AfkWorldConfig = require(ServerStorage.Server.Configs.AfkWorldConfig)

type PlayerData = PlayerData.PlayerData

type Visitor = {
	Data: PlayerData,
	-- Server time (Workspace:GetServerTimeNow) of the next roll; also the attribute.
	NextRoll: number,
	-- Seconds towards the next compass, the saved ones included.
	CompassTime: number,
	-- os.clock of the next write of CompassTime and of the next teleport back in.
	NextFlush: number,
	RejoinAt: number,
	-- A failure of this player's turn was already reported (one warning, not one a second).
	Faulted: boolean,
}

local ATTRIBUTES = AfkStateConfig.Attributes
local IS_AFK = PlaceConfig.Role == "AFK"
local IS_STUDIO = RunService:IsStudio()

local TICK = 1

local AfkWorldService = Knit.CreateService({
	Name = "AfkWorldService",
	Client = {},
})

local DataService

local random = Random.new()
local returnLimiter = RateLimiter.new(1, 1 / AfkWorldConfig.ReturnCooldown)
-- Players whose data is loaded: the only ones that earn.
local visitors: { [Player]: Visitor } = {}

-- How much faster than real time the timers run: 1 outside Studio.
local function readSpeed(): number
	if not IS_STUDIO then
		return 1
	end
	local wanted = Workspace:GetAttribute(AfkWorldConfig.StudioSpeedAttribute)
	if type(wanted) ~= "number" or wanted ~= wanted then
		return 1
	end
	return math.clamp(wanted, 1, AfkWorldConfig.StudioSpeedMax)
end

local function premiumFactor(player: Player): number
	return if player.MembershipType == Enum.MembershipType.Premium then AfkWorldConfig.PremiumFactor else 1
end

local function add(data: PlayerData, field: string, amount: number)
	local path = `AFK_World.{field}`
	local current = data:Get(path)
	data:Set(path, (if type(current) == "number" and current == current then current else 0) + amount)
end

-- Never yields: the teleport runs in its own thread and a failure is only logged.
local function teleport(player: Player, placeId: number)
	task.spawn(function()
		local ok, problem = pcall(TeleportService.TeleportAsync, TeleportService, placeId, { player })
		if not ok then
			warn(`[AfkWorldService] teleport of {player.Name} to place {placeId} failed: {problem}`)
		end
	end)
end

local function scheduleRoll(player: Player, visitor: Visitor, now: number, speed: number)
	visitor.NextRoll = now + AfkWorldConfig.RollInterval / speed
	player:SetAttribute(ATTRIBUTES.NextRoll, visitor.NextRoll)
end

local function roll(player: Player, visitor: Visitor)
	local rolled = random:NextNumber() * 100
	local threshold = 0
	for _, entry in AfkWorldConfig.Rolls do
		threshold += entry.Chance
		if rolled < threshold then
			local amount = entry.Amounts[random:NextInteger(1, #entry.Amounts)]
			add(visitor.Data, entry.Field, amount * premiumFactor(player))
			return
		end
	end
	-- Past the last entry: this roll pays nothing.
end

local function grantCompass(player: Player, visitor: Visitor)
	local total = 0
	for _, reward in AfkWorldConfig.CompassRewards do
		total += reward.Weight
	end

	local rolled = random:NextNumber() * total
	for _, reward in AfkWorldConfig.CompassRewards do
		rolled -= reward.Weight
		if rolled < 0 then
			add(visitor.Data, reward.Field, reward.Amount * premiumFactor(player))
			return
		end
	end
end

-- The whole count, not a difference: writing it again changes nothing.
local function flushCompassTime(visitor: Visitor, clock: number, speed: number)
	visitor.NextFlush = clock + AfkWorldConfig.CompassFlushInterval / speed
	visitor.Data:Set("AFK_World.CompassTime", math.floor(visitor.CompassTime))
end

--[[
	One player's turn. Every timer is moved on BEFORE what it pays for is written: if the
	write fails half-way the reward is lost, where the other order would pay it again on
	every tick (a roll a second instead of one every RollInterval).
]]
local function stepVisitor(
	player: Player,
	visitor: Visitor,
	deltaTime: number,
	speed: number,
	now: number,
	clock: number
)
	if not visitor.Data:IsActive() then
		return
	end

	visitor.CompassTime += deltaTime * speed
	if visitor.CompassTime >= AfkWorldConfig.CompassSeconds then
		visitor.CompassTime -= AfkWorldConfig.CompassSeconds
		-- The compass and the counter that paid for it are written in the same breath.
		grantCompass(player, visitor)
		flushCompassTime(visitor, clock, speed)
	elseif clock >= visitor.NextFlush then
		flushCompassTime(visitor, clock, speed)
	end

	if now >= visitor.NextRoll then
		scheduleRoll(player, visitor, now, speed)
		roll(player, visitor)
	end

	if not IS_STUDIO and clock >= visitor.RejoinAt then
		visitor.RejoinAt = clock + AfkWorldConfig.RejoinRetry
		teleport(player, PlaceConfig.Places.AFK)
	end
end

local function step(deltaTime: number)
	local speed = readSpeed()
	local now = Workspace:GetServerTimeNow()
	local clock = os.clock()

	for player, visitor in visitors do
		-- One loop serves everyone: an error raised for one player (a broken profile) used
		-- to kill the thread, and with it the rolls and the anti-idle teleport of the
		-- whole server until it closed.
		local ok, problem = pcall(stepVisitor, player, visitor, deltaTime, speed, now, clock)
		if not ok and not visitor.Faulted then
			visitor.Faulted = true
			warn(`[AfkWorldService] turn of {player.Name} failed: {problem}`)
		end
	end
end

local function onDataLoaded(player: Player, data: PlayerData)
	if visitors[player] or player.Parent ~= Players then
		return
	end

	-- The saved count is not trusted (old or damaged profiles): anything that is not a
	-- number counts as 0 and it is capped at one compass. Uncapped, a saved 1e9 paid a
	-- compass on every tick for hours (the loop takes CompassSeconds off per compass) and
	-- a saved math.huge paid one a second for ever.
	local saved = data:Get("AFK_World.CompassTime")
	local compassTime = 0
	if type(saved) == "number" and saved == saved and saved > 0 then
		compassTime = math.min(saved, AfkWorldConfig.CompassSeconds)
	end

	local speed = readSpeed()
	local clock = os.clock()
	local visitor: Visitor = {
		Data = data,
		NextRoll = 0,
		CompassTime = compassTime,
		NextFlush = clock + AfkWorldConfig.CompassFlushInterval / speed,
		RejoinAt = clock + AfkWorldConfig.RejoinAfter,
		Faulted = false,
	}
	visitors[player] = visitor
	scheduleRoll(player, visitor, Workspace:GetServerTimeNow(), speed)
end

local function onReleasing(player: Player, data: PlayerData)
	local visitor = visitors[player]
	if not visitor then
		return
	end
	visitors[player] = nil
	player:SetAttribute(ATTRIBUTES.NextRoll, nil)

	-- The session is no longer active here, so data:Set would refuse the write; the last
	-- save, which follows this signal, stores the table as it is now. Nobody is left to
	-- replicate it to.
	local stored = data.Data.AFK_World
	if type(stored) == "table" then
		stored.CompassTime = math.floor(visitor.CompassTime)
	end
end

--[[
	Sends the caller to the main place. Takes no argument: the destination is
	PlaceConfig's. True when the teleport was started (the client then waits for it).
]]
function AfkWorldService.Client:Return(player: Player): boolean
	if not IS_AFK or not returnLimiter:Consume(player) then
		return false
	end
	-- Nowhere to go from Studio.
	if IS_STUDIO then
		return false
	end

	-- The two teleports must not race: the trip back in waits for this one.
	local visitor = visitors[player]
	if visitor then
		visitor.RejoinAt = math.max(visitor.RejoinAt, os.clock() + AfkWorldConfig.RejoinRetry)
	end
	teleport(player, PlaceConfig.Places.Main)
	return true
end

function AfkWorldService:KnitInit()
	if not IS_AFK then
		return
	end
	DataService = Knit.GetService("DataService")
end

function AfkWorldService:KnitStart()
	if not IS_AFK then
		return
	end

	DataService:ObserveData(onDataLoaded)
	DataService.Releasing:Connect(onReleasing)
	Players.PlayerRemoving:Connect(function(player: Player)
		returnLimiter:Forget(player)
	end)

	task.spawn(function()
		while true do
			step(task.wait(TICK))
		end
	end)
end

return AfkWorldService
