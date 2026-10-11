--!strict
--[[
	Developer commands on what a player owns: the Fruits and Items tabs of the menu.

	Devil fruits are set, eaten, repainted and handed out through FruitService (and
	FruitSlotService / FruitSpawnService for swaps and drops); weapons through
	WeaponUnlockService and WeaponService; boxes, compasses, drinks, caches and emotes
	through the service that owns each of them. A name is only accepted when its config
	knows it. Handlers trust their caller (see DevKit).

	Editing an eaten fruit (affinities, aura, ability reset) re-applies it with
	FruitService:SetFruit, which is also what makes AbilityService drop the ability
	objects built for it and start its passives again.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CompassConfig = require(ReplicatedStorage.Shared.Configs.CompassConfig)
local EmoteConfig = require(ReplicatedStorage.Shared.Configs.EmoteConfig)
local FishingConfig = require(ReplicatedStorage.Shared.Configs.FishingConfig)
local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local ConsumableConfig = require(ServerStorage.Server.Configs.ConsumableConfig)
local FruitBoxConfig = require(ServerStorage.Server.Configs.FruitBoxConfig)
local DevKit = require(ServerStorage.Server.Modules.DevKit)
local ToolTemplates = require(ServerStorage.Server.Modules.ToolTemplates)

local NO_COLOR = "None"
local ITEM_FOLDER = "Items"
local EMOTE_PREFIX = "CB_Mark"
local MAX_SCORE = 10
local MAX_GIVE = 10
-- How far in front of the developer a fruit is dropped.
local DROP_DISTANCE = 6
-- Affinity multiplier a fruit set from the menu starts with (1 = neutral).
local NEUTRAL_AFFINITY = { Melee = 1, Defense = 1, Sniper = 1, Sword = 1 }

local handlers: { [string]: DevKit.Handler } = {}

local function uniformScores(score: number): { Defense: number, Melee: number, Sniper: number, Sword: number }
	return { Defense = score, Melee = score, Sniper = score, Sword = score }
end

-- The saved fruit of a slot and its affinities (multipliers).
local function getSlot(data: any, slot: number): (any, any)
	local fruits, affinities = data.Data.DevilFruits, data.Data.Affinities
	if slot == 1 then
		return fruits.Slot1, affinities.DF1
	end
	return fruits.Slot2, affinities.DF2
end

-- One affinity multiplier, 1.0 to 2.0 in tenths: what an eaten fruit can hold.
local function readAffinity(value: unknown): number?
	local multiplier = DevKit.Number(value, 1, 2)
	return if multiplier then math.floor(multiplier * 10 + 0.5) / 10 else nil
end

local function giveMany(count: number, give: () -> boolean): number
	local given = 0
	for _ = 1, count do
		if give() then
			given += 1
		end
	end
	return given
end

function handlers.SetFruit(_developer, target, slotArg, fruitArg)
	local slot = DevKit.Integer(slotArg, 1, 2)
	local fruitName = DevKit.Name(fruitArg)
	if not slot or not fruitName or not DevKit.Data(target) then
		return false, "invalid slot, fruit or target"
	end

	local FruitService = Knit.GetService("FruitService")
	if fruitName == FruitConfig.EmptyName then
		FruitService:RemoveFruit(target, slot)
		return true, `slot {slot} emptied`
	end
	if not FruitConfig.Fruits[fruitName] then
		return false, "unknown fruit"
	end
	FruitService:SetFruit(target, slot, fruitName, table.clone(NEUTRAL_AFFINITY), NO_COLOR)
	return true, `slot {slot} = {fruitName}`
end

-- Eating as the game resolves it: first free slot, the second only in Legendary Mode,
-- and a character with no room for the fruit dies of it.
function handlers.EatFruit(_developer, target, fruitArg, scoreArg, auraArg)
	local fruitName = DevKit.Key(fruitArg, FruitConfig.Fruits)
	local score = DevKit.Integer(scoreArg, 0, MAX_SCORE)
	if not fruitName or not score then
		return false, "unknown fruit or invalid affinity score"
	end

	local result = Knit.GetService("FruitService"):EatFruit(target, fruitName, uniformScores(score), auraArg == true)
	if result == "Slot1" or result == "Slot2" then
		return true, `ate {fruitName} into {result}, affinities x{FruitConfig.ScoreToMultiplier(score)}`
	elseif result == "Rejected" then
		return false, "rejected as in play: no free slot (the second needs Legendary Mode), the character was killed"
	end
	return false, "target data is not loaded"
end

function handlers.SwapFruits(_developer, target)
	local swapped = Knit.GetService("FruitSlotService"):Swap(target)
	return swapped, if swapped then "fruit slots swapped" else "needs a living character and a fruit in slot 2"
end

function handlers.SetAffinities(_developer, target, slotArg, meleeArg, defenseArg, sniperArg, swordArg)
	local slot = DevKit.Integer(slotArg, 1, 2)
	local data = DevKit.Data(target)
	local melee, defense = readAffinity(meleeArg), readAffinity(defenseArg)
	local sniper, sword = readAffinity(sniperArg), readAffinity(swordArg)
	if not slot or not data or not melee or not defense or not sniper or not sword then
		return false, "invalid slot, affinity or target"
	end

	local fruit = getSlot(data, slot)
	if not FruitConfig.Fruits[fruit.Name] then
		return false, `slot {slot} is empty`
	end
	local affinities = { Melee = melee, Defense = defense, Sniper = sniper, Sword = sword }
	Knit.GetService("FruitService"):SetFruit(target, slot, fruit.Name, affinities, fruit.Color)
	return true, `{fruit.Name} affinities: melee {melee}, defense {defense}, sniper {sniper}, sword {sword}`
end

-- "None" removes the aura, "Default" gives the fruit's own pair, "Custom" the two colours sent.
function handlers.SetAura(_developer, target, slotArg, modeArg, primaryArg, secondaryArg)
	local slot = DevKit.Integer(slotArg, 1, 2)
	local data = DevKit.Data(target)
	if not slot or not data then
		return false, "invalid slot or target"
	end
	local fruit, affinities = getSlot(data, slot)
	if not FruitConfig.Fruits[fruit.Name] then
		return false, `slot {slot} is empty`
	end

	local color: string
	if modeArg == "None" then
		color = NO_COLOR
	elseif modeArg == "Default" then
		color = FruitColor.GetDefault(fruit.Name) or NO_COLOR
	elseif modeArg == "Custom" then
		local primary, secondary = DevKit.Color(primaryArg), DevKit.Color(secondaryArg)
		if not primary or not secondary then
			return false, "invalid colours"
		end
		color = FruitColor.Serialize(primary, secondary)
	else
		return false, "unknown aura mode"
	end

	Knit.GetService("FruitService"):SetFruit(target, slot, fruit.Name, table.clone(affinities), color)
	return true, `{fruit.Name} aura = {color}`
end

--[[
	The nearest thing to "clear cooldowns" the services offer: an ability keeps its
	cooldown on its own object, and AbilityService drops every ability object of a
	character whose fruits are written. The HUD timers are not told and run out by
	themselves; dash, shave and weapon specials keep their cooldowns (no reset exists).
]]
function handlers.ResetAbilities(_developer, target)
	local data = DevKit.Data(target)
	if not data then
		return false, "target data is not loaded"
	end

	for slot = 1, 2 do
		local fruit, affinities = getSlot(data, slot)
		if FruitConfig.Fruits[fruit.Name] then
			-- One write is enough: the drop covers both slots.
			Knit.GetService("FruitService"):SetFruit(target, slot, fruit.Name, table.clone(affinities), fruit.Color)
			return true, "ability objects rebuilt: their cooldowns are gone (HUD timers still run out)"
		end
	end
	return false, "target has no fruit"
end

-- A fruit Tool in the backpack. Without a score its affinities are rolled, as for a spawn.
function handlers.GiveFruitItem(developer, target, fruitArg, auraArg, scoreArg)
	local fruitName = DevKit.Key(fruitArg, FruitConfig.Fruits)
	if not fruitName then
		return false, "unknown fruit"
	end

	local score = DevKit.Integer(scoreArg, 0, MAX_SCORE)
	local backpack = target:FindFirstChildOfClass("Backpack")
	local tool = backpack
		and Knit.GetService("FruitService"):CreateItem(fruitName, if score then uniformScores(score) else nil, auraArg == true)
	if not tool then
		return false, "no item template for that fruit (or the target has no backpack)"
	end
	Knit.GetService("FruitLogService"):Register(tool, developer)
	tool.Parent = backpack
	return true, `gave {fruitName} fruit{if auraArg == true then " with aura" else ""}`
end

-- A fruit on the ground in front of the developer, as a world spawn (no announcement).
function handlers.DropFruit(developer, _target, fruitArg)
	local fruitName = DevKit.Key(fruitArg, FruitConfig.Fruits)
	local own = DevKit.Living(developer)
	if not fruitName or not own then
		return false, "unknown fruit, or you have no living character"
	end
	local tool = Knit.GetService("FruitSpawnService"):SpawnFruit(fruitName, own.Root.CFrame * CFrame.new(0, 0, -DROP_DISTANCE))
	return tool ~= nil, if tool then `dropped {fruitName} fruit` else "no item template for that fruit"
end

function handlers.UnlockWeapon(_developer, target, weaponArg)
	local weaponName = DevKit.Key(weaponArg, WeaponConfig.Weapons)
	if not weaponName then
		return false, "unknown weapon"
	end
	local unlocked = Knit.GetService("WeaponUnlockService"):Unlock(target, weaponName)
	return true, if unlocked then `unlocked {weaponName}` else `{weaponName} was already owned`
end

function handlers.UnlockAllWeapons(_developer, target)
	if not DevKit.Data(target) then
		return false, "target data is not loaded"
	end
	local WeaponUnlockService = Knit.GetService("WeaponUnlockService")
	local unlocked = 0
	for weaponName in WeaponConfig.Weapons do
		if WeaponUnlockService:Unlock(target, weaponName, true) then
			unlocked += 1
		end
	end
	return true, `unlocked {unlocked} weapons (the rest were owned)`
end

--[[
	Unlocks a weapon when it is one that is owned, then equips it with the player's own
	request: WeaponService still checks the level of a level-gated weapon and that there
	is a spawned character to hold it.
]]
function handlers.EquipWeapon(_developer, target, weaponArg)
	local weaponName = DevKit.Key(weaponArg, WeaponConfig.Weapons)
	if not weaponName then
		return false, "unknown weapon"
	end

	local definition = WeaponConfig.Weapons[weaponName]
	if not definition.LevelRequirement then
		Knit.GetService("WeaponUnlockService"):Unlock(target, weaponName, true)
	end
	if Knit.GetService("WeaponService").Client:Equip(target, weaponName) then
		return true, `equipped {weaponName} ({definition.Slot})`
	end
	local requirement = if definition.LevelRequirement
		then ` and {definition.Slot} level {definition.LevelRequirement}`
		else ""
	return false, `{weaponName} not equipped: it needs a spawned character{requirement}`
end

function handlers.ResetLoadout(_developer, target)
	if not DevKit.Data(target) then
		return false, "target data is not loaded"
	end
	Knit.GetService("WeaponService"):ResetLoadout(target)
	return true, "loadout back to bare fists"
end

-- A box given this way has no finder: its fruit belongs to whoever opens it.
function handlers.GiveBox(_developer, target, boxArg, countArg)
	local boxName = DevKit.Key(boxArg, FruitBoxConfig.Boxes)
	local count = DevKit.Integer(countArg, 1, MAX_GIVE) or 1
	if not boxName then
		return false, "unknown box"
	end
	local FruitBoxService = Knit.GetService("FruitBoxService")
	local given = giveMany(count, function(): boolean
		return FruitBoxService:Give(target, boxName) ~= nil
	end)
	return given > 0, if given > 0 then `gave {given} x {boxName}` else "the target has no backpack"
end

function handlers.GiveCompass(_developer, target, compassArg, countArg)
	local compassName = DevKit.Name(compassArg)
	local count = DevKit.Integer(countArg, 1, MAX_GIVE) or 1
	if compassName == CompassConfig.ToolName then
		-- One at a time: only CompassService knows where it leads.
		local given = Knit.GetService("CompassService"):Give(target)
		return given, if given then `gave {compassName}` else "not given: no backpack, or the target already carries one"
	end
	if not compassName or not FruitBoxConfig.Compasses[compassName] then
		return false, "unknown compass"
	end

	-- TreasureService buries a compass's treasure the moment it lands in the backpack.
	local given = giveMany(count, function(): boolean
		return ToolTemplates.Give(target, compassName, ITEM_FOLDER) ~= nil
	end)
	return given > 0, if given > 0 then `gave {given} x {compassName}` else "the target has no backpack"
end

function handlers.GiveConsumable(_developer, target, consumableArg, countArg)
	local name = DevKit.Key(consumableArg, ConsumableConfig.Consumables)
	local count = DevKit.Integer(countArg, 1, MAX_GIVE) or 1
	if not name then
		return false, "unknown drink"
	end
	local ConsumableService = Knit.GetService("ConsumableService")
	local given = giveMany(count, function(): boolean
		return ConsumableService:Give(target, name)
	end)
	return given > 0, if given > 0 then `gave {given} x {name}` else "no tool template for it, or the target has no backpack"
end

function handlers.GiveCache(_developer, target, cacheArg)
	local cacheName = DevKit.Key(cacheArg, FishingConfig.Caches)
	if not cacheName then
		return false, "unknown cache"
	end
	local tool = Knit.GetService("CacheService"):Give(target, cacheName)
	return tool ~= nil, if tool then `gave {cacheName}` else "the target has no backpack"
end

-- One unlockable emote by its number, or every one of them with 0.
function handlers.GrantEmote(_developer, target, indexArg)
	local index = DevKit.Integer(indexArg, 0, #EmoteConfig.Marks)
	if not index or not DevKit.Data(target) then
		return false, "invalid emote number or target"
	end

	local EmoteService = Knit.GetService("EmoteService")
	local first = if index == 0 then 1 else index
	local last = if index == 0 then #EmoteConfig.Marks else index
	local granted = 0
	for mark = first, last do
		if EmoteService:Grant(target, EMOTE_PREFIX .. mark) then
			granted += 1
		end
	end
	return true, `granted {granted} emote(s) (the rest were owned)`
end

local function getCatalog(): { [string]: any }
	local weaponSlots = {}
	for weaponName, definition in WeaponConfig.Weapons do
		weaponSlots[weaponName] = definition.Slot
	end

	local compasses = DevKit.SortedKeys(FruitBoxConfig.Compasses)
	table.insert(compasses, CompassConfig.ToolName)

	return {
		Fruits = DevKit.SortedKeys(FruitConfig.Fruits),
		NoFruit = FruitConfig.EmptyName,
		Weapons = DevKit.SortedKeys(WeaponConfig.Weapons),
		WeaponSlots = weaponSlots,
		Boxes = DevKit.SortedKeys(FruitBoxConfig.Boxes),
		Compasses = compasses,
		Consumables = DevKit.SortedKeys(ConsumableConfig.Consumables),
		Caches = DevKit.SortedKeys(FishingConfig.Caches),
		EmoteCount = #EmoteConfig.Marks,
		MaxGive = MAX_GIVE,
	}
end

local function getState(target: Player): { [string]: any }
	local data = DevKit.Data(target)
	if not data then
		return {}
	end

	local fruits = {}
	for slot = 1, 2 do
		local fruit, affinities = getSlot(data, slot)
		fruits[slot] = { Name = fruit.Name, Color = fruit.Color, Affinities = table.clone(affinities) }
	end

	local owned = 0
	for _, isOwned in data.Data.Items do
		if isOwned == true then
			owned += 1
		end
	end

	return {
		Fruits = fruits,
		Loadout = table.clone(data.Data.Weapons),
		OwnedItems = owned,
	}
end

return {
	Handlers = handlers,
	Costs = {
		UnlockAllWeapons = 5,
		GiveBox = 2,
		GiveCompass = 2,
		GiveConsumable = 2,
		GrantEmote = 2,
	},
	GetCatalog = getCatalog,
	GetState = getState,
} :: DevKit.CommandModule
