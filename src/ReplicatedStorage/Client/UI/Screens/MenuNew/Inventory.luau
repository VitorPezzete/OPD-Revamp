--!strict
--[[
	Menu tab "Talents" (inventory). A row of sub-tabs, one open at a time:

		Utility   Melee   Sniper   Swords      equip lists
		Devil Fruit                            abilities of both fruits and the slot swap
		Special                                static help with the current keys
		Expertise                              built by the Expertise part

	Equip lists: the weapons of each list are named here and described by WeaponConfig
	(a name the config does not know is skipped). Owned weapons show "Equip", the others
	"Locked"; apart from the shop basics a weapon only appears once owned. Level-gated
	melee styles show the level they need. Clicking sends the weapon name and nothing else.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.Configs.InventoryConfig)
local PlaceManifest = require(ReplicatedStorage.Shared.Configs.PlaceManifest)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)

local Expertise = require(script.Parent.Expertise)
local Kit = require(script.Parent.Kit)

type Scope = Theme.Scope

local peek = Fusion.peek

-- Workspace attribute that is true while the Halloween event runs (SeasonService).
local EVENT_ATTRIBUTE = "Season_Halloween"
local SWAP_ICON = "rbxassetid://1995032784"

local WINDOW_SIZE = Vector2.new(860, 700)
local TABS_HEIGHT = 38

type WeaponList = {
	-- Weapons in display order.
	Weapons: { string },
	-- Listed from the start (shop basics); the rest appear once owned.
	Basics: { string },
	Empty: string,
}

local LISTS: { [string]: WeaponList } = {
	Utility = {
		Weapons = { "Wood Rod", "Sturdy Rod", "Super Rod", "Tea Cup", "Santa Bag", "Zombie Head" },
		Basics = {},
		Empty = "Utility items you own are listed here.",
	},
	Melee = {
		Weapons = { "Melee", "Table Kick", "Black Leg", "Seastone Cestus", "Candy Shield" },
		Basics = {},
		Empty = "",
	},
	Sniper = {
		Weapons = { "Slingshot", "Stars", "Crossbow", "Flintlock", "Cannon Ball", "Magma Gun" },
		Basics = { "Slingshot", "Stars", "Crossbow", "Flintlock" },
		Empty = "",
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
		Empty = "",
	},
}

local SUB_TABS = {
	{ Key = "Utility", Text = "Utility" },
	{ Key = "Melee", Text = "Melee" },
	{ Key = "Sniper", Text = "Sniper" },
	{ Key = "Swords", Text = "Swords" },
	{ Key = "DevilFruit", Text = "Devil Fruit" },
	{ Key = "Special", Text = "Special" },
	{ Key = "Expertise", Text = "Expertise" },
}
-- The Expertise page (last) spends points through ExpertiseService: no page in a place
-- that does not load it.
if not PlaceManifest.Has("Services", "ExpertiseService") then
	table.remove(SUB_TABS)
end

-- Ability rows of a fruit: hotkey letter and the key it has by default, per fruit slot.
local ABILITY_LETTERS = { "A", "B", "C", "D", "E", "F" }
local ABILITY_KEYS = {
	{ "Z", "X", "C", "V", "B", "N" },
	{ "F", "G", "H", "J", "K", "L" },
}

-- Help of the "Special" sub-tab; the key shown is the one currently bound to the action.
local SPECIALS = {
	{ Action = "Dash", Key = "E", Name = "Dash", Unlock = "Level 50 Melee" },
	{ Action = "Shave", Key = "LeftControl", Name = "Shave", Unlock = "Level 200 Melee" },
	{ Action = "Observation", Key = "R", Name = "Kenbunshoku", Unlock = "Requires Haki" },
	{ Action = "Haki", Key = "Q", Name = "Busoshoku", Unlock = "Level 200 Haki" },
	{ Action = "Conq", Key = "T", Name = "Conqueror's Haki", Unlock = "Level 500 Haki, awakened" },
}
-- An action whose system is switched off (InputConfig.IsEnabled) has no row.
for index = #SPECIALS, 1, -1 do
	if not InputConfig.IsEnabled(SPECIALS[index].Action) then
		table.remove(SPECIALS, index)
	end
