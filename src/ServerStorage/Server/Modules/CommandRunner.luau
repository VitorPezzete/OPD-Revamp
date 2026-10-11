--!strict
--[[
	Runs a staff command of Server.Modules.Commands for the moderator menu
	(Server.Modules.StaffActions): the menu's request carries the arguments by name and
	this module rebuilds them before the command's implementation sees anything.

		CommandRunner.Run(player, "kick", { Player = 123, Reason = "..." }) -> ok, lines

	A command is a definition (`<name>.luau`: name, group, argument types) and an
	implementation (`<name>Server.luau`). Both stay in ServerStorage: no client ever
	receives the list of commands.

	Nothing the client sends is trusted:
	- the command must be one the menu offers (MENU_COMMANDS). The other modules of the
	  folder are not loaded at all, so no request can reach them;
	- the executor's role is compared with the command's group (AdminConfig.CommandGroups);
	- every argument is rebuilt from its declared type: a "player" is a user id looked up
	  in this server, a "playerId" a positive id or a user name resolved by Roblox, numbers
	  are finite and bounded, text is clipped. An argument of a type not listed here cannot
	  be sent at all, so a command with one is not runnable from the menu;
	- who may be targeted is still decided by the implementation (Permissions.CanTarget).

	Every run and every refusal is written to the AuditLog. The caller rate limits and
	has already turned away players without a staff role.
]]
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local AdminConfig = require(ServerStorage.Server.Configs.AdminConfig)
local AuditLog = require(ServerStorage.Server.Modules.AuditLog)
local Permissions = require(ServerStorage.Server.Modules.Permissions)

type Argument = { Type: string, Name: string, Optional: boolean?, Default: any }
type Command = { Name: string, Group: string, Args: { Argument }, Run: (context: any, ...any) -> any }

local CommandRunner = {}

-- The commands the moderator menu may run: watching, teleporting, kicking and banning.
local MENU_COMMANDS = table.freeze({ "spectate", "goto", "bring", "kick", "ban", "unban", "globalkick" })
local DENIED = "You don't have permission to run this command."
local MAX_NAME_LENGTH = 40
local MAX_TEXT_LENGTH = 200
-- Roblox user names: 3 to 20 letters, digits or underscores.
local MAX_USER_NAME_LENGTH = 20
local MAX_USER_ID = 2 ^ 53
local MAX_INTEGER = 1_000_000_000
local MAX_DURATION = 10 * 365 * 86400
-- Lines a command may answer with (the logs are capped at 100 entries on their own).
local MAX_LINES = 120

local commands: { [string]: Command } = {}

local function load()
	local folder = ServerStorage.Server.Modules:FindFirstChild("Commands")
	if not folder then
		return
	end
	for _, commandName in MENU_COMMANDS do
		local module = folder:FindFirstChild(commandName)
		local implementation = folder:FindFirstChild(commandName .. "Server")
		if not module or not module:IsA("ModuleScript") or not implementation or not implementation:IsA("ModuleScript") then
			warn(`[CommandRunner] command "{commandName}" is missing`)
			continue
		end
		local ok, definition, run = pcall(function()
			return (require :: any)(module), (require :: any)(implementation)
		end)
		if not ok or type(definition) ~= "table" or type(run) ~= "function" then
			warn(`[CommandRunner] command "{module.Name}" could not be loaded: {tostring(definition)}`)
			continue
		end
		if definition.Name == commandName and type(definition.Group) == "string" then
			commands[definition.Name] = {
				Name = definition.Name,
				Group = definition.Group,
				Args = if type(definition.Args) == "table" then definition.Args else {},
				Run = run,
			}
		end
	end
end

local function whole(value: any, minimum: number, maximum: number): number?
	if type(value) ~= "number" or value ~= value or value < minimum or value > maximum then
		return nil
	end
	return math.floor(value)
end

