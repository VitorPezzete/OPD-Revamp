--!strict
--[[
	Respec tooltip (legacy MouseTipPerkPoints): what resetting the invested expertise
	points costs. Shown with Tooltip.showPerkPoints() / hidePerkPoints() by the respec button.

	The old periwinkle strip to the left of the cursor, its triangle pointing at it: the
	three tinted perk icons, an arrow, the point icon they turn back into, and the price.
	The pieces are a row now, so they are centred on one line and evenly spaced.

	The price shown is display only: 2,000 Beri per invested point, the legacy number.
	The server computes the real price when the respec is requested.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local MouseTipFollow = require(ReplicatedStorage.Client.UI.Legacy.Components.MouseTipFollow)

type Scope = Fusion.Scope<typeof(Fusion)>

local BERI_PER_POINT = 2000
local COST_COLOR = Color3.fromRGB(127, 255, 127)
local EMPTY_COLOR = Color3.fromRGB(255, 255, 127)

-- The old strip on a 1920x1080 screen (five times as wide as tall).
local SIZE = Vector2.new(512, 100)
local STRIP_COLOR = Color3.fromRGB(156, 171, 255)
-- The triangle is drawn pointing up and turned to the right; half of it sticks out.
local TRIANGLE = "rbxassetid://7118241629"
local TRIANGLE_SIZE = Vector2.new(SIZE.Y, SIZE.Y / 2)
local PERK_ICON = "rbxassetid://8530145081"
local ARROW = "rbxassetid://6278835808"
local POINT_ICON = "rbxassetid://2204238988"
local POINT_COLOR = Color3.fromRGB(102, 130, 255)

local ARROW_SIZE = 48
local POINT_SIZE = 76
local ICON = 44
local CLUSTER = Vector2.new(76, 80)
-- The three perk icons, as the old ones: two side by side and one above, between them.
local CLUSTER_ICONS: { { Position: UDim2, Color: Color3 } } = {
	{ Position = UDim2.new(0, ICON / 2, 1, -ICON / 2), Color = Color3.fromRGB(255, 255, 0) },
	{ Position = UDim2.new(1, -ICON / 2, 1, -ICON / 2), Color = Color3.fromRGB(0, 255, 0) },
	{ Position = UDim2.new(0.5, 0, 0, ICON / 2), Color = Color3.fromRGB(255, 0, 0) },
}

-- A picture drawn turned (the Kit's Image has no rotation).
local function turned(scope: Scope, props: { [string]: any }): Instance
	props.BackgroundTransparency = 1
	return scope:New("ImageLabel")(props)
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local perks = Bind.data(scope, "Expertise.Perks", {})

		local invested = scope:Computed(function(use): number
			local total = 0
			for _, perk in use(perks) :: { [string]: any } do
				if type(perk) == "table" and type(perk.Value) == "number" then
					total += perk.Value
				end
			end
			return total
		end)

		local icons: { Instance } = {}
		for index, icon in CLUSTER_ICONS do
			table.insert(
				icons,
				Kit.Image(scope, {
					Name = "PerkIcon",
					Image = PERK_ICON,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = icon.Position,
					Size = UDim2.fromOffset(ICON, ICON),
					ZIndex = index,
					Children = {
						Kit.Image(scope, {
							Name = "Tint",
							Image = PERK_ICON,
							Color = icon.Color,
							Transparency = 0.5,
							Size = UDim2.fromScale(1, 1),
						}),
					},
				})
			)
		end

		local frame = Kit.Panel(scope, {
			Name = "Frame",
			Image = "",
			Color = STRIP_COLOR,
			Transparency = 0,
			AnchorPoint = Vector2.new(1, 1),
			Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
			Visible = Tooltip.PerkPoints,
			Children = {
				turned(scope, {
					Name = "Triangle",
					Image = TRIANGLE,
					ImageColor3 = STRIP_COLOR,
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
					Padding = Kit.Space.M,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Children = {
						scope:New("Frame")({
							Name = "Perks",
							BackgroundTransparency = 1,
							Size = UDim2.fromOffset(CLUSTER.X, CLUSTER.Y),
							LayoutOrder = 1,
							[Fusion.Children] = icons,
						}),
						-- The old arrow: the picture points up, turned to point at the point icon.
						turned(scope, {
							Name = "Arrow",
							Image = ARROW,
							Rotation = 90,
							Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE),
							LayoutOrder = 2,
						}),
						Kit.Image(scope, {
							Name = "Points",
							Image = POINT_ICON,
							Color = POINT_COLOR,
							Size = UDim2.fromOffset(POINT_SIZE, POINT_SIZE),
							LayoutOrder = 3,
						}),
						Kit.Label(scope, {
							Name = "Description",
							Text = scope:Computed(function(use): string
								local points = use(invested)
								return if points > 0
									then `${Bind.formatNumber(points * BERI_PER_POINT)}`
									else "No Points Invested"
							end),
							Color = scope:Computed(function(use): Color3
								return if use(invested) > 0 then COST_COLOR else EMPTY_COLOR
							end),
							TextSize = Kit.TextSize.Body,
							Fit = true,
							-- What the row leaves: the three pictures, the gaps and the padding.
							Size = UDim2.new(1, -(CLUSTER.X + ARROW_SIZE + POINT_SIZE + 3 * Kit.Space.M), 1, 0),
							LayoutOrder = 4,
						}),
					},
				}),
			},
		})
		-- The point of the triangle on the cursor: it sticks out of the strip by its height.
		MouseTipFollow.bind(scope, frame, TRIANGLE_SIZE.Y)

		return Kit.Screen(scope, {
			Name = "MouseTipPerkPoints",
			-- Over every window, like the rework's: a tip belongs to what is under the cursor.
			DisplayOrder = 100,
			Children = { frame },
		})
	end,
}
