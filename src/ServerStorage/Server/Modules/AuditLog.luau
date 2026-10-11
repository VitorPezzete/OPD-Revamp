--!strict
--[[
	Record of privileged actions: who, what, on whom. Kept in memory for the `auditlog`
	console command, printed to the server log, and posted to the Discord channels the
	legacy moderation scripts used (bans, kicks, unbans, fruit and item spawns, data
	edits, integrity resets) through WebhookService.

		AuditLog.Record(player, "ban", "userId 123, 7 days: exploiting")

	Which entry goes to which channel is WebhookConfig.Audit; an entry that matches
	nothing there stays in the in-game log. Posting is WebhookService's business
	(batched, rate limited, off outside the final place): Record never yields.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Optional = require(ReplicatedStorage.Shared.Util.Optional)
local AdminConfig = require(ServerStorage.Server.Configs.AdminConfig)
local WebhookConfig = require(ServerStorage.Server.Configs.WebhookConfig)

export type Entry = { Time: number, Actor: string, ActorId: number, Action: string, Detail: string }

local AuditLog = {}

local CONFIG = AdminConfig.Log
local ROUTES = WebhookConfig.Audit
local RAN = "ran"
local DEV_PREFIX = "dev:"
-- CommandRunner (the staff menu) writes "menu: <command> <arguments>".
local MENU_PREFIX = "menu: "

local entries: { Entry } = {}
local webhookService: any = nil

-- Entries can be recorded before Knit has started (the lookup errors until then) and in
-- places that do not load the service (it answers nil): asked again the next time.
local function getWebhookService(): any
	if not webhookService then
		local ok, service = pcall(Optional.Service, "WebhookService")
		webhookService = if ok then service else nil
	end
	return webhookService
end

-- Name of the command behind a "ran" entry.
local function getCommand(detail: string): string
	local text = detail
	if string.sub(text, 1, #MENU_PREFIX) == MENU_PREFIX then
		text = string.sub(text, #MENU_PREFIX + 1)
	end
	return string.lower(string.match(text, "^%s*(%S+)") or "")
end

local function post(entry: Entry)
	local service = getWebhookService()
	if not service then
		return
	end

	local who = if entry.ActorId ~= 0 then `**{entry.Actor}** ({entry.ActorId})` else `**{entry.Actor}**`
	local line = `{who} {entry.Action}{if entry.Detail ~= "" then `: {entry.Detail}` else ""}`

	local first = ROUTES.Actions[entry.Action]
	local second: string? = nil
	if entry.Action == RAN then
		first = ROUTES.Commands[getCommand(entry.Detail)]
		second = ROUTES.EveryCommand
	elseif string.sub(entry.Action, 1, #DEV_PREFIX) == DEV_PREFIX then
		first = ROUTES.DevActions
	end

	if first then
		service:Send(first, line)
	end
	if second and second ~= first then
		service:Send(second, line)
	end
end

function AuditLog.Record(actor: Player | string, action: string, detail: string?)
	local entry: Entry = {
		Time = os.time(),
		Actor = if type(actor) == "string" then actor else actor.Name,
		ActorId = if type(actor) == "string" then 0 else actor.UserId,
		Action = action,
		Detail = detail or "",
	}

	table.insert(entries, entry)
	if #entries > CONFIG.Capacity then
		table.remove(entries, 1)
	end

	print(`[Audit] {entry.Actor} ({entry.ActorId}) {entry.Action} {entry.Detail}`)

	-- The log itself must never fail because of where it is copied to.
	pcall(post, entry)
end

-- Newest last. Do not mutate.
function AuditLog.GetEntries(): { Entry }
	return entries
end

return AuditLog
