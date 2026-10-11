--!strict
--[[
	The side menu: a compact column of buttons at the bottom-left of the screen.

		Customize   Shop   Stats   Talents   Settings        windows of this screen
		Emotes      Storage   Trade   Challenges   Crews     separate screens

	The shell only owns tab selection. One tab is open at a time: an inner tab is a
	UI.Window built in the dock beside the column when it is selected (and destroyed when
	it is left), by a child module of this one:

		return function(scope, context, menu): Instance end

	`scope` lives exactly as long as the tab stays open. menu.Selected is a Fusion value
	with the key of the open tab (or nil), menu.Select(key) toggles a tab, menu.Close()
	closes whatever is open. An external tab opens / closes its screen and lets go of its
	selected state when that screen is closed from its own close button.

	The menu belongs to a spawned player: with no character (spawn screen, dead) it is
	hidden and the open tab is closed.

	Alerts. A tab with something waiting (reward boxes, challenge rewards) carries a round
	red counter on the top-right corner of its button, partly outside it.

	Handle. On a phone or tablet (ScreenScale.Touch, the test InputController uses) a small
	button rides the right edge of the column, at mid-height: it puts the column away,
	closing the open tab, and then waits alone at the left edge of the screen to bring it
	back. Selecting a tab by any other way brings the column back too. Nothing is saved.
	With a mouse or a gamepad it is not built.

	Room. The dock is not left to the screen scaler: it is laid out here from the space
	really left beside the column. A window that does not fit in that space is shrunk
	until it does, so it never lies over the buttons, whatever the size or the ratio of
	the screen. A separate screen is centred and cannot be moved from here: when the
	screen is too narrow for it to clear the column, the column steps aside while that
	screen is open. The handle, where there is one, counts as part of the column for all of
	this; a window is only ever open with the column shown, so the dock never has to move.

	Neighbours. Two things outside this screen share its space, and neither can be laid
	out from here:
	- the HUD on the left edge (the mission tracker), which the column lies over on a touch
	  screen, where it sits at mid-height. The menu publishes its footprint in
	  UI.Util.MenuSpace (Edge, Busy) and the tracker places itself from it;
	- the engine's tool bar, drawn above every screen of the game. On a phone or tablet a
	  tab window takes the whole height and a separate screen the middle of the screen, so
	  the tool slots would lie over them: the tool bar is held hidden (UI.Util.Hotbar)
	  while a tab window or one of the menu's separate screens is open, whoever opened that
	  screen and however it closes. Not with a keyboard or a gamepad: hiding it takes the
	  tool keys away with it.

	Kit (also a child) is not a tab: helpers shared by the tabs.
]]
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local ChallengeConfig = require(ReplicatedStorage.Shared.Configs.ChallengeConfig)
local Hotbar = require(ReplicatedStorage.Client.UI.Util.Hotbar)
local Interface = require(ReplicatedStorage.Client.UI.Util.Interface)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local MenuSpace = require(ReplicatedStorage.Client.UI.Util.MenuSpace)
local PlaceManifest = require(ReplicatedStorage.Shared.Configs.PlaceManifest)
local Numerals = require(ReplicatedStorage.Client.UI.Util.Numerals)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI =require(ReplicatedStorage.Client.UI.Components)
local ScreenScale = require(ReplicatedStorage.Client.UI.Util.ScreenScale)

local Kit = require(script.Kit)

type Scope = Theme.Scope

export type Menu = {
	Selected: Fusion.Value<string?>,
	Select: (tab: string?) -> (),
	Close: () -> (),
}

type Tab = {
	Key: string,
	Text: string,
	-- Child module that builds the window of an inner tab.
	Part: string?,
	-- Screen an external tab opens.
	Screen: string?,
	-- An external screen that stays open when the character goes away.
	OutlivesCharacter: boolean?,
}

