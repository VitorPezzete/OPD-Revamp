--!strict
--[[
	Custom player list, top-right corner: one row per player, sorted by bounty. The
	header and every row are split the same way into two strips: the player (rank badge,
	top 100 / legendary star, name) and the bounty, centred in its strip.

	The small button left of the header folds the rows away and brings them back: the
	legacy list's hide button, same picture, same place against the list. The header stays
	either way, so the button never moves and is always there to press (mouse, touch, or
	selected with a gamepad).

	Everything shown comes from Player attributes (PlayerListService, SettingsService,
	LeaderboardService): other players' data is not replicated. A player who hides their
	bounty shows an empty bounty strip and sinks to the bottom. Hidden staff are listed
	for owners (and for themselves) only.

	The ScreenGui is named Core_i7: SettingsController enables / disables it from
	Settings.Player_List. The engine's own list stays off either way.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local RankConfig = require(ReplicatedStorage.Shared.Configs.RankConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local MenuSpace = require(ReplicatedStorage.Client.UI.Util.MenuSpace)
local Numerals = require(ReplicatedStorage.Client.UI.Util.Numerals)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local ScreenScale = require(ReplicatedStorage.Client.UI.Util.ScreenScale)

type Scope = Theme.Scope

local ATTRIBUTES = RankConfig.Attributes

local PANEL_WIDTH = 296
-- Top edge level with the health bar (HealthBar's TOP_MARGIN, both ignoring the top bar inset).
local TOP_MARGIN = 8
local RIGHT_MARGIN = 12
local HEADER_HEIGHT = 23
local LIST_TRANSPARENCY = 0.5
-- Arimo runs wider than the serif of the theme: a size that keeps long names whole.
local LIST_TEXT_SIZE = 15
local ROW_HEIGHT = 22
local ROW_GAP = 3
-- Rows shown before the list scrolls.
local MAX_ROWS = 12
-- A touch screen shorter than this (pixels) is a phone: the height below which
-- UI.Util.ScreenScale starts enlarging the interface.
local PHONE_HEIGHT = 720
-- Width of the bounty strip, of the header and of every row, and the gap between it
-- and the player strip.
local BOUNTY_WIDTH = 98
local STRIP_GAP = 3
local ICON_SIZE = 16
local ICON_GAP = 4
-- The hide button of the legacy list (its ShowButton and HideButton shared this picture,
-- drawn in see-through black), kept just left of the list's top-left corner.
local HIDE_ICON = "rbxassetid://5648080970"
-- As tall as the header with a mouse; a phone needs something a thumb can hit.
local HIDE_SIZE = if ScreenScale.Touch then 40 else HEADER_HEIGHT
local HIDDEN_BOUNTY_TEXT = ""
-- LayoutOrder is a 32-bit integer.
local MAX_ORDER = 2 ^ 31 - 1

local localPlayer = Players.LocalPlayer

local function buildRow(scope: Scope, player: Player): Frame
	local bounty = Bind.attribute(scope, player, ATTRIBUTES.Bounty, nil)
	local hideBounty = Bind.attribute(scope, player, ATTRIBUTES.HideBounty, false)
	local legendary = Bind.attribute(scope, player, ATTRIBUTES.Legendary, false)
	local top = Bind.attribute(scope, player, ATTRIBUTES.Top, false)
	local rank = Bind.attribute(scope, player, ATTRIBUTES.Rank, nil)
	local tester = Bind.attribute(scope, player, ATTRIBUTES.Tester, nil)

	local shownBounty = scope:Computed(function(use): number?
		local value = use(bounty)
		return if use(hideBounty) ~= true and type(value) == "number" then value else nil
	end)

	-- Moderator, owner, then the tester ranks.
	local badge = scope:Computed(function(use): string?
		local staff = use(rank)
		if staff == "Mod" or staff == "Owner" then
			return staff
		end
		local value = use(tester)
		return if type(value) == "string" and RankConfig.BadgeColors[value] then value else nil
	end)

	local starColor = scope:Computed(function(use): Color3?
		if use(top) == true then
			return if use(hideBounty) == true then RankConfig.StarLegendaryColor else RankConfig.StarTopColor
		elseif use(legendary) == true then
			return RankConfig.StarLegendaryColor
		end
		return nil
	end)

	-- Width taken by the icons left of the name.
	local iconsWidth = scope:Computed(function(use): number
		local count = (if use(badge) then 1 else 0) + (if use(starColor) then 1 else 0)
		return count * (ICON_SIZE + ICON_GAP)
	end)

	local isLocal = player == localPlayer

	local function strip(name: string, props: { [any]: any }, children: { Instance }): Instance
		props.Name = name
		props.Color = Theme.Colors.Black
		props.Transparency = LIST_TRANSPARENCY
		props.Radius = Theme.Radius.Small
		props.Stroke = false
		props.Gradient = false
		props.Padding = 0
		props.Children = children
		return UI.Panel(scope, props)
	end

	return scope:New("Frame")({
		Name = player.Name,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = scope:Computed(function(use): number
			local value = use(shownBounty)
			return if value then -math.clamp(math.floor(value), 0, MAX_ORDER) else 1
		end),
		[Fusion.Children] = {
			-- Each strip is its own see-through black piece, like the header's.
			strip("Player", { Size = UDim2.new(1, -(BOUNTY_WIDTH + STRIP_GAP), 1, 0) }, {
				UI.Image(scope, {
					Name = "Badge",
					Image = RankConfig.BadgeIcon,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, Theme.Space.S, 0.5, 0),
					Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
					Color = scope:Computed(function(use): Color3
						local name = use(badge)
						return if name then RankConfig.BadgeColors[name] else Theme.Colors.Text
					end),
					Visible = scope:Computed(function(use): boolean
						return use(badge) ~= nil
					end),
				}),
				UI.Image(scope, {
					Name = "Star",
					Image = RankConfig.StarIcon,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = scope:Computed(function(use): UDim2
						local offset = if use(badge) then ICON_SIZE + ICON_GAP else 0
						return UDim2.new(0, Theme.Space.S + offset, 0.5, 0)
					end),
					Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
					Color = scope:Computed(function(use): Color3
						return use(starColor) or Theme.Colors.Text
					end),
					Visible = scope:Computed(function(use): boolean
						return use(starColor) ~= nil
					end),
				}),
				UI.Label(scope, {
					Name = "PlayerName",
					Text = player.Name,
					Variant = if isLocal then "BodyBold" else "Body",
					TextSize = LIST_TEXT_SIZE,
					Color = Theme.Colors.White,
					Font = Numerals.Plain,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Position = scope:Computed(function(use): UDim2
						return UDim2.fromOffset(Theme.Space.S + use(iconsWidth), 0)
					end),
					Size = scope:Computed(function(use): UDim2
						return UDim2.new(1, -(Theme.Space.S * 2 + use(iconsWidth)), 1, 0)
					end),
				}),
			}),
			strip("Bounty", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, BOUNTY_WIDTH, 1, 0),
			}, {
				UI.Label(scope, {
					Name = "Amount",
					Text = scope:Computed(function(use): string
						local value = use(shownBounty)
						return if value then Bind.formatNumber(value) else HIDDEN_BOUNTY_TEXT
					end),
					Variant = "BodyBold",
					TextSize = LIST_TEXT_SIZE,
					Color = Theme.Colors.White,
					Font = Numerals.Plain,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.fromOffset(Theme.Space.XS, 0),
					Size = UDim2.new(1, -Theme.Space.XS * 2, 1, 0),
				}),
			}),
		},
	}) :: Frame
