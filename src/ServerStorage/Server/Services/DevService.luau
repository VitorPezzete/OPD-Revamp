--!strict
--[[
	Server side of the developer menu (drawn with Iris on the developer's client).

	Who has it: owners (Permissions role "Owner"), anyone inside Studio, and anyone in the
	development place (PlaceConfig.Role == "Dev", a baseplate that never touches a live
	profile). Nobody else, in any other place.

	Everything here is privileged, so the menu is only a remote control: each request
	is authorised on the server, rate limited, validated against the configs and written
	to the audit log.

	The menu's code is not in the client either. It lives in ServerStorage
	(Server.StaffClient.Dev) and StaffDelivery copies it into the PlayerGui of an
	authorised player, which replicates to that player alone: tab names, action names
	and ranges never reach anybody else. What every client does see is this service's
	name and its four remote names; a player without access is answered nil, or the same
	"unknown action" a developer gets for an action that does not exist, whatever was
	asked.

		DevService.Client:GetAccess()                     -> where the menu is, its key and its catalog, or nil
		DevService.Client:Execute(action, target?, ...)   -> ok: boolean, message: string
		DevService.Client:GetSnapshot(target?)            -> live numbers, or nil
		DevService.Client:GetReport(kind, target?)        -> "Server" or "Data" details, or nil

	The commands live in Server.Modules, one module per part of the game (their shape is
	in DevKit):

		DevPlayerCommands      the target's character: health, movement, teleports, test hits
		DevProgressCommands    levels, experience, perks, currencies, tokens, saved values
		DevInventoryCommands   devil fruits, weapons, boxes, compasses, drinks, emotes
		DevWorldCommands       clock, seasons, world events, test enemies and bosses

	They are required below by hand and an action is a key of their handler tables,
	nothing else: no request can name a service, a method, an instance or a data path that
	a handler does not spell out. Actions take a target user id first (the developer when
	absent, or another player in the server).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local TimeConfig = require(ReplicatedStorage.Shared.Configs.TimeConfig)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local AdminConfig = require(ServerStorage.Server.Configs.AdminConfig)
local SeasonConfig = require(ServerStorage.Server.Configs.SeasonConfig)
local AuditLog = require(ServerStorage.Server.Modules.AuditLog)
local DevKit = require(ServerStorage.Server.Modules.DevKit)
local Optional = require(ReplicatedStorage.Shared.Util.Optional)
local Permissions = require(ServerStorage.Server.Modules.Permissions)
local StaffDelivery = require(ServerStorage.Server.Modules.StaffDelivery)

-- Lowest role that may use the menu outside Studio and the development place.
local REQUIRED_ROLE: Permissions.Role = "Owner"
-- The bundle of Server.StaffClient that is the menu.
local MENU_BUNDLE = "Dev"
-- The answer to anything that is not an action, and to anybody without access.
local UNKNOWN = "unknown action or target"
local MAX_ACTION_LENGTH = 40
-- A report costs this many snapshots: it carries a whole profile or the audit log.
local REPORT_COST = 3
local AUDIT_TAIL = 30
-- The frame time sampler stops this long after the last snapshot asked for it.
local SAMPLER_IDLE = 5

local COMMAND_MODULES: { DevKit.CommandModule } = {
	require(ServerStorage.Server.Modules.DevPlayerCommands),
	require(ServerStorage.Server.Modules.DevProgressCommands),
	require(ServerStorage.Server.Modules.DevInventoryCommands),
	require(ServerStorage.Server.Modules.DevWorldCommands),
	require(ServerStorage.Server.Modules.DevBackupCommands),
	require(ServerStorage.Server.Modules.DevPrivateCommands),
	require(ServerStorage.Server.Modules.DevShutdownCommands),
}

local DevService = Knit.CreateService({
	Name = "DevService",
	Client = {},
})

local limiter = RateLimiter.new(20, 10)
local snapshotLimiter = RateLimiter.new(6, 3)

local handlers: { [string]: DevKit.Handler } = {}
local costs: { [string]: number } = {}
for _, module in COMMAND_MODULES do
	for action, handler in module.Handlers do
		assert(handlers[action] == nil, `[DevService] two commands are named "{action}"`)
		handlers[action] = handler
		costs[action] = if module.Costs then module.Costs[action] or 1 else 1
	end
end

-- Smoothed server frame time, for the snapshot. Only sampled while a menu is watching.
local frameTime = 1 / 60
local sampler: RBXScriptConnection? = nil
local lastWatched = 0

-- Decided once: neither changes while the server runs.
local OPEN_TO_EVERYONE = RunService:IsStudio() or PlaceConfig.Role == "Dev"

local function isAllowed(player: Player): boolean
	return OPEN_TO_EVERYONE or Permissions.Has(player, REQUIRED_ROLE)
end

local function getTarget(player: Player, targetUserId: unknown): Player?
	return if type(targetUserId) == "number" then Players:GetPlayerByUserId(targetUserId) else player
end

local function watchFrameTime()
	lastWatched = os.clock()
	if sampler then
		return
	end
	sampler = RunService.Heartbeat:Connect(function(deltaTime: number)
		frameTime += (deltaTime - frameTime) * 0.05
		if os.clock() - lastWatched > SAMPLER_IDLE and sampler then
			sampler:Disconnect()
			sampler = nil
		end
	end)
end

local function describeServer(): { [string]: any }
	-- The report covers the whole game, a place only loads part of it (PlaceManifest):
	-- what is not here is reported as absent.
	local CharacterService = Optional.Service("CharacterService")
	local DataService = Knit.GetService("DataService")
	local InputService = Optional.Service("InputService")
	local SeasonService = Optional.Service("SeasonService")
	local StatService = Optional.Service("StatService")
	local RewardService = Optional.Service("RewardService")
	local ServerPolicyService = Optional.Service("ServerPolicyService")

	local players = {}
	for _, player in Players:GetPlayers() do
		local entity = CharacterService and CharacterService:GetPlayerEntity(player)
		table.insert(players, {
			Name = player.Name,
			UserId = player.UserId,
			Role = Permissions.GetRole(player.UserId),
			Ping = math.floor(player:GetNetworkPing() * 1000),
			Device = if InputService then InputService:GetDevice(player) else "n/a",
			Loaded = DataService:GetData(player) ~= nil,
			Character = if not entity then "none" elseif entity.Dead then "dead" elseif entity.Spawned then "spawned" else "protected",
		})
	end
	table.sort(players, function(a, b)
		return a.Name < b.Name
	end)

	local seasons = {}
	for _, flag in DevKit.SortedKeys(SeasonConfig.Flags) do
		table.insert(seasons, { Flag = flag, Active = SeasonService ~= nil and SeasonService:IsActive(flag) })
	end

	-- Newest first, and only the tail: the full log is the `auditlog` console command.
	local audit = {}
	local entries = AuditLog.GetEntries()
	for index = #entries, math.max(1, #entries - AUDIT_TAIL + 1), -1 do
		local entry = entries[index]
		table.insert(audit, { Time = entry.Time, Actor = entry.Actor, Action = entry.Action, Detail = entry.Detail })
	end

	return {
		Players = players,
		Seasons = seasons,
		Audit = audit,
		Progression = StatService ~= nil and StatService.ProgressionEnabled,
		ExpMultiplier = if StatService then StatService.ExpMultiplier else 0,
		Rewards = RewardService ~= nil and RewardService.Enabled,
		Closing = ServerPolicyService ~= nil and ServerPolicyService:IsClosing(),
	}
end

function DevService.Client:GetAccess(player: Player): { [string]: any }?
	if not isAllowed(player) then
		return nil
	end
	local menuModule = StaffDelivery.Give(player, MENU_BUNDLE)
	if not menuModule then
		return nil
	end

	local catalog: { [string]: any } = {
		Server = {
			PlaceId = game.PlaceId,
			PlaceVersion = game.PlaceVersion,
			JobId = game.JobId,
			Studio = RunService:IsStudio(),
			Private = game.PrivateServerId ~= "",
			MaxPlayers = Players.MaxPlayers,
			Role = Permissions.GetRole(player.UserId),
		},
	}
	for _, module in COMMAND_MODULES do
		if module.GetCatalog then
			for key, value in module.GetCatalog() do
				catalog[key] = value
			end
		end
	end
	return { Module = menuModule, Key = AdminConfig.DevMenuKey, Catalog = catalog }
end

function DevService.Client:Execute(player: Player, action: unknown, targetUserId: unknown, ...: unknown): (boolean, string)
	if not isAllowed(player) then
		return false, UNKNOWN
	end

	local name = if type(action) == "string" and #action <= MAX_ACTION_LENGTH then action else nil
	local handler = if name then handlers[name] else nil
	if not limiter:Consume(player, if name and handler then costs[name] else 1) then
		return false, "slow down"
	end

	local target = getTarget(player, targetUserId)
	if not name or not handler or not target then
		return false, UNKNOWN
	end

	local ok, success, message = pcall(handler, player, target, ...)
	if not ok then
		warn(`[DevService] {name} failed: {success}`)
		return false, "error (see the server output)"
	end
	AuditLog.Record(player, `dev:{name}`, `{target.Name}: {message}`)
	return success, message
end

function DevService.Client:GetSnapshot(player: Player, targetUserId: unknown): { [string]: any }?
	if not isAllowed(player) or not snapshotLimiter:Consume(player) then
		return nil
	end
	watchFrameTime()

	-- As in describeServer: a system this place does not load counts as empty.
	local CharacterService = Optional.Service("CharacterService")
	local EnemyService = Optional.Service("EnemyService")
	local ChestService = Optional.Service("ChestService")
	local TimeService = Optional.Service("TimeService")
	local WorldEventService = Optional.Service("WorldEventService")

	local entityCount = 0
	for _ in if CharacterService then CharacterService:GetEntities() else {} do
		entityCount += 1
	end

	local snapshot: { [string]: any } = {
		ServerFps = math.floor(1 / frameTime + 0.5),
		PhysicsFps = math.floor(Workspace:GetRealPhysicsFPS() + 0.5),
		MemoryMb = math.floor(Stats:GetTotalMemoryUsageMb()),
		Instances = Stats.InstanceCount,
		SendKbps = Stats.DataSendKbps,
		ReceiveKbps = Stats.DataReceiveKbps,
		Uptime = math.floor(Workspace.DistributedGameTime),
		Players = #Players:GetPlayers(),
		Entities = entityCount,
		Enemies = if EnemyService then EnemyService:GetCount() else 0,
		Chests = if ChestService then ChestService:GetCount() else 0,
		ClockTime = if TimeService then TimeService:GetClockTime() else 0,
		ClockRate = Workspace:GetAttribute(TimeConfig.Attributes.Rate),
		Night = TimeService ~= nil and TimeService:IsNight(),
		Event = (WorldEventService and WorldEventService:GetActive()) or "none",
	}

	local target = getTarget(player, targetUserId)
	if target then
		for _, module in COMMAND_MODULES do
			if module.GetState then
				for key, value in module.GetState(target) do
					snapshot[key] = value
				end
			end
		end
	end
	return snapshot
end

--[[
	Read-only details the menu asks for on demand, never on a timer:
	"Server"  who is here (role, ping, device, character), season flags, server switches
	          and the tail of the audit log
	"Data"    the saved profile of the target, as it is in memory
]]
function DevService.Client:GetReport(player: Player, kind: unknown, targetUserId: unknown): { [string]: any }?
	if not isAllowed(player) or not snapshotLimiter:Consume(player, REPORT_COST) then
		return nil
	end

	if kind == "Server" then
		return describeServer()
	elseif kind == "Data" then
		local target = getTarget(player, targetUserId)
		local data = target and DevKit.Data(target)
		if target and data then
			-- Reading somebody else's profile is a privileged action like any other.
			if target ~= player then
				AuditLog.Record(player, "dev:ReadData", target.Name)
			end
			return { Name = target.Name, UserId = target.UserId, Data = data.Data }
		end
	end
	return nil
end

function DevService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		limiter:Forget(player)
		snapshotLimiter:Forget(player)
	end)
end

return DevService
