--!strict
local ServerStorage = game:GetService("ServerStorage")

local AuditLog = require(ServerStorage.Server.Modules.AuditLog)

return function(context: any, lines: number?): string
	local entries = AuditLog.GetEntries()
	local now = os.time()
	local shown = 0
	for index = #entries, math.max(1, #entries - math.min(lines or 20, 100) + 1), -1 do
		local entry = entries[index]
		context:Reply(`[{now - entry.Time}s] {entry.Actor} {entry.Action} {entry.Detail}`)
		shown += 1
	end
	return `{shown} of {#entries} entries.`
end