end

-- The list scrolls by wheel, drag or stick; its bar would be drawn over the right edge of
-- the bounty strips, and its inset would make the rows narrower than the header.
local function noBar(scroll: ScrollingFrame): ScrollingFrame
	scroll.ScrollBarThickness = 0
	scroll.VerticalScrollBarInset = Enum.ScrollBarInset.None
	scroll.HorizontalScrollBarInset = Enum.ScrollBarInset.None
	return scroll
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)

		local players = scope:Value(Players:GetPlayers())
		-- A phone has no room for the list beside the touch controls: it starts folded
		-- there, one tap on its button away.
		local collapsed = scope:Value(ScreenScale.Touch and Fusion.peek(ScreenScale.Viewport).Y < PHONE_HEIGHT)
		local viewerRank = Bind.attribute(scope, localPlayer, ATTRIBUTES.Rank, nil)
		-- Bumped whenever a player's "hidden from the list" attribute changes.
		local hiddenRevision = scope:Value(0)

		local hiddenWatchers: { [Player]: RBXScriptConnection } = {}
		local function watch(player: Player)
			if hiddenWatchers[player] then
				return
			end
			hiddenWatchers[player] = player:GetAttributeChangedSignal(ATTRIBUTES.Hidden):Connect(function()
				hiddenRevision:set(Fusion.peek(hiddenRevision) + 1)
			end)
		end
		local function unwatch(player: Player)
			local connection = hiddenWatchers[player]
			if connection then
				connection:Disconnect()
				hiddenWatchers[player] = nil
			end
		end
		table.insert(scope, function()
			for _, connection in hiddenWatchers do
				connection:Disconnect()
			end
			table.clear(hiddenWatchers)
		end)

		for _, player in Players:GetPlayers() do
			watch(player)
		end
		Bind.connect(scope, Players.PlayerAdded, function(player: Player)
			watch(player)
			players:set(Players:GetPlayers())
		end)
		-- The leaving player is still in GetPlayers while PlayerRemoving runs.
		Bind.connect(scope, Players.PlayerRemoving, function(leaving: Player)
			unwatch(leaving)
			local remaining = Players:GetPlayers()
			local index = table.find(remaining, leaving)
			if index then
				table.remove(remaining, index)
			end
			players:set(remaining)
		end)

		local listed = scope:Computed(function(use): { Player }
			use(hiddenRevision)
			local seesHidden = use(viewerRank) == "Owner"
			local result: { Player } = {}
			for _, player in use(players) do
				if seesHidden or player == localPlayer or player:GetAttribute(ATTRIBUTES.Hidden) ~= true then
					table.insert(result, player)
				end
			end
			return result
		end)

		local listHeight = scope:Computed(function(use): UDim2
			local rows = math.min(#use(listed), MAX_ROWS)
			return UDim2.new(1, 0, 0, rows * ROW_HEIGHT + math.max(rows - 1, 0) * ROW_GAP)
		end)

		return UI.Screen(scope, {
			Name = "Core_i7",
			DisplayOrder = 1,
			-- Level with the health bar, which also sits in the strip of the top bar.
			IgnoreGuiInset = true,
			Children = {
				UI.Panel(scope, {
					Name = "PlayerList",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -RIGHT_MARGIN, 0, TOP_MARGIN),
					Size = UDim2.fromOffset(PANEL_WIDTH, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					-- Touch: a menu window or one of the menu's screens takes the room of the
					-- list (UI.Util.MenuSpace). The panel, not the gui: its Enabled is the
					-- "Disable Player List" setting's (SettingsController).
					Visible = if ScreenScale.Touch
						then scope:Computed(function(use): boolean
							return not use(MenuSpace.Busy)
						end)
						else nil,
					-- Nothing behind the list as a whole: the header and each row carry the black.
					Transparency = 1,
					Stroke = false,
					-- No padding: the header's top edge is the list's, level with the health bar.
					Padding = 0,
					Children = {
						UI.Stack(scope, {
							Name = "Content",
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Gap = Theme.Space.S,
							Children = {
								scope:New("Frame")({
									Name = "Header",
									Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
									BackgroundTransparency = 1,
									LayoutOrder = 1,
									[Fusion.Children] = {
										scope:New("Frame")({
											Name = "PlayerHeader",
											Size = UDim2.new(1, -(BOUNTY_WIDTH + STRIP_GAP), 1, 0),
											BackgroundColor3 = Theme.Colors.Black,
											BackgroundTransparency = LIST_TRANSPARENCY,
											BorderSizePixel = 0,
											[Fusion.Children] = UI.Label(scope, {
												Name = "PlayerHeading",
												Text = "Player",
												Variant = "BodyBold",
												TextSize = LIST_TEXT_SIZE,
												Color = Theme.Colors.White,
												Font = Numerals.Plain,
												AnchorPoint = Vector2.new(0.5, 0.5),
												Position = UDim2.fromScale(0.5, 0.5),
											}),
										}),
										scope:New("Frame")({
											Name = "BountyHeader",
											AnchorPoint = Vector2.new(1, 0),
											Position = UDim2.fromScale(1, 0),
											Size = UDim2.new(0, BOUNTY_WIDTH, 1, 0),
											BackgroundColor3 = Theme.Colors.Black,
											BackgroundTransparency = LIST_TRANSPARENCY,
											BorderSizePixel = 0,
											[Fusion.Children] = UI.Label(scope, {
												Name = "BountyHeading",
												Text = "Bounty",
												Variant = "BodyBold",
												TextSize = LIST_TEXT_SIZE,
												Color = Theme.Colors.White,
												Font = Numerals.Plain,
												AnchorPoint = Vector2.new(0.5, 0.5),
												Position = UDim2.fromScale(0.5, 0.5),
											}),
										}),
										-- Outside the header, against its left edge: it folds and unfolds the rows.
										scope:New("ImageButton")({
											Name = "HideButton",
											AnchorPoint = Vector2.new(1, 0),
											Position = UDim2.fromOffset(-STRIP_GAP, 0),
											Size = UDim2.fromOffset(HIDE_SIZE, HIDE_SIZE),
											BackgroundTransparency = 1,
											Image = HIDE_ICON,
											ImageColor3 = Theme.Colors.Black,
											ImageTransparency = LIST_TRANSPARENCY,
											ScaleType = Enum.ScaleType.Fit,
											[Fusion.OnEvent("Activated")] = function()
												collapsed:set(not Fusion.peek(collapsed))
											end,
										}),
									},
								}),
								noBar(UI.Scroll(scope, {
									Name = "Rows",
									Size = listHeight,
									Background = false,
									Padding = 0,
									Gap = ROW_GAP,
									LayoutOrder = 2,
									Visible = scope:Computed(function(use): boolean
										return not use(collapsed)
									end),
									Children = scope:ForValues(listed, function(_use, rowScope: any, player: Player)
										return buildRow(rowScope, player)
									end),
								})),
							},
						}),
					},
				}),
			},
		})
	end,
}
