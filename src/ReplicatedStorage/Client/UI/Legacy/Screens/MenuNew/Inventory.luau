--!strict
--[[
	Menu tab "Talents" (inventory): a parchment column of plank buttons, the sub-tabs, and
	the page of the open one on the second parchment to its right, tinted in its colour.

		Expertise     the perk honeycomb (built by MenuNew/Expertise; only where the place
		              loads ExpertiseService)
		Utility   Melee   Sniper   Swords      equip lists
		Devil Fruit   abilities of both fruits with their keys, and the slot swap
		Special       help, with the keys currently bound

		Inventory(scope, context, menu): GuiObject     -- the panel, for the shell to dock

	One sub-tab is open at a time; pressing the open one closes it.

	Equip lists: the weapons of each list are named here and described by WeaponConfig
	(a name the config does not know is skipped). Owned weapons show "Equip" (the one in
	hand "Equipped"), the others "Locked"; apart from the shop basics a weapon only
	appears once owned. Level-gated melee styles show the level they need. Clicking sends
	the weapon name and nothing else.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)
local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.Configs.InventoryConfig)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local PlaceManifest = require(ReplicatedStorage.Shared.Configs.PlaceManifest)
local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)

local Expertise = require(script.Parent.Expertise)

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

local peek = Fusion.peek

-- Workspace attribute that is true while the Halloween event runs (SeasonService).
local EVENT_ATTRIBUTE = "Season_Halloween"
-- The Expertise page spends points through ExpertiseService: no page without it.
local EXPERTISE = "Expertise"
-- Key of this tab (PlaceManifest.MenuTabs), which is what menu.Selected holds.
local TAB_KEY = "Talents"
local EXPERTISE_SERVICE = "ExpertiseService"
local SWAP_ICON = "rbxassetid://1995032784"

type WeaponList = {
	-- Weapons in display order.
	Weapons: { string },
	-- Listed from the start (shop basics); the rest appear once owned.
	Basics: { string },
}

local LISTS: { [string]: WeaponList } = {
	Utility = {
		Weapons = { "Wood Rod", "Sturdy Rod", "Super Rod", "Tea Cup", "Santa Bag", "Zombie Head" },
		Basics = {},
	},
	Melee = {
		Weapons = { "Melee", "Table Kick", "Black Leg", "Seastone Cestus", "Candy Shield" },
		Basics = {},
	},
	Sniper = {
		Weapons = { "Slingshot", "Stars", "Crossbow", "Flintlock", "Cannon Ball", "Magma Gun" },
		Basics = { "Slingshot", "Stars", "Crossbow", "Flintlock" },
	},
	Swords = {
		Weapons = {
			"Dagger",
			"Tachi",
			"Wakizashi",
			"Katana",
			"Flail",
			"Krizma",
			"Candy Cane Yoru",
			"Aqua Staff",
			"Ultra Great Sword",
			"Kogatana",
			"Yoru",
			"Masamune",
			"Lightning Sword",
			"Kanshou and Bakuya",
			"Meteorite Sword",
			"Scissors Blade",
			"Divine Axe",
			"Divine Kogatana",
			"Divine Yoru",
			"Candy Cane Kogatana",
			"Golden Fish",
			"Roger",
			"Ice Dagger",
			"Ice Spear",
			"Shirayuki",
			"Yamato",
			"Bisento",
			"Lollipop",
		},
		Basics = { "Dagger", "Tachi", "Wakizashi", "Katana" },
	},
}

type SubTab = { Key: string, Text: string, Title: string?, Tint: Color3 }

-- Top to bottom, as the old column had them, each with the tint of its page.
local SUB_TABS: { SubTab } = {
	{ Key = EXPERTISE, Text = "Expertise", Tint = Color3.fromRGB(255, 255, 255) },
	{ Key = "Utility", Text = "Utility", Title = "Utilities", Tint = Color3.fromRGB(0, 255, 255) },
	{ Key = "Melee", Text = "Melee", Title = "Melee Abilities", Tint = Color3.fromRGB(255, 127, 0) },
	{ Key = "Sniper", Text = "Sniper", Title = "Sniper Weapons", Tint = Color3.fromRGB(255, 255, 0) },
	{ Key = "Swords", Text = "Swords", Title = "Swords", Tint = Color3.fromRGB(0, 127, 255) },
	{ Key = "DevilFruit", Text = "Devil Fruit", Tint = Color3.fromRGB(150, 80, 180) },
	{ Key = "Special", Text = "Special", Title = "Special", Tint = Color3.fromRGB(255, 255, 255) },
}

