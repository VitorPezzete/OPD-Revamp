--!strict
--[[
	Private servers.

	Two kinds exist:
	- Roblox private servers (game.PrivateServerOwnerId ~= 0): owner known at boot.
	- Code servers: a player buys 30 days (developer product), generates a 6 character
	  code and shares it. The code maps to a reserved server; whoever knows the code can
	  join, so replacing the code is how the owner locks people out (everyone but staff
	  in the old server is removed).

	What "private" changes for gameplay (no stat progression, VIP compass tokens, owner
	only purchases...) belongs to the systems concerned. They ask:

		PrivateServerService:IsPrivate() -> boolean
		PrivateServerService:GetOwnerId() -> number      (0 when unknown / public)
		PrivateServerService:IsOwner(player) -> boolean
		PrivateServerService.Changed (isPrivate, ownerId)
		Workspace attributes "PrivateServer" / "PrivateServerOwner" for the client

	Staff tooling (console commands) uses FindPlayerCode, TeleportToCode, GetActiveServers.
	Purchases arrive through MonetizationService's "PrivateServer" grant handler.

	Developer tooling (Server.Modules.DevPrivateCommands, behind DevService and nothing
	else) tests all of the above without a purchase:

		PrivateServerService:Simulate(ownerUserId?)   this server behaves as that user's
		                                              private server; nil ends it
		PrivateServerService:Describe()               what the server is and behaves as
		PrivateServerService:GrantSubscription(player, granter)
		PrivateServerService:RevokeSubscription(player, revoker)
		PrivateServerService:GetSubscriptionStatus(player)

	A simulation changes the answers above, the attributes and the switches, never what
	the server really is: its code, its entry in the active list and the identification
	of a reserved server keep following the real state, and ending the simulation goes
	back to exactly that.

	Legacy holes closed:
	- A reserved server believed any VIPCode found in the first player's TeleportData,
	  including one a client attached to its own teleport: it then exposed that code's
	  owner-only purchases. The data is now only read when the teleport came from this
	  game's servers, and the code must be the one whose record points at this server.
	- Buying without a code wrote the placeholder key "Generate a Code" into the code
	  store (one shared record for every such buyer). A code is generated right away.
	- Code generation looped forever on a DataStore failure and could overwrite a live code.
	- The global list of active servers was one DataStore key rewritten on every join and
	  never cleaned after a crash. It is a MemoryStore map that expires on its own.
]]
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)

local AuditLog = require(ServerStorage.Server.Modules.AuditLog)
local DataStoreUtil = require(ServerStorage.Server.Modules.DataStoreUtil)
local Permissions = require(ServerStorage.Server.Modules.Permissions)
local PrivateServerConfig = require(ServerStorage.Server.Configs.PrivateServerConfig)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

type Subscription = { Player: string?, UserId: number?, Code: string?, TimeLimit: number? }
type CodeRecord = { Player: string?, UserId: number?, PSCode: string?, TimeLimit: number?, ServerId: string? }

export type Status = { Code: string?, DaysLeft: number }
export type ActiveServer = { Code: string, Owner: string, OwnerId: number, Players: number }
export type Description = {
	-- What the server behaves as.
	Private: boolean,
	OwnerId: number,
	Simulated: boolean,
	-- What it really is.
	Kind: "Public" | "Roblox" | "Code",
	RealOwnerId: number,
	Code: string?,
	-- False where the stores are not opened (Studio): no subscription can be read or written.
	Stores: boolean,
}

local TOPIC = "RemoveCode"
local UNAVAILABLE = "Private servers are unavailable right now, try again in a moment."
local CODE_PATTERN = "^%w+$"
-- Service -> boolean field that is true while progression / rewards are allowed.
local PROGRESSION_SWITCHES: { [string]: string } = {
	StatService = "ProgressionEnabled",
	RewardService = "Enabled",
	CacheService = "RewardsEnabled",
	FishingService = "RewardsEnabled",
	MerlinService = "RewardsEnabled",
}

local PrivateServerService = Knit.CreateService({
	Name = "PrivateServerService",
	Client = {
		-- (status: Status) after the caller's code or time changed.
		Status = Knit.CreateSignal(),

		-- Replaces the caller's code with a new one (needs time left).
		Generate = Knit.CreateSignal(),
		-- (code: string) teleports the caller to that private server.
		Join = Knit.CreateSignal(),
		-- Opens the purchase prompt for 30 days.
		Buy = Knit.CreateSignal(),
		-- (target: Player) owner of this private server removes a player.
		Kick = Knit.CreateSignal(),
	},
})

