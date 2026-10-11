--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Storage > Frame): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): Frame
	return scope:New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 4,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 0.8),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Visible = false,
		-- legacy behaviour: LocalScript (LocalScript, 44 lines)
		[Children] = {
			require(script.Background)(scope),
			require(script.Storage1)(scope),
			require(script.Storage2)(scope),
			require(script.Storage4)(scope),
			require(script.TextLabel)(scope),
			require(script.Unlock1)(scope),
			require(script.Storage3)(scope),
			require(script.Storage5)(scope),
			require(script.Storage6)(scope),
			require(script.Storage7)(scope),
			require(script.Storage8)(scope),
			require(script.Storage9)(scope),
			require(script.Storage10)(scope),
			require(script.Storage11)(scope),
			require(script.Storage12)(scope),
			require(script.Unlock2)(scope),
			require(script.Unlock3)(scope),
			require(script.Unlock4)(scope),
			require(script.Unlock5)(scope),
			require(script.Unlock6)(scope),
			require(script.Unlock7)(scope),
			require(script.Unlock8)(scope),
			require(script.Unlock9)(scope),
			require(script.Unlock10)(scope),
			require(script.Unlock11)(scope),
			require(script.Unlock12)(scope),
			require(script.SwitchTabRight)(scope),
		},
	}) :: any
end
