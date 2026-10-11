--!strict
--[[
	The arrow of the old paged boxes (the Top 100 board, the tutorial): one picture of an
	arrow pointing up, tinted with the box's colour and turned left or right. An arrow with
	nowhere to go is faded.

		ArrowButton(scope, {
			Name = "Arrow1", Direction = "Left", Color = tint,
			Size = UDim2.fromOffset(56, 56), LayoutOrder = 1,
			Faded = atStart,        -- drawn faded, still pressable
			Disabled = atStart,     -- faded, deaf and skipped by the gamepad
			OnClick = previous,
		})
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

export type Props = Kit.Layout & {
	Direction: "Left" | "Right",
	Color: UsedAs<Color3>?,
	Faded: UsedAs<boolean>?,
	Disabled: UsedAs<boolean>?,
	OnClick: (() -> ())?,
}

local ARROW = "rbxassetid://6278835808"
local FADED = 0.7

return function(scope: Scope, props: Props): TextButton
	local merged: any = table.clone(props)
	merged.Name = props.Name or "Arrow"
	merged.Variant = "Ghost"
	merged.Size = props.Size or UDim2.fromOffset(56, 56)
	merged.Children = {
		scope:New("ImageLabel")({
			Name = "Arrow",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Rotation = if props.Direction == "Left" then -90 else 90,
			Image = ARROW,
			ImageColor3 = props.Color or Kit.Colors.Text,
			ImageTransparency = scope:Computed(function(use): number
				local faded = (props.Faded ~= nil and use(props.Faded) == true)
					or (props.Disabled ~= nil and use(props.Disabled) == true)
				return if faded then FADED else 0
			end),
		}),
	}
	return Kit.Button(scope, merged)
end
