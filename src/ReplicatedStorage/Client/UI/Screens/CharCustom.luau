--!strict
--[[
	Character editor (legacy StarterGui.CharCustom): style and colour of torso, legs, arms
	and hair, and the skin tone.

	In the legacy place this GUI was a leftover of the first customization system and
	nothing opened it; the menu's Customize tab replaced it. It stays registered as a
	screen (UIController:Open("CharCustom")).

	The preview is the real character, updated by the server: the window sits at the side
	so the character stays in view. Every click only sends a field name and an index
	through AppearanceService.Change, which validates both. The swatches are the real
	clothing palette and skin tones (Shared.Util.AppearanceAssets) instead of the eight
	named colours the legacy buttons approximated; the legacy "Extras" numbers predate
	named accessories and are gone.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local AppearanceConfig = require(ReplicatedStorage.Shared.Configs.AppearanceConfig)
local AppearanceAssets = require(ReplicatedStorage.Shared.Util.AppearanceAssets)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local Swatch = require(ReplicatedStorage.Client.UI.Components.Swatch)

type Scope = Theme.Scope
type State<T> = Fusion.StateObject<T>
type Section = { Key: string, Text: string, Field: string }

-- Tab -> Appearance field. Skin has tones only.
local SECTIONS: { Section } = {
	{ Key = "Torso", Text = "Torso", Field = "Torso" },
	{ Key = "Legs", Text = "Legs", Field = "Pants" },
	{ Key = "Arms", Text = "Arms", Field = "Arms" },
	{ Key = "Hair", Text = "Hair", Field = "Hair" },
	{ Key = "Skin", Text = "Skin", Field = "SkinColor" },
}
local SKIN_FIELD = "SkinColor"
local COLOR_SUFFIX = "_Color"

local BODY_WIDTH = 488
local TAB_HEIGHT = 40
local HEADING_HEIGHT = 24
local STYLE_CELL = Vector2.new(54, 40)
local SWATCH = 40
local GAP = Theme.Space.S
local STYLE_COLUMNS = math.floor((BODY_WIDTH + GAP) / (STYLE_CELL.X + GAP))
local SWATCH_COLUMNS = math.floor((BODY_WIDTH + GAP) / (SWATCH + GAP))

local function rowsHeight(count: number, columns: number, cell: number): number
	local rows = math.max(1, math.ceil(count / columns))
	return rows * cell + (rows - 1) * GAP
end

local function heading(scope: Scope, text: string, order: number): TextLabel
	return UI.Label(scope, {
		Text = text,
		Variant = "BodyBold",
		Color = Theme.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, HEADING_HEIGHT),
		LayoutOrder = order,
	})
end

local function grid(scope: Scope, name: string, order: number, cell: Vector2, height: number, children: { any }): Frame
	return scope:New("Frame")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("UIGridLayout")({
				CellSize = UDim2.fromOffset(cell.X, cell.Y),
				CellPadding = UDim2.fromOffset(GAP, GAP),
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
		local selected = scope:Value(SECTIONS[1].Key)

		-- A grid of swatches that set `field` to their index; `getColor` is the palette.
		local function swatches(field: string, count: number, getColor: (index: number) -> Color3?, order: number): (Frame, number)
			local current = Bind.data(scope, "Appearance." .. field, 1)
			local items: { any } = {}
			for index = 1, count do
				local color = getColor(index)
				if color then
					table.insert(
						items,
						Swatch(scope, {
							Name = tostring(index),
							Color = color,
							LayoutOrder = index,
							Selected = scope:Computed(function(use): boolean
								return use(current) == index
							end),
							OnClick = function()
								AppearanceService.Change:Fire(field, index)
							end,
						})
					)
				end
			end

			local height = rowsHeight(#items, SWATCH_COLUMNS, SWATCH)
			if #items == 0 then
				-- The palette assets are missing: nothing to pick from.
				return UI.Label(scope, {
					Text = "Colours are not available right now.",
					Variant = "Small",
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, 0, 0, height),
					LayoutOrder = order,
				}) :: any,
					height
			end
			return grid(scope, field, order, Vector2.new(SWATCH, SWATCH), height, items), height
		end

		local function styles(field: string, count: number, order: number): (Frame, number)
			local current = Bind.data(scope, "Appearance." .. field, 1)
			local items: { any } = {}
			for style = 1, count do
				items[style] = UI.Button(scope, {
					Name = tostring(style),
					Text = tostring(style),
					Variant = "Secondary",
					LayoutOrder = style,
					Selected = scope:Computed(function(use): boolean
						return use(current) == style
					end),
					OnClick = function()
						AppearanceService.Change:Fire(field, style)
					end,
				})
			end
			local height = rowsHeight(count, STYLE_COLUMNS, STYLE_CELL.Y)
			return grid(scope, field, order, STYLE_CELL, height, items), height
		end

		local pages: { any } = {}
		local tallest = 0
		for _, section in SECTIONS do
			local content: { any } = {}
			local height = 0

			local function add(title: string, block: Frame, blockHeight: number)
				if #content > 0 then
					height += GAP
				end
				table.insert(content, heading(scope, title, #content + 1))
				table.insert(content, block)
				height += HEADING_HEIGHT + GAP + blockHeight
			end

			if section.Field == SKIN_FIELD then
				local count = AppearanceConfig.Categories.SkinColor.Count
				add("Skin tone", swatches(SKIN_FIELD, count, AppearanceAssets.GetSkin, 2))
			else
				local category = AppearanceConfig.Categories[section.Field]
				add("Style", styles(section.Field, category.Count, 2))
				if category.Colored then
					add(
						"Colour",
						swatches(section.Field .. COLOR_SUFFIX, AppearanceConfig.ColorCount, AppearanceAssets.GetColor, 4)
					)
				end
			end
			tallest = math.max(tallest, height)

			table.insert(
				pages,
				UI.Stack(scope, {
					Name = section.Key,
					Position = UDim2.fromOffset(0, TAB_HEIGHT + Theme.Space.L),
					Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + Theme.Space.L)),
					Gap = GAP,
					Visible = scope:Computed(function(use): boolean
						return use(selected) == section.Key
					end),
					Children = content,
				})
			)
		end

		local tabWidth = math.floor((BODY_WIDTH - (#SECTIONS - 1) * GAP) / #SECTIONS)
		local bodyHeight = TAB_HEIGHT + Theme.Space.L + tallest

		return UI.Screen(scope, {
			Name = "CharCustom",
			DisplayOrder = 10,
			Children = {
				UI.Window(scope, {
					Title = "Character",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -60, 0.5, 0),
					Size = UDim2.fromOffset(BODY_WIDTH + Theme.Space.L * 2, bodyHeight + 52 + Theme.Space.L * 2),
					OnClose = context.Close,
					Children = {
						UI.Tabs(scope, {
							Tabs = SECTIONS :: any,
							Selected = selected,
							TabSize = UDim2.fromOffset(tabWidth, TAB_HEIGHT),
							Gap = GAP,
						}),
						pages,
					},
				}),
			},
		})
	end,
}
