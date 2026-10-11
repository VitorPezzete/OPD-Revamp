--!strict
--[[
	The candy raid boss (legacy ServerStorage.Boss.Normal.CandyBoss, AI_Global with the
	"Candy Fruit" flag on). All of its behaviour is the shared engine, Bosses/_Global;
	this module only says which fruit it fights with.

	What the Candy fruit gives it there:
	- the first time it is hurt its body hardens into spiked candy and a blade grows on
	  each arm, for the rest of the fight (touching it hurts once a second);
	- target within 12 studs: arm blade swings, about every 0.6 s;
	- within 15 studs (before the blades are out): a pool of syrup around it, 9.5 s cooldown;
	- 20 to 120 studs: a wide syrup wave, 8.5 s cooldown;
	- 25 to 120 studs: 1.5 s standing still, then a giant jawbreaker, 9 s cooldown.
	Every candy hit but the swings sticks the victim in syrup for 3 s.
]]
local ServerStorage = game:GetService("ServerStorage")

local BossTypes = require(ServerStorage.Server.Types.BossTypes)
local Global = require(script.Parent._Global)

-- Walk speed of the legacy model's Humanoid; its Config.WalkSpeed (85, the value in
-- EnemyConfig) was only applied by status scripts after a stun ended.
local WALK_SPEED = 16

local CandyBoss = {}

function CandyBoss.new(handle: BossTypes.BossHandle)
	return Global.new(handle, { Fruits = { "Candy" }, WalkSpeed = WALK_SPEED })
end

return CandyBoss
