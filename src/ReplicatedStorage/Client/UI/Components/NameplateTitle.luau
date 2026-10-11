--!strict
--[[
	The title that floats over a character: its name and, when it has one, its level.
	It replaces the engine's own name tag, which NameplateController turns off.

		NameplateTitle(scope, { Name = "Zombie", Level = levelState, StudsOffset = offset })

	Sized in pixels, so it reads the same at any distance up to MaxDistance. The health bar
	under it is sized in studs: the title hangs from its own bottom edge (SizeOffset), a
	little above the bar, so however large its pixels are next to the bar's studs it only
	ever grows upwards and never lies over the bar. White text with a black 1 pixel
	outline: it is drawn straight over the world.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Numerals = require(ReplicatedStorage.Client.UI.Util.Numerals)
local Label = require(script.Parent.Label)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = {
	Name: UsedAs<string>,
	-- Anything that is not a number leaves the level line out.
	Level: UsedAs<any>?,
	-- Where the title floats, from the adornee's centre.
	StudsOffset: Vector3?,
	MaxDistance: number?,
}

-- Pixels.
local SIZE = UDim2.fromOffset(260, 44)
local NAME_SIZE = 17
local LEVEL_SIZE = 14
-- Studs from the offset to the bottom edge of the title: just over the health bar
-- (UI.Nameplate: 0.4 up, 0.15 tall). In the same space as the bar's own offset (StudsOffset,
-- which follows the camera): a world-space rise shrinks on screen when the camera looks
-- down on the character, and the title then sank into the bar.
local RISE = Vector3.new(0, 0.65, 0)
-- Half the gui's own height up: its bottom edge is what sits at RISE.
local BOTTOM_ANCHORED = Vector2.new(0, 0.5)
local OUTLINE_THICKNESS = 1

return function(scope: Scope, props: Props): BillboardGui
	local level = props.Level
	local hasLevel = scope:Computed(function(use): boolean
		return type(use(level)) == "number"
	end)

	return scope:New("BillboardGui")({
		Name = "NameplateTitle",
		Size = SIZE,
		StudsOffset = (props.StudsOffset or Vector3.zero) + RISE,
		SizeOffset = BOTTOM_ANCHORED,
		MaxDistance = props.MaxDistance or 60,
		LightInfluence = 0,
		ResetOnSpawn = false,
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Label(scope, {
				Name = "Level",
				Text = scope:Computed(function(use): string
					local value = use(level)
					return if type(value) == "number" then `Lv {Numerals.format(value)}` else ""
				end),
				Font = Numerals.Font,
				TextSize = LEVEL_SIZE,
				Color = Theme.Colors.White,
				Outline = true,
				OutlineColor = Theme.Colors.Black,
				OutlineThickness = OUTLINE_THICKNESS,
				OutlineTransparency = 0,
				Visible = hasLevel,
				LayoutOrder = 1,
			}),
			Label(scope, {
				Name = "Title",
				Text = props.Name,
				Font = Numerals.Font,
				TextSize = NAME_SIZE,
				Color = Theme.Colors.White,
				Outline = true,
				OutlineColor = Theme.Colors.Black,
				OutlineThickness = OUTLINE_THICKNESS,
				OutlineTransparency = 0,
				LayoutOrder = 2,
			}),
		},
	}) :: any
end
