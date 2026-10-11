--!strict
--[[
	Rules a server applies to itself and to who may be in it. Numbers are in
	AdminConfig.Policies. One legacy script each, rewritten:

	- Capacity (MaximumPlayers): a server keeps slots for staff. A non-staff player who
	  arrives above the limit is sent to another server.
	- New accounts (KickNewAccounts): minimum account age. The legacy kick was commented
	  out, so it ships disabled.
	- Lifetime (Shutdown Servers): after 40 hours the server announces its shutdown once a
	  minute for five minutes, then empties itself. The same countdown is what the
	  `shutdown` console command and the moderator menu start, with a reason typed by the
	  staff member: it is shown in every warning and in the kick message.
	- Version shutdown: an owner closes every server of the game that runs a given
	  VersionConfig.Version (or all of them) from one server. The order travels through
	  MessagingService; each server compares it with its own version and starts the very
	  same countdown.
	- The legacy lobby guard (ForceSpawn) is gone with the lobby itself: a player without a
	  character is on the spawn screen and has no body to put anywhere (CharacterService).
	- Integrity (Fixes/BeriDupe): impossible Beri / chef gift balances left by old dupes
	  are zeroed when the profile loads, and logged.

	Server API
		ServerPolicyService:Shutdown(seconds, rejoin?, by?, reason?) -> (boolean, string?)
			false if already closing; else true and the reason as the players are shown it
		ServerPolicyService:ShutdownVersion(by, version, seconds, reason?) -> (boolean, string)
		ServerPolicyService:IsClosing() -> boolean

	Neither checks who is asking: the caller has (StaffActions, DevShutdownCommands,
	CommandRunner).
]]
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local VersionConfig = require(ReplicatedStorage.Shared.Configs.VersionConfig)
local AdminConfig = require(ServerStorage.Server.Configs.AdminConfig)
local AuditLog = require(ServerStorage.Server.Modules.AuditLog)
local Permissions = require(ServerStorage.Server.Modules.Permissions)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local WebhookConfig = require(ServerStorage.Server.Configs.WebhookConfig)

type PlayerData = PlayerData.PlayerData

local POLICIES = AdminConfig.Policies
local SHUTDOWN_MESSAGE = "Server Shutdown"
local ANNOUNCEMENT_SECONDS = 10
local MAX_SHUTDOWN_SECONDS = 3600
-- Bytes of a shutdown reason that are kept.
local MAX_REASON_LENGTH = 120
local MAX_VERSION_LENGTH = 64
local MAX_NAME_LENGTH = 64
-- Topic of the version shutdown, and the "version" that means every server.
local SHUTDOWN_TOPIC = "ServerShutdown"
local ALL_VERSIONS = "*"

local ServerPolicyService = Knit.CreateService({
	Name = "ServerPolicyService",
	Client = {},
})

local DataService
local NotifyService
local WebhookService

local closing = false
local closed = false
-- What a player removed by the shutdown reads: SHUTDOWN_MESSAGE, plus the reason if any.
local kickMessage = SHUTDOWN_MESSAGE

