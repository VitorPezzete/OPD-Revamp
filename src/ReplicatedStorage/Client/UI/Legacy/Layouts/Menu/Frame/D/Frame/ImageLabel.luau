--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Menu > Frame > D > Frame > ImageLabel): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ImageLabel
	return scope:New("ImageLabel")({
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		BorderSizePixel = 1,
		Image = "rbxassetid://1012757720",
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 1.3233),
	}) :: any
end
