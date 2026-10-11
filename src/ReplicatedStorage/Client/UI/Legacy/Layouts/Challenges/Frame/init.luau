--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Challenges > Frame): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): Frame
	return scope:New("Frame")({
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Visible = false,
		-- legacy behaviour: ButtonController (LocalScript, 50 lines)
		[Children] = {
			require(script.Button1)(scope),
			require(script.Button)(scope),
			require(script.Button2)(scope),
			require(script.Button4)(scope),
			require(script.Frame)(scope),
		},
	}) :: any
end
