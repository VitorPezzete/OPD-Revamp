--!strict
--[[
	The affinities of a devil fruit as a round chart: four quarters, one per skill
	(Defense top-left, Melee top-right, Sniper bottom-left, Sword bottom-right). Each
	quarter holds a disc centred on the middle of the chart that grows with the
	multiplier: nothing at 1.0, the whole chart at 2.0. Ten faint rings mark the steps.

		AffinityChart(scope, { Affinities = multipliers, Size = UDim2.fromOffset(150, 150) })

	Not part of Components/init: require it by path
	(ReplicatedStorage.Client.UI.Components.AffinityChart). Affinities maps a skill to
	its multiplier (1.0-2.0); nil draws the empty chart. The chart only draws: the
	figures are written next to it by the screen. Keep the Size square.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Affinities: UsedAs<{ [string]: number }?>,
}

-- Each quarter: where it sits in the chart, and its corner that touches the middle.
local QUARTERS = {
	{ Skill = "Defense", Position = Vector2.new(0, 0), Centre = Vector2.new(1, 1) },
	{ Skill = "Melee", Position = Vector2.new(0.5, 0), Centre = Vector2.new(0, 1) },
	{ Skill = "Sniper", Position = Vector2.new(0, 0.5), Centre = Vector2.new(1, 0) },
	{ Skill = "Sword", Position = Vector2.new(0.5, 0.5), Centre = Vector2.new(0, 0) },
}

-- The same colours as the skills on the Stats tab.
local COLORS: { [string]: Color3 } = {
	Defense = Theme.Colors.Success,
	Melee = Theme.Colors.Danger,
	Sniper = Theme.Colors.Warning,
	Sword = Theme.Colors.Gems,
}

local RINGS = 10
-- Light enough for the rings to show through.
local FILL_TRANSPARENCY = 0.35
local RING_TRANSPARENCY = 0.7

local function disc(scope: Scope, props: { [any]: any }): Frame
	props.AnchorPoint = Vector2.new(0.5, 0.5)
	props[Fusion.Children] = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		props[Fusion.Children],
	} :: { any }
	return scope:New("Frame")(props) :: any
end

local function line(scope: Scope, vertical: boolean): Frame
	return scope:New("Frame")({
		Name = if vertical then "Vertical" else "Horizontal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = if vertical then UDim2.new(0, 1, 1, 0) else UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Colors.Border,
		BorderSizePixel = 0,
		ZIndex = 4,
	}) :: any
end

return function(scope: Scope, props: Props): Frame
	local rings: { any } = {}
	for step = 1, RINGS do
		local scale = step / RINGS
		rings[step] = disc(scope, {
			Name = `Ring{step}`,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(scale, scale),
			BackgroundTransparency = 1,
			ZIndex = 2,
			[Fusion.Children] = scope:New("UIStroke")({
				Color = Theme.Colors.TextDim,
				Thickness = Theme.Stroke.Thin,
				Transparency = RING_TRANSPARENCY,
			}),
		})
	end

	local quarters: { any } = {}
	for index, quarter in QUARTERS do
		-- 0 at a multiplier of 1.0, 1 at 2.0.
		local ratio = scope:Computed(function(use): number
			local affinities = use(props.Affinities)
			local multiplier = if affinities then tonumber(affinities[quarter.Skill]) or 1 else 1
			return if multiplier == multiplier then math.clamp(multiplier - 1, 0, 1) else 0
		end)
		local diameter = scope:Spring(ratio, Theme.Motion.SlowSpeed, Theme.Motion.Damping)

		quarters[index] = scope:New("Frame")({
			Name = quarter.Skill,
			Position = UDim2.fromScale(quarter.Position.X, quarter.Position.Y),
			Size = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 3,
			[Fusion.Children] = disc(scope, {
				Name = "Fill",
				Position = UDim2.fromScale(quarter.Centre.X, quarter.Centre.Y),
				-- The quarter is half the chart, so a full disc is twice its size.
				Size = scope:Computed(function(use): UDim2
					local scale = math.max(0, use(diameter)) * 2
					return UDim2.fromScale(scale, scale)
				end),
				BackgroundColor3 = COLORS[quarter.Skill],
				BackgroundTransparency = FILL_TRANSPARENCY,
				BorderSizePixel = 0,
			}),
		})
	end

	return scope:New("Frame")(Theme.place(props, {
		Name = "AffinityChart",
		Size = UDim2.fromOffset(150, 150),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			-- The well the chart is drawn in.
			disc(scope, {
				Name = "Face",
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.Sunken,
				BackgroundTransparency = Theme.Transparency.Sunken,
				BorderSizePixel = 0,
				ZIndex = 1,
				[Fusion.Children] = scope:New("UIStroke")({
					Color = Theme.Colors.Border,
					Thickness = Theme.Stroke.Thin,
					Transparency = Theme.Stroke.Transparency,
				}),
			}),
			rings,
			quarters,
			line(scope, true),
			line(scope, false),
		} :: { any },
	})) :: any
end