local function resolveUserId(value: any): number?
	if type(value) == "number" then
		return whole(value, 1, MAX_USER_ID)
	elseif type(value) ~= "string" or #value > MAX_USER_NAME_LENGTH + 1 then
		return nil
	end

	local text = string.gsub(value, "^%s*#?", "")
	text = string.gsub(text, "%s+$", "")
	local id = tonumber(text)
	if id then
		return whole(id, 1, MAX_USER_ID)
	end
	if #text < 3 or #text > MAX_USER_NAME_LENGTH or string.find(text, "[^%w_]") then
		return nil
	end
	-- Somebody in this server needs no web call.
	local present = Players:FindFirstChild(text)
	if present and present:IsA("Player") then
		return present.UserId
	end
	local ok, found = pcall(Players.GetUserIdFromNameAsync, Players, text)
	return if ok and type(found) == "number" then found else nil
end

-- (true, value) or (false, why not). A nil value is an argument that was left out.
local function convert(argument: Argument, value: any): (boolean, any)
	local kind = argument.Type
	if kind == "string" and type(value) == "string" then
		local text = string.sub((string.gsub(value, "%c", " ")), 1, MAX_TEXT_LENGTH)
		value = if string.match(text, "%S") then text else nil
	end
	if value == nil then
		if argument.Default ~= nil then
			return true, argument.Default
		elseif argument.Optional then
			return true, nil
		end
		return false, `{argument.Name} is missing.`
	end

	if kind == "string" then
		return true, value
	elseif kind == "player" then
		local id = whole(value, 1, MAX_USER_ID)
		local player = if id then Players:GetPlayerByUserId(id) else nil
		if not player then
			return false, "That player is not in this server."
		end
		return true, player
	elseif kind == "playerId" then
		local id = resolveUserId(value)
		if not id then
			return false, "No user with that name or id."
		end
		return true, id
	elseif kind == "boolean" then
		return type(value) == "boolean", if type(value) == "boolean" then value else `{argument.Name} is not a yes/no.`
	elseif kind == "integer" or kind == "positiveInteger" or kind == "nonNegativeInteger" then
		local minimum = if kind == "positiveInteger" then 1 elseif kind == "nonNegativeInteger" then 0 else -MAX_INTEGER
		local number = whole(value, minimum, MAX_INTEGER)
		if not number then
			return false, `{argument.Name} is not a valid number.`
		end
		return true, number
	elseif kind == "duration" then
		-- Seconds; nothing (or zero) means "no duration", which the ban reads as permanent.
		local seconds = whole(value, 0, MAX_DURATION)
		if not seconds then
			return false, `{argument.Name} is not a valid duration.`
		end
		return true, if seconds > 0 then seconds else nil
	end
	return false, "This command cannot be run from the menu."
end

local function describe(value: any): string
	if typeof(value) == "Instance" then
		return (value :: Instance).Name
	end
	return tostring(value)
end

function CommandRunner.Run(player: Player, name: unknown, values: unknown): (boolean, { string })
	local command = if type(name) == "string" and #name <= MAX_NAME_LENGTH then commands[name] else nil
	if not command then
		return false, { "Unknown command." }
	end

	local required = AdminConfig.CommandGroups[command.Group]
	if not required or not Permissions.Has(player, required) then
		AuditLog.Record(player, "denied", `menu: {command.Name}`)
		return false, { DENIED }
	end

	local given: { [any]: any } = if type(values) == "table" then values :: any else {}
	local arguments = table.create(#command.Args)
	local shown = { command.Name }
	for index, argument in command.Args do
		local ok, value = convert(argument, given[argument.Name])
		if not ok then
			return false, { value }
		end
		arguments[index] = value
		if value ~= nil then
			table.insert(shown, describe(value))
		end
	end

	local lines: { string } = {}
	local context = {
		Executor = player,
		Name = command.Name,
		Group = command.Group,
		Reply = function(_self: any, text: any)
			if #lines < MAX_LINES then
				table.insert(lines, tostring(text))
			end
		end,
	}
	local ok, result = pcall(command.Run, context, table.unpack(arguments, 1, #command.Args))
	if not ok then
		warn(`[CommandRunner] {command.Name} failed: {tostring(result)}`)
		return false, { "The request failed (it may not be available in this place)." }
	end
	if type(result) == "string" then
		table.insert(lines, result)
	end
	AuditLog.Record(player, "ran", `menu: {table.concat(shown, " ")}`)
	return true, lines
end

load()

return CommandRunner