-- (isPrivate, ownerId)
PrivateServerService.Changed = Signal.new() :: Signal.Signal<boolean, number>

local NotifyService
local MonetizationService: any = nil

local subscriptions: DataStore? = nil
local codes: DataStore? = nil
local presence: MemoryStoreSortedMap? = nil
local active: MemoryStoreSortedMap? = nil

-- What the server behaves as: the real state below, unless a developer is simulating.
local isPrivate = false
local ownerId = 0
-- What the server really is.
local realPrivate = false
local realOwnerId = 0
local simulating = false
-- Values the progression switches had before the simulation turned them off.
local savedSwitches: { [string]: boolean }? = nil
local ownerName = ""
local serverCode: string? = nil
local identifying = false

local busy: { [Player]: boolean } = {}
local actionLimiter = RateLimiter.new(2, 0.5)
local statusLimiter = RateLimiter.new(3, 0.2)
local random = Random.new()

local function today(): number
	return os.time() // 86400
end

local function isCode(value: unknown): boolean
	return type(value) == "string"
		and #value == PrivateServerConfig.CodeLength
		and string.match(value, CODE_PATTERN) ~= nil
end

local function notify(player: Player, text: string, kind: string?)
	NotifyService:Send(player, text, kind or "Error")
end

local function toStatus(subscription: Subscription?): Status
	local limit = if subscription then tonumber(subscription.TimeLimit) or 0 else 0
	local code = if subscription then subscription.Code else nil
	return {
		Code = if isCode(code) then code else nil,
		DaysLeft = math.clamp(limit - today(), 0, PrivateServerConfig.MaxDaysShown),
	}
end

local function memoryCall(call: () -> any): (boolean, any)
	local ok, result = pcall(call)
	if not ok then
		warn(`[PrivateServer] memory store: {result}`)
	end
	return ok, result
end

-- Tells everybody what the server behaves as: the client (attributes), the purchases
-- (owner-only products, VIP tokens) and whoever listens to Changed.
local function publish()
	Workspace:SetAttribute("PrivateServer", if isPrivate then true else nil)
	Workspace:SetAttribute("PrivateServerOwner", if isPrivate then ownerId else nil)
	if MonetizationService then
		MonetizationService:SetPrivateServerOwner(if isPrivate then ownerId else nil)
	end
	PrivateServerService.Changed:Fire(isPrivate, ownerId)
end

--[[
	These services decide at load time from game.PrivateServerOwnerId, which is 0 in a
	code server. Their switches are public fields, so they are turned off from here.
	Returns what each one was, for a simulation to put back.
]]
local function turnSwitchesOff(): { [string]: boolean }
	local previous: { [string]: boolean } = {}
	for serviceName, field in PROGRESSION_SWITCHES do
		local ok, service = pcall(Knit.GetService, serviceName)
		if ok and type(service) == "table" and type(service[field]) == "boolean" then
			previous[serviceName] = service[field]
			service[field] = false
		end
	end
	return previous
end

local function setPrivate(owner: number, code: string?)
	-- The server turned out to be private for real (a reserved server identified while a
	-- developer was simulating): the real state wins and there is nothing left to restore.
	simulating = false
	savedSwitches = nil

	realPrivate = true
	realOwnerId = owner
	isPrivate = true
	ownerId = owner
	serverCode = code

	turnSwitchesOff()
	publish()
end

local function markPresence(player: Player)
	local map, code = presence, serverCode
	if map and code then
		memoryCall(function()
			map:SetAsync(
				tostring(player.UserId),
				{ ServerId = game.JobId, VIPCode = code },
				PrivateServerConfig.PresenceSeconds
			)
		end)
	end
end

