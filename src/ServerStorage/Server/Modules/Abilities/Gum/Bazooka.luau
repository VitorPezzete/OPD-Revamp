--!strict
--[[
	Gum fruit - Bazooka (Jet Bazooka in 2nd Gear): both arms stretch towards the aim
	point at once and blow away what they hit.

	Each arm is a full stretch punch (see _Shared), so a target in front of both takes
	the damage twice, as in the legacy game.

	Knockback on hit, with m = melee affinity and s = melee level / cap:
	speed = base * m^2 * s studs per second, away from the user with a slight lift
	(direction (x, 0.25, z) normalised); base 50, or 300 for Jet Bazooka.

	                 punch time   cooldown   melee level
	Bazooka            0.25 s      0.25 s        50
	Jet Bazooka        0.10 s      0.25 s       150

	As for Pistol, the user is pinned and Gatling is held back until the arms are back
	(3.5 punch times + 0.1 s).

	The legacy knockback was a BodyVelocity living 0.18 s inside the victim (MaxForce
	1e5 * its mass on each axis, P 1250); the same held push is applied (_Shared).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

local ROOT = "GumBazooka"
local JET_LEVEL = 150

local PUNCH_TIME = 0.25
local JET_PUNCH_TIME = 0.1
local COOLDOWN = 0.25
local PUSH = 50
local JET_PUSH = 300

local Bazooka = Ability.extend()

function Bazooka:CanBegin(): boolean
	local entity = self.Entity
	return not Shared.IsBusy(entity) and not entity.Humanoid.Sit and Shared.MeetsGearLevel(self, JET_LEVEL)
end

function Bazooka:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local jet = Shared.IsSecondGear(entity)
	local punchTime = if jet then JET_PUNCH_TIME else PUNCH_TIME
	local affinity = self:GetAffinity("Melee")
	local push = (if jet then JET_PUSH else PUSH) * affinity * affinity * self:GetLevelScale("Melee")

	Shared.MarkMove(entity)
	Shared.SetBusy(entity, COOLDOWN)
	self:StartCooldown(COOLDOWN)
	local busyTime = punchTime * 3.5 + 0.1
	Shared.Hold(self, ROOT, busyTime)
	Shared.SetArmsOut(entity, busyTime)

	for _, hand in { "Left", "Right" } do
		Shared.Punch(self, input.AimPosition, {
			Hand = hand,
			Time = punchTime,
			Hold = punchTime + 0.1,
			Push = push,
			Face = true,
		})
	end
end

function Bazooka:OnInterrupt()
	Shared.Release(self, ROOT)
end

return Bazooka
