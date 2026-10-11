--!strict
--[[
	The side menu of the old game: a column of plank buttons on a strip of parchment in the
	bottom-left corner of the screen, the open tab's panel standing to its right.

		Crews   Challenges   Trade   Storage   Emotes            separate screens
		Customize   Shop   Stats   Talents   Settings            panels of this screen

	(top to bottom, as the old game drew them; "Trade" is new, the old game had no trading.)
	Built with the Kit. The column is shorter than the old one - ten buttons in 430 design
	pixels - so that the charge bars (ChargingMenu, at the left edge with their feet at
	half the height of the screen) stand clear above it.

	The shell only owns tab selection. One tab is open at a time. A separate-screen tab
	opens and closes its screen, and lets go of its selected state when that screen is
	closed from its own close button. A panel tab is a part, a child module of this one:

		return function(scope, context, menu): GuiObject? end

	It builds and returns its panel (pixel Size, anchored and placed by its bottom-left
	corner), which the shell parents into the frame named "Dock" while the tab is open and
	takes out again when it is left. A part is mounted once, with the menu's scope, the
	first time its tab is opened; it returns nil where the place lacks what it needs. One
	that errors is reported and replaced by a notice, the others keep working.
	menu.Selected is a Fusion value with the key of the open tab (or nil), menu.Select(key)
	toggles a tab, menu.Close() closes whatever is open.
	A part that wants its panel in the middle of the screen instead (Shop, Stats, the
	Expertise page of Talents) hands it to menu.Centre(panel, size, clear?): the shell then
	parents that panel into the full-screen frame named "Center" instead of the dock, and
	shrinks it to the room left between the column (plus `clear` design pixels a part keeps
	docked beside it) and the same distance from the right edge.
	menu.Side(panel, size) does the same against the right edge of the screen, at mid-height,
	for a panel the character must stay visible beside (Customize): it never reaches the
	middle of the screen, where the character stands.
	A part may also parent a panel of its own into menu.Center after placing it with one
	of the two (a page of a part that is not the whole tab); it then owns its visibility. Keys are those of
	PlaceManifest.MenuTabs: only the tabs of this place are built.

	The menu belongs to a spawned player: with no character (spawn screen, dead) it is
	hidden and the open tab is closed. A trade goes on after a death: its screen stays.

	Alerts. The Shop and Challenges buttons carry a round red counter over their right
	edge: reward boxes waiting, challenge rewards to claim. They count while their tab is
	closed, so they are computed here.

	Handle. On a phone or tablet (ScreenScale.Touch) a small button rides the right edge
	of the column, at mid-height: it puts the column away, closing the open tab, and then
	waits alone at the left edge of the screen to bring it back. Selecting a tab by any
	other way brings the column back too. Nothing is saved. With a mouse or a gamepad it
	is not built. The column itself stays in the corner the old game drew it in, so on a
	phone the handle is also what clears the thumbstick.

	Room. The column, the dock and the handle are not left to the screen scaler: they are
	laid out here, in design pixels, from each other. The dock is a point - the column's
	right edge plus a gap, at the column's bottom - and a panel grows up and to the right
	from it; one that does not fit in the space really left beside the column is shrunk
	until it does ("DockFit"), whatever the size or the ratio of the screen, the player's
	UI Scale or a phone's enlargement. A separate screen is centred and cannot be moved
	from here: when the screen is too narrow for it to clear the column, the column steps
	aside while that screen is open.

	Neighbours. As the rework's menu does, this one publishes its footprint in
	UI.Util.MenuSpace (Edge, Busy) for the HUD that shares the left edge, and on a phone or
	tablet holds the engine's tool bar hidden (UI.Util.Hotbar) while a panel or one of the
	menu's separate screens is open, whoever opened that screen and however it closes.

	Gamepad. NavigationController gives the selection to a panel arriving in the dock, and
	B closes the open tab from anywhere inside it (UI.Util.Closers), as it closes a window.
]]
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local ChallengeConfig = require(ReplicatedStorage.Shared.Configs.ChallengeConfig)
local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)
local Hotbar = require(ReplicatedStorage.Client.UI.Util.Hotbar)
local Interface = require(ReplicatedStorage.Client.UI.Util.Interface)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local MenuSpace = require(ReplicatedStorage.Client.UI.Util.MenuSpace)
local PlaceManifest = require(ReplicatedStorage.Shared.Configs.PlaceManifest)
local ScreenScale = require(ReplicatedStorage.Client.UI.Util.ScreenScale)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Menu = {
	Selected: Fusion.Value<string?>,
	Select: (tab: string?) -> (),
	Close: () -> (),
	Centre: (panel: GuiObject, size: Vector2, clear: number?) -> (),
	Side: (panel: GuiObject, size: Vector2) -> (),
	-- The full-screen frame centred panels live in, for a part that shows one by itself.
	Center: Frame,
}