local function markActive()
	local map, code = active, serverCode
	if map and code then
		memoryCall(function()
			map:SetAsync(
				code,
				{ Player = ownerName, UserId = realOwnerId, Players = #Players:GetPlayers() },
				PrivateServerConfig.PresenceSeconds
			)
		end)
	end
end

-- Only code servers run this: one loop keeps both maps alive while the server lives.
local function startRefreshing()
	task.spawn(function()
		while serverCode do
			markActive()
			for _, player in Players:GetPlayers() do
				markPresence(player)
			end
			task.wait(PrivateServerConfig.RefreshSeconds)
		end
	end)
end

--[[
	A reserved server learns which code it belongs to from the first trusted arrival.
	TeleportData can be forged by a client-initiated teleport, so it only counts when the
	player came from this experience, and the code's own record has the last word.
]]
local function identify(player: Player)
	-- The real state: a simulation must not stop a reserved server from learning its code.
	if realPrivate or identifying or not codes then
		return
	end

	local joinData = player:GetJoinData()
	local teleportData: any = joinData.TeleportData
	local code = if type(teleportData) == "table" then teleportData.VIPCode else nil
	if joinData.SourceGameId ~= game.GameId or not isCode(code) then
		return
	end

	identifying = true
	local ok, record: CodeRecord? = DataStoreUtil.Get(codes, code)
	identifying = false
	if not ok or type(record) ~= "table" or realPrivate then
		return
	end
	-- Records made before the rewrite have no ServerId: the code is all there is to check.
	if record.ServerId ~= nil and record.ServerId ~= game.PrivateServerId then
		return
	end

	ownerName = if type(record.Player) == "string" then record.Player else ""
	setPrivate(tonumber(record.UserId) or 0, code)
	startRefreshing()
end

local function loadSubscription(player: Player): (boolean, Subscription?)
	if not subscriptions then
		return false, nil
	end
	local ok, result = DataStoreUtil.Get(subscriptions, tostring(player.UserId))
	return ok, if ok and type(result) == "table" then result else nil
end

-- Reserves a server and claims an unused code for it. Returns the code.
local function createCode(player: Player, timeLimit: number): string?
	local store = codes
	if not store then
		return nil
	end

	local ok, accessCode, serverId = pcall(TeleportService.ReserveServerAsync, TeleportService, game.PlaceId)
	if not ok or type(accessCode) ~= "string" then
		warn(`[PrivateServer] could not reserve a server: {accessCode}`)
		return nil
	end

	local alphabet = PrivateServerConfig.CodeAlphabet
	for _ = 1, 5 do
		local characters = table.create(PrivateServerConfig.CodeLength)
		for index = 1, PrivateServerConfig.CodeLength do
			local position = random:NextInteger(1, #alphabet)
			characters[index] = string.sub(alphabet, position, position)
		end
		local code = table.concat(characters)

		local record: CodeRecord = {
			Player = player.Name,
			UserId = player.UserId,
			PSCode = accessCode,
			TimeLimit = timeLimit,
			ServerId = serverId,
		}
		-- Never overwrites: a taken code is somebody's live server.
		local written, value = DataStoreUtil.Update(store, code, function(current: any): any
			return if current == nil then record else nil
		end)
		if not written then
			return nil
		elseif value ~= nil then
			return code
		end
	end
	return nil
end

local function retireCode(code: string?)
	if not isCode(code) or not codes then
		return
	end
	DataStoreUtil.Remove(codes, code :: string)
	pcall(MessagingService.PublishAsync, MessagingService, TOPIC, {
		Code = code,
		Reason = PrivateServerConfig.CodeChangedMessage,
	})
end

local function sendStatus(player: Player, subscription: Subscription?)
	if player.Parent == Players then
		PrivateServerService.Client.Status:Fire(player, toStatus(subscription))
	end
end

local function generate(player: Player)
	local ok, subscription = loadSubscription(player)
	if not ok or not subscriptions then
		notify(player, UNAVAILABLE)
		return
	end
	if not subscription or (tonumber(subscription.TimeLimit) or 0) < today() then
		notify(player, "Buy private server time first.")
		return
	end

	local timeLimit = tonumber(subscription.TimeLimit) or 0
	local newCode = createCode(player, timeLimit)
	if not newCode then
		notify(player, UNAVAILABLE)
		return
	end

	local oldCode: string? = nil
	local written, updated = DataStoreUtil.Update(subscriptions, tostring(player.UserId), function(current: any): any
		if type(current) ~= "table" then
			return nil
		end
		oldCode = current.Code
		current.Player = player.Name
		current.UserId = player.UserId
		current.Code = newCode
		return current
	end)
	if not written or type(updated) ~= "table" then
		if codes then
			DataStoreUtil.Remove(codes, newCode)
		end
		notify(player, UNAVAILABLE)
		return
	end

	retireCode(oldCode)
	AuditLog.Record(player, "private.generate", newCode)
	sendStatus(player, updated)
end

-- The code record carries its own expiry; if a renewal failed to reach it, the owner's
-- subscription is the reference and the record is repaired.
local function isExpired(code: string, record: CodeRecord): boolean
	if (tonumber(record.TimeLimit) or 0) >= today() then
		return false
	end

	local owner = tonumber(record.UserId)
	if not owner or not subscriptions or not codes then
		return true
	end
	local ok, subscription = DataStoreUtil.Get(subscriptions, tostring(owner))
	if not ok or type(subscription) ~= "table" or subscription.Code ~= code then
		return true
	end

	local limit = tonumber(subscription.TimeLimit) or 0
	if limit < today() then
		return true
	end
	DataStoreUtil.Update(codes, code, function(current: any): any
		if type(current) ~= "table" then
			return nil
		end
		current.TimeLimit = limit
		return current
	end)
	return false
end

local function teleport(player: Player, code: string, record: CodeRecord): boolean
	if type(record.PSCode) ~= "string" then
		return false
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = record.PSCode
	options:SetTeleportData({ VIPCode = code })

	local ok, problem = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player }, options)
	if not ok then
		warn(`[PrivateServer] teleport failed: {problem}`)
	end
	return ok
