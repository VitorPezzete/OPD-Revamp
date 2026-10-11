--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

return function(context: any, userId: number, reason: string, duration: number?): string
	local _, message = Knit.GetService("AdminService"):Ban(context.Executor, userId, duration, reason)
	return message
end