type Tab = {
	-- PlaceManifest.MenuTabs key, and what menu.Selected holds.
	Key: string,
	Text: string,
	-- Child module that builds the panel of a tab.
	Part: string?,
	-- Screen a separate-screen tab opens.
	Screen: string?,
	-- A separate screen that stays open when the character goes away.
	OutlivesCharacter: boolean?,
}

-- Top to bottom, as the old column.
local ALL_TABS: { Tab } = {
	{ Key = "Crew", Text = "Crews", Screen = "CrewGui" },
	{ Key = "Challenges", Text = "Challenges", Screen = "Challenges" },
	-- A trade goes on after a death (TradeService), and closing its screen cancels it.
	{ Key = "Trade", Text = "Trade", Screen = "Trade", OutlivesCharacter = true },
	{ Key = "Storage", Text = "Storage", Screen = "Storage" },
	{ Key = "Emotes", Text = "Emotes", Screen = "Emotes" },
	{ Key = "Customize", Text = "Customize", Part = "Customize" },
	{ Key = "Shop", Text = "Shop", Part = "Shop" },
	{ Key = "Stats", Text = "Stats", Part = "Stats" },
	{ Key = "Talents", Text = "Talents", Part = "Inventory" },
	{ Key = "Settings", Text = "Settings", Part = "Settings" },
}

-- Design pixels. The old column was 192 wide, its buttons 46 tall and 58 apart.
local MARGIN = 8
local BUTTON_SIZE = Vector2.new(176, 36)
local BUTTON_GAP = 6
local COLUMN_PADDING = 8
-- Between the column (or its handle) and the dock.
local DOCK_GAP = 8
-- Size assumed for a panel whose own cannot be read.
local DOCK_SIZE = Vector2.new(900, 700)
-- Nothing is shrunk below this: past it the text is unreadable anyway.
local MIN_FIT = 0.45

-- That floor for the UI Scale in force. It is a size on the screen: the player's own
-- enlargement must not raise it, or a panel that fits at 100% is pushed off the screen
-- (and onto the player list) at 150%.
local function minFit(use: any): number
	return MIN_FIT / math.max(use(Interface.UserScale), 1)
end
-- Half the width kept free around the middle of the screen for the character (menu.Side).
local CHARACTER_ROOM = 140
-- Width of the widest separate screen: what has to clear the column.
local WIDEST_SCREEN = 1280
local MAX_SHOWN = 99
-- The handle that hides the column on touch devices, and its gap to the column and to the
-- edge of the screen.
local HANDLE_SIZE = Vector2.new(44, 80)
local HANDLE_GAP = 4
local HANDLE_HIDE_TEXT = "<"
local HANDLE_SHOW_TEXT = ">"
-- The notice standing in for a panel that could not be built.
local NOTICE_SIZE = Vector2.new(420, 140)
local NOTICE_FAILED = "This tab could not be opened."
local NOTICE_ABSENT = "This tab is not available here."
-- Read by UI.Util.ScreenScale: false keeps the scaler's hands off what is laid out here.
local SCALER_ATTRIBUTE = "ScreenScale"
-- Marks a panel the shell shows in the middle of the screen (menu.Centre).
local CENTRED_ATTRIBUTE = "MenuCentred"

-- PlaceManifest.Verify warns about a misspelt tab: once is enough, however often the
-- menu is mounted.
local verified = false

local function countText(count: number): string
	return if count > MAX_SHOWN then `{MAX_SHOWN}+` else tostring(count)
end

