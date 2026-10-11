--!strict
--[[
	Bomb fruit - Bomb Punch (charged): the fist detonates towards the aim point.

	Charge: 25 per second held, 4 to 100 (timed on the server).
	With m = melee affinity, s = melee level / cap, c = charge / 100:
	- blast diameter = 200 * m * s * c, centred a quarter of a diameter from the punching
	  hand towards the aim point (so it reaches from the fist outwards). A character is
	  hit when its root is inside; the ball drawn is half that wide (see _Shared);
	- damage = 1000 * m * s * c, Special, not dodgeable; doubled with armament haki
	  (the legacy damage stayed Special with haki, only the amount changed).

	Legacy problems fixed here:
	- The charge was `time() - Charge.Value` on a value the release reset but an
	  interrupted charge did not, and the Charging flags could stay set after a death.
	- The hand ("Right" / "Left") came from the client; the server keeps the turn now
	  (_Shared: hands alternate, right first, shared with Bomb Wave).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

local CHARGE_RATE = 25
local GROW_SECONDS = 3
local DIAMETER = 200
local DAMAGE = 1000

local BombPunch = Ability.extend()

function BombPunch:CanBegin(): boolean
	return not Shared.IsCharging(self.Entity)
end

function BombPunch:OnBegin()
	Shared.BeginCharge(self, "Punch", "Melee", GROW_SECONDS, Shared.ChargeMax / CHARGE_RATE)
end

function BombPunch:OnEnd(input: Ability.AbilityInput)
	local charge = Shared.EndCharge(self, CHARGE_RATE)
	if not charge then
		return
	end

	local entity = self.Entity
	local hand = Shared.GetHand(entity)
	Shared.SwapHand(entity)
	local power =self:GetAffinity("Melee") * self:GetLevelScale("Melee") * (charge / Shared.ChargeMax)
	local diameter = DIAMETER * power
	local damage = DAMAGE * power
	local haki = self.Services.Haki:IsArmamentActive(entity)
	if haki then
		damage *= Shared.HakiMultiplier
	end

	local direction = Shared.AimDirection(entity, input.AimPosition)
	local center = Shared.LimbPosition(entity, hand .. " Arm") + direction * (diameter / 4)
	Shared.Explode(self, center, diameter / 2, damage, haki, 0, "Power5", nil, {
		Scale = diameter,
		PartSize = Shared.BallPartSize,
		Release = "Punch",
		Hand = hand,
		Aim = input.AimPosition,
	})
end

function BombPunch:OnInterrupt()
	Shared.CancelCharge(self)
end

return BombPunch
