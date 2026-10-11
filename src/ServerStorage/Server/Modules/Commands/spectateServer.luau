--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

return function(context: any, target: Player?): string
	local executor: Player = context.Executor
	local watched = if target ~= executor then target else nil
	Knit.GetService("AdminService"):Spectate(executor, watched)
	return if watched then `Spectating {watched.Name}.` else "Back to your character."
end