-- Ability rows of a fruit: hotkey letter and the key it has by default, per fruit slot
-- (Hotkeys.DF<slot><letter>.KB).
local ABILITY_LETTERS = { "A", "B", "C", "D", "E", "F" }
local ABILITY_KEYS = {
	{ "Z", "X", "C", "V", "B", "N" },
	{ "F", "G", "H", "J", "K", "L" },
}

local HAKI_TINT = Color3.fromRGB(127, 0, 255)
-- Rows of the "Special" sub-tab: the action whose key is shown (with its default) and
-- what unlocks it today.
local SPECIALS: { { Action: string, Key: string, Name: string, Unlock: string, Tint: Color3? } } = {
	{ Action = "Dash", Key = "E", Name = "Dash", Unlock = "Level 50 Melee" },
	{ Action = "Shave", Key = "LeftControl", Name = "Shave", Unlock = "Level 200 Melee" },
	{ Action = "Observation", Key = "R", Name = "Kenbunshoku", Unlock = "Requires Haki", Tint = HAKI_TINT },
	{ Action = "Haki", Key = "Q", Name = "Busoshoku", Unlock = "Level 200 Haki", Tint = HAKI_TINT },
	{ Action = "Conq", Key = "T", Name = "Conqueror's Haki", Unlock = "Level 500 Haki, awakened", Tint = HAKI_TINT },
}
-- An action whose system is switched off (InputConfig.IsEnabled) has no row.
for index = #SPECIALS, 1, -1 do
	if not InputConfig.IsEnabled(SPECIALS[index].Action) then
		table.remove(SPECIALS, index)
	end
end

local NAME_TINT = Color3.fromRGB(180, 180, 180)
local COUNTER_COLOR = Color3.fromRGB(155, 255, 125)
local COOLDOWN_COLOR = Color3.fromRGB(255, 80, 80)

-- The column of sub-tabs.
-- The proportions of the menu column it stands beside.
local TABS_WIDTH = 192
local TABS_PADDING = 8
local TAB_GAP = 6
local TAB_BUTTON = Vector2.new(TABS_WIDTH - 2 * TABS_PADDING, 36)
local PAGE_GAP = Kit.Space.M
local PAGE_LEFT = TABS_WIDTH + PAGE_GAP

-- The pages.
local PAGE_PADDING = Kit.Space.L
local TITLE_HEIGHT = 56
local TITLE_COLOR = Color3.fromRGB(232, 232, 232)
local ROW_HEIGHT = 48
local TABLE_ROW_HEIGHT = 52
local LIST_SIZE = Vector2.new(620, 620)
local SPECIAL_SIZE = Vector2.new(740, 500)
local FRUIT_SIZE = Vector2.new(550, 560)
local SWAP_SIZE = 64
local EXPERTISE_SIZE = Vector2.new(940, 720)
-- Room a scrolling list keeps for its bar.
local SCROLL_BAR = 8
-- Share of an equip row its button takes.
local EQUIP_SHARE = 0.33

local PANEL_SIZE = Vector2.new(
	-- The Expertise page is not in the panel: it stands in the middle of the screen.
	PAGE_LEFT + math.max(LIST_SIZE.X, SPECIAL_SIZE.X, 2 * (FRUIT_SIZE.X + PAGE_GAP) + SWAP_SIZE),
	math.max(LIST_SIZE.Y, SPECIAL_SIZE.Y, FRUIT_SIZE.Y)
)