local function trim(text: string): string
	return (string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

--[[
	A reason as it may be shown and logged: one line, at most MAX_REASON_LENGTH bytes, cut
	before a broken UTF-8 character rather than in the middle of one. nil when nothing is
	left. This is not the text filter (see filterReason).
]]
local function cleanReason(value: unknown): string?
	if type(value) ~= "string" then
		return nil
	end
	local text = string.sub(trim((string.gsub(value, "%c", " "))), 1, MAX_REASON_LENGTH)
	local length, invalidAt = utf8.len(text)
	if not length then
		text = string.sub(text, 1, (invalidAt :: number) - 1)
	end
	text = trim(text)
	return if text == "" then nil else text
end

-- Text typed by a staff member is still shown to everybody: it goes through the filter.
-- nil when the filter cannot be reached, the shutdown then goes on without a reason.
local function filterReason(reason: string, author: Player): string?
	local ok, filtered = pcall(function(): string
		return TextService:FilterStringAsync(reason, author.UserId, Enum.TextFilterContext.PublicChat)
			:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		warn(`[Policy] shutdown reason could not be filtered: {filtered}`)
		return nil
	end
	return cleanReason(filtered)
end

local function countNormalPlayers(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if not Permissions.IsStaff(player) then
			count += 1
		end
	end
	return count
end

local function sendElsewhere(players: { Player }): boolean
	if #players == 0 then
		return true
	end
	local ok, problem = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, players)
	if not ok then
		warn(`[Policy] teleport failed: {problem}`)
	end
	return ok
end

local function onPlayerAdded(player: Player)
	if closed then
		player:Kick(kickMessage)
		return
	end

	-- Group ranks are fetched before deciding, so group staff are not bounced.
	Permissions.Resolve(player)
	if player.Parent ~= Players or Permissions.IsStaff(player) then
		return
	end

	if POLICIES.EnforceAccountAge and player.AccountAge < POLICIES.MinAccountAgeDays then
		player:Kick(`Your account needs to be at least {POLICIES.MinAccountAgeDays} days old to play.`)
		return
	end

	if countNormalPlayers() > POLICIES.MaxNormalPlayers and not RunService:IsStudio() then
		task.wait(1)
		if player.Parent == Players and not sendElsewhere({ player }) then
			player:Kick("This server is full, please join another one.")
		end
	end
end

local function checkIntegrity(player: Player, data: PlayerData)
	local integrity = POLICIES.Integrity
	if not integrity.Enabled then
		return
	end

	local beri = data:Get("Economy.Beri")
	local bounty = data:Get("Combat.Bounty")
	if type(beri) == "number" and beri > integrity.MaxBeri and (tonumber(bounty) or 0) <= integrity.BountyThatJustifiesBeri then
		data:Set("Economy.Beri", 0)
		AuditLog.Record("Integrity", "beri-reset", `{player.Name} ({player.UserId}) had {beri} Beri`)
	end

	local chefGift = data:Get("Fishing.ChefGift")
	if type(chefGift) == "number" and chefGift > integrity.MaxChefGift then
		data:Set("Economy.Beri", 0)
		data:Set("Fishing.ChefGift", 0)
		AuditLog.Record("Integrity", "chefgift-reset", `{player.Name} ({player.UserId}) had {chefGift} chef gift`)
	end
end

-- The legacy "#WealthWarning": a report for moderators, nothing is taken.
local function reportWealth(player: Player, data: PlayerData)
	local beri = data:Get("Economy.Beri")
	local gems = data:Get("Economy.Gems")
	local wealth = WebhookConfig.Wealth
	if type(beri) == "number" and type(gems) == "number" and beri > wealth.Beri and gems > wealth.Gems then
		local who = `**{player.Name}** ({player.DisplayName}) - ID: {player.UserId}`
		WebhookService:Send("Integrity", `{who} #WealthWarning: has {beri} Beri and {gems} Gems`)
	end
end

local function announce(text: string)
	NotifyService:Broadcast(text, "Announcement", ANNOUNCEMENT_SECONDS)
end

local function close(rejoin: boolean)
	closed = true
	announce("Server is Shutting Down.")

	local players = Players:GetPlayers()
	if rejoin and sendElsewhere(players) then
		-- Whoever is still here once the teleports had time to leave is removed.
		task.wait(15)
	end
	for _, player in Players:GetPlayers() do
		player:Kick(kickMessage)
	end
end

--[[
	Starts the countdown unless one is running. `by` is a player of this server, or the
	name of whoever ordered it elsewhere. `shown` is the reason the players read (filtered
	already, or nil) and `logged` the reason as it was typed, for the audit log only.
]]
local function begin(seconds: number, rejoin: boolean, by: Player | string, shown: string?, logged: string?): boolean
	if closing then
		return false
	end
	closing = true

	local remaining = math.clamp(math.floor(seconds), 0, MAX_SHUTDOWN_SECONDS)
	AuditLog.Record(by, "shutdown", `in {remaining}s{if rejoin then " (rejoin)" else ""}{if logged then `: {logged}` else ""}`)

	local suffix = if shown then ` Reason: {shown}` else ""
	if shown then
		kickMessage = `{SHUTDOWN_MESSAGE}: {shown}`
	end

	task.spawn(function()
		local partial = remaining % 60
		if partial > 0 then
			announce(`Server will Shutdown in {remaining} seconds.{suffix}`)
			task.wait(partial)
			remaining -= partial
		end
		while remaining > 0 do
			local minutes = remaining // 60
			announce(`Server will Shutdown in {minutes} minute{if minutes == 1 then "" else "s"}.{suffix}`)
			task.wait(60)
			remaining -= 60
		end
		close(rejoin)
	end)
	return true
end

-- An order published by ShutdownVersion, here or in another server of the game.
local function onShutdownMessage(message: any)
	local payload = message.Data
	if type(payload) ~= "table" or type(payload.Version) ~= "string" or type(payload.Seconds) ~= "number" then
		return
	end
	local seconds = payload.Seconds
	local version = trim(payload.Version)
	if seconds ~= seconds or (version ~= ALL_VERSIONS and version ~= trim(VersionConfig.Version)) then
		return
	end

	local by = if type(payload.By) == "string" then string.sub(payload.By, 1, MAX_NAME_LENGTH) else "?"
	-- Filtered by the server that published it; only its shape is checked again.
	local reason = cleanReason(payload.Reason)
	-- Answers false in the server that published it: its own countdown is running already.
	begin(seconds, false, `{by} (version shutdown)`, reason, reason)
end

function ServerPolicyService:IsClosing(): boolean
	return closing
end

--[[
	Starts the shutdown countdown: a warning per remaining minute, then everyone leaves.
	rejoin = true teleports the players to fresh servers instead of kicking them (soft
	shutdown, for updates). New arrivals are refused once the server has closed.

	`reason` is free text from `by`: it is cleaned, filtered for broadcast and shown in the
	warnings and in the kick message. Without an author there is nobody to filter it for,
	so it is only shown when `by` is given; the audit log keeps it either way. Yields while
	the filter answers (never without a reason). Returns whether the countdown started
	and the reason as the players are shown it.
]]
function ServerPolicyService:Shutdown(seconds: number, rejoin: boolean?, by: Player?, reason: string?): (boolean, string?)
	if closing then
		return false, nil
	end
	local typed = cleanReason(reason)
	if not typed or not by then
		return begin(seconds, rejoin == true, by or "Server", nil, typed), nil
	end

	-- Taken while the filter yields: a second request must not start a second countdown.
	closing = true
	local shown = filterReason(typed, by)
	closing = false
	return begin(seconds, rejoin == true, by, shown, typed), shown
end

--[[
	Closes every server of the game whose VersionConfig.Version is `version` ("*": all of
	them), this one included when it matches. Always a hard shutdown: with every server of
	a version closing at once, a teleport would land the players in another closing server.

	The reason is filtered once, here, and travels filtered. This server does not wait for
	its own message. In Studio nothing is published: only this server can be closed.
]]
function ServerPolicyService:ShutdownVersion(by: Player, version: string, seconds: number, reason: string?): (boolean, string)
	local wanted = trim(version)
	if wanted == "" or #wanted > MAX_VERSION_LENGTH or string.find(wanted, "%c") then
		return false, "invalid version"
	end
	local remaining = math.clamp(math.floor(seconds), 0, MAX_SHUTDOWN_SECONDS)
	local typed = cleanReason(reason)
	local shown = if typed then filterReason(typed, by) else nil
	local which = if wanted == ALL_VERSIONS then "every server" else `every server on version "{wanted}"`

	local published = not RunService:IsStudio()
	if published then
		local ok, problem = pcall(MessagingService.PublishAsync, MessagingService, SHUTDOWN_TOPIC, {
			Version = wanted,
			Seconds = remaining,
			Reason = shown,
			By = by.Name,
		})
		if not ok then
			warn(`[Policy] version shutdown could not be published: {problem}`)
			return false, "the shutdown could not be sent to the other servers, try again"
		end
	end
	AuditLog.Record(
		by,
		"shutdown",
		`{which} in {remaining}s{if typed then `: {typed}` else ""}{if published then "" else " (Studio: not published)"}`
	)

	local here = wanted == ALL_VERSIONS or wanted == trim(VersionConfig.Version)
	local started = here and begin(remaining, false, by, shown, typed)

	local parts = { if published then `{which} closes in {remaining}s` else `Studio: nothing was sent to {which}` }
	if typed and not shown then
		table.insert(parts, "the reason could not be filtered and is not shown")
	end
	table.insert(
		parts,
		if started
			then "this server is closing too"
			elseif here then "this server was already closing"
			else `this server runs "{VersionConfig.Version}" and stays open`
	)
	return true, table.concat(parts, ", ")
end

function ServerPolicyService:KnitInit()
	DataService = Knit.GetService("DataService")
	NotifyService = Knit.GetService("NotifyService")
	WebhookService = Knit.GetService("WebhookService")
end

function ServerPolicyService:KnitStart()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	DataService:ObserveData(checkIntegrity)
	DataService:ObserveData(reportWealth)

	task.delay(POLICIES.ServerLifetimeSeconds, function()
		ServerPolicyService:Shutdown(POLICIES.ShutdownWarningSeconds, false)
	end)

	-- Studio has no other server to hear from, and its subscription may fail.
	if not RunService:IsStudio() then
		task.spawn(function()
			local subscribed, problem = pcall(MessagingService.SubscribeAsync, MessagingService, SHUTDOWN_TOPIC, onShutdownMessage)
			if not subscribed then
				warn(`[Policy] version shutdowns will not reach this server: {problem}`)
			end
		end)
	end
end

return ServerPolicyService