local ALL_TABS: { Tab } = {
	{ Key = "Customize", Text = "Customize", Part = "Customize" },
	{ Key = "Shop", Text = "Shop", Part = "Shop" },
	{ Key = "Stats", Text = "Stats", Part = "Stats" },
	{ Key = "Talents", Text = "Talents", Part = "Inventory" },
	{ Key = "Settings", Text = "Settings", Part = "Settings" },
	{ Key = "Emotes", Text = "Emotes", Screen = "Emotes" },
	{ Key = "Storage", Text = "Storage", Screen = "Storage" },
	-- A trade goes on after a death (TradeService), and closing its screen cancels it.
	{ Key = "Trade", Text = "Trade", Screen = "Trade", OutlivesCharacter = true },
	{ Key = "Challenges", Text = "Challenges", Screen = "Challenges" },
	{ Key = "Crew", Text = "Crews", Screen = "CrewGui" },
}

-- The tabs this place offers (PlaceManifest.MenuTabs): the others are not built at all.
local TABS: { Tab } = {}
do
	local keys: { string } = {}
	for _, tab in ALL_TABS do
		table.insert(keys, tab.Key)
		if PlaceManifest.Has("MenuTabs", tab.Key) then
			table.insert(TABS, tab)
		end
	end
	PlaceManifest.Verify("MenuTabs", keys)
end

local MARGIN = 16
local BUTTON_WIDTH = 168
local BUTTON_HEIGHT = 36
local BUTTON_GAP = Theme.Space.XS
local COLUMN_PADDING = 6
-- Size assumed for a tab window whose own cannot be read.
local DOCK_SIZE = Vector2.new(900, 700)
-- A window is never shrunk below this: past it the text is unreadable anyway.
local MIN_DOCK_SCALE = 0.45
-- Width (design pixels) of the widest separate screen: what has to clear the column.
local WIDEST_SCREEN = 1280
local MAX_SHOWN = 99
-- The counter of a tab: a circle this tall, wider only when its number needs it.
local ALERT_HEIGHT = 22
local ALERT_PADDING = 5
-- How far it sticks out of its button's corner: the column's padding, so it stops at the
-- edge of the column.
local ALERT_OVERHANG = COLUMN_PADDING
-- The handle that hides the column on touch devices, and its gap to the column.
local HANDLE_SIZE = Vector2.new(44, 80)
local HANDLE_GAP = Theme.Space.XS
local HANDLE_HIDE_TEXT = "<"
local HANDLE_SHOW_TEXT = ">"

local function countText(count: number): string
	return if count > MAX_SHOWN then `{MAX_SHOWN}+` else tostring(count)
end