-- The keyboard key bound to an action, kept current; the default while none is saved.
local function keyText(scope: Scope, action: string, default: string): Fusion.StateObject<string>
	local key = Bind.data(scope, `Hotkeys.{action}.KB`, default)
	return scope:Computed(function(use): string
		local current = use(key)
		return if type(current) == "string" and current ~= "" then current else default
	end)
end

type SheetProps = Kit.Layout & {
	Title: UsedAs<string>,
	Tint: Color3,
	Children: Fusion.Child?,
}

-- A page: the second parchment under its tint, a title box and the body below it.
local function sheet(scope: Scope, props: SheetProps): Instance
	return Kit.Panel(scope, {
		Name = props.Name,
		Image = Kit.Images.ParchmentAlt,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		Children = {
			Kit.Well(scope, {
				Name = "Tint",
				Color = props.Tint,
				Transparency = 0.7,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}),
			Kit.Stack(scope, {
				Size = UDim2.fromScale(1, 1),
				Padding = PAGE_PADDING,
				Gap = Kit.Space.M,
				ZIndex = 2,
				Children = {
					-- The plank of the buttons: on the page's own parchment under the same tint the
					-- title box could only be told from the page by its grain.
					Kit.Panel(scope, {
						Name = "Title",
						Image = Kit.Images.Plank,
						ImageColor = TITLE_COLOR,
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
						Children = {
							Kit.Label(scope, {
								Text = props.Title,
								TextSize = Kit.TextSize.Heading,
								Fit = true,
								Size = UDim2.fromScale(1, 1),
								ZIndex = 2,
							}),
						},
					}),
					scope:New("Frame")({
						Name = "Body",
						BackgroundTransparency = 1,
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 1, -(TITLE_HEIGHT + Kit.Space.M)),
						[Fusion.Children] = props.Children,
					}),
				},
			}),
		},
	})
end

-- A row of a table: its cells side by side, each a share of the row.
local function tableRow(scope: Scope, order: number, cells: { { Text: UsedAs<string>, Share: number } }, tint: Color3?): Instance
	local labels: { Instance } = {}
	local left = 0
	for _, cell in cells do
		table.insert(
			labels,
			Kit.Label(scope, {
				Text = cell.Text,
				Fit = true,
				Position = UDim2.new(left, Kit.Space.XS, 0, 0),
				Size = UDim2.new(cell.Share, -2 * Kit.Space.XS, 1, 0),
			})
		)
		left += cell.Share
	end
	return Kit.Well(scope, {
		Name = "Row",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, TABLE_ROW_HEIGHT),
		Color = tint,
		Transparency = 0.7,
		Children = labels,
	})
end

---------------------------------------------------------------------------------
-- Equip lists

local function equipRow(scope: Scope, weaponName: string, order: number, basic: boolean, items: Fusion.Value<any>): Instance?
	local definition = WeaponConfig.Weapons[weaponName]
	if not definition then
		-- Weapons that never shipped are not offered.
		return nil
	end

	local alive = true
	table.insert(scope, function()
		alive = false
	end)

	local requirement = definition.LevelRequirement
	local equipped = Bind.data(scope, `Weapons.{definition.Slot}`, WeaponConfig.EmptyName)
	local busy = scope:Value(false)

	local usable: Fusion.StateObject<boolean>
	local visible: Fusion.StateObject<boolean>? = nil
	if requirement then
		local level = Bind.data(scope, `Skills.{definition.Slot}.Level`, 0)
		usable = scope:Computed(function(use): boolean
			return (tonumber(use(level)) or 0) >= requirement
		end)
	else
		usable = scope:Computed(function(use): boolean
			local owned = use(items)
			return type(owned) == "table" and owned[weaponName] == true
		end)
		if not basic then
			visible = usable
		end
	end
	local isEquipped = scope:Computed(function(use): boolean
		return use(equipped) == weaponName
	end)

	return scope:New("Frame")({
		Name = weaponName,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.new(1, -SCROLL_BAR, 0, ROW_HEIGHT),
		Visible = visible,
		[Fusion.Children] = {
			Kit.Well(scope, {
				Name = "Ability",
				Size = UDim2.new(1 - EQUIP_SHARE, -Kit.Space.XS, 1, 0),
				Color = NAME_TINT,
				Transparency = 0.7,
				Children = Kit.Label(scope, {
					Text = weaponName,
					Fit = true,
					Size = UDim2.new(1, -2 * Kit.Space.S, 1, 0),
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
				}),
			}),
			Kit.Button(scope, {
				Name = "Equip",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromScale(EQUIP_SHARE, 1),
				TextSize = Kit.TextSize.Body,
				Variant = scope:Computed(function(use): Kit.Variant
					if not use(usable) then
						return "Red"
					end
					return if use(isEquipped) then "Grey" else "Green"
				end),
				Text = scope:Computed(function(use): string
					if use(usable) then
						return if use(isEquipped) then "Equipped" else "Equip"
					end
					return if requirement then `Require Level {requirement}` else "Locked"
				end),
				OnClick = function()
					-- One request at a time per row; the server decides whether the weapon is equipped.
					if not peek(usable) or peek(busy) then
						return
					end
					busy:set(true)
					local WeaponService = Knit.GetService("WeaponService")
					WeaponService:Equip(weaponName):catch(warn):finally(function()
						if alive then
							busy:set(false)
						end
					end)
				end,
			}),
		},
	})
