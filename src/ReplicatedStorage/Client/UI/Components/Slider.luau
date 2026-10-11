--!strict
--[[
	A horizontal slider from 0 to 1. It displays Value and reports drags; the screen
	stores the result.

		UI.Slider(scope, { Value = volume, OnChange = function(ratio) volume:set(ratio) end, OnRelease = save })

	OnChange fires while dragging, OnRelease once when the drag ends (the moment to tell
	the server).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Value: UsedAs<number>,
	OnChange: ((ratio: number) -> ())?,
	OnRelease: ((ratio: number) -> ())?,
	Color: UsedAs<Color3>?,
}

local KNOB = 12

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

return function(scope: Scope, props: Props): Frame
	local ratio = scope:Computed(function(use): number
		local value = use(props.Value)
		return if value == value then math.clamp(value, 0, 1) else 0
	end)

	local track: Frame
	local dragging = false
	local last = 0

	local function update(x: number)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		last = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
		if props.OnChange then
			props.OnChange(last)
		end
	end

	table.insert(
		scope,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				update(input.Position.X)
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if dragging and isPointer(input) then
				dragging = false
				if props.OnRelease then
					props.OnRelease(last)
				end
			end
		end)
	)

	track = scope:New("Frame")({
		Name = "Track",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -KNOB, 0, 4),
		BackgroundColor3 = Theme.Colors.Sunken,
		BackgroundTransparency = Theme.Transparency.Sunken,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Pill) }),
			scope:New("UIStroke")({
				Color = Theme.Colors.Border,
				Thickness = Theme.Stroke.Thin,
				Transparency = Theme.Stroke.Transparency,
			}),
			scope:New("Frame")({
				Name = "Fill",
				BackgroundColor3 = props.Color or Theme.Colors.Primary,
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromScale(use(ratio), 1)
				end),
				[Fusion.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Pill) }) },
			}),
			scope:New("Frame")({
				Name = "Knob",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(KNOB, KNOB),
				BackgroundColor3 = Theme.Colors.Primary,
				-- A diamond riding the line.
				Rotation = 45,
				Position = scope:Computed(function(use): UDim2
					return UDim2.fromScale(use(ratio), 0.5)
				end),
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Pill) }),
					scope:New("UIStroke")({ Color = Theme.Colors.Halo, Thickness = Theme.Stroke.Thin }),
				},
			}),
		},
	}) :: any

	return scope:New("Frame")(Theme.place(props, {
		Name = "Slider",
		Size = UDim2.fromOffset(220, 28),
		BackgroundTransparency = 1,
		Active = true,
		[Fusion.OnEvent("InputBegan")] = function(input: InputObject)
			if isPointer(input) then
				dragging = true
				update(input.Position.X)
			end
		end,
		[Fusion.Children] = { track },
	})) :: any
end
