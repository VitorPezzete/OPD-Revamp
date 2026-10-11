--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Menu > Frame): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): Frame
	return scope:New("Frame")({
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.7,
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		Position = UDim2.fromScale(0, 0.7),
		Size = UDim2.fromScale(0.1, 0.3),
		[Children] = {
			require(script.Frame)(scope),
			require(script.ImageLabel)(scope),
			require(script.ImageLabels)(scope),
			require(script.ImageLabels2)(scope),
			require(script.ImageLabels3)(scope),
			require(script.ImageLabels4)(scope),
			require(script.ImageLabels5)(scope),
			require(script.ImageLabels6)(scope),
			require(script.ImageLabels7)(scope),
			require(script.ImageLabels8)(scope),
			require(script.A)(scope),
			require(script.B)(scope),
			require(script.C)(scope),
			require(script.D)(scope),
			require(script.E)(scope),
			require(script.F)(scope),
			require(script.G)(scope),
			require(script.H)(scope),
			require(script.Frame2)(scope),
		},
	}) :: any
end
