--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.MouseTip in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "MouseTip",
		DisplayOrder = 51,
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("TextLabel")({
				Name = "Message",
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Color3.fromRGB(35, 35, 35),
				BackgroundTransparency = 0.45,
				BorderColor3 = Color3.fromRGB(221, 221, 221),
				BorderSizePixel = 1,
				Position = UDim2.fromOffset(996, 157),
				Size = UDim2.fromScale(0.25, 0.07),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextWrapped = true,
				Visible = false,
				-- legacy behaviour: LocalScript (LocalScript, 7 lines)
			}),
		},
	}) :: any
end
