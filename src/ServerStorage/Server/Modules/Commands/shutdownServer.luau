--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

return function(context: any, seconds: number?, rejoin: boolean?): string
	local started = Knit.GetService("ServerPolicyService"):Shutdown(seconds or 300, rejoin == true, context.Executor)
	return if started then "Shutdown countdown started." else "This server is already shutting down."
end
