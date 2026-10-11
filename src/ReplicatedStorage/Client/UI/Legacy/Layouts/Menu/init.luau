--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Menu): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Menu",
		Enabled = false,
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		-- legacy behaviour: LocalScript (LocalScript, 111 lines)
		[Children] = {
			require(script.Frame)(scope),
		},
	}) :: any
end
