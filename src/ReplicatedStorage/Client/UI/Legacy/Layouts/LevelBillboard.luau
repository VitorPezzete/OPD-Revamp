--!strict
--[[
	GENERATED from ReplicatedStorage.Level in the legacy place: static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): BillboardGui
	return scope:New("BillboardGui")({
		Name = "Level",
		Size = UDim2.fromScale(2, 2),
		ClipsDescendants = true,
		Active = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		StudsOffset = Vector3.new(0, 1, 0),
		StudsOffsetWorldSpace = Vector3.new(0, 1, 0),
		MaxDistance = 15,
		[Children] = {
			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				Text = "Lv 3000",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 20,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
				TextStrokeTransparency = 0.5,
				TextWrapped = true,
			}),
		},
	}) :: any
end
