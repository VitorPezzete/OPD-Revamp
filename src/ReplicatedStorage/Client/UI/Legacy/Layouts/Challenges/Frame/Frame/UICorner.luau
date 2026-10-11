--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Challenges > Frame > Frame > UICorner): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): UICorner
	return scope:New("UICorner")({
		BottomLeftRadius = UDim.new(0.02, 0),
		BottomRightRadius = UDim.new(0.02, 0),
		TopLeftRadius = UDim.new(0.02, 0),
		TopRightRadius = UDim.new(0.02, 0),
	}) :: any
end
