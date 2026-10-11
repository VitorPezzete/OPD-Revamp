--!strict
--[[
	Developer commands on saved progress: the Stats and Economy tabs of the menu.

	Levels and experience go through StatService and StatResetService. The rest are
	numbers of the profile, and only the ones listed in VALUES can be written: each entry
	names its data path and its range, and the menu builds its fields from the same list.
	SetData is the escape hatch for everything else: an existing number, boolean or string
	of the profile, replaced by a value of the same type, never a new key or a table.

	Every write goes through PlayerData (Set / Increment), so replication and the
	observers of a path react as they do in play: a Beri gain feeds a running mission, a
	kill counter unlocks its weapon. Handlers trust their caller (see DevKit).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local ExpertiseConfig = require(ReplicatedStorage.Shared.Configs.ExpertiseConfig)
local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)
local TablePath = require(ReplicatedStorage.Shared.Util.TablePath)
local DevKit = require(ServerStorage.Server.Modules.DevKit)

type Value = {
	Key: string,
	Label: string,
	Group: "Currencies" | "Tokens" | "Records",
	Path: string,
	Min: number,
	Max: number,
	-- What the menu's + and - buttons move it by.
	Step: number,
}

local MAX_CURRENCY = 1e12
local MAX_TOKENS = 1000
local MAX_EXP = 1e9
local MAX_TEXT = 64
local SKILLS = { "Melee", "Defense", "Sniper", "Sword", "Haki", "Expertise" }
local CAPS = StatConfig.Caps :: { [string]: number }

local function define(key: string, label: string, group: any, path: string, minimum: number, maximum: number, step: number): Value
	return { Key = key, Label = label, Group = group, Path = path, Min = minimum, Max = maximum, Step = step }
end

-- Every number SetValue / AddValue can reach, in menu order.
local VALUES: { Value } = {
	define("Beri", "Beri", "Currencies", "Economy.Beri", 0, MAX_CURRENCY, 100000),
	define("Gems", "Gems", "Currencies", "Economy.Gems", 0, MAX_CURRENCY, 100),
	define("DFCoins", "DF Coins", "Currencies", "Economy.DFCoins", 0, MAX_CURRENCY, 10),
	define("Tea", "Tea", "Currencies", "Economy.Tea", 0, MAX_CURRENCY, 10),
	define("Fish", "Fish", "Currencies", "Economy.Fish", 0, MAX_CURRENCY, 10),

	define("CompassTokens", "Compass tokens", "Tokens", "CompassTokens.Current", 0, MAX_TOKENS, 1),
	define("CompassLimit", "Compass token limit", "Tokens", "CompassTokens.Limit", 1, MAX_TOKENS, 1),
	define("VIPTokens", "VIP compass tokens", "Tokens", "CompassTokens.VIPBonus", 0, MAX_TOKENS, 1),
	define("AuraTokens", "Aura compass tokens", "Tokens", "CompassTokens.AuraBonus", 0, MAX_TOKENS, 1),
	define("ExpertiseTokens", "Expertise tokens", "Tokens", "ExpertiseTokens.Current", 0, MAX_TOKENS, 1),
	define("ExpertiseLimit", "Expertise token limit", "Tokens", "ExpertiseTokens.Limit", 1, MAX_TOKENS, 1),

	define("Bounty", "Bounty", "Records", "Combat.Bounty", 0, MAX_CURRENCY, 1000000),
	define("Kills", "Kills", "Records", "Combat.Kills", 0, MAX_CURRENCY, 1000),
	define("ZombiesKilled", "Zombies killed", "Records", "Combat.ZombiesKilled", 0, MAX_CURRENCY, 50),
	define("FireBossKills", "Fire boss kills", "Records", "Bosses.FireBoss.Kills", 0, MAX_CURRENCY, 1),
	define("MerlinTrust", "Merlin trust", "Records", "Fishing.MerlinTrust", 0, MAX_CURRENCY, 10),
	define("ChefGift", "Chef gift", "Records", "Fishing.ChefGift", 0, MAX_CURRENCY, 10000),
	-- 0 = locked. Using it also takes Haki 500 (ConquerorConfig.HakiLevel).
	define("ConquerorStage", "Conqueror's Haki stage", "Records", "Haki.ConquerorStage", 0, 3, 1),
}

local valuesByKey: { [string]: Value } = {}
for _, entry in VALUES do
	valuesByKey[entry.Key] = entry
end

local handlers: { [string]: DevKit.Handler } = {}

local function findValue(keyArg: unknown): Value?
	local key = DevKit.Name(keyArg)
	return if key then valuesByKey[key] else nil
end

local function writeLevel(target: Player, data: any, skill: string, level: number)
	data:Set(`Skills.{skill}.Exp`, 0)
	data:Set(`Skills.{skill}.Level`, level)
	Knit.GetService("StatService").LevelChanged:Fire(target, skill, level)
end

-- A level that dropped can leave a level-gated weapon in the loadout: WeaponService
-- takes it out and hands the tools again.
local function refreshLoadout(target: Player)
	Knit.GetService("WeaponService"):Refresh(target)
end

function handlers.SetSkill(_developer, target, skillArg, levelArg)
	local skill = DevKit.Member(skillArg, SKILLS)
	local level = skill and DevKit.Integer(levelArg, 0, CAPS[skill])
	local data = DevKit.Data(target)
	if not skill or not level or not data then
		return false, "invalid skill, level or target"
	end

	writeLevel(target, data, skill, level)
	refreshLoadout(target)
	return true, `{skill} = {level}`
end

function handlers.AddLevels(_developer, target, skillArg, deltaArg)
	local skill = DevKit.Member(skillArg, SKILLS)
	local delta = skill and DevKit.Integer(deltaArg, -CAPS[skill], CAPS[skill])
	local data = DevKit.Data(target)
	if not skill or not delta or not data then
		return false, "invalid skill, amount or target"
	end

	local level = math.clamp(data.Data.Skills[skill :: any].Level + delta, 0, CAPS[skill])
	writeLevel(target, data, skill, level)
	refreshLoadout(target)
	return true, `{skill} {if delta >= 0 then "+" else ""}{delta} = {level}`
end

function handlers.SetAllSkills(_developer, target, levelArg)
	local level = DevKit.Integer(levelArg, 0, math.huge)
	local data = DevKit.Data(target)
	if not level or not data then
		return false, "invalid level or target"
	end
	for _, skill in SKILLS do
		-- Expertise has its own point economy: leave it to its own field.
		if skill ~= "Expertise" then
			writeLevel(target, data, skill, math.min(level, CAPS[skill]))
		end
	end
	refreshLoadout(target)
	return true, `combat skills = {level} (capped per skill)`
end

-- Experience as the game grants it: levels are resolved by StatService.
function handlers.AddExp(_developer, target, skillArg, amountArg, multiplierArg)
	local skill = DevKit.Member(skillArg, SKILLS)
	local amount = DevKit.Integer(amountArg, 1, MAX_EXP)
	local data = DevKit.Data(target)
	if not skill or not amount or not data then
		return false, "invalid skill, amount or target"
	end

	local StatService = Knit.GetService("StatService")
	if not StatService.ProgressionEnabled then
		return false, "experience is off on this server (private servers do not progress stats)"
	end
	local entry = data.Data.Skills[skill :: any]
	local before = entry.Level
	StatService:AddExp(target, skill, amount, multiplierArg == true)
	return true, `{skill} +{amount} exp: level {before} -> {entry.Level}, {entry.Exp} exp into it`
end

-- The player's own "Stat Reset": items, Beri, bounty, kills, skills and both fruits.
function handlers.ResetStats(_developer, target)
	local reset = Knit.GetService("StatResetService"):ResetStats(target)
	return reset, if reset then "full stat reset done" else "target data is not loaded"
end

--[[
	Expertise perk points, up to the cap saved with the player. The menu is not held to
	the "one point per Expertise level" budget: a build can be tried before it is earned.
]]
function handlers.SetPerk(_developer, target, perkArg, valueArg)
	local perkName = DevKit.Key(perkArg, ExpertiseConfig.Perks)
	local data = DevKit.Data(target)
	local perk = perkName and data and data.Data.Expertise.Perks[perkName]
	local points = perk and DevKit.Integer(valueArg, 0, math.max(0, perk.Limit))
	if not perkName or not data or not points then
		return false, "invalid perk, value or target"
	end
	data:Set(`Expertise.Perks.{perkName}.Value`, points)
	return true, `{perkName} = {points}`
end

function handlers.SetAllPerks(_developer, target, maximumArg)
	local data = DevKit.Data(target)
	if not data then
		return false, "target data is not loaded"
	end

	local perks = data.Data.Expertise.Perks
	local written = 0
	for _, perkName in ExpertiseConfig.PerkOrder do
		local perk = perks[perkName]
		if perk then
			data:Set(`Expertise.Perks.{perkName}.Value`, if maximumArg == true then math.max(0, perk.Limit) else 0)
			written += 1
		end
	end
	return true, `{written} perks {if maximumArg == true then "maxed" else "emptied"}`
end

-- The flag only: the altar's price (skills back to 1, Beri and the eaten fruit gone) is
-- StatResetService's and is not charged here.
function handlers.SetLegendary(_developer, target, enabledArg)
	local data = DevKit.Data(target)
	if not data then
		return false, "target data is not loaded"
	end
	data:Set("Combat.LegendaryMode", enabledArg == true)
	return true, if enabledArg == true then "Legendary Mode on" else "Legendary Mode off"
end

function handlers.SetValue(_developer, target, keyArg, amountArg)
	local entry = findValue(keyArg)
	local amount = entry and DevKit.Integer(amountArg, entry.Min, entry.Max)
	local data = DevKit.Data(target)
	if not entry or not amount or not data or type(data:Get(entry.Path)) ~= "number" then
		return false, "invalid value, amount or target"
	end
	data:Set(entry.Path, amount)
	return true, `{entry.Label} = {DevKit.Whole(amount)}`
end

function handlers.AddValue(_developer, target, keyArg, deltaArg)
	local entry = findValue(keyArg)
	local delta = entry and DevKit.Integer(deltaArg, -entry.Max, entry.Max)
	local data = DevKit.Data(target)
	if not entry or not delta or not data or type(data:Get(entry.Path)) ~= "number" then
		return false, "invalid value, amount or target"
	end
	local result = data:Increment(entry.Path, delta, entry.Min, entry.Max)
	return true, `{entry.Label} {if delta >= 0 then "+" else ""}{DevKit.Whole(delta)} = {DevKit.Whole(result)}`
end

-- Any existing leaf of the profile, keeping its type ("Combat.Bounty", "Items.Katana").
function handlers.SetData(_developer, target, pathArg, value)
	local path = DevKit.Name(pathArg)
	local data = DevKit.Data(target)
	if not path or not data or string.find(path, "[^%w_%.]") then
		return false, "invalid path or target"
	end

	local current = TablePath.Get(data.Data :: any, path)
	local kind = type(current)
	if kind ~= "number" and kind ~= "boolean" and kind ~= "string" then
		return false, `"{path}" is not an existing number, boolean or string`
	end
	if type(value) ~= kind or (kind == "string" and #(value :: string) > MAX_TEXT) then
		return false, `"{path}" expects a {kind}`
	end
	-- NaN and infinity cannot be saved: a profile holding one fails to store.
	if kind == "number" and (value ~= value or math.abs(value :: number) == math.huge) then
		return false, `"{path}" expects a finite number`
	end
	data:Set(path, value)
	return true, `{path} = {tostring(value)}`
end

-- Conqueror's Haki stage, 0 (locked) to 3, through its service: lowering it also takes
-- off a coating the new stage does not have.
function handlers.SetConquerorStage(_developer, target, stageArg)
	local stage = DevKit.Integer(stageArg, 0, 3)
	if not stage or not DevKit.Data(target) then
		return false, "invalid stage (0-3) or target"
	end

	local ConquerorService = Knit.GetService("ConquerorService")
	ConquerorService:SetStage(target, stage)
	return true, `Conqueror's Haki stage = {ConquerorService:GetStage(target)}`
end

local function getCatalog(): { [string]: any }
	local perks = {}
	for _, perkName in ExpertiseConfig.PerkOrder do
		table.insert(perks, { Name = perkName, Limit = ExpertiseConfig.Perks[perkName].Limit })
	end
	return {
		Skills = SKILLS,
		Caps = StatConfig.Caps,
		Values = VALUES,
		Perks = perks,
	}
end

local function getState(target: Player): { [string]: any }
	local data = DevKit.Data(target)
	if not data then
		return {}
	end

	local levels, experience = {}, {}
	for _, skill in SKILLS do
		local entry = data.Data.Skills[skill :: any]
		levels[skill] = entry.Level
		experience[skill] = entry.Exp
	end

	local values = {}
	for _, entry in VALUES do
		values[entry.Key] = data:Get(entry.Path)
	end

	local perks = {}
	for perkName, perk in data.Data.Expertise.Perks do
		perks[perkName] = { Value = perk.Value, Limit = perk.Limit }
	end

	return {
		Levels = levels,
		Exp = experience,
		Values = values,
		Perks = perks,
		PerkPoints = ExpertiseConfig.GetSpentPoints(data.Data.Expertise.Perks),
		Legendary = data.Data.Combat.LegendaryMode,
	}
end

return {
	Handlers = handlers,
	Costs = {
		SetAllSkills = 2,
		SetAllPerks = 3,
		ResetStats = 5,
	},
	GetCatalog = getCatalog,
	GetState = getState,
} :: DevKit.CommandModule
