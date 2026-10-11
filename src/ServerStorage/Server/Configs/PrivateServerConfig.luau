--!strict
--[[
	Private servers bought with a developer product: 30 days per purchase, reached with a
	6 character code. Store names and record shapes are the legacy ones, so subscriptions
	and codes sold before the rewrite keep working.
]]
return table.freeze({
	-- Developer product "30 days". The purchase handler calls PrivateServerService:GrantSubscription.
	ProductId = 3541255352,
	DaysPerPurchase = 30,

	CodeLength = 6,
	CodeAlphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
	MaxDaysShown = 999,

	-- [userId] = { Player, UserId, Code, TimeLimit (day number) }
	SubscriptionStore = "VIPCodesList",
	-- [code] = { Player, UserId, PSCode, TimeLimit, ServerId }
	CodeStore = "VIPCode",

	-- MemoryStore maps refreshed by private servers while they are alive.
	PresenceMap = "VIPPlayers",
	ActiveMap = "VIPActiveServers",
	PresenceSeconds = 180,
	RefreshSeconds = 60,

	-- Shown to everyone in a private server whose code was replaced.
	CodeChangedMessage = "Code Expired or Changed",
})
