--!strict
--[[
	Who is staff, what each role may run, and the server policies staff used to tune by
	editing scripts. Server-only: clients never see ids, ranks or policy numbers.

	Roles are ordered: None < Tester < Mod < Admin < Owner. A role includes everything
	below it. The ids are the `Owners` and `Moderators` tables of the legacy GlobalModule,
	kept identical to it. An id may be in both lists: the highest role wins (Permissions).
]]

export type Role = "None" | "Tester" | "Mod" | "Admin" | "Owner"

local AdminConfig = {}

AdminConfig.RoleLevels = table.freeze({
	None = 0,
	Tester = 1,
	Mod = 2,
	Admin = 3,
	Owner = 4,
} :: { [Role]: number })

AdminConfig.Owners = table.freeze({
	451082957, -- leonardoe10
	2261590335, -- chizewe
	630398541, -- yuuki / caio
	106625686, -- uta / ghoul
	4729622082, -- Szortek
	7124931877, -- NoUselessGuns / Nug
	9216136710, -- Sei
})

-- The legacy list existed and was empty.
AdminConfig.Admins = table.freeze({} :: { number })

-- Every legacy moderator had level 5 (the maximum), so levels collapsed into the role.
AdminConfig.Moderators = table.freeze({
	1042971374, -- kiwi
	513583299, -- Crashneitor2D
	9216136710, -- sei
	498827506, -- luanrlf
	2240769876, -- Samcompetitive
	389403845, -- mstrnavalha
	656022601, -- alpha
	2317759923, -- Just
	1214022304, -- erik
	5102955703, -- vterxs
	519500818, -- kin
	2667971788, -- aj
	31634625, -- leo
	486208989, -- Zariel
})

-- Places where every player is a Tester (the legacy test place). Never more than Tester:
-- the unfinished legacy command framework gave everyone there the owner rank.
AdminConfig.TesterPlaceIds = table.freeze({ 100503540842201 })

-- Group-rank roles, highest matching entry wins. The legacy check (rank 7 of this group
-- = Tester) was commented out, so the list ships empty: add { MinRank = 7, Role = "Tester" }.
AdminConfig.Group = table.freeze({
	Id = 312713684,
	Ranks = table.freeze({} :: { { MinRank: number, Role: Role } }),
})

-- Minimum role per command group (Server.Modules.Commands). A group that is not listed
-- here cannot be run.
AdminConfig.CommandGroups = table.freeze({
	Help = "Tester",
	Tester = "Tester",
	Mod = "Mod",
	Admin = "Admin",
	Owner = "Owner",
} :: { [string]: Role })

-- Enum.KeyCode names that open the two menus. They reach a client only in the server's
-- answer to a player who may have that menu (AdminService / DevService GetAccess).
-- Moderator menu: role Mod and above.
AdminConfig.MenuKey = "F3"
-- Developer menu: owners, plus anyone inside Studio or in the development place.
AdminConfig.DevMenuKey = "F4"

-- Menu requests per staff member: { burst, refill per second }.
AdminConfig.CommandRate = table.freeze({ 5, 1 })

AdminConfig.AdminZone = CFrame.new(0, 200005.313, 200)

AdminConfig.Bans = table.freeze({
	-- Legacy bans ({ [userId] = true }); still honoured on join, cleared by unban.
	LegacyStore = "OP-M_BanData2",
	Message = "You are banned from this game.",
})

AdminConfig.Log = table.freeze({
	Capacity = 200,
	JoinLeaveCapacity = 200,
	-- Name of a Secret (Game Settings > Security) holding a webhook URL; "" disables it.
	-- The legacy scripts had six webhook URLs in plain text: they are gone on purpose.
	WebhookSecret = "",
	WebhookFlushSeconds = 10,
})

AdminConfig.Policies = table.freeze({
	-- Non-staff players a server accepts; the extra slots are left for staff.
	MaxNormalPlayers = 28,

	-- The legacy kick for young accounts was commented out: kept, disabled.
	EnforceAccountAge = false,
	MinAccountAgeDays = 30,

	-- A server retires itself after this long, warning once a minute before closing.
	ServerLifetimeSeconds = 144000,
	ShutdownWarningSeconds = 300,

	-- Legacy "BeriDupe" sanity checks, applied when a profile loads.
	Integrity = table.freeze({
		Enabled = false,
		MaxBeri = 1_000_000_000,
		-- Beri above MaxBeri is only believable with more bounty than this.
		BountyThatJustifiesBeri = 500_000_000,
		MaxChefGift = 500_000_000,
	}),
})

return table.freeze(AdminConfig)
