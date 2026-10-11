--!strict
local ServerStorage = game:GetService("ServerStorage")

local Permissions = require(ServerStorage.Server.Modules.Permissions)

-- The kicked player sees a fixed text: the typed reason is unfiltered and stays in the log.
return function(context: any, target: Player): string
	if not Permissions.CanTarget(context.Executor, target.UserId) then
		return "You cannot kick that player."
	end
	target:Kick("You have been kicked by an admin.")
	return `Kicked {target.Name}.`
end