end

local function join(player: Player, code: unknown)
	if not isCode(code) or not codes then
		notify(player, "That code is not valid.")
		return
	end

	local ok, record = DataStoreUtil.Get(codes, code :: string)
	if not ok then
		notify(player, UNAVAILABLE)
	elseif type(record) ~= "table" or isExpired(code :: string, record) then
		notify(player, "That code is not valid or has expired.")
	elseif not teleport(player, code :: string, record) then
		notify(player, "The teleport failed, try again.")
	end
end

local function buy(player: Player)
	if MonetizationService then
		MonetizationService:PromptProduct(player, "PrivateServerMonth")
	else
		notify(player, UNAVAILABLE)
	end
end

-- Not in the legacy game, where the only way to remove someone was a new code.
local function kick(player: Player, target: unknown)
	if not isPrivate or ownerId ~= player.UserId then
		return
	end
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target.Parent ~= Players or target == player then
		return
	end
	if Permissions.IsStaff(target) then
		notify(player, "Staff cannot be removed.")
		return
	end

	AuditLog.Record(player, "private.kick", target.Name)
	target:Kick("Removed by the private server owner.")
end

local function runAction(action: (player: Player, ...unknown) -> (), player: Player, ...: unknown)
	if busy[player] or not actionLimiter:Consume(player) then
		return
	end

	busy[player] = true
	local ok, problem = pcall(action, player, ...)
	busy[player] = nil
	if not ok then
		warn(`[PrivateServer] action failed for {player.Name}: {problem}`)
	end
end

local function onCodeRetired(message: any)
	local payload = message.Data
	if type(payload) ~= "table" or serverCode == nil or payload.Code ~= serverCode then
		return
	end

	local reason = if type(payload.Reason) == "string" then payload.Reason else PrivateServerConfig.CodeChangedMessage
	local map, code = active, serverCode
	serverCode = nil
	if map and code then
		memoryCall(function()
			map:RemoveAsync(code)
		end)
	end
	for _, player in Players:GetPlayers() do
		if not Permissions.IsStaff(player) then
			player:Kick(reason)
		end
	end
end

function PrivateServerService:IsPrivate(): boolean
	return isPrivate
end

function PrivateServerService:GetOwnerId(): number
	return ownerId
end

function PrivateServerService:IsOwner(player: Player): boolean
	return isPrivate and ownerId ~= 0 and ownerId == player.UserId
end

