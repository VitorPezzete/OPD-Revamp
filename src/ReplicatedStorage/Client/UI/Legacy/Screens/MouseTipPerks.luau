--!strict
--[[
	Expertise perk tooltip (legacy MouseTipPerks): the old dark box to the left of the
	cursor, its triangle pointing at it. On the left the perk icon, filled from the bottom
	up to the invested ratio, with "value / limit" in a white box under it; on the right
	the perk description. The expertise menu feeds it through
	Tooltip.showPerk({ Description, Value, Limit, Icon, IconColor, ProgressColor }).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local MouseTipFollow = require(ReplicatedStorage.Client.UI.Legacy.Components.MouseTipFollow)

type Scope = Fusion.Scope<typeof(Fusion)>

local DEFAULT_COLOR = Color3.fromRGB(115, 159, 255)

-- The old box on a 1920x1080 screen (twice as wide as tall).
local SIZE = Vector2.new(512, 256)
local BOX_COLOR = Color3.fromRGB(40, 40, 40)
-- The triangle is drawn pointing up and turned to the right; it is as tall as the box.
local TRIANGLE = "rbxassetid://7118241629"
local TRIANGLE_SIZE = Vector2.new(SIZE.Y, SIZE.Y / 2)
-- The plate every perk icon is drawn on, and the icon shown until a perk names its own.
local PERK_PLATE = "rbxassetid://8530145081"
local DEFAULT_ICON = "rbxassetid://8530041421"

local ICON_SIZE = 128
local COLUMN_WIDTH = 176
local PROGRESS_SIZE = Vector2.new(104, 40)

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		-- Fraction of the icon left empty: the fill frame slides down and its image slides
		-- back up by the same amount, so the image stays put while being clipped.
		local empty = scope:Computed(function(use): number
			local perk = use(Tooltip.Perk)
			if not perk or perk.Limit <= 0 then
				return 1
			end
			return 1 - math.clamp(perk.Value / perk.Limit, 0, 1)
		end)

		local frame = Kit.Panel(scope, {
			Name = "Frame",
			Image = "",
			Color = BOX_COLOR,
			Transparency = 0,
			AnchorPoint = Vector2.new(1, 1),
			Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
			Visible = scope:Computed(function(use): boolean
				return use(Tooltip.Perk) ~= nil
			end),
			Children = {
				scope:New("ImageLabel")({
					Name = "Triangle",
					BackgroundTransparency = 1,
					Image = TRIANGLE,
					ImageColor3 = BOX_COLOR,
					Rotation = -90,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(1, TRIANGLE_SIZE.Y / 2 - 1, 0.5, 0),
					Size = UDim2.fromOffset(TRIANGLE_SIZE.X, TRIANGLE_SIZE.Y),
				}),
				Kit.Stack(scope, {
					Name = "Row",
					Direction = "Horizontal",
					Size = UDim2.fromScale(1, 1),
					Gap = Kit.Space.M,
					Padding = Kit.Space.L,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Children = {
						Kit.Stack(scope, {
							Name = "Perk",
							Size = UDim2.new(0, COLUMN_WIDTH, 1, 0),
							Gap = Kit.Space.M,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							LayoutOrder = 1,
							Children = {
								Kit.Image(scope, {
									Name = "PerkIcon",
									Image = PERK_PLATE,
									Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
									LayoutOrder = 1,
									Children = {
										scope:New("Frame")({
											Name = "ProgressFrame",
											BackgroundTransparency = 1,
											ClipsDescendants = true,
											Size = UDim2.fromScale(1, 1),
											Position = scope:Computed(function(use): UDim2
												return UDim2.fromScale(0, use(empty))
											end),
											[Fusion.Children] = {
												Kit.Image(scope, {
													Name = "Fill",
													Image = PERK_PLATE,
													Transparency = 0.5,
													Size = UDim2.fromScale(1, 1),
													Position = scope:Computed(function(use): UDim2
														return UDim2.fromScale(0, -use(empty))
													end),
													Color = scope:Computed(function(use): Color3
														local perk = use(Tooltip.Perk)
														return (perk and (perk.ProgressColor or perk.IconColor)) or DEFAULT_COLOR
													end),
												}),
											},
										}),
										Kit.Image(scope, {
											Name = "Icon",
											Size = UDim2.fromScale(1, 1),
											ZIndex = 2,
											Image = scope:Computed(function(use): string
												local perk = use(Tooltip.Perk)
												return (perk and perk.Icon) or DEFAULT_ICON
											end),
											Color = scope:Computed(function(use): Color3
												local perk = use(Tooltip.Perk)
												return (perk and perk.IconColor) or DEFAULT_COLOR
											end),
										}),
									},
								}),
								Kit.Panel(scope, {
									Name = "Progress",
									Image = "",
									Color = Kit.Colors.Box,
									Transparency = 0,
									Size = UDim2.fromOffset(PROGRESS_SIZE.X, PROGRESS_SIZE.Y),
									LayoutOrder = 2,
									Children = {
										scope:New("UICorner")({ CornerRadius = UDim.new(0.2, 0) }),
										Kit.Label(scope, {
											Name = "Text",
											Text = scope:Computed(function(use): string
												local perk = use(Tooltip.Perk)
												return if perk then `{perk.Value} / {perk.Limit}` else ""
											end),
											TextSize = Kit.TextSize.Body,
											Outline = false,
											Fit = true,
											Size = UDim2.fromScale(1, 1),
										}),
									},
								}),
							},
						}),
						Kit.Label(scope, {
							Name = "Description",
							Text = scope:Computed(function(use): string
								local perk = use(Tooltip.Perk)
								return if perk then perk.Description else ""
							end),
							TextSize = Kit.TextSize.Small,
							Fit = true,
							-- What the row leaves: the perk column, the gap and the padding.
							Size = UDim2.new(1, -(COLUMN_WIDTH + Kit.Space.M), 1, 0),
							LayoutOrder = 2,
						}),
					},
				}),
			},
		})
		-- The point of the triangle on the cursor: it sticks out of the box by its height.
		MouseTipFollow.bind(scope, frame, TRIANGLE_SIZE.Y)

		return Kit.Screen(scope, {
			Name = "MouseTipPerks",
			-- Over every window, like the rework's: a tip belongs to what is under the cursor.
			DisplayOrder = 100,
			Children = { frame },
		})
	end,
}
