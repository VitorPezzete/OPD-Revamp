--!strict
--[[
	What players see of each other's rank: the Player attributes PlayerListService
	publishes, and how the player list (UI.Screens.Core_i7) and the chat (ChatController)
	paint them. Colours and icons are the legacy ones.

	Two independent attributes, because the legacy game showed them independently:
	- Rank:   staff. "Owner" | "Mod" | nil. A moderator who hides their bounty is not
	          published at all (the legacy list dropped their icon: incognito staff).
	- Tester: "Helper" | "Alpha" | "Beta" | nil, from the Spec flags of the player data.
]]

export type StaffRank = "Owner" | "Mod"
export type TesterRank = "Helper" | "Alpha" | "Beta"

local RankConfig = {}

RankConfig.Attributes = table.freeze({
	-- number, absent while the owner hides it.
	Bounty = "Bounty",
	-- boolean, set by SettingsService.
	HideBounty = "HideBounty",
	-- boolean
	Legendary = "LegendaryMode",
	-- boolean, set by LeaderboardService.
	Top = "Top100",
	Rank = "Rank",
	Tester = "Tester",
	-- true for staff who do not appear in the list.
	Hidden = "ListHidden",
})

-- Player list: the badge left of the name.
RankConfig.BadgeIcon = "rbxassetid://98153329437702"
RankConfig.BadgeColors = table.freeze({
	Mod = Color3.fromRGB(0, 148, 255),
	Owner = Color3.fromRGB(150, 0, 170),
	Helper = Color3.fromRGB(127, 0, 204),
	Alpha = Color3.fromRGB(107, 255, 146),
	Beta = Color3.fromRGB(255, 206, 92),
} :: { [string]: Color3 })
-- A moderator's badge wins over the owner's, then the tester ones in this order.
RankConfig.TesterOrder = table.freeze({ "Helper", "Alpha", "Beta" })

-- Player list: the star of the top 100 and of legendary mode.
RankConfig.StarIcon = "http://www.roblox.com/asset/?id=2204238994"
RankConfig.StarTopColor = Color3.fromRGB(197, 0, 0)
-- Legendary mode, and a top 100 player who hides their bounty.
RankConfig.StarLegendaryColor = Color3.fromRGB(54, 33, 177)

-- Chat: colour of the message text. Owner, Helper, legendary mode, Alpha, Beta, in
-- that order; moderators have no colour of their own.
RankConfig.ChatColors = table.freeze({
	Normal = Color3.fromRGB(255, 255, 255),
	Owner = Color3.fromRGB(255, 152, 220),
	Helper = Color3.fromRGB(127, 255, 255),
	Legendary = Color3.fromRGB(200, 180, 255),
	Alpha = Color3.fromRGB(140, 255, 140),
	Beta = Color3.fromRGB(255, 206, 92),
} :: { [string]: Color3 })
RankConfig.BubbleTextColor = Color3.fromRGB(0, 0, 0)

return table.freeze(RankConfig)