--[[
	Adds a purchase to a player's subscription: 30 days from today, or from the current
	end if there is time left. Returns true once the time is stored. Yields.

	`granter` is the developer giving the time away (developer menu): the same path as a
	purchase, so a free month does what a paid one does. Only the audit line differs.
]]
function PrivateServerService:GrantSubscription(player: Player, granter: Player?): boolean
	if not subscriptions then
		return false
	end

	local ok, updated = DataStoreUtil.Update(subscriptions, tostring(player.UserId), function(current: any): any
		local subscription: Subscription = if type(current) == "table" then current else {}
		local base = math.max(tonumber(subscription.TimeLimit) or 0, today())
		subscription.TimeLimit = base + PrivateServerConfig.DaysPerPurchase
		subscription.Player = player.Name
		subscription.UserId = player.UserId
		return subscription
	end)
	if not ok or type(updated) ~= "table" then
		return false
	end

	-- The time is paid for and stored; what follows is best effort and repairs itself
	-- (isExpired re-reads the subscription, Generate makes a code).
	task.spawn(function()
		local subscription: Subscription = updated
		local limit = tonumber(subscription.TimeLimit) or 0
		if isCode(subscription.Code) and codes then
			DataStoreUtil.Update(codes, subscription.Code :: string, function(current: any): any
				if type(current) ~= "table" then
					return nil
				end
				current.TimeLimit = limit
				return current
			end)
			sendStatus(player, subscription)
		elseif not busy[player] then
			busy[player] = true
			pcall(generate, player)
			busy[player] = nil
		end
	end)

	if granter then
		AuditLog.Record(granter, "private.grant", `{player.Name} ({player.UserId}) until day {updated.TimeLimit}`)
	else
		AuditLog.Record(player, "private.purchase", `until day {updated.TimeLimit}`)
	end
	return true
end

--[[
	Ends a player's subscription now: no time left and no code. The code is retired the
	way a replaced one is, so its server empties (staff stay) and nobody can join it again.
	Developer menu only: nothing in the game takes paid time away. Yields.
]]
function PrivateServerService:RevokeSubscription(player: Player, revoker: Player): (boolean, string)
	local store = subscriptions
	if not store then
		return false, "the subscription store is not opened here (Studio)"
	end
	-- A code being generated for this player would be written back after the revoke.
	if busy[player] then
		return false, `{player.Name} has a private server request in progress, try again`
	end

	busy[player] = true
	local oldCode: string? = nil
	local ok, updated = DataStoreUtil.Update(store, tostring(player.UserId), function(current: any): any
		if type(current) ~= "table" then
			return nil
		end
		oldCode = current.Code
		current.TimeLimit = today() - 1
		current.Code = nil
		return current
	end)
	busy[player] = nil

	if not ok then
		return false, "the subscription store did not answer"
	elseif type(updated) ~= "table" then
		return false, `{player.Name} has no subscription`
	end

	retireCode(oldCode)
	AuditLog.Record(revoker, "private.revoke", `{player.Name} ({player.UserId}), code {tostring(oldCode)}`)
	sendStatus(player, updated)
	return true, `{player.Name}: subscription ended{if isCode(oldCode) then `, code {oldCode} retired` else ""}`
end

-- A player's code and days left, read from the store (nil when it cannot be read). Yields.
function PrivateServerService:GetSubscriptionStatus(player: Player): Status?
	local ok, subscription = loadSubscription(player)
	return if ok then toStatus(subscription) else nil
end

--[[
	Developer menu only. Makes this server behave as the private server of `ownerUserId`:
	progression and rewards off, VIP token claims, owner-only purchases and removals, the
	attributes the client reads. nil ends the simulation and puts back what the server
	really is, switches included.

	It can only add to the real state: a server that is private for real stays private
	when the simulation ends (with its real owner), and there is nothing to end otherwise.
]]
function PrivateServerService:Simulate(ownerUserId: number?): (boolean, string)
	if ownerUserId == nil then
		if not simulating then
			return false,
				if realPrivate then "this server really is private: nothing is simulated" else "nothing is simulated"
		end

		simulating = false
		isPrivate = realPrivate
		ownerId = realOwnerId

		local saved = savedSwitches
		savedSwitches = nil
		for serviceName, value in saved or {} do
			local ok, service = pcall(Knit.GetService, serviceName)
			if ok and type(service) == "table" then
				service[PROGRESSION_SWITCHES[serviceName]] = value
			end
		end
		publish()
		return true,
			if realPrivate
				then `simulation ended: private server of {realOwnerId} again`
				else "simulation ended: public server again"
	end

	-- Studio test clients have negative ids; 0 is "no owner".
	if ownerUserId ~= ownerUserId or ownerUserId % 1 ~= 0 or ownerUserId == 0 then
		return false, "invalid owner"
	end

	-- Changing the simulated owner keeps the values remembered by the first call.
	if not simulating then
		simulating = true
		savedSwitches = turnSwitchesOff()
	end
	isPrivate = true
	ownerId = ownerUserId
	publish()
	return true, `simulating the private server of {ownerUserId}`
end

function PrivateServerService:Describe(): Description
	return {
		Private = isPrivate,
		OwnerId = ownerId,
		Simulated = simulating,
		Kind = if not realPrivate then "Public" elseif game.PrivateServerOwnerId ~= 0 then "Roblox" else "Code",
		RealOwnerId = realOwnerId,
		Code = serverCode,
		Stores = subscriptions ~= nil,
	}
