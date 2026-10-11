--!strict
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

return function(context: any, userId: number): string
	local executor: Player = context.Executor
	local PrivateServerService = Knit.GetService("PrivateServerService")

	local code = PrivateServerService:FindPlayerCode(userId)
	if code then
		return if PrivateServerService:TeleportToCode(executor, code)
			then "Joining their private server..."
			else "They are in a private server, but the teleport failed."
	end

	local ok, _, _, placeId, jobId = pcall(TeleportService.GetPlayerPlaceInstanceAsync, TeleportService, userId)
	if not ok or type(placeId) ~= "number" or type(jobId) ~= "string" or jobId == "" then
		return "That user is not in the game (or cannot be located)."
	elseif jobId == game.JobId then
		return "That user is in this server."
	end

	local options = Instance.new("TeleportOptions")
	options.ServerInstanceId = jobId
	local teleported = pcall(TeleportService.TeleportAsync, TeleportService, placeId, { executor }, options)
	return if teleported then "Joining their server..." else "The teleport failed."
end
