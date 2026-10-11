--!strict
--[[
	Experience and levels. Server-only: there is no remote that grants exp.
	Levelling is resolved synchronously on AddExp (the legacy version polled
	ValueObjects with waits, which is where the exp desyncs came from).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)
local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)

type SkillName = DataTypes.SkillName

local StatService = Knit.CreateService({
	Name = "StatService",
	Client = {},
})

StatService.LevelChanged = Signal.new() :: Signal.Signal<Player, SkillName, number>

-- Server-wide multiplier (weekend / events). Applied only when requested by the caller.
StatService.ExpMultiplier = 1

-- Private servers do not progress stats.
StatService.ProgressionEnabled = game.PrivateServerOwnerId == 0

local DataService

function StatService:GetLevel(player: Player, skill: SkillName): number
	local data = DataService:GetData(player)
	return if data then data.Data.Skills[skill].Level else 0
end

function StatService:GetLevels(player: Player): StatConfig.Levels?
	local data = DataService:GetData(player)
	if not data then
		return nil
	end

	local skills = data.Data.Skills
	return {
		Melee = skills.Melee.Level,
		Defense = skills.Defense.Level,
		Sniper = skills.Sniper.Level,
		Sword = skills.Sword.Level,
		Haki = skills.Haki.Level,
	}
end

function StatService:AddExp(player: Player, skill: SkillName, amount: number, useMultiplier: boolean?)
	if not StatService.ProgressionEnabled or amount ~= amount or amount <= 0 then
		return
	end

	local data = DataService:GetData(player)
	if not data then
		return
	end

	local cap = StatConfig.Caps[skill]
	local entry = data.Data.Skills[skill]
	local level = entry.Level
	local exp = entry.Exp + math.floor(amount * (if useMultiplier then StatService.ExpMultiplier else 1))

	local requirement = StatConfig.GetExpRequirement(skill, level)
	while level < cap and exp >= requirement do
		exp -= requirement
		level += 1
		requirement = StatConfig.GetExpRequirement(skill, level)
	end

	if level >= cap then
		level = cap
		exp = requirement
	end

	data:Set(`Skills.{skill}.Exp`, exp)
	if level ~= entry.Level then
		data:Set(`Skills.{skill}.Level`, level)
		StatService.LevelChanged:Fire(player, skill, level)
	end
end

function StatService:KnitInit()
	DataService = Knit.GetService("DataService")
end

return StatService
