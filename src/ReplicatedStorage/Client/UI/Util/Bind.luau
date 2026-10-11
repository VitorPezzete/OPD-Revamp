--!strict
--[[
	Helpers to drive a generated layout (UI.Layouts.<Name>) from state.

	The layouts are static trees exported from the legacy place. A screen builds one,
	looks its elements up by path and binds Fusion state to them:

		local title = Bind.find(gui, "Frame/Title")
		Bind.props(scope, title, { Text = scope:Computed(function(use) ... end) })
		Bind.click(scope, Bind.find(gui, "Frame/Close"), function() context.Close() end)
		local beri = Bind.data(scope, "Economy.Beri")       -- Fusion.Value kept in sync
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

type Scope = Fusion.Scope<typeof(Fusion)>

local Numerals = require(script.Parent.Numerals)

local Bind = {}

-- Resolves "A/B/C" below root. "Name#2" picks the second child with that name (the
-- legacy trees have many siblings sharing a name). Errors with the full path on a miss.
function Bind.find(root: Instance, path: string): any
	local current = root
	for _, segment in string.split(path, "/") do
		local name, index = string.match(segment, "^(.-)#(%d+)$")
		local wanted = tonumber(index) or 1
		local target = name or segment

		local found: Instance? = nil
		local seen = 0
		for _, child in current:GetChildren() do
			if child.Name == target then
				seen += 1
				if seen == wanted then
					found = child
					break
				end
			end
		end
		if not found then
			error(`UI element "{segment}" of "{path}" not found under {root:GetFullName()}`, 2)
		end
		current = found
	end
	return current
end

-- Same as find, but returns nil on a miss.
function Bind.tryFind(root: Instance, path: string): any
	local ok, result = pcall(Bind.find, root, path)
	return if ok then result else nil
end

-- Binds properties / state objects / events to an existing instance.
function Bind.props(scope: Scope, instance: Instance, props: { [any]: any }): Instance
	return scope:Hydrate(instance)(props)
end

-- Connects a button. The connection dies with the scope.
function Bind.click(scope: Scope, button: GuiButton, callback: () -> ())
	table.insert(scope, button.Activated:Connect(function()
		callback()
	end))
end

-- Any event connection tied to the scope.
function Bind.connect(scope: Scope, signal: RBXScriptSignal, callback: (...any) -> ())
	table.insert(scope, signal:Connect(callback))
end

-- A Fusion value mirroring one path of the replicated player data.
function Bind.data(scope: Scope, path: string, default: any?): Fusion.Value<any>
	local DataController = Knit.GetController("DataController")
	local initial = DataController:Get(path)
	local value = scope:Value(if initial == nil then default else initial)
	local connection = DataController:Observe(path, function(current: any)
		value:set(if current == nil then default else current)
	end)
	table.insert(scope, function()
		connection:Disconnect()
	end)
	return value
end

-- A Fusion value mirroring an attribute of an instance (character statuses, ...).
function Bind.attribute(scope: Scope, instance: Instance, name: string, default: any?): Fusion.Value<any>
	local function read(): any
		local current = instance:GetAttribute(name)
		return if current == nil then default else current
	end
	local value = scope:Value(read())
	table.insert(scope, instance:GetAttributeChangedSignal(name):Connect(function()
		value:set(read())
	end))
	return value
end

-- 1234567 -> "1.234.567" (see Util.Numerals).
function Bind.formatNumber(value: number): string
	return Numerals.format(value)
end

return Bind
