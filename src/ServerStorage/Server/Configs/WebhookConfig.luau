--!strict
--[[
	Discord webhooks (WebhookService): where they are allowed to post, which channels
	exist and what gets reported to them.

	No address is ever written here or anywhere else in the source. A channel names a
	token ("W1".."W19", the nineteen webhooks of the legacy game); the address behind a
	token lives in a ModuleScript that exists only inside the place file:

		ServerStorage.Secrets.Webhooks   ->   return { W1 = "https://...", W3 = "https://..." }

	A missing module, or a missing key, silently turns the channels of that token off.
	Two channels on the same token are the same Discord channel and share one queue.

	Posting only happens in the places listed in EnabledPlaceIds, and never in Studio.
	The testing place (70580933622015, PlaceConfig.Places.Main) is the source version of
	the final place and is NOT listed on purpose: the same code and the same Secrets
	module can sit in both, and only the final place posts. The raid / AFK / trade
	places of the final game post nothing either until their ids are added here.
]]

export type Flag = {
	-- Channel the report goes to.
	Channel: string,
	-- What happened, completing "<player> (<id>) ...".
	Text: string,
	-- Reported once the player was flagged this many times within Window seconds.
	Strikes: number,
	Window: number,
}

local WebhookConfig = {}

WebhookConfig.EnabledPlaceIds = table.freeze({ 112233665771826 })

-- ServerStorage.<SecretsFolder>.<SecretsModule>
WebhookConfig.SecretsFolder = "Secrets"
WebhookConfig.SecretsModule = "Webhooks"

