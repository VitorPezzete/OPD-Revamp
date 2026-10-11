--!strict
--[[
	Full-screen character editor (legacy StarterGui.CharCustom): style and colour of torso,
	arms, legs and hair, and the skin tone.

	In the old place this GUI was a leftover of the first customization system: its frame
	was hidden, it had no script and nothing opened it; the menu's Customize tab replaced
	it. It is registered as a screen so it can be opened (UIController:Open("CharCustom")),
	but nothing opens it.

	The arrangement is the old one: a column at the left edge (Torso, Arms, Legs, Skin),
	a column at the right edge (Hair), and "Main Menu" at the bottom of the screen. The
	middle is empty on purpose: the preview is the real character, updated by the server,
	exactly like the menu tab. The old columns were plain grey boxes; so are these.

	What can be picked today is larger than what the old screen was drawn for, so each
	section is built from the game's data instead of the old handful of buttons:
	- one numbered button per style the category really has (AppearanceConfig);
	- one swatch per colour of the clothing palette (the eight named colours are gone:
	  they could only approximate it);
	- one swatch per skin tone;
	- the current choice is marked (green number, green frame);
	- "Extras" (twelve numbered buttons) predates named accessories and is not rebuilt.
	A column scrolls when its sections outgrow it.

	Every click only sends a field name and an index through AppearanceService.Change,
	which validates both.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local AppearanceConfig = require(ReplicatedStorage.Shared.Configs.AppearanceConfig)
local AppearanceAssets = require(ReplicatedStorage.Shared.Util.AppearanceAssets)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)
local ColorButton = require(ReplicatedStorage.Client.UI.Legacy.Components.ColorButton)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>
type Section = { Text: string, Field: string }

-- The sections of each column, top to bottom, and the Appearance field each one edits.
local LEFT: { Section } = {
	{ Text = "Torso", Field = "Torso" },
	{ Text = "Arms", Field = "Arms" },
	{ Text = "Legs", Field = "Pants" },
	{ Text = "Skin", Field = "SkinColor" },
}
local RIGHT: { Section } = {
	{ Text = "Hair", Field = "Hair" },
}
local SKIN_FIELD = "SkinColor"
local COLOR_SUFFIX = "_Color"

local COLUMN_COLOR = Color3.fromRGB(163, 162, 165)
local COLUMN_SIZE = Vector2.new(480, 820)
-- From the edge of the screen to a column, and from the bottom to the button.
local EDGE = 38
local COLUMN_PADDING = Kit.Space.M
-- Room the column's scroll bar takes.
local SCROLL_BAR = 8
local CONTENT_WIDTH = COLUMN_SIZE.X - 2 * COLUMN_PADDING - SCROLL_BAR
local HEADING_HEIGHT = 44
local GRID_GAP = Kit.Space.XS
local STYLE_COLUMNS = 6
local STYLE_HEIGHT = 44
local SWATCH_COLUMNS = 13
local SKIN_HEIGHT = 56
local MENU_BUTTON = Vector2.new(384, 80)

-- Width of a cell when `columns` of them share the content width.
local function cellWidth(columns: number): number
	return math.floor((CONTENT_WIDTH - (columns - 1) * GRID_GAP) / columns)
end

-- A grid that takes the height its cells need.
local function grid(scope: Scope, name: string, order: number, cell: Vector2, children: { any }): Frame
	return scope:New("Frame")({
		Name = name,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		[Fusion.Children] = {
			scope:New("UIGridLayout")({
				CellSize = UDim2.fromOffset(cell.X, cell.Y),
				CellPadding = UDim2.fromOffset(GRID_GAP, GRID_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			children,
		} :: { any },
	}) :: any
end

return {
	-- On a phone the engine's tool bar would be drawn over this window (UIController).
	HidesHotbar = true,

	Mount = function(scope: Scope, _gui: any, context: any)
		local AppearanceService = Knit.GetService("AppearanceService")

		local function close()
			context.Close()
		end
		local function pick(field: string, index: number)
			AppearanceService.Change:Fire(field, index)
		end

		-- One numbered button per style of the category.
		local function styles(field: string, count: number, order: number): Frame
			local current = Bind.data(scope, "Appearance." .. field, 1)
			local items: { any } = {}
			for style = 1, count do
				items[style] = Kit.Button(scope, {
					Name = tostring(style),
					Text = tostring(style),
					Variant = "Grey",
					LayoutOrder = style,
					Selected = scope:Computed(function(use): boolean
						return use(current) == style
					end),
					OnClick = function()
						pick(field, style)
					end,
				})
			end
			return grid(scope, "Styles", order, Vector2.new(cellWidth(STYLE_COLUMNS), STYLE_HEIGHT), items)
		end

		-- One swatch per colour `getColor` knows, setting `field` to its index. An index
		-- the palette has no colour for is skipped.
		local function swatches(
			field: string,
			count: number,
			columns: number,
			height: number?,
			getColor: (index: number) -> Color3?,
			order: number
		): Frame
			local current = Bind.data(scope, "Appearance." .. field, 1)
			local items: { any } = {}
			for index = 1, count do
				local color = getColor(index)
				if color then
					table.insert(
						items,
						ColorButton(scope, {
							Name = `Swatch{index}`,
							Color = color,
							LayoutOrder = index,
							Selected = scope:Computed(function(use): boolean
								return use(current) == index
							end),
							OnClick = function()
								pick(field, index)
							end,
						})
					)
				end
			end
			local width = cellWidth(columns)
			return grid(scope, "Colors", order, Vector2.new(width, height or width), items)
		end

		local function section(entry: Section, order: number): Instance
			local category = AppearanceConfig.Categories[entry.Field]
			local blocks: { any } = {
				Kit.Well(scope, {
					Name = "Heading",
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, HEADING_HEIGHT),
					Transparency = 0.5,
					Children = Kit.Label(scope, {
						Text = entry.Text,
						TextSize = Kit.TextSize.Heading,
						Size = UDim2.fromScale(1, 1),
					}),
				}),
			}
			if entry.Field == SKIN_FIELD then
				-- One row, as the old four tones were (it wraps if the tones outgrow it).
				local count = category.Count
				table.insert(
					blocks,
					swatches(SKIN_FIELD, count, math.clamp(count, 1, SWATCH_COLUMNS), SKIN_HEIGHT, AppearanceAssets.GetSkin, 2)
				)
			else
				table.insert(blocks, styles(entry.Field, category.Count, 2))
				if category.Colored then
					table.insert(
						blocks,
						swatches(
							entry.Field .. COLOR_SUFFIX,
							AppearanceConfig.ColorCount,
							SWATCH_COLUMNS,
							nil,
							AppearanceAssets.GetColor,
							3
						)
					)
				end
			end

			return Kit.Stack(scope, {
				Name = entry.Text,
				LayoutOrder = order,
				Gap = Kit.Space.S,
				Size = UDim2.fromOffset(CONTENT_WIDTH, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Children = blocks,
			})
		end

		local function column(name: string, entries: { Section }, anchor: number, offset: number): Instance
			local sections: { Instance } = {}
			for order, entry in entries do
				table.insert(sections, section(entry, order))
			end
			return Kit.Well(scope, {
				Name = name,
				AnchorPoint = Vector2.new(anchor, 0.5),
				Position = UDim2.new(anchor, offset, 0.5, 0),
				Size = UDim2.fromOffset(COLUMN_SIZE.X, COLUMN_SIZE.Y),
				Color = COLUMN_COLOR,
				Transparency = 0.3,
				Children = Kit.Scroll(scope, {
					Background = false,
					Gap = Kit.Space.L,
					Padding = COLUMN_PADDING,
					Children = sections,
				}),
			})
		end

		-- The left column is the "Window" the gamepad looks for: the selection on open.
		local left = column("Window", LEFT, 0, EDGE)
		local right = column("Right", RIGHT, 1, -EDGE)

		local screen = Kit.Screen(scope, {
			Name = "CharCustom",
			Children = {
				left,
				right,
				Kit.Button(scope, {
					Name = "Customize",
					Text = "Main Menu",
					Variant = "Blue",
					TextSize = Kit.TextSize.Title,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -EDGE),
					Size = UDim2.fromOffset(MENU_BUTTON.X, MENU_BUTTON.Y),
					OnClick = close,
				}),
			},
		})
		-- B closes it from anywhere, like "Main Menu".
		Closers.register(scope, screen, close)
		return screen
	end,
}
