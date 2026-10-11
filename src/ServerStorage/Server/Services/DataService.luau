--!strict
--[[
	Owns player sessions (ProfileStore) and replicates data to its owner.

	Server API
		DataService:GetData(player) -> PlayerData?
		DataService:ObserveData(callback) -> calls back for every loaded player, present and future
		DataService.Loaded / DataService.Releasing (player, playerData)
		DataService:SetLoadGate(gate)          -> see below (Server.Services.BackupService)
		DataService:EndSession(player, message) -> kicks with that message and saves; false when not loaded
		DataService:SendMessage(userId, message) -> boolean, a ProfileStore message to a profile. Yields.

	Clients never write data and the service exposes no inbound remote: the full
	table is pushed once on load (delta with an empty path) and deltas follow.

	Profiles of the game before the rework live under the same keys in the old game's
	shape. One is converted the first time it loads (Server.Modules.LegacyDataMigration),
	before anything reads it, and the old save is kept whole inside the profile under
	`_legacy`. A profile that cannot be converted is left exactly as it was and its owner
	is kicked: it is never reconciled or written over half-read.

	The load gate is the one step that may still rewrite a profile after that: it runs with
	the player and the ProfileStore profile once the data is converted and reconciled, and
	before the session exists (nothing has read the data yet, nothing was replicated). It
	may yield and change profile.Data in place. BackupService uses it to copy the data for
	the daily snapshot and to apply a restore or a global rollback that was waiting for
	this player. It can delay a join, never fail one: an error in it is only a warning.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)
local ProfileStore = require(ServerStorage.Server.Packages.ProfileStore)

local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)
local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local DataTemplate = require(ServerStorage.Server.Configs.DataTemplate)
local LegacyDataMigration = require(ServerStorage.Server.Modules.LegacyDataMigration)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)

type PlayerData = PlayerData.PlayerData

-- Accounts created before this timestamp keep the alpha tester badge.
local ALPHA_TESTER_CUTOFF = 1764445717

local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {
		-- Fires with a list of DataDelta, at most once per frame per player.
		Replicate = Knit.CreateSignal(),
	},
})

DataService.Loaded = Signal.new() :: Signal.Signal<Player, PlayerData>
DataService.Releasing = Signal.new() :: Signal.Signal<Player, PlayerData>

local store: any
local sessions: { [Player]: PlayerData } = {}
local pending: { [Player]: { DataTypes.DataDelta } } = {}
local loadGate: ((player: Player, profile: any) -> ())? = nil

local function flushReplication()
	if next(pending) == nil then
		return
	end

	for player, deltas in pending do
		DataService.Client.Replicate:Fire(player, deltas)
	end
	table.clear(pending)
end

local function queueDelta(player: Player, path: string, value: any)
	local deltas = pending[player]
	if not deltas then
		deltas = {}
		pending[player] = deltas
	end
	table.insert(deltas, { Path = path, Value = value })
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

-- Swaps an old profile's content for its converted form, in place (the profile keeps
-- its table). False when it could not be converted: nothing was changed then.
local function migrate(player: Player, data: { [string]: any }): boolean
	local ok, converted = pcall(function()
		local backup = deepCopy(data)
		local result = LegacyDataMigration.Convert(data)
		result._legacy = backup
		result._version = DataTemplate.Version
		return result
	end)
	if not ok or type(converted) ~= "table" then
		warn(`[DataService] profile of {player.UserId} could not be converted: {converted}`)
		return false
	end
	table.clear(data)
	for key, value in converted do
		data[key] = value
	end
	print(`[DataService] profile of {player.UserId} converted from the old game`)
	return true
end

