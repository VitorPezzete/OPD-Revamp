--!strict
--[[
	DataStore calls with a pcall, a bounded number of attempts and a look at the request
	budget first, so a throttled store slows one request down instead of erroring or
	looping forever (the legacy code generators retried a failed GetAsync inside a
	`while true` with no wait).

		local ok, value = DataStoreUtil.Get(store, key)
		local ok, value = DataStoreUtil.Update(store, key, function(current) return new end)
		local ok = DataStoreUtil.Remove(store, key)

	`ok` is false only when every attempt failed. An Update whose transform returns nil is
	a successful, cancelled write: ok is true and value is nil.
]]
local DataStoreService = game:GetService("DataStoreService")

local DataStoreUtil = {}

local ATTEMPTS = 3
local BACKOFF_SECONDS = 1
local BUDGET_WAIT_SECONDS = 1

local uncached = Instance.new("DataStoreGetOptions")
uncached.UseCache = false

local function attempt(requestType: Enum.DataStoreRequestType, call: () -> any): (boolean, any)
	local result: any = nil
	for index = 1, ATTEMPTS do
		if DataStoreService:GetRequestBudgetForRequestType(requestType) <= 0 then
			task.wait(BUDGET_WAIT_SECONDS)
		end

		local ok, value = pcall(call)
		if ok then
			return true, value
		end
		result = value
		if index < ATTEMPTS then
			task.wait(BACKOFF_SECONDS * 2 ^ (index - 1))
		end
	end
	warn(`[DataStore] request failed after {ATTEMPTS} attempts: {result}`)
	return false, result
end

function DataStoreUtil.GetStore(name: string): DataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if not ok then
		warn(`[DataStore] "{name}" is unavailable: {store}`)
		return nil
	end
	return store
end

-- Always reads the live value: crews and codes change on other servers.
function DataStoreUtil.Get(store: DataStore, key: string): (boolean, any)
	return attempt(Enum.DataStoreRequestType.GetAsync, function()
		return (store:GetAsync(key, uncached))
	end)
end

-- The transform may run several times and must not yield.
function DataStoreUtil.Update(store: DataStore, key: string, transform: (current: any) -> any): (boolean, any)
	return attempt(Enum.DataStoreRequestType.UpdateAsync, function()
		return (store:UpdateAsync(key, transform))
	end)
end

function DataStoreUtil.Remove(store: DataStore, key: string): boolean
	return (attempt(Enum.DataStoreRequestType.SetIncrementAsync, function()
		return (store:RemoveAsync(key))
	end))
end

return DataStoreUtil
