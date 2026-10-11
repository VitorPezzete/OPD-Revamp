--!strict
export type SkillName = "Melee" | "Defense" | "Sniper" | "Sword" | "Haki" | "Expertise"
export type WeaponSlot = "Melee" | "Sniper" | "Sword" | "Utility"

export type Skill = { Level: number, Exp: number }
export type Perk = { Value: number, Limit: number }
export type FruitSlot = { Name: string, Color: string }
export type Affinity = { Melee: number, Defense: number, Sniper: number, Sword: number }
-- One column per device layout: keyboard, Advanced pad, Classic pad (Shared.Configs.InputConfig).
export type Hotkey = { KB: string, GP: string, GC: string }
export type ChallengeEntry = { P: number, Done: boolean }
export type StorageSlot = { Item: string, ID: string, Unlocked: boolean }
-- One touch button of the "Custom" control layout (Shared.Configs.ControlsConfig).
export type ControlButton = { X: number?, Y: number?, Scale: number, Behavior: string }

export type PlayerData = {
	_version: number,
	-- BackupService bookkeeping (see DataTemplate).
	_rollback: string,
	_backupDay: number,

	Economy: {
		Beri: number,
		Gems: number,
		DFCoins: number,
		Tea: number,
		Fish: number,
		GemsBought: number,
		BeriBought: number,
	},
	DevilFruits: { Slot1: FruitSlot, Slot2: FruitSlot },
	Skills: { [SkillName]: Skill },
	Combat: { Bounty: number, Kills: number, ZombiesKilled: number, LegendaryMode: boolean },
	CompassTokens: { Current: number, Limit: number, VIPBonus: number, AuraBonus: number },
	ExpertiseTokens: { Current: number, Limit: number },
	Rewards: { Daily: { N: number, R: number }, Hourly: { N: number, R: number } },

	-- Owned items, keyed by item name.
	Items: { [string]: boolean },
	Weapons: { [WeaponSlot]: string },
	Storages: { [string]: StorageSlot },
	Hotkeys: { [string]: Hotkey },
	Appearance: { [string]: any },
	Emotes: { [string]: boolean },

	Expertise: {
		Mission: {
			Progress: number,
			Requirement: number,
			Difficulty: string,
			Objective: string,
			ObjectiveTarget: string,
			Hour: number,
		},
		Perks: { [string]: Perk },
	},
	Affinities: { DF1: Affinity, DF2: Affinity },
	Challenges: { [string]: any },
	Settings: { [string]: any },
	-- The "Custom" control layout; written whole by SettingsService:SetControls.
	Controls: {
		CameraOffset: { X: number, Y: number, Z: number },
		AimOffset: { X: number, Y: number },
		Buttons: { [string]: ControlButton },
	},
	Shop: { VIPRush: number, AuraCompass: number },
	Bounds: { [string]: { Unlocked: boolean, Fruit: string } },
	Bosses: { [string]: { [string]: number } },
	Fishing: { MerlinTrust: number, ChefGift: number },
	Quests: { AuraSold: number },
	Haki: { ConquerorStage: number, ConquerorColor: string },
	AFK_World: { [string]: number },
	Crew: { Id: string, Rank: string },
	Spec: { [string]: boolean },
	GamePasses: { [string]: boolean },
	SpawnNumber: number,
	SSM: { boolean },
	Events: { XMasLevel: number, XMasTask: string },
	PurchaseIds: { string },
}

-- One replicated change: dot-separated path and its new value.
export type DataDelta = { Path: string, Value: any }

return {}
