--!strict
--[[
	Turns a profile saved by the game before the rework into the rework's schema.

	Both games keep their profiles in the same ProfileStore ("OPD", key "User_<id>"), so a
	returning player's profile arrives here in the old shape: the old game saved, as it
	was, the tree of Value objects it kept under Workspace.UserData.User_<id>.Data. That
	is a flat table (MeleeLvl, Melee_Exp1, DevilFruit, Gems...) with a few folders
	(ClothingRelated, Challenges, Storages...), and nothing in it says which version it is.

		LegacyDataMigration.IsLegacy(data)   -- an old save that was not converted yet
		LegacyDataMigration.Convert(old)     -- -> the same save in the rework's shape

	Convert builds a new table and never changes the old one. Every value is checked for
	its type on the way: one that is missing or of the wrong type is left out, and
	Profile:Reconcile() then gives that field its default from DataTemplate, exactly as
	for a field added after a profile was made. DataService swaps the profile's content
	for the result and keeps the untouched old save under `_legacy`, so nothing a player
	owned is lost if a field turns out to have been read wrongly here.

	Mixed profiles. Before this module existed the rework was run on live profiles: those
	were reconciled as they were, so they hold the old save untouched with the rework's
	tables, at their defaults, laid beside it (and inside the tables both games name the
	same: Settings, Haki, Hotkeys, Storages, Challenges, Items). They are recognised by
	the old save's own fields rather than by the missing version, and converted the same
	way: the old save is what the player owns. Of what the rework wrote there, only what
	the old save cannot give is carried over: the receipts already granted, the custom
	control layout, the settings the old game did not have and items unlocked since.

	What has no place in the rework and is only kept in `_legacy`: Race, Crafting,
	Haki.HakiPoints, Haki.Quests, FunnyNumber, Settings.AuraAttackColor, the two reward
	values DailyReward / HourlyReward, and the gamepad columns of the hotkeys (the old pad
	had one layout with modes; the rework has two layouts with other actions, so the pad
	starts from the defaults and only the keyboard keys are carried over).

	Weapons the old game sold that the rework does not have yet (Items.Own_*) are carried
	over under their old names: owning one does nothing until the weapon exists.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)

local LegacyDataMigration = {}

type Table = { [string]: any }

local SKILLS = { "Melee", "Defense", "Sniper", "Sword", "Haki", "Expertise" }
local AFFINITY_SKILLS = { "Melee", "Defense", "Sniper", "Sword" }
local STORAGE_SLOTS = 12
local BOUND_SLOTS = 3
local GENERAL_CHALLENGES = 14
local EXTRA_SLOTS = { "A", "B", "C", "D", "E", "F" }
-- Prefixes of the old flags.
local OWNED_ITEM = "^Own_(.+)$"
local OWNED_ACCESSORY = "^PlayerHas_(.+)$"
local PERK_VALUE = "^Perk_(.+)$"
-- Old keyboard hotkey rows are "Basic_<Action>"; the pad's were "Basic-<Action>".
local KEYBOARD_HOTKEY = "^Basic_(.+)$"
-- Settings.FastMode was a number.
local FAST_MODES = { [0] = "Off", [1] = "On", [2] = "Extreme" }
-- Haki.ConqStage was "Locked" or the stage as text.
local MAX_CONQUEROR_STAGE = 3

-- Appearance fields that kept their name (ClothingRelated.<Name>).
local APPEARANCE_NUMBERS = {
	"SkinColor", "Hair", "Hair_Color", "Face", "Torso", "Torso_Color", "Pants", "Pants_Color",
	"Arms", "Arms_Color", "Feet", "Feet_Color", "Gloves", "Gloves_Color",
}
-- Settings only the rework has: carried over from a mixed profile.
local NEW_SETTINGS: { [string]: string } = {
	Trade_Requests = "boolean",
	Aim_Assist = "boolean",
	Root_Lock = "boolean",
	Camera_Lock = "number",
	UI_Scale = "number",
	UI_Style = "string",
	Control_Layout = "string",
}
-- Settings that kept their name and type.
local SETTINGS: { [string]: string } = {
	Auto_Menu = "boolean",
	Damage_Numbers = "boolean",
	Hide_Bounty = "boolean",
	Join_Message = "boolean",
	Player_List = "boolean",
	Music = "number",
	Sun_Mode = "boolean",
	Fog_Mode = "boolean",
	Obs_Mode = "string",
	Hitbox = "boolean",
	Hit_Counter = "boolean",
}
-- Challenges.T_* -> Challenges.Timestamps.*
local TIMESTAMPS: { [string]: string } = {
	T_DoTy = "DayOfYear",
	T_DoTm = "DayOfMonth",
	T_DoTw = "DayOfWeek",
	T_MoTy = "MonthOfYear",
	T_WoTy = "WeekOfYear",
	T_YoTc = "YearOfCycle",
}
local CHALLENGE_GROUPS: { [string]: number } = { Daily = 4, Weekly = 3, Monthly = 2 }
-- AFK_World: two names had a space.
local AFK_FIELDS: { [string]: string } = {
	Beri = "Beri",
	Gems = "Gems",
	Compass = "Compass",
	["Silver Compass"] = "SilverCompass",
	["Golden Compass"] = "GoldenCompass",
	CompassTime = "CompassTime",
}

local function number(value: any): number?
	-- NaN and infinities do not survive a save.
	return if type(value) == "number" and value == value and math.abs(value) ~= math.huge then value else nil
end

local function text(value: any): string?
	return if type(value) == "string" then value else nil
end

local function flag(value: any): boolean?
	return if type(value) == "boolean" then value else nil
end

local function folder(value: any): Table
	return if type(value) == "table" then value else {}
end

-- A table without its nil fields is still a table: Reconcile fills what is missing.
local function fruitSlot(name: any, color: any): Table
	return { Name = text(name), Color = text(color) }
end

local function conquerorStage(value: any): number?
	local stage = tonumber(value)
	if stage then
		return math.clamp(math.floor(stage), 0, MAX_CONQUEROR_STAGE)
	end
	return if value == "Locked" then 0 else nil
end

-- "r,g,b" (0-255) -> the hex the rework saves. Anything else: no colour yet.
local function conquerorColor(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local parts = string.split(value, ",")
	local red, green, blue = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
	if #parts ~= 3 or not red or not green or not blue then
		return nil
	end
	return Color3.fromRGB(math.clamp(red, 0, 255), math.clamp(green, 0, 255), math.clamp(blue, 0, 255)):ToHex()
end

-- "false,true,false,false" -> { false, true, false, false }
local function meteoriteFeats(value: any): { boolean }?
	if type(value) ~= "string" then
		return nil
	end
	local parts = string.split(value, ",")
	if #parts ~= 4 then
		return nil
	end
	local feats = {}
	for index, part in parts do
		feats[index] = part == "true"
	end
	return feats
end

--[[
	Keyboard keys only. A key the rework cannot bind, or an action it does not have, is
	skipped (the default stays). If the result would put two actions on one key - the old
	game allowed it - the whole table is dropped and the player starts from the defaults.
]]
local function hotkeys(old: Table): Table?
	local keys: { [string]: string } = {}
	for action, row in InputConfig.Defaults do
		keys[action] = row.KB
	end
	local changed = false
	for name, value in old do
		local action = string.match(name, KEYBOARD_HOTKEY)
		if action and keys[action] ~= nil and type(value) == "string" and InputConfig.Keys.KB[value] then
			if keys[action] ~= value then
				keys[action] = value
				changed = true
			end
		end
	end
	if not changed then
		return nil
	end

	local taken: { [string]: boolean } = {}
	for _, key in keys do
		if key ~= InputConfig.Unbound then
			if taken[key] then
				return nil
			end
			taken[key] = true
		end
	end

	local rows: Table = {}
	for action, row in InputConfig.Defaults do
		rows[action] = { KB = keys[action], GP = row.GP, GC = row.GC }
	end
	return rows
end

local function appearance(old: Table, usingSkinDye: any): Table
	local result: Table = {
		SkinDye = text(old.SkinDye),
		UsingSkinDye = flag(usingSkinDye),
	}
	for _, name in APPEARANCE_NUMBERS do
		result[name] = number(old[name])
	end

	local slots: Table = {}
	for _, letter in EXTRA_SLOTS do
		slots[letter] = text(old[`Extra{letter}`])
		slots[`{letter}_Color`] = number(old[`Extra{letter}_Color`])
	end
	result.ExtraSlots = slots

	local owned: Table = {}
	for name, value in old do
		local accessory = string.match(name, OWNED_ACCESSORY)
		if accessory and value == true then
			owned[accessory] = true
		end
	end
	result.OwnedAccessories = owned
	return result
end

local function expertise(old: Table): Table
	local perks: Table = {}
	local oldPerks = folder(old.Perks)
	for name, value in oldPerks do
		local perk = string.match(name, PERK_VALUE)
		if perk then
			perks[perk] = { Value = number(value), Limit = number(oldPerks[`PerkLimit_{perk}`]) }
		end
	end
	return {
		Mission = {
			Progress = number(old.MissionProgress),
			Requirement = number(old.MissionRequirement),
			Difficulty = text(old.MissionDifficulty),
			Objective = text(old.MissionObjective),
			ObjectiveTarget = text(old.MissionObjectiveTarget),
			Hour = number(old.MissionHour),
		},
		Perks = perks,
	}
end

local function challenges(old: Table): Table
	local result: Table = {
		AllCompleted = {
			Daily = flag(old.QQQ_AllDaily),
			Weekly = flag(old.QQQ_AllWeekly),
			Monthly = flag(old.QQQ_AllMonthly),
		},
		Total = number(old.QQQ_Total),
		Timestamps = {},
		General = {},
		LegendaryUnlock = {
			TotalLevel = number(old.LU_TotalLevel),
			AllDone = flag(old.LU_AllDone),
			DefenseLvl = { Goal = number(old.LU_DefenseLvl), Completed = flag(old.LUC_DefenseLvl) },
			MeleeLvl = { Goal = number(old.LU_MeleeLvl), Completed = flag(old.LUC_MeleeLvl) },
			Enemy = {
				Name = text(old.LU_Enemy),
				Progress = number(old.LUP_Enemy),
				Limit = number(old.LUL_Enemy),
				Completed = flag(old.LUC_Enemy),
			},
			Extra = {
				Name = text(old.LU_Extra),
				Progress = number(old.LUP_Extra),
				Limit = number(old.LUL_Extra),
				Completed = flag(old.LUC_Extra),
			},
		},
	}
	for group, count in CHALLENGE_GROUPS do
		local entries: Table = {}
		for index = 1, count do
			entries[tostring(index)] = {
				P = number(old[`QQ_{group}{index}`]),
				Done = flag(old[`QQQ_{group}{index}`]),
			}
		end
		result[group] = entries
	end
	for index = 1, GENERAL_CHALLENGES do
		result.General[tostring(index)] = number(old[`QQ_Challenge{index}`])
	end
	for oldName, newName in TIMESTAMPS do
		result.Timestamps[newName] = text(old[oldName])
	end
	return result
end

local function settings(old: Table, controllerType: any): Table
	local result: Table = {}
	for name, kind in SETTINGS do
		if type(old[name]) == kind then
			result[name] = old[name]
		end
	end
	for name, kind in NEW_SETTINGS do
		if type(old[name]) == kind then
			result[name] = old[name]
		end
	end
	result.Fast_Mode = FAST_MODES[old.FastMode]
	result.Charge_Toggle = flag(old.NoChargeHold)
	for _, value in InputConfig.ControllerTypes do
		if controllerType == value then
			result.ControllerType = value
		end
	end
	return result
end

-- A save of the old game that was not converted yet: one with no schema version, or a
-- mixed profile, which still carries the old save's fields (see the header).
function LegacyDataMigration.IsLegacy(data: any): boolean
	if type(data) ~= "table" or data._legacy ~= nil then
		return false
	end
	if data._version == nil then
		return next(data) ~= nil
	end
	return type(data.MeleeLvl) == "number" or type(data.ClothingRelated) == "table"
end

function LegacyDataMigration.Convert(old: Table): Table
	local new: Table = {}

	new.Economy = {
		Beri = number(old.Beri),
		Gems = number(old.Gems),
		DFCoins = number(old.DFCoins),
		Tea = number(old.Tea),
		Fish = number(old.Fish),
		GemsBought = number(old.GemsBought),
		BeriBought = number(old.BeriBought),
	}

	new.DevilFruits = {
		Slot1 = fruitSlot(old.DevilFruit, old.DevilFruit_Color),
		Slot2 = fruitSlot(old.DevilFruit2, old.DevilFruit2_Color),
	}

	-- <Skill>_Exp2 was the experience the next level needs: the rework derives it.
	new.Skills = {}
	for _, skill in SKILLS do
		new.Skills[skill] = { Level = number(old[`{skill}Lvl`]), Exp = number(old[`{skill}_Exp1`]) }
	end

	new.Combat = {
		Bounty = number(old.Bounty),
		Kills = number(old.Kills),
		ZombiesKilled = number(old.ZombiesKilled),
		LegendaryMode = flag(old.LegendaryMode),
	}
	new.CompassTokens = {
		Current = number(old.CompassTokens),
		Limit = number(old.CompassTokenLimit),
		VIPBonus = number(old.CompassTokensVIP),
		AuraBonus = number(old.CompassTokensAura),
	}
	new.ExpertiseTokens = { Current = number(old.ExpertiseTokens), Limit = number(old.ExpertiseTokenLimit) }
	new.Rewards = {
		Daily = { N = number(old.DailyRewardN), R = number(old.DailyRewardR) },
		Hourly = { N = number(old.HourlyRewardN), R = number(old.HourlyRewardR) },
	}

	new.Items = {}
	for name, value in folder(old.Items) do
		if type(name) == "string" and value == true then
			-- Without the prefix: unlocked under the rework, in a mixed profile.
			new.Items[string.match(name, OWNED_ITEM) or name] = true
		end
	end

	local weapons = folder(old.Weapons)
	new.Weapons = {
		Melee = text(weapons.MeleeUsing),
		Sniper = text(weapons.SniperUsing),
		Sword = text(weapons.SwordUsing),
		Utility = text(weapons.UtilityUsing),
	}

	local storages = folder(old.Storages)
	new.Storages = {}
	for index = 1, STORAGE_SLOTS do
		new.Storages[tostring(index)] = {
			Item = text(storages[`Storage{index}`]),
			ID = text(storages[`Storage{index}ID`]),
			Unlocked = flag(storages[`Storage{index}Unlocked`]),
		}
	end

	new.Hotkeys = hotkeys(folder(old.Hotkeys))
	new.Appearance = appearance(folder(old.ClothingRelated), old.UsingSkinDye)

	new.Emotes = {}
	for name, value in folder(old.Emotes) do
		if type(name) == "string" and value == true then
			new.Emotes[name] = true
		end
	end

	new.Expertise = expertise(folder(old.Expertise))

	local affinities = folder(old.Affinities)
	new.Affinities = { DF1 = {}, DF2 = {} }
	for slot = 1, 2 do
		for _, skill in AFFINITY_SKILLS do
			new.Affinities[`DF{slot}`][skill] = number(affinities[`DFT{slot}{skill}`])
		end
	end

	new.Challenges = challenges(folder(old.Challenges))
	new.Settings = settings(folder(old.Settings), old.ControllerType)
	new.Shop = { VIPRush = number(old.Shop_VIPRush), AuraCompass = number(old.Shop_AuraCompass) }

	local bounds = folder(old.Bounds)
	new.Bounds = {}
	for index = 1, BOUND_SLOTS do
		new.Bounds[tostring(index)] = {
			Unlocked = flag(bounds[`BoundUnlock{index}`]),
			Fruit = text(bounds[`BoundFruit{index}`]),
		}
	end

	local bosses = folder(old.Bosses)
	new.Bosses = {
		FireBoss = { Count = number(bosses.FireBoss), Kills = number(bosses.FireBossKills) },
		MarineRaid = { Count = number(bosses.MarineRaid), Completed = number(bosses.MarineRaidsCompleted) },
		EndlessRaid = {
			Count = number(bosses.EndlessRaid),
			Max = number(bosses.EndlessMax),
			Completed = number(bosses.EndlessRaidsCompleted),
		},
	}

	local fishing = folder(old.Fishing)
	new.Fishing = { MerlinTrust = number(fishing.MerlinTrust), ChefGift = number(fishing.ChefGift) }
	new.Quests = { AuraSold = number(folder(old.Quests).AuraSold) }

	-- A colour only means something once the haki is unlocked: before that the old game
	-- left a placeholder there, and the rework draws the colour itself at the unlock.
	local haki = folder(old.Haki)
	local stage = conquerorStage(haki.ConqStage)
	new.Haki = {
		ConquerorStage = stage,
		ConquerorColor = if stage and stage > 0 then conquerorColor(haki.HakiColor) else nil,
	}

	local afk = folder(old.AFK_World)
	new.AFK_World = {}
	for oldName, newName in AFK_FIELDS do
		new.AFK_World[newName] = number(afk[oldName])
	end

	local crew = folder(old.Crews)
	new.Crew = { Id = text(crew.CrewId), Rank = text(crew.Rank) }

	new.Spec = {}
	for name, value in folder(old.Spec) do
		if type(name) == "string" and type(value) == "boolean" then
			new.Spec[name] = value
		end
	end
	new.GamePasses = {}
	for name, value in folder(old.GamePasses) do
		if type(name) == "string" and type(value) == "boolean" then
			new.GamePasses[name] = value
		end
	end

	new.SpawnNumber = number(old.SpawnNumber)
	new.SSM = meteoriteFeats(old.SSM)

	-- Only the rework writes these: present in a mixed profile.
	new.PurchaseIds = if type(old.PurchaseIds) == "table" then old.PurchaseIds else nil
	new.Controls = if type(old.Controls) == "table" then old.Controls else nil
	local events = folder(old.Events)
	new.Events = { XMasLevel = number(events.XMasLevel), XMasTask = text(events.XMasTask) }

	return new
end

return LegacyDataMigration
