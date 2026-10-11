--!strict
--[[
	GENERATED from Workspace.AA.ToPlayerHead.DisplayHealth in the legacy place: static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): BillboardGui
	return scope:New("BillboardGui")({
		Name = "DisplayHealth",
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		Size = UDim2.fromScale(6, 1.5),
		Active = true,
		MaxDistance = 100,
		[Children] = {
			scope:New("Frame")({
				BorderSizePixel = 1,
				Position = UDim2.fromScale(0, -0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				[Children] = {
					scope:New("Frame")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.75),
						Size = UDim2.fromScale(0.5, 0.05),
						BackgroundColor3 = Color3.fromRGB(255, 0, 0),
						BorderSizePixel = 0,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						Visible = false,
						[Children] = {
							scope:New("Frame")({
								Size = UDim2.fromScale(1, 1),
								BackgroundColor3 = Color3.fromRGB(17, 255, 0),
								BorderSizePixel = 0,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								-- legacy behaviour: DisplayHealthServer (Script, 57 lines)
							}),
							scope:New("ImageLabel")({
								Name = "SysFail",
								BorderSizePixel = 1,
								Position = UDim2.fromOffset(-25, 0),
								Size = UDim2.fromOffset(20, 20),
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Visible = false,
								Image = "rbxassetid://1915498085",
								ImageTransparency = 0.6,
								-- legacy behaviour: ClientSysFail (LocalScript, 22 lines)
							}),
						},
					}),
				},
			}),
		},
	}) :: any
end