local function startSession(player: Player)
	local profile = store:StartSessionAsync(DataTemplate.KeyPrefix .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick("Failed to load your data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	if LegacyDataMigration.IsLegacy(profile.Data) and not migrate(player, profile.Data) then
		-- Untouched: ending the session saves it as it was loaded.
		profile:EndSession()
		player:Kick("Your data could not be loaded. It is safe; please report this and rejoin later.")
		return
	end
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		local session = sessions[player]
		if session then
			sessions[player] = nil
			pending[player] = nil
			DataService.Releasing:Fire(player, session)
			session:Destroy()
		end
		player:Kick("Your session ended. Please rejoin, your data is safe.")
	end)

	if loadGate then
		local ok, problem = pcall(loadGate, player, profile)
		if not ok then
			warn(`[DataService] load gate failed for {player.UserId}: {problem}`)
		end
	end

	-- The gate may have yielded: the session can have ended meanwhile (EndSession is a
	-- no-op then), with or without the player leaving.
	if player.Parent ~= Players or not profile:IsActive() then
		profile:EndSession()
		return
	end

	local session = PlayerData.new(player, profile)
	if session.FirstSessionTime > 0 and session.FirstSessionTime < ALPHA_TESTER_CUTOFF then
		session.Data.Spec.AlphaTester = true
	end

	session.Changed:Connect(function(path: string, value: any)
		queueDelta(player, path, value)
	end)

	sessions[player] = session
	-- Everything but the old save kept by the conversion: the client has no use for it.
	local visible = table.clone(session.Data :: any)
	visible._legacy = nil
	queueDelta(player, "", visible)
	DataService.Loaded:Fire(player, session)
end

local function endSession(player: Player)
	local session = sessions[player]
	if session then
		-- OnSessionEnd does the cleanup, so there is a single teardown path.
		session._profile:EndSession()
	end
end

function DataService:GetData(player: Player): PlayerData?
	return sessions[player]
end

-- Runs callback for every player whose data is loaded, now and in the future.
function DataService:ObserveData(callback: (player: Player, data: PlayerData) -> ())
	for player, session in sessions do
		task.spawn(callback, player, session)
	end
	return DataService.Loaded:Connect(callback)
end

-- One gate, set during KnitInit: sessions only start in KnitStart.
function DataService:SetLoadGate(gate: (player: Player, profile: any) -> ())
	assert(loadGate == nil, "[DataService] the load gate is already set")
	loadGate = gate
end

--[[
	Ends a loaded player's session on purpose: after their data was swapped for a backup,
	every system has to start again from the saved table. The first kick is the one the
	player reads, so it comes before the session end (whose own kick is for sessions that
	end unasked). The session stops accepting writes at once and the last save follows.
]]
function DataService:EndSession(player: Player, message: string): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	player:Kick(message)
	session._profile:EndSession()
	return true
end

--[[
	Leaves a message in a profile (ProfileStore:MessageAsync), wherever its owner is: the
	server holding the session receives it within seconds, and a profile nobody has loaded
	gets it when it next loads. Handlers are set on the profile (profile:MessageHandler),
	which the load gate receives. Yields; false when it could not be stored.
]]
function DataService:SendMessage(userId: number, message: { [string]: any }): boolean
	local ok, sent = pcall(function()
		return store:MessageAsync(DataTemplate.KeyPrefix .. userId, message)
	end)
	if not ok then
		warn(`[DataService] message to {userId} failed: {sent}`)
	end
	return ok and sent == true
end

function DataService:KnitInit()
	store = ProfileStore.New(DataTemplate.StoreName, DataTemplate.Template)
	if RunService:IsStudio() or PlaceConfig.Role == "Dev" then
		-- Studio sessions never touch live player data, and neither does the development
		-- place, published or not: what is tried there must not end up in a real profile.
		store = store.Mock
	end
end

function DataService:KnitStart()
	Players.PlayerAdded:Connect(startSession)
	Players.PlayerRemoving:Connect(endSession)
	for _, player in Players:GetPlayers() do
		task.spawn(startSession, player)
	end

	RunService.Heartbeat:Connect(flushReplication)
end

return DataService
