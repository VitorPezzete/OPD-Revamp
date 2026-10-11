--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Menu > Frame > G): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): TextButton
	return scope:New("TextButton")({
		Name = "G",
		AutoButtonColor = true,
		BackgroundTransparency = 0.85,
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		BorderSizePixel = 1,
		Position = UDim2.fromScale(0.05, -0.34),
		Size = UDim2.fromScale(0.9, 0.15),
		Text = "Storage",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextStrokeTransparency = 0.6,
		TextWrapped = true,
		-- legacy behaviour: LocalScript (LocalScript, 6 lines)
	}) :: any
end