end

-- Code of the private server a user is in right now, if any (staff "follow").
function PrivateServerService:FindPlayerCode(userId: number): string?
	local map = presence
	if not map then
		return nil
	end
	local ok, entry = memoryCall(function()
		return (map:GetAsync(tostring(userId)))
	end)
	local code = if ok and type(entry) == "table" then entry.VIPCode else nil
	return if isCode(code) then code else nil
end

-- Sends a player into the server behind a code, expired or not (staff only: callers check).
function PrivateServerService:TeleportToCode(player: Player, code: string): boolean
	if not isCode(code) or not codes then
		return false
	end
	local ok, record = DataStoreUtil.Get(codes, code)
	return ok and type(record) == "table" and teleport(player, code, record)
end

function PrivateServerService:GetActiveServers(): { ActiveServer }
	local servers: { ActiveServer } = {}
	local map = active
	if not map then
		return servers
	end

	local ok, entries = memoryCall(function()
		return map:GetRangeAsync(Enum.SortDirection.Ascending, 100)
	end)
	if ok and type(entries) == "table" then
		for _, entry in entries do
			local value = entry.value
			if type(value) == "table" then
				table.insert(servers, {
					Code = entry.key,
					Owner = tostring(value.Player),
					OwnerId = tonumber(value.UserId) or 0,
					Players = tonumber(value.Players) or 0,
				})
			end
		end
	end
	return servers
end

-- The caller's code and days left. One DataStore read: the screen asks when it opens.
function PrivateServerService.Client:GetStatus(player: Player): Status?
	if busy[player] or not statusLimiter:Consume(player) then
		return nil
	end
	local ok, subscription = loadSubscription(player)
	return if ok then toStatus(subscription) else nil
end

function PrivateServerService:KnitInit()
	NotifyService = Knit.GetService("NotifyService")
	local ok, service = pcall(Knit.GetService, "MonetizationService")
	MonetizationService = if ok then service else nil

	if not RunService:IsStudio() then
		subscriptions = DataStoreUtil.GetStore(PrivateServerConfig.SubscriptionStore)
		codes = DataStoreUtil.GetStore(PrivateServerConfig.CodeStore)
		local mapsOk, problem = pcall(function()
			presence = MemoryStoreService:GetSortedMap(PrivateServerConfig.PresenceMap)
			active = MemoryStoreService:GetSortedMap(PrivateServerConfig.ActiveMap)
		end)
		if not mapsOk then
			warn(`[PrivateServer] memory store unavailable: {problem}`)
		end
	end
end

function PrivateServerService:KnitStart()
	if game.PrivateServerOwnerId ~= 0 then
		setPrivate(game.PrivateServerOwnerId, nil)
	end

	if MonetizationService then
		MonetizationService:SetGrantHandler("PrivateServer", function(recipient: Player): boolean
			return PrivateServerService:GrantSubscription(recipient)
		end)
	end

	local client = PrivateServerService.Client
	client.Generate:Connect(function(player: Player)
		runAction(generate, player)
	end)
	client.Join:Connect(function(player: Player, code: unknown)
		runAction(join, player, code)
	end)
	client.Buy:Connect(function(player: Player)
		runAction(buy, player)
	end)
	client.Kick:Connect(function(player: Player, target: unknown)
		runAction(kick, player, target)
	end)

	-- Only a reserved server can be a code server, and only of the main place: the
	-- reserved servers of the other places (raids) are not private servers.
	local reserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 and PlaceConfig.Role == "Main"
	local function onPlayerAdded(player: Player)
		if reserved then
			identify(player)
			markPresence(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		busy[player] = nil
		actionLimiter:Forget(player)
		statusLimiter:Forget(player)

		local map = presence
		if map and serverCode then
			task.spawn(memoryCall, function()
				map:RemoveAsync(tostring(player.UserId))
			end)
		end
	end)

	game:BindToClose(function()
		local map, code = active, serverCode
		if map and code then
			memoryCall(function()
				map:RemoveAsync(code)
			end)
		end
	end)

	task.spawn(function()
		local ok, problem = pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, onCodeRetired)
		if not ok then
			warn(`[PrivateServer] code changes will not reach this server: {problem}`)
		end
	end)
end

return PrivateServerService