--[[
	Channel -> token. The comment is what the legacy game posted there.
	Tokens that are not "W<n>" belong to legacy calls whose address was not exported
	("<URL>" in the dump): they stay off until a key of that name is added to the
	Secrets module, or the channel is pointed at one of the nineteen tokens.
]]
WebhookConfig.Channels = table.freeze({
	-- Observation haki remote spammed (auto-ban).
	HakiAntiCheat = "W1",
	-- "Tried to use mixer in spawnbox": commented out in the legacy scripts, nothing posts.
	JuicerSpawnBox = "W2",
	-- Too many barrels / distant barrels too fast / juicer used from far away (auto-bans).
	BarrelAntiCheat = "W3",
	-- Chests opened faster than the trip between them allows (auto-ban).
	ChestAntiCheat = "W4",
	-- Barrels clicked inhumanly fast (suspect) and the trap "special barrels".
	BarrelSuspects = "W5",
	-- BeriDupe checks (#BF1, #BF2, #WealthWarning) and invalid accessory names.
	Integrity = "W6",
	-- Sam's compass claimed from across the map, compass treasure auto-farms (#C1A-C).
	CompassAntiCheat = "W7",
	-- Aura fruit picked up / dropped / eaten / given: commented out in the legacy scripts.
	AuraFruitMoves = "W8",
	-- Fishing minigame results a client cannot produce.
	FishingAntiCheat = "W9",
	-- Many rare / ultra rare boxes opened on one server within a minute.
	FruitBoxBursts = "W10",
	-- Two live fruits carrying the same id.
	FruitDupes = "W11",
	-- Santa's remote called with an unknown action (the remote was not ported).
	SantaErrors = "W12",
	-- Owner tool: fruit spawned for a player.
	StaffFruitSpawns = "W13",
	-- Declared by the moderator script for its command log, never called there. The
	-- rework's full command trail (AuditLog "ran" / "denied" / "shutdown") goes here.
	StaffCommands = "W14",
	-- Ban, global ban, kick, slay.
	ModActions = "W15",
	Unbans = "W16",
	-- Box opened into an aura fruit.
	FruitBoxAura = "W17",
	-- "Got the Lightning Sword": commented out in the legacy scripts, nothing posts.
	LightningSword = "W18",
	-- Merlin's packages delivered by teleporting (auto-ban).
	PackageAntiCheat = "W19",

	-- Legacy address not exported. Posted in the owner-tool script next to W13, so they
	-- default to it: point them elsewhere if those were different Discord channels.
	StaffItems = "W13", -- "Item Spawned", "Drop Party"
	StaffData = "W13", -- "Data Updated (Set / Add / Global)"
	-- Legacy address not exported and nothing to pair it with: off until a key exists.
	GiftPurchases = "GiftPurchases",
})

--[[
	Budget. Discord allows 30 requests per minute per webhook, counted across every
	server of the game; Roblox allows 500 HTTP requests per minute per server, shared
	with everything else that uses HttpService. Messages are therefore batched: a channel
	sends at most one request per ChannelIntervalSeconds (several messages joined in
	it), and the whole server at most MaxRequestsPerMinute.
]]
WebhookConfig.FlushSeconds = 2
WebhookConfig.ChannelIntervalSeconds = 10
WebhookConfig.MaxRequestsPerMinute = 30
-- Seconds between two sends, for channels that should be slower or faster than the default.
WebhookConfig.ChannelIntervals = table.freeze({
	StaffCommands = 15,
}) :: { [string]: number }
-- Messages waiting per webhook; past this the oldest is dropped (and the drop is reported).
WebhookConfig.MaxQueue = 60
-- A batch that keeps failing (network, Discord 5xx) is given up after this many attempts.
WebhookConfig.MaxAttempts = 3
WebhookConfig.RetrySeconds = 15
-- Longest a server waits on a rate limit Discord announced, whatever it announced.
WebhookConfig.MaxRateLimitSeconds = 300
-- BindToClose: how long the last messages may take to leave (data saving comes first).
WebhookConfig.CloseFlushSeconds = 6

--[[
	Suspected exploits (WebhookService:Flag). The legacy game banned automatically and
	announced the ban; the rework refuses the impossible request and only reports it,
	once the player has done it Strikes times within Window seconds. A reported player
	is not reported again for the same reason during FlagCooldownSeconds.
]]
WebhookConfig.FlagCooldownSeconds = 300
WebhookConfig.Flags = table.freeze({
	HakiToggleSpam = { Channel = "HakiAntiCheat", Text = "spammed the haki remote", Strikes = 40, Window = 5 },
	BarrelFlood = { Channel = "BarrelAntiCheat", Text = "got too many barrels", Strikes = 10, Window = 60 },
	BarrelTravel = {
		Channel = "BarrelAntiCheat",
		Text = "got distant barrels too fast",
		Strikes = 15,
		Window = 600,
	},
	BarrelHoneypot = { Channel = "BarrelSuspects", Text = "got the special barrel", Strikes = 1, Window = 60 },
	JuicerFar = {
		Channel = "BarrelAntiCheat",
		Text = "used a juicing bowl from too far away",
		Strikes = 10,
		Window = 200,
	},
	ChestTravel = {
		Channel = "ChestAntiCheat",
		Text = "opened chests faster than the trip allows",
		Strikes = 5,
		Window = 60,
	},
	InvalidAccessory = {
		Channel = "Integrity",
		Text = "tried using an invalid accessory",
		Strikes = 1,
		Window = 60,
	},
	CompassClaimFar = {
		Channel = "CompassAntiCheat",
		Text = "claimed compasses away from the merchant",
		Strikes = 5,
		Window = 60,
	},
	CompassTravel = {
		Channel = "CompassAntiCheat",
		Text = "reached compass treasures faster than the trip allows",
		Strikes = 5,
		Window = 300,
	},
	FishingBadHit = {
		Channel = "FishingAntiCheat",
		Text = "sent a fishing hit the minigame cannot produce",
		Strikes = 3,
		Window = 60,
	},
	PackageTravel = {
		Channel = "PackageAntiCheat",
		Text = "delivered packages faster than the trip allows (auto-package)",
		Strikes = 3,
		Window = 300,
	},
}) :: { [string]: Flag }

--[[
	AuditLog -> channels. Actions are AuditLog.Record's `action`; Commands are the console
	/ staff menu commands behind a "ran" entry, which is posted to EveryCommand as well.
	Entries that match nothing (crew and private server actions of players) stay in the
	in-game log only.
]]
WebhookConfig.Audit = table.freeze({
	Actions = table.freeze({
		ban = "ModActions",
		globalkick = "ModActions",
		unban = "Unbans",
		["beri-reset"] = "Integrity",
		["chefgift-reset"] = "Integrity",
		denied = "StaffCommands",
		shutdown = "StaffCommands",
	}) :: { [string]: string },
	Commands = table.freeze({
		kick = "ModActions",
		slay = "ModActions",
		givefruit = "StaffFruitSpawns",
		setfruit = "StaffFruitSpawns",
		givebox = "StaffItems",
		dropparty = "StaffItems",
		data = "StaffData",
	}) :: { [string]: string },
	EveryCommand = "StaffCommands",
	-- Developer menu actions (DevService, "dev:<name>"): the legacy data / item tools.
	DevActions = "StaffData",
})

-- FruitBoxService: boxes of one rarity opened on this server within Window seconds.
WebhookConfig.BoxBursts = table.freeze({
	Window = 60,
	Thresholds = table.freeze({ Rare = 10, UltraRare = 4 }) :: { [string]: number },
})
-- Fruits whose box opening is reported even without an aura (the legacy Alice Fruit post).
WebhookConfig.NotableBoxFruits = table.freeze({ Alice = true }) :: { [string]: boolean }

-- ServerPolicyService: the legacy "#WealthWarning", posted when a profile loads with both.
WebhookConfig.Wealth = table.freeze({ Beri = 100_000_000, Gems = 10_000 })

return table.freeze(WebhookConfig)
