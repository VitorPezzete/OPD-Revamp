--!strict
--[[
	The sand raid boss (legacy ServerStorage.Boss.Normal.SandBoss, AI_Global with the
	"Sand Fruit" flag on). All of its behaviour is the shared engine, Bosses/_Global;
	this module only says which fruit it fights with.

	What the Sand fruit gives it there:
	- target more than 5 studs above it, or further than 15 studs: a spike bursts out
	  where the target stands, with no warning, 5 s cooldown;
	- within 15 studs: seven blades in a line, each longer than the last, which cut and
	  leave a bleed, 7 s cooldown;
	- within 40 studs: a tornado that drifts at the target and ropes whoever it reaches
	  for 3 s (it deals no damage), 16 s cooldown.
]]
local ServerStorage = game:GetService("ServerStorage")

local BossTypes = require(ServerStorage.Server.Types.BossTypes)
local Global = require(script.Parent._Global)

-- Walk speed of the legacy model's Humanoid; its Config.WalkSpeed (85, the value in
-- EnemyConfig) was only applied by status scripts after a stun ended.
local WALK_SPEED = 16

local SandBoss = {}

function SandBoss.new(handle: BossTypes.BossHandle)
	return Global.new(handle, { Fruits = { "Sand" }, WalkSpeed = WALK_SPEED })
end

return SandBoss