-- A part is loaded on first use: one that fails to load only costs its own tab.
local function loadPart(name: string): ((scope: Scope, context: any, menu: Menu) -> GuiObject?)?
	local module = script:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		warn(`[UI] menu part "{name}" is missing`)
		return nil
	end
	local ok, part = pcall(require :: any, module)
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

		-- The tabs this place offers (PlaceManifest.MenuTabs): the others are not built at all.
		local tabs: { Tab } = {}
		local tabsByKey: { [string]: Tab } = {}
		local keys: { string } = {}
		for _, tab in ALL_TABS do
			table.insert(keys, tab.Key)
			if PlaceManifest.Has("MenuTabs", tab.Key) then
				table.insert(tabs, tab)
				tabsByKey[tab.Key] = tab
			end
		end
		if not verified then
			verified = true
			PlaceManifest.Verify("MenuTabs", keys)
		end

		local selected: Fusion.Value<string?> = scope:Value(nil :: string?)

		local function externalOf(key: string?): string?
			local tab = if key then tabsByKey[key] else nil
			return if tab then tab.Screen else nil
		end

		-- Touch devices only: the column put away with its handle.
		local hidden = scope:Value(false)

		local function select(key: string?)
			local previous = Fusion.peek(selected)
			local nextKey = if key == previous then nil else key
			-- Not a tab of this place: it has no button, and a part must not open it either.
			if nextKey and not tabsByKey[nextKey] then
				nextKey = nil
			end
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
			-- Both set once the column has been measured, below.
			Centre = nil :: any,
			Side = nil :: any,
			Center = nil :: any,
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
		for _, tab in tabs do
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
		-- Badges: reward boxes waiting (shop) and challenge rewards to claim.

		local daily = Bind.data(scope, "Rewards.Daily.N", 0)
		local hourly = Bind.data(scope, "Rewards.Hourly.N", 0)
		local challenges = Bind.data(scope, "Challenges", {})
		local melee = Bind.data(scope, "Skills.Melee.Level", 0)
		local defense = Bind.data(scope, "Skills.Defense.Level", 0)

		local badges: { [string]: Fusion.StateObject<number> } = {
			Shop = scope:Computed(function(use): number
				return (tonumber(use(daily)) or 0) + (tonumber(use(hourly)) or 0)
			end),
			-- The saved table is read as it comes: a shape the config does not expect counts zero.
			Challenges = scope:Computed(function(use): number
				local ok, count = pcall(ChallengeConfig.CountClaimable, use(challenges), use(melee), use(defense))
				return if ok and type(count) == "number" then count else 0
			end),
		}

		---------------------------------------------------------------------------------
		-- Column

		local buttons: { Instance } = {}
		for index, tab in tabs do
			local count = badges[tab.Key]
			table.insert(
				buttons,
				Kit.Button(scope, {
					Name = tab.Key,
					Text = tab.Text,
					TextSize = Kit.TextSize.Body,
					Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y),
					LayoutOrder = index,
					Selected = scope:Computed(function(use): boolean
						return use(selected) == tab.Key
					end),
					OnClick = function()
						select(tab.Key)
					end,
					Children = if count
						then Kit.Badge(scope, {
							Name = "Alert",
							-- Centred on the button's height, hung over its right edge as far as
							-- the edge of the parchment.
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, COLUMN_PADDING, 0.5, 0),
							Visible = scope:Computed(function(use): boolean
								return use(count) > 0
							end),
							Text = scope:Computed(function(use): string
								return countText(use(count))
							end),
						})
						else nil,
				})
			)
		end

		local columnSize = Vector2.new(
			BUTTON_SIZE.X + COLUMN_PADDING * 2,
			#tabs * BUTTON_SIZE.Y + math.max(#tabs - 1, 0) * BUTTON_GAP + COLUMN_PADDING * 2
		)
		-- Room the handle takes right of the column.
		local handleRoom = if ScreenScale.Touch then HANDLE_GAP + HANDLE_SIZE.X else 0

		-- The screen in design pixels: what is left of it once the scaler has had its way.
		local area = scope:Computed(function(use): Vector2
			local factor = math.max(use(ScreenScale.Factor), 0.01)
			local screen = use(ScreenScale.Viewport)
			return Vector2.new(screen.X, screen.Y - GuiService:GetGuiInset().Y) / factor
		end)
		-- The column on a screen too short for it (a phone's enlargement, a large UI Scale).
		local columnFit = scope:Computed(function(use): number
			return math.clamp((use(area).Y - MARGIN * 2) / columnSize.Y, minFit(use), 1)
		end)
		-- Left edge of the dock: beside the column and its handle.
		local dockLeft = scope:Computed(function(use): number
			return MARGIN + columnSize.X * use(columnFit) + handleRoom + DOCK_GAP
		end)

		---------------------------------------------------------------------------------
		-- Centre: the panels shown in the middle of the screen.

		local centre = scope:New("Frame")({
			Name = "Center",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = hasCharacter,
		}) :: Frame
		centre:SetAttribute(SCALER_ATTRIBUTE, false)
		Closers.register(scope, centre, menu.Close)
		menu.Center = centre

		menu.Centre = function(panel: GuiObject, size: Vector2, clear: number?)
			panel.AnchorPoint = Vector2.new(0.5, 0.5)
			panel.Position = UDim2.fromScale(0.5, 0.5)
			panel:SetAttribute(CENTRED_ATTRIBUTE, true)
			scope:New("UIScale")({
				Name = "CentreFit",
				Parent = panel,
				-- As much is left free on the right as the column takes on the left, so the
				-- panel stays in the middle of the screen while it shrinks.
				Scale = scope:Computed(function(use): number
					local space = use(area)
					local roomX = space.X - 2 * (use(dockLeft) + (clear or 0))
					local roomY = space.Y - MARGIN * 2
					return math.clamp(math.min(roomX / size.X, roomY / size.Y), minFit(use), 1)
				end),
			})
		end

		menu.Side = function(panel: GuiObject, size: Vector2)
			panel.AnchorPoint = Vector2.new(1, 0.5)
			panel.Position = UDim2.new(1, -MARGIN, 0.5, 0)
			panel:SetAttribute(CENTRED_ATTRIBUTE, true)
			scope:New("UIScale")({
				Name = "SideFit",
				Parent = panel,
				Scale = scope:Computed(function(use): number
					local space = use(area)
					local roomX = space.X / 2 - CHARACTER_ROOM - MARGIN
					local roomY = space.Y - MARGIN * 2
					return math.clamp(math.min(roomX / size.X, roomY / size.Y), minFit(use), 1)
				end),
			})
		end

		---------------------------------------------------------------------------------
		-- Dock: the panel of the selected tab.

		local dock: Frame
		-- Tab key -> its panel, built on the first visit and kept (a part is mounted once).
		local panels: { [string]: GuiObject } = {}
		-- The panel in the dock.
		local shown: Fusion.Value<GuiObject?> = scope:Value(nil :: GuiObject?)

		local function notice(text: string): GuiObject
			return Kit.Panel(scope, {
				Name = "Notice",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromOffset(NOTICE_SIZE.X, NOTICE_SIZE.Y),
				Padding = Kit.Space.L,
				Children = Kit.Label(scope, {
					Text = text,
					Wrapped = true,
					Size = UDim2.fromScale(1, 1),
				}),
			})
		end

		local function panelOf(tab: Tab): GuiObject
			local existing = panels[tab.Key]
			if existing then
				return existing
			end
			local part = loadPart(tab.Part :: string)
			local ok, result = pcall(function(): GuiObject?
				if not part then
					error("not loaded")
				end
				return part(scope, context, menu)
			end)
			local panel: GuiObject
			if ok and typeof(result) == "Instance" and result:IsA("GuiObject") then
				panel = result
			elseif ok and result == nil then
				panel = notice(NOTICE_ABSENT)
			else
				warn(`[UI] menu tab "{tab.Part}" failed: {result}`)
				panel = notice(NOTICE_FAILED)
			end
			panels[tab.Key] = panel
			return panel
		end

		-- In the dock only while its tab is open: NavigationController watches what arrives.
		local function showPanel()
			local tab = tabsByKey[Fusion.peek(selected) or ""]
			local nextPanel = if tab and tab.Part then panelOf(tab) else nil
			local previous = Fusion.peek(shown)
			if previous == nextPanel then
				return
			end
			if previous then
				previous.Parent = nil
			end
			-- First, so that the dock is already at the panel's scale when it arrives.
			shown:set(nextPanel)
			if nextPanel then
				nextPanel.Parent = if nextPanel:GetAttribute(CENTRED_ATTRIBUTE) then centre else dock
			end
		end

		local dockScale = scope:Computed(function(use): number
			local current = use(shown)
			local size = DOCK_SIZE
			if current and current.Size.X.Offset > 0 and current.Size.Y.Offset > 0 then
				size = Vector2.new(current.Size.X.Offset, current.Size.Y.Offset)
			end
			local space = use(area)
			local roomX = space.X - use(dockLeft) - MARGIN
			local roomY = space.Y - MARGIN * 2
			return math.clamp(math.min(roomX / size.X, roomY / size.Y), minFit(use), 1)
		end)

		dock = scope:New("Frame")({
			Name = "Dock",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			-- A point, not a box: the panel grows up and to the right from it.
			Position = scope:Computed(function(use): UDim2
				return UDim2.new(0, use(dockLeft), 1, -MARGIN)
			end),
			Size = UDim2.fromOffset(0, 0),
			Visible = hasCharacter,
			[Fusion.Children] = {
				scope:New("UIScale")({ Name = "DockFit", Scale = dockScale }),
			},
		}) :: any
		dock:SetAttribute(SCALER_ATTRIBUTE, false)
		-- The gamepad's B closes the tab from anywhere inside its panel. A window a part
		-- opens inside its panel registers its own close and is the one B reaches first.
		Closers.register(scope, dock, menu.Close)

		scope:Observer(selected):onChange(showPanel)

		-- A centred screen as wide as the widest one would lie over the column.
		local columnFits = scope:Computed(function(use): boolean
			if not use(hasCharacter) or #tabs == 0 then
				return false
			end
			if externalOf(use(selected)) == nil then
				return true
			end
			return (use(area).X - WIDEST_SCREEN) / 2 >= use(dockLeft)
		end)
		-- A panel is only ever open with the column shown (no character, the handle and a
		-- separate screen all close it first), so the dock never has to move.
		local columnShown = scope:Computed(function(use): boolean
			return use(columnFits) and not use(hidden)
		end)

		local column = Kit.Panel(scope, {
			Name = "Column",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, MARGIN, 1, -MARGIN),
			Size = UDim2.fromOffset(columnSize.X, columnSize.Y),
			Padding = COLUMN_PADDING,
			Visible = columnShown,
			Children = {
				-- Around the bottom-left corner it is anchored to.
				scope:New("UIScale")({ Name = "ColumnFit", Scale = columnFit }),
				Kit.Stack(scope, {
					Name = "Buttons",
					Gap = BUTTON_GAP,
					Children = buttons,
				}),
			},
		})
		column:SetAttribute(SCALER_ATTRIBUTE, false)

		---------------------------------------------------------------------------------
		-- Neighbours: what the HUD beside the column and the engine's tool bar are told.

		-- Where the free space starts, right of whatever stands at the left edge: the
		-- column (and its handle), the handle alone, or nothing.
		local edge = scope:Computed(function(use): number
			if use(columnShown) then
				return use(dockLeft)
			elseif ScreenScale.Touch and use(columnFits) then
				return HANDLE_GAP + HANDLE_SIZE.X + DOCK_GAP
			end
			return 0
		end)
		-- The panel as docked (not the selected key: a separate screen that failed to open
		-- leaves its tab selected with nothing on the screen).
		local busy = scope:Computed(function(use): boolean
			return use(shown) ~= nil or use(externalCount) > 0
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
			local button = Kit.Button(scope, {
				Name = "Handle",
				Text = scope:Computed(function(use): string
					return if use(hidden) then HANDLE_SHOW_TEXT else HANDLE_HIDE_TEXT
				end),
				AnchorPoint = Vector2.new(0, 0.5),
				-- From the corner the column stands in, at the middle of its height.
				Position = scope:Computed(function(use): UDim2
					local fit = use(columnFit)
					local left = if use(hidden) then HANDLE_GAP else MARGIN + columnSize.X * fit + HANDLE_GAP
					return UDim2.new(0, left, 1, -(MARGIN + columnSize.Y * fit / 2))
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
			button:SetAttribute(SCALER_ATTRIBUTE, false)
			handle = button
		end

		return Kit.Screen(scope, {
			Name = "MenuNew",
			DisplayOrder = 5,
			Children = { column, centre, dock, handle } :: { any },
		})
	end,
}
