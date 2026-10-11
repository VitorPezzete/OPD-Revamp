--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Permissions = require(ServerStorage.Server.Modules.Permissions)

local MAX_PATH_LENGTH = 100
local MAX_TEXT_LENGTH = 100

--[[
	Only an existing number, boolean or string can be written, and only with a value of
	the same type: the legacy command searched the data tree by name and wrote whatever
	text it was given, and its "Global" variant opened other players' profiles.
]]
return function(context: any, target: Player, mode: string, path: string, value: string): string
	local executor: Player = context.Executor
	if target ~= executor and not Permissions.CanTarget(executor, target.UserId) then
		return "You cannot edit that player."
	end

	mode = string.lower(mode)
	if mode ~= "set" and mode ~= "add" then
		return "Mode is set or add."
	elseif #path > MAX_PATH_LENGTH or not string.match(path, "^[%w_]+[%w_%.]*$") or string.find(path, "..", 1, true) then
		return "Invalid path."
	end

	local data = Knit.GetService("DataService"):GetData(target)
	if not data then
		return `{target.Name}'s data is not loaded.`
	end

	local current = data:Get(path)
	local kind = type(current)
	local nextValue: any
	if kind == "number" then
		local number = tonumber(value)
		if not number or number ~= number or math.abs(number) == math.huge then
			return "That value is not a number."
		end
		nextValue = if mode == "add" then current + number else number
	elseif mode == "add" then
		return "Only numbers can be added to."
	elseif kind == "boolean" then
		local text = string.lower(value)
		if text ~= "true" and text ~= "false" then
			return "That value is true or false."
		end
		nextValue = text == "true"
	elseif kind == "string" then
		if #value > MAX_TEXT_LENGTH then
			return "That text is too long."
		end
		nextValue = value
	else
		return `"{path}" is not a single saved value.`
	end

	data:Set(path, nextValue)
	return `{target.Name} {path}: {tostring(current)} -> {tostring(nextValue)}`
end
