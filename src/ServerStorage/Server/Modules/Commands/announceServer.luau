--!strict
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local MAX_LENGTH = 200

return function(context: any, text: string): string
	local executor: Player = context.Executor
	if #text > MAX_LENGTH or not string.match(text, "%S") then
		return `An announcement has 1 to {MAX_LENGTH} characters.`
	end

	-- Staff text shown to everyone still goes through the filter.
	local ok, filtered = pcall(function(): string
		return TextService:FilterStringAsync(text, executor.UserId, Enum.TextFilterContext.PublicChat)
			:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return "The text could not be filtered, try again."
	end

	Knit.GetService("AnnouncementService"):Publish(filtered)
	return "Announcement sent."
end
