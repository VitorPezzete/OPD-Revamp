--!strict
--[[
	How each open window is closed, so something that only holds an instance inside it
	(the gamepad selection) can close it the way its close button would.

		Closers.register(scope, windowFrame, onClose)   -- UI.Window does it
		Closers.closeContaining(selectedButton) -> boolean
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

type Scope = Fusion.Scope<any>

local Closers = {}

local registry: { [Instance]: () -> () } = {}

function Closers.register(scope: Scope, window: Instance, onClose: () -> ())
	registry[window] = onClose
	table.insert(scope, function()
		if registry[window] == onClose then
			registry[window] = nil
		end
	end)
end

-- Closes the innermost registered window around `object`. False when it is in none.
function Closers.closeContaining(object: Instance): boolean
	local current: Instance? = object
	while current do
		local close = registry[current]
		if close then
			task.spawn(close)
			return true
		end
		current = current.Parent
	end
	return false
end

return Closers
