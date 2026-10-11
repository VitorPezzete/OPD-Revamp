--!strict
--[[
	GENERATED from ReplicatedStorage.effects.ShaveEffect in the legacy place: static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): BillboardGui
	return scope:New("BillboardGui")({
		Name = "ShaveEffect",
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		Size = UDim2.fromScale(20, 20),
		ClipsDescendants = true,
		Active = true,
		AlwaysOnTop = true,
		MaxDistance = 100,
		LightInfluence = 1,
		[Children] = {
			scope:New("ImageLabel")({
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				Position = UDim2.fromScale(0.3, 0.35),
				Size = UDim2.fromScale(0.3, 0.3),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = "rbxassetid://79719642659878",
				ImageColor3 = Color3.fromRGB(30, 30, 30),
			}),
		},
	}) :: any
end