end

-- Progress towards the event weapon, shown in the utility list while the event runs.
local function eventCounter(scope: Scope, items: Fusion.Value<any>): Instance
	local counter = InventoryConfig.EventCounter
	-- Published by SeasonService (the old Workspace.WorldEvent.Halloween value is gone).
	local eventActive = Bind.attribute(scope, Workspace, EVENT_ATTRIBUTE, false)
	local progress = Bind.data(scope, counter.Path, 0)

	return Kit.Bar(scope, {
		Name = "CounterBar",
		LayoutOrder = 0,
		Size = UDim2.new(1, -SCROLL_BAR, 0, ROW_HEIGHT - Kit.Space.M),
		Color = COUNTER_COLOR,
		Visible = scope:Computed(function(use): boolean
			local owned = use(items)
			return use(eventActive) == true and not (type(owned) == "table" and owned[counter.Weapon] == true)
		end),
		Value = scope:Computed(function(use): number
			return (tonumber(use(progress)) or 0) / counter.Goal
		end),
		Text = scope:Computed(function(use): string
			return `{counter.Label}: {use(progress)}/{counter.Goal}`
		end),
	})
end

local function equipList(scope: Scope, key: string, items: Fusion.Value<any>): Instance
	local list = LISTS[key]
	local rows: { any } = {}
	if key == "Utility" then
		table.insert(rows, eventCounter(scope, items))
	end
	for order, weaponName in list.Weapons do
		local row = equipRow(scope, weaponName, order, table.find(list.Basics, weaponName) ~= nil, items)
		if row then
			table.insert(rows, row)
		end
	end
	return Kit.Scroll(scope, {
		Name = "Equipables",
		Background = false,
		Gap = 6,
		Padding = 0,
		Children = rows,
	})
end

---------------------------------------------------------------------------------
-- Devil fruits

-- The name of the fruit in one slot.
local function fruitNameOf(scope: Scope, slot: number): Fusion.StateObject<string>
	local fruit = Bind.data(scope, `DevilFruits.Slot{slot}`, { Name = FruitConfig.EmptyName })
	return scope:Computed(function(use): string
		local current = use(fruit)
		return if type(current) == "table" and type(current.Name) == "string" then current.Name else FruitConfig.EmptyName
	end)
end

