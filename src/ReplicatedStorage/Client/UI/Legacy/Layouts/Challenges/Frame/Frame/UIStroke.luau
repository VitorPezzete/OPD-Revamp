--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Challenges > Frame > Frame > UIStroke): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): UIStroke
	return scope:New("UIStroke")({
		Color = Color3.fromRGB(91, 51, 44),
		Thickness = 3,
	}) :: any
end