end

local function keyText(scope: Scope, action: string, default: string): Fusion.StateObject<string>
	local key = Kit.key(scope, action, default)
	return scope:Computed(function(use): string
		local current = use(key)
		return if type(current) == "string" and current ~= "" then current else default
	end)
end

---------------------------------------------------------------------------------
-- Equip lists

local function equipRow(scope: Scope, weaponName: string, order: number, basic: boolean, items: Fusion.Value<any>): Instance?
	local definition = WeaponConfig.Weapons[weaponName]
	if not definition then
		-- Weapons that never shipped.
		return nil
	end
	local WeaponService = Knit.GetService("WeaponService")

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

	return Kit.Row(scope, {
		Label = weaponName,
		Hint = if requirement and requirement > 0 then `Level {requirement} {definition.Slot}` else nil,
		LayoutOrder = order,
		Visible = visible,
		Selected = isEquipped,
		Children = UI.Button(scope, {
			Name = "Equip",
			TextSize = Theme.TextSize.Small,
			Size = UDim2.fromOffset(170, 32),
			Variant = scope:Computed(function(use): any
				if not use(usable) then
					return "Danger"
				end
				return if use(isEquipped) then "Secondary" else "Success"
			end),
			Text = scope:Computed(function(use): string
				if use(usable) then
					return if use(isEquipped) then "Equipped" else "Equip"
				end
				return if requirement then `Require Level {requirement}` else "Locked"
			end),
			Disabled = scope:Computed(function(use): boolean
				return use(busy) or not use(usable)
			end),
			OnClick = function()
				if not peek(usable) then
					return
				end
				busy:set(true)
				WeaponService:Equip(weaponName):catch(warn):finally(function()
					if alive then
						busy:set(false)
					end
				end)
			end,
		}),
	})
end

-- Progress towards the event weapon, shown in the utility list while the event runs.
local function eventCounter(scope: Scope, items: Fusion.Value<any>): Instance
	local counter = InventoryConfig.EventCounter
	local eventActive = Bind.attribute(scope, Workspace, EVENT_ATTRIBUTE, false)
	local progress = Bind.data(scope, counter.Path, 0)

	return UI.ProgressBar(scope, {
		Name = "CounterBar",
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 30),
		Color = Theme.Colors.Warning,
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

local function equipList(scope: Scope, key: string): Instance
	local list = LISTS[key]
	local items = Bind.data(scope, "Items", {})

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
	if list.Empty ~= "" then
		table.insert(
			rows,
			UI.Label(scope, {
				Text = list.Empty,
				Variant = "Small",
				LayoutOrder = 1000,
				Size = UDim2.new(1, 0, 0, 28),
			})
		)
	end

	return UI.Scroll(scope, { Name = key, Children = rows })
end

---------------------------------------------------------------------------------
-- Devil fruits

-- The swap button of the second fruit. The server reports the cooldown left; the client
-- only counts it down.
local function swapButton(scope: Scope): Instance
	local FruitSlotService = Knit.GetService("FruitSlotService")

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

	return UI.Button(scope, {
		Name = "Swap",
		Icon = SWAP_ICON,
		Variant = "Secondary",
		TextSize = Theme.TextSize.Small,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 38),
		Text = scope:Computed(function(use): string
			local seconds = use(remaining)
			return if seconds > 0 then `Swap fruit slots ({seconds}s)` else "Swap fruit slots"
		end),
		OnClick = function()
			local current = run
			FruitSlotService:Swap()
				:andThen(function(seconds: any)
					if current == run and type(seconds) == "number" and seconds > 0 then
						countDown(math.ceil(seconds))
					end
				end)
				:catch(warn)
		end,
	})
end

