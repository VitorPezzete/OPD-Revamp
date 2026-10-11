--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

return function(context: any, lines: number?): string
	local log = Knit.GetService("AdminService"):GetJoinLog()
	local now = os.time()
	local shown = 0
	for index = #log, math.max(1, #log - math.min(lines or 30, 100) + 1), -1 do
		local entry = log[index]
		local action = if entry.Joined then "joined" else "left"
		context:Reply(`{entry.Name} ({entry.UserId}) {action} {now - entry.Time}s ago`)
		shown += 1
	end
	return `{shown} of {#log} entries.`
end
