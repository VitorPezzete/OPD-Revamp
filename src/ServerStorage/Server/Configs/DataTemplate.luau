--!strict
--[[
	Persistent player schema. Shape matches schema v2 of the legacy game so existing
	profiles reconcile cleanly; bump Version and add a migration when it changes.

	Reconcile only adds what is missing. A key this template no longer has stays in the
	profiles that carry it and is never read: settings are only read and written by the
	names of SettingsConfig.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)

local SCHEMA_VERSION = 2

local function skill(level: number): DataTypes.Skill
	return { Level = level, Exp = 0 }
end

local function perk(limit: number): DataTypes.Perk
	return { Value = 0, Limit = limit }
end

local function hotkeys(): { [string]: DataTypes.Hotkey }
	local rows: { [string]: DataTypes.Hotkey } = {}
	for action, row in InputConfig.Defaults do
		rows[action] = { KB = row.KB, GP = row.GP, GC = row.GC }
	end
	return rows
end

local function affinity(): DataTypes.Affinity
	return { Melee = 1, Defense = 1, Sniper = 1, Sword = 1 }
end

local function challenges(count: number): { [string]: DataTypes.ChallengeEntry }
	local entries = {}
	for index = 1, count do
		entries[tostring(index)] = { P = 0, Done = false }
	end
	return entries
end

local function storages(count: number): { [string]: DataTypes.StorageSlot }
	local slots = {}
	for index = 1, count do
		slots[tostring(index)] = { Item = "None", ID = "None", Unlocked = false }
	end
	return slots
end

local TEMPLATE: DataTypes.PlayerData = {
	_version = SCHEMA_VERSION,
	-- Bookkeeping of Server.Services.BackupService, never read by gameplay: the id of the
	-- last global rollback keypoint this profile obeyed ("" for none) and the UTC day
	-- (os.time() // 86400) of its last snapshot. An id and a day number: they replicate
	-- with the rest and tell a client nothing. New keys: older profiles get them on reconcile.
	_rollback = "",
	_backupDay = 0,

	Economy = { Beri = 0, Gems = 0, DFCoins = 0, Tea = 0, Fish = 0, GemsBought = 0, BeriBought = 0 },

	DevilFruits = {
		Slot1 = { Name = "None", Color = "None" },
		Slot2 = { Name = "None", Color = "None" },
	},

	Skills = {
		Melee = skill(1),
		Defense = skill(1),
		Sniper = skill(1),
		Sword = skill(1),
		Haki = skill(0),
		Expertise = skill(0),
	},

	Combat = { Bounty = 0, Kills = 0, ZombiesKilled = 0, LegendaryMode = false },
	CompassTokens = { Current = 0, Limit = 1, VIPBonus = 5, AuraBonus = 0 },
	ExpertiseTokens = { Current = 0, Limit = 1 },
	Rewards = { Daily = { N = 0, R = 0 }, Hourly = { N = 0, R = 0 } },

	Items = {},
	Weapons = { Melee = "Melee", Sniper = "None", Sword = "None", Utility = "None" },
	Storages = storages(12),

	-- One row per action, one column per device layout (keyboard, Advanced pad, Classic
	-- pad): the defaults are InputConfig's, which is also what "Defaults" restores. Columns
	-- and rows added since a profile was made arrive on reconcile.
	Hotkeys = hotkeys(),

	Appearance = {
		SkinColor = 1,
		SkinDye = "Pastel brown",
		UsingSkinDye = false,
		Hair = 7,
		Hair_Color = 35,
		Face = 11,
		Torso = 5,
		Torso_Color = 1,
		Pants = 5,
		Pants_Color = 15,
		Arms = 1,
		Arms_Color = 1,
		Feet = 1,
		Feet_Color = 1,
		Gloves = 1,
		Gloves_Color = 1,
		ExtraSlots = {
			A = "",
			A_Color = 1,
			B = "",
			B_Color = 1,
			C = "",
			C_Color = 1,
			D = "",
			D_Color = 1,
			E = "",
			E_Color = 1,
			F = "",
			F_Color = 1,
		},
		OwnedAccessories = {},
	},

	Emotes = {},

	Expertise = {
		Mission = {
			Progress = 0,
			Requirement = 0,
			Difficulty = "",
			Objective = "None",
			ObjectiveTarget = "",
			Hour = 0,
		},
		Perks = {
			BuffDash = perk(25),
			BuffHealth = perk(50),
			BuffRegen = perk(40),
			BuffShave = perk(25),
			BuffSpeed = perk(25),
			BuffWeapons = perk(50),
			ResistAbilities = perk(40),
			ResistGeneral = perk(50),
			ResistHaki = perk(40),
			ResistWeapons = perk(20),
			BuffRewards = perk(40),
			AntiHeal = perk(50),
			BuffFishing = perk(50),
			FullHealth = perk(10),
			KillHeal = perk(10),
			LowHealth = perk(10),
			TargetLow = perk(20),
			TrueDamage = perk(10),
		},
	},

	Affinities = { DF1 = affinity(), DF2 = affinity() },

	Challenges = {
		Daily = challenges(4),
		Weekly = challenges(3),
		Monthly = challenges(2),
		General = {},
		AllCompleted = { Daily = false, Weekly = false, Monthly = false },
		Total = 0,
		Timestamps = {
			DayOfYear = "0",
			DayOfMonth = "0",
			DayOfWeek = "0",
			MonthOfYear = "0",
			WeekOfYear = "0",
			YearOfCycle = "0",
		},
		LegendaryUnlock = {
			TotalLevel = 1,
			AllDone = false,
			DefenseLvl = { Goal = 30, Completed = false },
			MeleeLvl = { Goal = 50, Completed = false },
			Enemy = { Name = "Crab", Progress = 0, Limit = 20, Completed = false },
			Extra = { Name = "Compass", Progress = 0, Limit = 1, Completed = false },
		},
	},

	Settings = {
		Auto_Menu = false,
		Damage_Numbers = false,
		Hide_Bounty = false,
		Join_Message = false,
		Player_List = false,
		Music = 2,
		Sun_Mode = false,
		Fog_Mode = false,
		Obs_Mode = "",
		Fast_Mode = "Off",
		Hitbox = false,
		Hit_Counter = false,
		ControllerType = "Legacy",
		Aim_Assist = true,
		Camera_Lock = 2,
		Root_Lock = false,
		Control_Layout = "Default",
		Trade_Requests = true,
		Charge_Toggle = false,
		UI_Style = "Rework",
		UI_Scale = 0,
	},

	-- The "Custom" control layout (ControlsConfig): camera and aim offsets, and the touch
	-- buttons the player moved, resized or gave another behaviour. A new table: older
	-- profiles get it on reconcile. Only read while Settings.Control_Layout is "Custom"
	-- ("Default" and "Auto" keep it stored and ignore it).
	Controls = {
		CameraOffset = { X = 0, Y = 0, Z = 0 },
		AimOffset = { X = 0, Y = 0 },
		Buttons = {},
	},

	Shop = { VIPRush = 5, AuraCompass = 0 },

	Bounds = {
		["1"] = { Unlocked = false, Fruit = "None" },
		["2"] = { Unlocked = false, Fruit = "None" },
		["3"] = { Unlocked = false, Fruit = "None" },
	},

	Bosses = {
		FireBoss = { Count = 0, Kills = 0 },
		MarineRaid = { Count = 0, Completed = 0 },
		EndlessRaid = { Count = 0, Max = 0, Completed = 0 },
	},

	Fishing = { MerlinTrust = 0, ChefGift = 0 },
	Quests = { AuraSold = 0 },
	-- Conqueror's Haki: stage 0 (locked) to 3, and the player's colour as a hex string
	-- ("" until ConquerorService draws one). New keys: older profiles get them on reconcile.
	Haki = { ConquerorStage = 0, ConquerorColor = "" },

	AFK_World = { Beri = 0, Gems = 0, Compass = 0, SilverCompass = 0, GoldenCompass = 0, CompassTime = 0 },

	Crew = { Id = "", Rank = "" },
	Spec = { AlphaTester = false, BetaTester = false, ModTester = false, HelperTester = false },
	GamePasses = { DiscoVIP = false, SkipSpin = false, SlotD = false, SlotE = false, SlotF = false },

	SpawnNumber = 1,
	SSM = { false, false, false, false },
	Events = { XMasLevel = 0, XMasTask = "" },

	-- Receipts already granted (MonetizationService), newest last, capped.
	PurchaseIds = {},
}

return table.freeze({
	Template = TEMPLATE,
	Version = SCHEMA_VERSION,
	StoreName = "OPD",
	KeyPrefix = "User_",
})