-- Ability names, keys and unlock levels of the fruit in one slot.
local function fruitPanel(scope: Scope, slot: number): Instance
	local fruit = Bind.data(scope, `DevilFruits.Slot{slot}`, { Name = FruitConfig.EmptyName })
	local fruitName = scope:Computed(function(use): string
		local current = use(fruit)
		return if type(current) == "table" and type(current.Name) == "string" then current.Name else FruitConfig.EmptyName
	end)

	local rows: { Instance } = {}
	for index, letter in ABILITY_LETTERS do
		local ability = scope:Computed(function(use): FruitConfig.AbilityDefinition?
			-- A switched-off ability keeps its line, marked as such: an empty one would
			-- read as a fruit that lost a power.
			return FruitConfig.GetAbility(use(fruitName), index, true)
		end)
		table.insert(
			rows,
			Kit.Row(scope, {
				LayoutOrder = index,
				Height = 40,
				Leading = Kit.KeyCap(scope, keyText(scope, `DF{slot}{letter}`, ABILITY_KEYS[slot][index]), 1),
				Label = scope:Computed(function(use): string
					local definition = use(ability)
					return if definition then definition.Name else "None"
				end),
				Children = UI.Label(scope, {
					Name = "Unlock",
					Variant = "Small",
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
				}),
			})
		)
	end

	local gap = Theme.Space.M
	return Kit.Section(scope, {
		Name = if slot == 1 then "DevilFruit" else "DevilFruit2",
		Position = UDim2.new((slot - 1) * 0.5, if slot == 1 then 0 else gap / 2, 0, 0),
		Size = UDim2.new(0.5, -gap / 2, 1, 0),
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
		Children = {
			UI.Stack(scope, {
				Name = "Abilities",
				Gap = 6,
				Size = UDim2.fromScale(1, 1),
				Children = rows,
			}),
			if slot == 2 then swapButton(scope) else nil,
		} :: { any },
	})
end

local function fruitPage(scope: Scope): Instance
	return scope:New("Frame")({
		Name = "DevilFruits",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		[Fusion.Children] = { fruitPanel(scope, 1), fruitPanel(scope, 2) },
	})
end

---------------------------------------------------------------------------------
-- Special abilities (help)

local function specialPage(scope: Scope): Instance
	local rows: { Instance } = {}
	for order, special in SPECIALS do
		table.insert(
			rows,
			Kit.Row(scope, {
				LayoutOrder = order,
				Leading = Kit.KeyCap(scope, keyText(scope, special.Action, special.Key), 1),
				Label = special.Name,
				Children = UI.Label(scope, { Name = "Unlock", Text = special.Unlock, Variant = "Small" }),
			})
		)
	end
	return UI.Scroll(scope, { Name = "Special", Children = rows })
end

---------------------------------------------------------------------------------

return function(scope: Scope, _context: any, menu: any): Instance
	local subTab = scope:Value("Melee")

	local content = scope:Computed(function(use, pageScope: Scope): Instance
		local key = use(subTab)
		if LISTS[key] then
			return equipList(pageScope, key)
		elseif key == "DevilFruit" then
			return fruitPage(pageScope)
		elseif key == "Special" then
			return specialPage(pageScope)
		end
		return Expertise(pageScope)
	end)

	return UI.Window(scope, {
		Name = "Talents",
		Title = "Talents",
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		AnchorPoint = Kit.WindowAnchor,
		Position = Kit.WindowPosition,
		OnClose = menu.Close,
		Children = {
			UI.Tabs(scope, {
				Tabs = SUB_TABS,
				Selected = subTab,
				TabSize = UDim2.fromOffset(111, TABS_HEIGHT),
			}),
			scope:New("Frame")({
				Name = "Page",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, TABS_HEIGHT + Theme.Space.M),
				Size = UDim2.new(1, 0, 1, -(TABS_HEIGHT + Theme.Space.M)),
				[Fusion.Children] = content,
			}),
		},
	})
end
