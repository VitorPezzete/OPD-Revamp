--!strict
--[[
	Quest glue shared by the systems that hand out "quest objectives" (deliveries,
	compasses, fishing) and the Haki master's quest.

	The Expertise missions themselves (objectives, requirements, stage exp) are
	ExpertiseConfig / ExpertiseService; nothing about them is repeated here.
]]

local QuestConfig = {}

-- Seconds taken off Sam's compass token timer per finished Expertise mission stage.
QuestConfig.StageSamSeconds = 300
-- Mission objective advanced by one for every finished quest objective.
QuestConfig.QuestObjective = "Quests"

-- Silvers Rayleigh, the wandering Haki master.
QuestConfig.Haki = table.freeze({
	Merchant = "QuestHakiMerchant",
	-- Melee + Sniper + Defense + Sword levels needed before he teaches anything.
	TotalLevelRequirement = 1000,
	-- Haki level he grants. Level 1 is also what unlocks Observation (StatConfig.ObservationRequirement).
	UnlockedLevel = 1,
	Dialogue = table.freeze({
		Stranger = "Hello. I'm waiting for someone. Someone strong. Maybe you can help me with that. Come back later.",
		Greeting = "My name is Silvers Rayleigh. Have you been looking for me? I'm a busy guy, but maybe I can spare a moment for you.",
		Offer = "Would you like me to teach you about Haki? You'll need to unlock its power on your own, but I can show you how. Once it's unlocked, you'll need to train yourself.",
		Lesson = "Haki is the act of not doubting. Presence, fighting spirit, and intimidation! You must meditate on what I have taught you, but meditation is only a tool to unlock your potential.",
		Trained = "If you want to become a master of Haki, you'll need to train. The more you use Haki, the better you'll get.",
	}),
})

return table.freeze(QuestConfig)
