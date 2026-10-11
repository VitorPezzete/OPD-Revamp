--!strict
--[[
	Read-only mirror of the local player's saved data.

		DataController:Get("Economy.Beri")
		DataController:Observe("Skills.Melee.Level", function(level) ... end)

	Observe also fires for changes above or below the path (a full sync, or a write to
	a parent table), so UI bound to a leaf never goes stale.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)
local TablePath = require(ReplicatedStorage.Shared.Util.TablePath)

local DataController = Knit.CreateController({
	Name = "DataController",
})

DataController.Data = nil :: DataTypes.PlayerData?
-- (path, value) for every replicated change; path is "" on a full sync.
DataController.Changed = Signal.new() :: Signal.Signal<string, any>
DataController.Ready = Signal.new() :: Signal.Signal<DataTypes.PlayerData>

local function isRelated(observed: string, changed: string): boolean
	return changed == ""
		or observed == changed
		or string.sub(observed, 1, #changed + 1) == changed .. "."
		or string.sub(changed, 1, #observed + 1) == observed .. "."
end

local function applyDeltas(deltas: { DataTypes.DataDelta })
	for _, delta in deltas do
		if delta.Path == "" then
			local firstSync = DataController.Data == nil
			DataController.Data = delta.Value
			if firstSync then
				DataController.Ready:Fire(delta.Value)
			end
		elseif DataController.Data then
			TablePath.Set(DataController.Data :: any, delta.Path, delta.Value)
		end
		DataController.Changed:Fire(delta.Path, delta.Value)
	end
end

function DataController:IsReady(): boolean
	return DataController.Data ~= nil
end

function DataController:Get(path: string): any
	local data = DataController.Data
	return if data then TablePath.Get(data :: any, path) else nil
end

-- Calls callback with the current value (once data exists) and again on every related change.
function DataController:Observe(path: string, callback: (value: any) -> ()): Signal.Connection
	if DataController.Data then
		task.spawn(callback, DataController:Get(path))
	end

	return DataController.Changed:Connect(function(changedPath: string)
		if isRelated(path, changedPath) then
			callback(DataController:Get(path))
		end
	end)
end

function DataController:KnitStart()
	Knit.GetService("DataService").Replicate:Connect(applyDeltas)
end

return DataController
