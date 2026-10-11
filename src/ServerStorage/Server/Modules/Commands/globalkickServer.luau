--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

return function(context: any, userId: number): string
	local _, message = Knit.GetService("AdminService"):GlobalKick(context.Executor, userId, "Kicked By Administrator")
	return message
end
