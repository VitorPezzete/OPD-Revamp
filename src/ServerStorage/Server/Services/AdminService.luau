--!strict
--[[
	Staff tooling: the moderator menu, bans, cross-server kicks, the join/leave log and
	spectating. Replaces the legacy `Commands`, `Spec`, `Cultist` and `VipList` GUIs and
	the two remotes behind them (`Connections.Special`, `GlobalReference.Spec`).

	What a client can see of it
	A Knit service always shows its name and its remote names to every client, so there
	are only two, and neither says what staff can do:

		GetAccess()               nil, or what a moderator's client needs to load the menu
		Execute(action, payload)  ok, message, result?

	The menu's code is not in the client: it lives in ServerStorage (Server.StaffClient.Mod)
	and StaffDelivery copies it into the PlayerGui of a moderator, which replicates to
	that player alone. A player without the role is answered nil by GetAccess and the
	same "unknown request" by Execute whatever was asked, exactly as a moderator is for
	an action that does not exist: nothing can be probed.

	How a request is authorised
	1. Role Mod or above (Permissions), then a rate limit, before anything is read.
	2. Server.Modules.StaffActions reads the payload field by field and runs the action;
	   the player actions go on to Server.Modules.CommandRunner and the very commands of
	   Server.Modules.Commands.
	3. Whatever changes a player asks Permissions.CanTarget: staff only act on someone
	   they outrank.
	4. Every action and every refusal is written to the AuditLog.

	There is no typed console: Cmdr copies the definition of every command into
	ReplicatedStorage for its autocomplete, where every client can read it.

	Legacy holes closed
	- `if permission == "Owner" or "Mod"`: every player could global-kick anyone.
	- Data_Set / Data_Add / Data_Global, box and fruit spawning were reachable by firing
	  the remote; a failed check kicked the caller instead of stopping an earlier branch.
	- The GUIs were cloned into PlayerGui by role, but the remotes behind them accepted
	  calls from clients that never had the GUI.
	- Bans were a DataStore flag checked on join in one script, with a hardcoded exempt id.

	Server API
		AdminService:Ban(executor, userId, seconds?, reason) -> (ok, message)
		AdminService:Unban(executor, userId) -> (ok, message)
		AdminService:GlobalKick(executor, userId, reason) -> (ok, message)
		AdminService:Spectate(executor, target?)
		AdminService:GetJoinLog() -> { JoinLogEntry }
]]
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AdminConfig = require(ServerStorage.Server.Configs.AdminConfig)
local AuditLog = require(ServerStorage.Server.Modules.AuditLog)
local DataStoreUtil = require(ServerStorage.Server.Modules.DataStoreUtil)
local Permissions = require(ServerStorage.Server.Modules.Permissions)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local StaffActions = require(ServerStorage.Server.Modules.StaffActions)
local StaffDelivery = require(ServerStorage.Server.Modules.StaffDelivery)

export type JoinLogEntry = { Name: string, UserId: number, Joined: boolean, Time: number }
-- What a moderator's client is told: where its copy of the menu is and the key that opens it.
export type Access = { Module: string, Key: string, Role: string }

local KICK_TOPIC = "AdminKick"
local MAX_REASON_LENGTH = 200
-- Lowest role that has the menu.
local MENU_ROLE: Permissions.Role = "Mod"
-- The bundle of Server.StaffClient that is the menu.
local MENU_BUNDLE = "Mod"
-- Seconds between two looks at where the watched players are.
local SPECTATE_INTERVAL = 1
-- A watched player who moved this far has the map around them sent again.
local SPECTATE_STREAM_DISTANCE = 64

local AdminService = Knit.CreateService({
	Name = "AdminService",
	Client = {},
})

local legacyBans: DataStore? = nil
local joinLog: { JoinLogEntry } = {}
local commandLimiter = RateLimiter.new(AdminConfig.CommandRate[1], AdminConfig.CommandRate[2])
-- Who is watching whom, and where the map was last streamed for them.
local spectating: { [Player]: { Target: Player, Streamed: Vector3? } } = {}
local spectateLoop: thread? = nil

local function logJoin(player: Player, joined: boolean)
	table.insert(joinLog, { Name = player.Name, UserId = player.UserId, Joined = joined, Time = os.time() })
	if #joinLog > AdminConfig.Log.JoinLeaveCapacity then
		table.remove(joinLog, 1)
	end
end

local function cleanReason(reason: string?): string
	local text = string.gsub(reason or "", "%c", " ")
	text = string.sub(text, 1, MAX_REASON_LENGTH)
	return if string.match(text, "%S") then text else "No reason given."
end

local function checkLegacyBan(player: Player)
	local store = legacyBans
	if not store then
		return
	end
	local ok, banned = DataStoreUtil.Get(store, tostring(player.UserId))
	-- The legacy check exempted one hardcoded owner id; owners are simply never banned now.
	if ok and banned == true and Permissions.GetRole(player.UserId) ~= "Owner" then
		player:Kick(AdminConfig.Bans.Message)
	end
end

local function onKickMessage(message: any)
	local payload = message.Data
	if type(payload) ~= "table" or type(payload.UserId) ~= "number" then
		return
	end
	local player = Players:GetPlayerByUserId(payload.UserId)
	if player and Permissions.GetRole(player.UserId) ~= "Owner" then
		player:Kick(cleanReason(if type(payload.Reason) == "string" then payload.Reason else nil))
	end
end

