--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Storage > Frame > SwitchTabRight): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): TextButton
	return scope:New("TextButton")({
		Name = "SwitchTabRight",
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = true,
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		BorderSizePixel = 1,
		FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		Position = UDim2.fromScale(0.925, 0.5),
		Size = UDim2.fromScale(0.075, 0.2),
		Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
		Text = ">",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextWrapped = true,
		Visible = false,
		-- legacy behaviour: LocalScript (LocalScript, 5 lines)
	}) :: any
end
