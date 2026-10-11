--!strict
--[[
	An on / off switch. It only displays Value: the screen decides what a click does
	(usually ask the server and let the replicated data flip it).

		UI.Toggle(scope, { Value = musicOn, OnToggle = function(nextValue) SettingsService:Set("Music", nextValue) end })
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Value: UsedAs<boolean>,
	OnToggle: ((nextValue: boolean) -> ())?,
	Disabled: UsedAs<boolean>?,
}

local WIDTH, HEIGHT, KNOB = 52, 24, 16

return function(scope: Scope, props: Props): TextButton
	local on = scope:Computed(function(use): boolean
		return use(props.Value) == true
	end)
	local margin = (HEIGHT - KNOB) / 2

	return scope:New("TextButton")(Theme.place(props, {
		Name = "Toggle",
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = scope:Spring(
			scope:Computed(function(use): Color3
				return if use(on) then Theme.Colors.Primary else Theme.Colors.Raised
			end),
			Theme.Motion.Speed,
			Theme.Motion.Damping
		),
		BackgroundTransparency = scope:Computed(function(use): number
			return if use(props.Disabled) then 0.8 else 0
		end),
		[Fusion.OnEvent("Activated")] = function()
			if props.OnToggle and Fusion.peek(props.Disabled) ~= true then
				props.OnToggle(not Fusion.peek(on))
			end
		end,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Pill) }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Colors.Border,
				Thickness = Theme.Stroke.Thin,
				Transparency = Theme.Stroke.Transparency,
			}),
			scope:New("Frame")({
				Name = "Knob",
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.fromOffset(KNOB, KNOB),
				BackgroundColor3 = scope:Computed(function(use): Color3
					return if use(on) then Theme.Colors.TextOnPrimary else Theme.Colors.Border
				end),
				Position = scope:Spring(
					scope:Computed(function(use): UDim2
						return UDim2.new(0, if use(on) then WIDTH - KNOB - margin else margin, 0.5, 0)
					end),
					Theme.Motion.Speed,
					Theme.Motion.Damping
				),
				[Fusion.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Pill) }) },
			}),
		},
	})) :: any
end
