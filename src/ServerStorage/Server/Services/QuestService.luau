--!strict
--[[
	The seam between the systems that produce quest progress and the ones that own it.

	The legacy game had no quest log: "quests" were things done for an NPC (a package
	delivered for Merlin, a compass followed to its treasure, a fish landed) and each of
	those scripts reached into two other systems by hand: the Expertise mission of the
	player ("Complete N quest objectives") and Sam's compass token timer, which every
	such reward shortens. Producers now report here and stay unaware of both.

	Server API
		QuestService:AddQuestObjective(player, amount?)   a quest objective was finished
		QuestService:ReduceSamTimer(player, seconds)      a reward shortens Sam's timer
		QuestService.ObjectiveCompleted (player, amount)
		QuestService.SamTimerReduced (player, seconds)    CompassQuestService applies it

	There is no remote: the mission a player is on is accepted through ExpertiseService
	and read by the tracker (MissionGui) from the replicated data, Expertise.Mission.
	The legacy ExpertiseModule.Expertise(char, attacker, damage, reward, quest) entry point
	that every compass and package called with five positional arguments is what
	AddQuestObjective replaces.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local QuestConfig = require(ReplicatedStorage.Shared.Configs.QuestConfig)

local QuestService = Knit.CreateService({
	Name = "QuestService",
	Client = {},
})

QuestService.ObjectiveCompleted = Signal.new() :: Signal.Signal<Player, number>
QuestService.SamTimerReduced = Signal.new() :: Signal.Signal<Player, number>

local ExpertiseService

function QuestService:AddQuestObjective(player: Player, amount: number?)
	local count = amount or 1
	if count ~= count or count <= 0 then
		return
	end
	ExpertiseService:AddMissionProgress(player, QuestConfig.QuestObjective, count)
	QuestService.ObjectiveCompleted:Fire(player, count)
end

function QuestService:ReduceSamTimer(player: Player, seconds: number)
	if seconds == seconds and seconds > 0 then
		QuestService.SamTimerReduced:Fire(player, seconds)
	end
end

function QuestService:KnitInit()
	ExpertiseService = Knit.GetService("ExpertiseService")
end

function QuestService:KnitStart()
	-- Every finished mission stage is worth five minutes of Sam's timer.
	ExpertiseService.MissionStageCompleted:Connect(function(player: Player)
		QuestService:ReduceSamTimer(player, QuestConfig.StageSamSeconds)
	end)
end

return QuestService