--[[
	The map is streamed: a spectator far from the watched player has nothing to look at.
	The area around the watched character is requested for the spectator, again each time
	the character has moved away from the last request. One loop for the whole server,
	alive only while somebody spectates.
]]
local function streamSpectators()
	while next(spectating) do
		for executor, watch in spectating do
			local target = watch.Target
			if executor.Parent ~= Players or target.Parent ~= Players then
				spectating[executor] = nil
				continue
			end
			local character = target.Character
			local root = character and character.PrimaryPart
			local streamed = watch.Streamed
			if root and (not streamed or (root.Position - streamed).Magnitude > SPECTATE_STREAM_DISTANCE) then
				watch.Streamed = root.Position
				task.spawn(pcall, executor.RequestStreamAroundAsync, executor, root.Position)
			end
		end
		task.wait(SPECTATE_INTERVAL)
	end
	spectateLoop = nil
end

--[[
	Universe-wide ban through Players:BanAsync (Roblox kicks the player wherever they
	are and can catch alternate accounts). seconds nil or <= 0 bans permanently.
]]
function AdminService:Ban(executor: Player, userId: number, seconds: number?, reason: string?): (boolean, string)
	if not Permissions.CanTarget(executor, userId) then
		return false, "You cannot ban that player."
	end

	local text = cleanReason(reason)
	local duration = if seconds and seconds > 0 then math.floor(seconds) else -1
	local ok, problem = pcall(function()
		Players:BanAsync({
			UserIds = { userId },
			Duration = duration,
			DisplayReason = text,
			PrivateReason = `By {executor.Name} ({executor.UserId}): {text}`,
			ApplyToUniverse = true,
			ExcludeAltAccounts = false,
		})
	end)
	if not ok then
		warn(`[Admin] ban of {userId} failed: {problem}`)
		return false, "The ban failed, try again."
	end

	AuditLog.Record(executor, "ban", `{userId} for {if duration < 0 then "ever" else `{duration}s`}: {text}`)
	return true, `Banned {userId}.`
end

-- Lifts a ban made with Ban and a ban left by the legacy game.
function AdminService:Unban(executor: Player, userId: number): (boolean, string)
	if not Permissions.CanTarget(executor, userId) then
		return false, "You cannot unban that player."
	end

	local ok, problem = pcall(function()
		Players:UnbanAsync({ UserIds = { userId }, ApplyToUniverse = true })
	end)
	local legacyOk = true
	if legacyBans then
		legacyOk = DataStoreUtil.Remove(legacyBans, tostring(userId))
	end
	if not ok or not legacyOk then
		warn(`[Admin] unban of {userId} failed: {problem}`)
		return false, "The unban failed, try again."
	end

	AuditLog.Record(executor, "unban", tostring(userId))
	return true, `Unbanned {userId}.`
end

-- Kicks a user from whichever server of the game they are in.
function AdminService:GlobalKick(executor: Player, userId: number, reason: string?): (boolean, string)
	if not Permissions.CanTarget(executor, userId) then
		return false, "You cannot kick that player."
	end

	local text = cleanReason(reason)
	local ok, problem = pcall(MessagingService.PublishAsync, MessagingService, KICK_TOPIC, {
		UserId = userId,
		Reason = text,
	})
	if not ok then
		warn(`[Admin] global kick of {userId} failed: {problem}`)
		return false, "The kick could not be sent, try again."
	end

	AuditLog.Record(executor, "globalkick", `{userId}: {text}`)
	return true, `Kick sent for {userId}.`
end

--[[
	The camera is the client's: the moderator menu points it at the watched character once
	this request is answered. The server's part is the map around that character (see
	streamSpectators). nil stops.
]]
function AdminService:Spectate(executor: Player, target: Player?)
	if not target or target == executor then
		spectating[executor] = nil
		return
	end
	spectating[executor] = { Target = target, Streamed = nil }
	if not spectateLoop then
		spectateLoop = task.spawn(streamSpectators)
	end
end

-- Oldest first. Do not mutate.
function AdminService:GetJoinLog(): { JoinLogEntry }
	return joinLog
end

-- nil below the menu's role, and nothing was sent to that client.
function AdminService.Client:GetAccess(player: Player): Access?
	Permissions.Resolve(player)
	if not Permissions.Has(player, MENU_ROLE) then
		return nil
	end
	local module = StaffDelivery.Give(player, MENU_BUNDLE)
	if not module then
		return nil
	end
	return { Module = module, Key = AdminConfig.MenuKey, Role = Permissions.GetRole(player.UserId) }
end

-- One request of the moderator menu (Server.Modules.StaffActions lists them).
function AdminService.Client:Execute(player: Player, action: unknown, payload: unknown): (boolean, string, any?)
	if not Permissions.Has(player, MENU_ROLE) then
		return false, StaffActions.Unknown, nil
	elseif not commandLimiter:Consume(player) then
		return false, "You are sending requests too fast.", nil
	end
	return StaffActions.Run(player, action, payload)
end

function AdminService:KnitInit()
	if not RunService:IsStudio() then
		legacyBans = DataStoreUtil.GetStore(AdminConfig.Bans.LegacyStore)
	end
end

function AdminService:KnitStart()
	local function onPlayerAdded(player: Player)
		logJoin(player, true)
		checkLegacyBan(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		logJoin(player, false)
		commandLimiter:Forget(player)
		StaffActions.Forget(player)
		spectating[player] = nil
	end)

	task.spawn(function()
		local subscribed, reason = pcall(MessagingService.SubscribeAsync, MessagingService, KICK_TOPIC, onKickMessage)
		if not subscribed then
			warn(`[Admin] global kicks will not reach this server: {reason}`)
		end
	end)
end

return AdminService
