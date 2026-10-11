--!strict
--[[
	Yamato, the gate-opening sword of the legacy developers.

	In the legacy tool script only two hardcoded user ids could swing it, open gates or
	type a destination; everybody else had it unequipped on the spot. The list is kept
	as it was: add the ids of whoever should wield it in this game.

	Destinations are the names typed in the Yamato box (legacy also accepted them in
	chat). They were hardcoded positions of the legacy map, lower-cased on lookup.
]]
return table.freeze({
	AllowedUserIds = table.freeze({
		[2261590335] = true,
		[630398541] = true,
	} :: { [number]: boolean }),

	Locations = table.freeze({
		["sam"] = Vector3.new(-1282, 220, -1304),
		["bigtree"] = Vector3.new(-6028, 402, -8),
		["runner"] = Vector3.new(-6469, 279.007, 4547),
		["cave"] = Vector3.new(-48.5, 218, -889.5),
		["crab"] = Vector3.new(-2, 219, -257),
		["marine"] = Vector3.new(-3137, 526.5, -4091),
		["fishcook"] = Vector3.new(1971, 214, 564.5),
		["vokun"] = Vector3.new(4569, 218, 5002),
		["purple"] = Vector3.new(-5214, 217, -7628),
		["snow 1"] = Vector3.new(-1894.5, 227, 3296),
		["snow 2"] = Vector3.new(6213.071, 539, -1222.651),
		["desert 1"] = Vector3.new(127.4, 217, 4721),
		["desert 2"] = Vector3.new(1078, 243.2, -3334),
		["affinity"] = Vector3.new(117.4, 276, 4946),
		["admin"] = Vector3.new(0, 200005.313, 200),
		-- Legacy key was "ilhaC", which the lower-cased lookup could never match.
		["ilhac"] = Vector3.new(2050, 488.5, -671),
		["disco"] = Vector3.new(1515, 259, 2171),
		["yellow"] = Vector3.new(775, 244, 1218),
		["yuuki"] = Vector3.new(15244.406, 100031.719, -521),
	} :: { [string]: Vector3 }),

	-- Destinations that need a map piece cloned into Workspace.Instances first (kept 15 minutes).
	Islands = table.freeze({
		["yuuki"] = "YuukiIsland",
	} :: { [string]: string }),
	IslandLifetime = 15 * 60,

	-- Everyone this close to the user goes through the gate with it.
	PassengerRadius = 15,
	-- Seconds a passenger takes to sink into the gate before reappearing.
	TravelSeconds = 2,
	-- Gates open this far above the ground point they lead to.
	GateHeight = 7,
	-- Seconds between two gates of the same user (typed destinations).
	Cooldown = 3,
	MaxNameLength = 20,
})