-- Ability names, unlock levels and keys of the fruit in one slot.
local function fruitSheet(scope: Scope, slot: number, fruitName: Fusion.StateObject<string>, tint: Color3, order: number): Instance
	local rows: { Instance } = {}
	for index, letter in ABILITY_LETTERS do
		local ability = scope:Computed(function(use): FruitConfig.AbilityDefinition?
			-- A switched-off ability keeps its line, marked as such: an empty one would
			-- read as a fruit that lost a power.
			return FruitConfig.GetAbility(use(fruitName), index, true)
		end)
		table.insert(
			rows,
			tableRow(scope, index, {
				{
					Share = 0.5,
					Text = scope:Computed(function(use): string
						local definition = use(ability)
						return if definition then definition.Name else "None"
					end),
				},
				{
					Share = 0.3,
					Text = scope:Computed(function(use): string
						local definition = use(ability)
						if definition and definition.Disabled then
							return "Disabled"
						end
						if definition and definition.Requirement > 0 then
							return `Level {definition.Requirement} {definition.Skill}`
						end
						return "-"
					end),
				},
				-- The key the ability is on today.
				{ Share = 0.2, Text = keyText(scope, `DF{slot}{letter}`, ABILITY_KEYS[slot][index]) },
			})
		)
	end

	return sheet(scope, {
		Name = if slot == 1 then "DevilFruit" else "DevilFruit2",
		LayoutOrder = order,
		Size = UDim2.fromOffset(FRUIT_SIZE.X, FRUIT_SIZE.Y),
		Tint = tint,
		-- The second slot only exists once it holds a fruit.
		Visible = if slot == 1
			then nil
			else scope:Computed(function(use): boolean
				return use(fruitName) ~= FruitConfig.EmptyName
			end),
		Title = scope:Computed(function(use): string
			local name = use(fruitName)
			return if name == FruitConfig.EmptyName then "No Devil Fruit" else `{name} Fruit`
		end),
		Children = Kit.Stack(scope, {
			Size = UDim2.fromScale(1, 1),
			Gap = Kit.Space.S,
			Children = rows,
		}),
	})
end

-- The button between the two fruits that swaps their slots. The server reports the
-- cooldown left; the client only counts it down.
local function swapButton(scope: Scope, tint: Color3, visible: Fusion.StateObject<boolean>, order: number): Instance
	local remaining = scope:Value(0)
	local run = 0
	local function countDown(seconds: number)
		run += 1
		local current = run
		remaining:set(seconds)
		task.spawn(function()
			while current == run and peek(remaining) > 0 do
				task.wait(1)
				if current == run then
					remaining:set(math.max(0, peek(remaining) - 1))
				end
			end
		end)
	end
	table.insert(scope, function()
		run += 1
	end)

	return Kit.Well(scope, {
		Name = "Swap",
		LayoutOrder = order,
		Size = UDim2.fromOffset(SWAP_SIZE, SWAP_SIZE),
		Color = tint,
		Transparency = 0.3,
		Visible = visible,
		Children = {
			Kit.Image(scope, {
				Image = SWAP_ICON,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}),
			Kit.Button(scope, {
				Name = "Button",
				Variant = "Ghost",
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
				TextColor = COOLDOWN_COLOR,
				Text = scope:Computed(function(use): string
					local seconds = use(remaining)
					return if seconds > 0 then tostring(seconds) else ""
				end),
				OnClick = function()
					local current = run
					Knit.GetService("FruitSlotService")
						:Swap()
						:andThen(function(seconds: any)
							-- An answer that comes after a newer count-down (or after the menu) is dropped.
							if current == run and type(seconds) == "number" and seconds > 0 then
								countDown(math.ceil(seconds))
							end
						end)
						:catch(warn)
				end,
			}),
		},
	})
end

---------------------------------------------------------------------------------
-- Special abilities (help): static, except for the keys (the ones bound now).

local function specialRows(scope: Scope): Instance
	local rows: { Instance } = {
		tableRow(scope, 0, {
			{ Share = 0.5, Text = "Ability" },
			{ Share = 0.25, Text = "Unlock" },
			{ Share = 0.25, Text = "Button" },
		}),
	}
	for order, special in SPECIALS do
		table.insert(
			rows,
			tableRow(scope, order, {
				{ Share = 0.5, Text = special.Name },
				{ Share = 0.25, Text = special.Unlock },
				{ Share = 0.25, Text = keyText(scope, special.Action, special.Key) },
			}, special.Tint)
		)
	end
	return Kit.Stack(scope, {
		Size = UDim2.fromScale(1, 1),
		Gap = Kit.Space.S,
		Children = rows,
	})
end

---------------------------------------------------------------------------------

