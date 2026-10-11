--!strict
--[[
	Dot-path access into nested tables ("Skills.Melee.Level").
	Split results are cached: the set of paths used by the game is small and fixed.
]]

local TablePath = {}

local splitCache: { [string]: { string } } = {}

function TablePath.Split(path: string): { string }
	local keys = splitCache[path]
	if not keys then
		keys = string.split(path, ".")
		splitCache[path] = keys
	end
	return keys
end

function TablePath.Get(root: { [any]: any }, path: string): any
	local current: any = root
	for _, key in TablePath.Split(path) do
		if type(current) ~= "table" then
			return nil
		end
		current = current[key]
	end
	return current
end

-- Returns the previous value. Intermediate tables are created when missing.
function TablePath.Set(root: { [any]: any }, path: string, value: any): any
	local keys = TablePath.Split(path)
	local current: any = root
	for index = 1, #keys - 1 do
		local nextTable = current[keys[index]]
		if type(nextTable) ~= "table" then
			nextTable = {}
			current[keys[index]] = nextTable
		end
		current = nextTable
	end

	local lastKey = keys[#keys]
	local previous = current[lastKey]
	current[lastKey] = value
	return previous
end

return TablePath