-- A part is loaded on first use: one that fails to load only costs its own tab.
local function loadPart(name: string): ((scope: Scope, context: any, menu: Menu) -> Instance)?
	local module = script:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		warn(`[UI] menu part "{name}" is missing`)
		return nil
	end
	local ok, part = pcall(require, module)
	if not ok or type(part) ~= "function" then
		warn(`[UI] menu part "{name}" failed to load: {part}`)
		return nil
	end
	return part :: any
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, context: any)
		local UIController = Knit.GetController("UIController")

		local selected: Fusion.Value<string?> = scope:Value(nil :: string?)
		local tabsByKey: { [string]: Tab } = {}
		for _, tab in TABS do
			tabsByKey[tab.Key] = tab
		end

		local function externalOf(key: string?): string?
			local tab = if key then tabsByKey[key] else nil
			return if tab then tab.Screen else nil
		end

		-- Touch devices only: the column put away with its handle.
		local hidden = scope:Value(false)

		local function select(key: string?)
			local previous = Fusion.peek(selected)
			local nextKey = if key == previous then nil else key
			-- A tab never opens beside a column that is not there.
			if nextKey then
				hidden:set(false)
			end

			local closing = externalOf(previous)
			if closing then
				context.Close(closing)
			end
			selected:set(nextKey)
			local opening = externalOf(nextKey)
			if opening then
				context.Open(opening)
			end
		end

		local menu: Menu = {
			Selected = selected,
			Select = select,
			Close = function()
				if Fusion.peek(selected) then
					select(nil)
				end
			end,
		}

		-- The menu's separate screens that are open, whoever opened them (a trade starts
		-- from an invite, and goes on after a death with its tab released).
		local openExternal: { [string]: boolean } = {}
		local externalCount = scope:Value(0)
		local function trackExternal(name: string, isOpen: boolean)
			if (openExternal[name] == true) == isOpen then
				return
			end
			openExternal[name] = if isOpen then true else nil
			externalCount:set(Fusion.peek(externalCount) + (if isOpen then 1 else -1))
		end
		local externalScreens: { [string]: boolean } = {}
		for _, tab in TABS do
			if tab.Screen then
				externalScreens[tab.Screen] = true
				trackExternal(tab.Screen, context.IsOpen(tab.Screen))
			end
		end

		-- A screen closed from its own close button must release its tab.
		local screenConnection = UIController.ScreenChanged:Connect(function(name: string, isOpen: boolean)
			if externalScreens[name] then
				trackExternal(name, isOpen)
			end
			if not isOpen and externalOf(Fusion.peek(selected)) == name then
				selected:set(nil)
			end
		end)
		table.insert(scope, function()
			screenConnection:Disconnect()
		end)

		-- The menu is for a spawned player: on the spawn screen (no character yet, or dead
		-- and removed) it is hidden and whatever tab was open is closed.
		local hasCharacter = scope:Value(LocalCharacter.Exists())
		table.insert(scope, LocalCharacter.Observe(function(character: Model?)
			hasCharacter:set(character ~= nil)
			if not character then
				local open = tabsByKey[Fusion.peek(selected) or ""]
				if open and open.OutlivesCharacter then
					-- Its screen stays up: only the tab lets go of it.
					selected:set(nil)
				else
					menu.Close()
				end
			end
		end))

		---------------------------------------------------------------------------------
		-- Badges: reward boxes waiting (shop) and challenge rewards to claim. They count
		-- while their window is closed, so they live here.

		local daily = Bind.data(scope, "Rewards.Daily.N", 0)
		local hourly = Bind.data(scope, "Rewards.Hourly.N", 0)
		local challenges = Bind.data(scope, "Challenges", {})
		local melee = Bind.data(scope, "Skills.Melee.Level", 0)
		local defense = Bind.data(scope, "Skills.Defense.Level", 0)

		local badges: { [string]: Fusion.StateObject<number> } = {
			Shop = scope:Computed(function(use): number
				return (tonumber(use(daily)) or 0) + (tonumber(use(hourly)) or 0)
			end),
			Challenges = scope:Computed(function(use): number
				local ok, count = pcall(ChallengeConfig.CountClaimable, use(challenges), use(melee), use(defense))
				return if ok and type(count) == "number" then count else 0
			end),
		}

		---------------------------------------------------------------------------------
		-- Column

		local buttons: { Instance } = {}
		for index, tab in TABS do
			local count = badges[tab.Key]
			table.insert(
				buttons,
				UI.Button(scope, {
					Name = tab.Key,
					Text = tab.Text,
					Variant = "Secondary",
					TextSize = Theme.TextSize.Small,
					Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT),
					LayoutOrder = index,
					Selected = scope:Computed(function(use): boolean
						return use(selected) == tab.Key
					end),
					OnClick = function()
						select(tab.Key)
					end,
					-- Not a UI.Badge: the theme's pills are square, and this one is a round dot
					-- hung on the corner of its button. Nothing above it clips.
					Children = if count
						then scope:New("TextLabel")({
							Name = "Alert",
							-- Centred on the button's height, hung over its right edge.
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, ALERT_OVERHANG, 0.5, 0),
							Size = UDim2.fromOffset(ALERT_HEIGHT, ALERT_HEIGHT),
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundColor3 = Theme.Colors.HealthLost,
							BorderSizePixel = 0,
							FontFace = Theme.Fonts.Heading,
							RichText = true,
							TextColor3 = Theme.Colors.White,
							TextSize = Theme.TextSize.Tiny,
							ZIndex = 3,
							Visible = scope:Computed(function(use): boolean
								return use(count) > 0
							end),
							Text = scope:Computed(function(use): string
								return Numerals.rich(countText(use(count)), false)
							end),
							[Fusion.Children] = {
								scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
								scope:New("UIPadding")({
									PaddingLeft = UDim.new(0, ALERT_PADDING),
									PaddingRight = UDim.new(0, ALERT_PADDING),
								}),
							},
						})
						else nil,
				})
			)
		end

		local columnWidth = BUTTON_WIDTH + COLUMN_PADDING * 2
		local columnHeight = #TABS * BUTTON_HEIGHT + (#TABS - 1) * BUTTON_GAP + COLUMN_PADDING * 2
		-- On a touch screen the bottom-left corner belongs to the thumbstick: the column
		-- sits at mid-height instead.
		local touch = MenuSpace.MidLeft
		-- Room the handle takes right of the column.
		local handleRoom = if ScreenScale.Touch then HANDLE_GAP + HANDLE_SIZE.X else 0

		---------------------------------------------------------------------------------
		-- Dock: the window of the selected inner tab, rebuilt on every selection.

		local parts: { [string]: any } = {}
		local window = scope:Computed(function(use, tabScope: Scope): Instance?
			local key = use(selected)
			local tab = if key then tabsByKey[key] else nil
			local partName = if tab then tab.Part else nil
			if not partName then
				return nil
			end

			if parts[partName] == nil then
				parts[partName] = loadPart(partName) or false
			end
			local part = parts[partName]
			local ok, result = pcall(function(): Instance
				if not part then
					error("not loaded")
				end
				return part(tabScope, context, menu)
			end)
			if ok and typeof(result) == "Instance" then
				return result
			end

			warn(`[UI] menu tab "{partName}" failed: {result}`)
			return UI.Window(tabScope, {
				Name = partName,
				Title = (tab :: Tab).Text,
				Size = UDim2.fromOffset(420, 200),
				AnchorPoint = Kit.WindowAnchor,
				Position = Kit.WindowPosition,
				OnClose = menu.Close,
				Children = UI.Label(tabScope, {
					Text = "This tab could not be opened.",
					Variant = "Muted",
					Size = UDim2.fromScale(1, 1),
				}),
			})
		end)

		-- The screen in design pixels: what is left of it once the scaler has had its way.
		local area = scope:Computed(function(use): Vector2
			local factor = math.max(use(ScreenScale.Factor), 0.01)
			local screen = use(ScreenScale.Viewport)
			return Vector2.new(screen.X, screen.Y - GuiService:GetGuiInset().Y) / factor
		end)
		-- Left edge of the dock: beside the column, however large the boost has made it.
		local dockLeft = scope:Computed(function(use): number
			return MARGIN + columnWidth * use(ScreenScale.Boost) + handleRoom + Theme.Space.M
		end)
		local dockScale = scope:Computed(function(use): number
			local current = use(window)
			local size = DOCK_SIZE
			if current and current:IsA("GuiObject") and current.Size.X.Offset > 0 and current.Size.Y.Offset > 0 then
				size = Vector2.new(current.Size.X.Offset, current.Size.Y.Offset)
			end
			local space = use(area)
			local roomX = space.X - use(dockLeft) - MARGIN
			local roomY = space.Y - MARGIN * 2
			-- The floor is a size on the screen: the player's own UI Scale must not raise it,
			-- or a window that fits at 100% is pushed off the screen at 150%.
			local floor = MIN_DOCK_SCALE / math.max(use(Interface.UserScale), 1)
			return math.clamp(math.min(roomX / size.X, roomY / size.Y), floor, 1)
		end)

		-- A centred screen as wide as the widest one would lie over the column.
		local columnFits = scope:Computed(function(use): boolean
			if not use(hasCharacter) then
				return false
			end
			if externalOf(use(selected)) == nil then
				return true
			end
			return (use(area).X - WIDEST_SCREEN) / 2 >= use(dockLeft)
		end)
		local columnShown = scope:Computed(function(use): boolean
			return use(columnFits) and not use(hidden)
		end)

		---------------------------------------------------------------------------------
		-- Neighbours: what the HUD beside the column and the engine's tool bar are told.

		-- Where the free space starts, right of whatever stands at the left edge: the
		-- column (and its handle), the handle alone, or nothing.
		local edge = scope:Computed(function(use): number
			if use(columnShown) then
				return use(dockLeft)
			elseif ScreenScale.Touch and use(columnFits) then
				return MARGIN + HANDLE_SIZE.X + Theme.Space.M
			end
			return 0
		end)
		-- The tab's window as built (not the selected key: a separate screen that failed to
		-- open leaves its tab selected with nothing on the screen).
		local busy = scope:Computed(function(use): boolean
			return use(window) ~= nil or use(externalCount) > 0
		end)

		-- Phones and tablets only: with a keyboard or a gamepad the tool bar carries the
		-- keys that equip the tools, and is left alone.
		local releaseHotbar: (() -> ())? = nil
		local function publish()
			MenuSpace.Edge:set(Fusion.peek(edge))
			local isBusy = Fusion.peek(busy)
			MenuSpace.Busy:set(isBusy)
			if not ScreenScale.Touch then
				return
			end
			if isBusy and not releaseHotbar then
				releaseHotbar = Hotbar.hide()
			elseif not isBusy and releaseHotbar then
				releaseHotbar()
				releaseHotbar = nil
			end
		end
		scope:Observer(edge):onChange(publish)
		scope:Observer(busy):onChange(publish)
		publish()
		table.insert(scope, function()
			MenuSpace.Edge:set(0)
			MenuSpace.Busy:set(false)
			if releaseHotbar then
				releaseHotbar()
				releaseHotbar = nil
			end
		end)

		-- Against the column while it shows, at the edge of the screen in its place once it
		-- is put away. Steps aside with the column.
		local handle: Instance? = nil
		if ScreenScale.Touch then
			local button = UI.Button(scope, {
				Name = "Handle",
				Text = scope:Computed(function(use): string
					return if use(hidden) then HANDLE_SHOW_TEXT else HANDLE_HIDE_TEXT
				end),
				Variant = "Secondary",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = scope:Computed(function(use): UDim2
					local left = if use(hidden) then MARGIN else MARGIN + columnWidth + HANDLE_GAP
					return UDim2.new(0, left, 0.5, 0)
				end),
				Size = UDim2.fromOffset(HANDLE_SIZE.X, HANDLE_SIZE.Y),
				Visible = columnFits,
				OnClick = function()
					if Fusion.peek(hidden) then
						hidden:set(false)
					else
						menu.Close()
						hidden:set(true)
					end
				end,
			})
			-- Placed from the column's own numbers, like the dock.
			button:SetAttribute("ScreenScale", false)
			handle = button
		end

		local dock = scope:New("Frame")({
			Name = "Dock",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			-- A point, not a box: the window grows up and to the right from it.
			Position = scope:Computed(function(use): UDim2
				return UDim2.new(0, use(dockLeft), 1, -MARGIN)
			end),
			Size = UDim2.fromOffset(0, 0),
			Visible = hasCharacter,
			[Fusion.Children] = {
				scope:New("UIScale")({ Name = "DockFit", Scale = dockScale }),
				window,
			} :: { any },
		})
		-- Laid out above: the scaler must not pin it to a share of the screen.
		dock:SetAttribute("ScreenScale", false)

		return UI.Screen(scope, {
			Name = "MenuNew",
			DisplayOrder = 5,
			Children = {
				UI.Panel(scope, {
					Name = "Column",
					AnchorPoint = if touch then Vector2.new(0, 0.5) else Vector2.new(0, 1),
					Position = if touch then UDim2.new(0, MARGIN, 0.5, 0) else UDim2.new(0, MARGIN, 1, -MARGIN),
					Size = UDim2.fromOffset(columnWidth, columnHeight),
					Transparency = Theme.Transparency.Hud,
					Padding = COLUMN_PADDING,
					Visible = columnShown,
					Children = {
						-- Enlarged on small screens, around the bottom-left corner it is anchored to.
						ScreenScale.boost(scope),
						UI.Stack(scope, {
							Name = "Buttons",
							Gap = BUTTON_GAP,
							Children = buttons,
						}),
					},
				}),
				dock,
				handle,
			} :: { any },
		})
	end,
}
