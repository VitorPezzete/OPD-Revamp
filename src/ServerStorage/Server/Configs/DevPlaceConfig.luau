--!strict
--[[
	The development place (DevPlaceService).

	The plate stands well above WorldConfig.SeaLevel: the water rules are by height, and a
	plate at the origin would have everybody "swimming".
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)
local ConquerorConfig = require(ReplicatedStorage.Shared.Configs.ConquerorConfig)
local ExpertiseConfig = require(ReplicatedStorage.Shared.Configs.ExpertiseConfig)

local DevPlaceConfig = {
	-- Where bodies appear: the middle of Workspace.Map.Baseplate, a little above it.
	Spawn = Vector3.new(0, 506.5, 0),
	-- Players are scattered this far around it, so several do not land on each other.
	SpawnSpread = 12,
	-- Seconds without a body before the next one (a death is seen for that long).
	RespawnSeconds = 1,
	ScanSeconds = 0.5,

	-- What every profile is given as it loads: nobody levels up in a place made for trying
	-- things. Data path -> value, written before the first body exists. The profile is a
	-- throw-away one (DataService never saves here), so this is all a player ever has.
	Profile = {
		["Skills.Melee.Level"] = StatConfig.Caps.Melee,
		["Skills.Defense.Level"] = StatConfig.Caps.Defense,
		["Skills.Sniper.Level"] = StatConfig.Caps.Sniper,
		["Skills.Sword.Level"] = StatConfig.Caps.Sword,
		["Skills.Haki.Level"] = StatConfig.Caps.Haki,
		["Skills.Expertise.Level"] = StatConfig.Caps.Expertise,
		["Haki.ConquerorStage"] = ConquerorConfig.MaxStage,
		-- Opens the second fruit slot.
		["Combat.LegendaryMode"] = true,
		["Combat.Bounty"] = 10_000_000,
		["Combat.Kills"] = 10_000,
		["Economy.Beri"] = 1_000_000_000,
		["Economy.Gems"] = 1_000_000,
		["ExpertiseTokens.Limit"] = ExpertiseConfig.TokenLimitMax,
		["ExpertiseTokens.Current"] = ExpertiseConfig.TokenLimitMax,
	} :: { [string]: any },
	-- Every talent (Expertise.Perks) at its limit.
	MaxPerks = true,
	-- Every weapon owned.
	AllWeapons = true,
}

return table.freeze(DevPlaceConfig)
