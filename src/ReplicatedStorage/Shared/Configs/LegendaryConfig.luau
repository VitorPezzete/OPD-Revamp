--!strict
--[[
	The quests of the Legendary Hero (Workspace.Map.Merchants.LegendaryHero). The Legendary
	Mode transition itself is StatResetService / InventoryConfig.Legendary.

	Requirements, cooldowns, prices and lines come from LegendaryHeroServer and
	QuestsHandler in the legacy place, which each had their own copy of the tables. The
	server checks with the same predicates the screen uses to pick a line.
]]

export type Requirement = { Path: string, Value: number, Label: string }

export type Quest = {
	-- Frame name in the LegendaryQuests layout, and the name sent to the server.
	Title: string,
	Image: string,
	-- Data path holding the os.time() at which the quest can be taken again.
	CooldownPath: string,
	Cooldown: number,
	Requirements: { Requirement },
	RequiresLegendary: boolean,
	GemCost: number?,
	-- Raids open a party lobby (RaidService); the others are handled by LegendaryService.
	Raid: boolean?,
	Dialogue: { [string]: { string } },
}

local MILLION = 1_000_000

local Quests: { [string]: Quest } = {
	FireBoss = {
		Title = "Fight Fire Boss",
		Image = "rbxassetid://134273497267016",
		CooldownPath = "Bosses.FireBoss.Count",
		Cooldown = 20 * 60,
		Requirements = {
			{ Path = "Skills.Defense.Level", Value = 500, Label = "Defense" },
			{ Path = "Skills.Melee.Level", Value = 500, Label = "Melee" },
			{ Path = "Skills.Haki.Level", Value = 300, Label = "Haki" },
			{ Path = "Skills.Expertise.Level", Value = 30, Label = "Expertise" },
			{ Path = "Combat.Kills", Value = 5000, Label = "Kills" },
			{ Path = "Combat.Bounty", Value = 15 * MILLION, Label = "Bounty" },
		},
		RequiresLegendary = true,
		Dialogue = {
			Qualified = {
				"Oh, this? It's just an old Burning Compass. Used to glow when the sun stood at its highest. Points somewhere out at sea... I think. Never really cared enough to follow it. You can have it.",
				"That thing? Just a worn-out compass. It heats up around noon. Glows a little. Supposedly leads somewhere important. Didn't mean much to me. Maybe it'll mean something to you.",
				"What's this? It's called a Burning Compass. Reacts to the sun at midday. That's about it. If you're curious, take it. I have no use for it anymore",
			},
			NotQualified = {
				"Focus on getting stronger first, then talk to me.",
				"...",
				"You are not worth my time. Go away.",
				"You are pitiful. Leave.",
				"Get stronger first and then come back.",
				"Leave, insect.",
			},
			Taken = {
				"I got nothing else for you. Go away.",
				"You already have it. Go away.",
				"You already have it. Leave.",
				"You already have it. I'm not giving you another one.",
			},
			Timed = { "...", "Come back later.", "I got nothing for you now.", "You may be worth it, but later." },
		},
	},

	MarineRaid = {
		Title = "Fight Marine Raid",
		Image = "rbxassetid://77909306485141",
		CooldownPath = "Bosses.MarineRaid.Count",
		Cooldown = 60 * 60,
		Requirements = {
			{ Path = "Skills.Defense.Level", Value = 500, Label = "Defense" },
			{ Path = "Skills.Melee.Level", Value = 500, Label = "Melee" },
			{ Path = "Skills.Haki.Level", Value = 400, Label = "Haki" },
			{ Path = "Skills.Expertise.Level", Value = 50, Label = "Expertise" },
			{ Path = "Combat.Kills", Value = 15000, Label = "Kills" },
			-- The legacy comment said 25M; the value in both scripts was 20M.
			{ Path = "Combat.Bounty", Value = 20 * MILLION, Label = "Bounty" },
			{ Path = "Quests.AuraSold", Value = 1, Label = "Auras sold" },
		},
		RequiresLegendary = true,
		Raid = true,
		Dialogue = {
			-- Shown instead of Qualified until the first raid has been started.
			FirstRaid = {
				"Looks like Marines took away that guy, Maybe you should get some friends and get him back",
				"Marines have taken him, you should get some friends and get him back",
				"I saw some marines going after him, are you going to look for him?",
				"I kinda liked that guy... Mind looking for him?",
				"Marines are getting more agressive each day... They got the guy. You going after him? Get some friends.",
			},
			Qualified = {
				"Yo, Wanna mess with marines?",
				"Im in the mood for some fight, wanna go hunt a few marines?",
				"Lets play a bit with marines.",
			},
			NotQualified = { "..." },
			Timed = {
				"Marines probably need some time to recover after this.",
				"I doubt we will se any marines for some time.",
				"After the chaos in Marine Ford last time, marines have been busy.",
			},
		},
	},

	Endless = {
		Title = "Fight Endless Raid",
		Image = "rbxassetid://134273497267016",
		CooldownPath = "Bosses.EndlessRaid.Count",
		Cooldown = 60 * 60,
		Requirements = {},
		RequiresLegendary = false,
		GemCost = 250,
		Raid = true,
		Dialogue = {
			Qualified = {
				"Yo, I got some big stuff planned, but we need some funds, do you got it?",
				"Hey there, Let's do some big stuff, as long as you can pay",
				"We might be able to get our names on the news, with a few funds tho",
				"You got the money, we got the plan, let's go?",
			},
		},
	},
}

local LegendaryConfig = {}

LegendaryConfig.Merchant = "LegendaryHero"
LegendaryConfig.Quests = Quests
LegendaryConfig.LegendaryPath = "Combat.LegendaryMode"

-- `get` reads a data path: PlayerData:Get on the server, DataController:Get on the client.
function LegendaryConfig.MeetsRequirements(questName: string, get: (path: string) -> any): boolean
	local quest = Quests[questName]
	if not quest then
		return false
	end
	if quest.RequiresLegendary and get(LegendaryConfig.LegendaryPath) ~= true then
		return false
	end
	for _, requirement in quest.Requirements do
		local value = get(requirement.Path)
		if type(value) ~= "number" or value < requirement.Value then
			return false
		end
	end
	return true
end

-- Seconds left before the quest can be taken again (0 when it is available).
function LegendaryConfig.GetCooldownLeft(questName: string, get: (path: string) -> any, now: number): number
	local quest = Quests[questName]
	local readyAt = quest and get(quest.CooldownPath)
	return if type(readyAt) == "number" then math.max(0, readyAt - now) else 0
end

-- Labels of what the player still lacks for a quest, in the order the hero lists them.
function LegendaryConfig.MissingRequirements(questName: string, get: (path: string) -> any): { string }
	local missing: { string } = {}
	local quest = Quests[questName]
	if not quest then
		return missing
	end
	if quest.RequiresLegendary and get(LegendaryConfig.LegendaryPath) ~= true then
		table.insert(missing, "Legendary Mode")
	end
	for _, requirement in quest.Requirements do
		local value = get(requirement.Path)
		if type(value) ~= "number" or value < requirement.Value then
			table.insert(missing, requirement.Label)
		end
	end
	return missing
end

return table.freeze(LegendaryConfig)