return function(scope: Scope, _context: any, menu: any): GuiObject?
	local subTabs: { SubTab } = {}
	for _, subTab in SUB_TABS do
		if subTab.Key ~= EXPERTISE or PlaceManifest.Has("Services", EXPERTISE_SERVICE) then
			table.insert(subTabs, subTab)
		end
	end

	local selected: Fusion.Value<string?> = scope:Value(nil :: string?)
	local function shown(key: string): Fusion.StateObject<boolean>
		return scope:Computed(function(use): boolean
			return use(selected) == key
		end)
	end

	local items = Bind.data(scope, "Items", {})
	local pagePosition = UDim2.new(0, PAGE_LEFT, 1, 0)
	local pageAnchor = Vector2.new(0, 1)

	local buttons: { Instance } = {}
	local pages: { Instance } = {}
	for order, subTab in subTabs do
		local key = subTab.Key
		local isShown = shown(key)
		table.insert(
			buttons,
			Kit.Button(scope, {
				Name = key,
				Text = subTab.Text,
				LayoutOrder = order,
				TextSize = Kit.TextSize.Body,
				Size = UDim2.fromOffset(TAB_BUTTON.X, TAB_BUTTON.Y),
				Selected = isShown,
				OnClick = function()
					selected:set(if peek(selected) == key then nil else key)
				end,
			})
		)

		if key == EXPERTISE then
			-- In the middle of the screen, clear of the column of sub-tabs, which stays docked.
			-- It is not a child of the panel, so it also has to follow the tab itself.
			local page = Expertise(scope, {
				Name = key,
				Size = UDim2.fromOffset(EXPERTISE_SIZE.X, EXPERTISE_SIZE.Y),
				Visible = scope:Computed(function(use): boolean
					return use(isShown) and use(menu.Selected) == TAB_KEY
				end),
			}, menu) :: GuiObject
			menu.Centre(page, EXPERTISE_SIZE, PAGE_LEFT)
			page.Parent = menu.Center
		elseif key == "DevilFruit" then
			local first = fruitNameOf(scope, 1)
			local second = fruitNameOf(scope, 2)
			local hasSecond = scope:Computed(function(use): boolean
				return use(second) ~= FruitConfig.EmptyName
			end)
			table.insert(
				pages,
				Kit.Stack(scope, {
					Name = key,
					Direction = "Horizontal",
					Gap = PAGE_GAP,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					AnchorPoint = pageAnchor,
					Position = pagePosition,
					Size = UDim2.fromOffset(2 * (FRUIT_SIZE.X + PAGE_GAP) + SWAP_SIZE, FRUIT_SIZE.Y),
					Visible = isShown,
					Children = {
						fruitSheet(scope, 1, first, subTab.Tint, 1),
						swapButton(scope, subTab.Tint, hasSecond, 2),
						fruitSheet(scope, 2, second, subTab.Tint, 3),
					},
				})
			)
		else
			local size = if key == "Special" then SPECIAL_SIZE else LIST_SIZE
			table.insert(
				pages,
				sheet(scope, {
					Name = key,
					AnchorPoint = pageAnchor,
					Position = pagePosition,
					Size = UDim2.fromOffset(size.X, size.Y),
					Visible = isShown,
					Tint = subTab.Tint,
					Title = subTab.Title or subTab.Text,
					Children = if key == "Special" then specialRows(scope) else equipList(scope, key, items),
				})
			)
		end
	end

	local tabsHeight = 2 * TABS_PADDING + #subTabs * TAB_BUTTON.Y + (#subTabs - 1) * TAB_GAP
	local tabs = Kit.Panel(scope, {
		Name = "Tabs",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(TABS_WIDTH, tabsHeight),
		Children = Kit.Stack(scope, {
			Size = UDim2.fromScale(1, 1),
			Gap = TAB_GAP,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Children = buttons,
		}),
	})

	local panel = scope:New("Frame")({
		Name = "Talents",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		[Fusion.Children] = { tabs, pages },
	}) :: Frame
	-- The gamepad's B closes the tab from anywhere inside it, as it closes a window.
	Closers.register(scope, panel, menu.Close)
	return panel
end
