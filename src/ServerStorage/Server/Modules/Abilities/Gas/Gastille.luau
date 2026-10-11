--!strict
--[[
	Gas fruit - Gastille (charged): a beam of ignited gas from the mouth that explodes
	where it lands.

	Hold to charge: 25 charge per second, from 4 up to 100 (4s for a full charge). The
	caster cannot walk while charging. On release, with
		s = (sniper level / cap) * sniper affinity * charge / 100
	- The beam leaves the head towards the aim point and stops at the first thing it
	  meets, 200 studs at most.
	- Everyone within a sphere of diameter 125 * s around that point takes 1000 * s
	  "Special" damage (not dodgeable), plus up to as much again the lower their health:
	  bonus = clamp(damage * 5/3 * (1 - health / max health), 0, damage).
	  Armament haki doubles the base damage and makes it "Haki".
	- 0.75s after a release before the next charge. Charging and releasing both ground
	  the gas form for 3s.

	Clients draw the growing ball in front of the face while charging
	(Effects.Status.GasCharging, status value "<size scale * 100>|<colors>") and the beam
	and explosion on release (Effects.OneShot.GasGastille).

	Legacy problems fixed here:
	- Charging was a separate remote that checked neither the level requirement nor the
	  cooldown, and the charge time lived in a NumberValue; the client sent its own
	  charge along. The hold is timed here by BeginCharge / EndCharge.
	- A "StopCharging" with no charge running fired a minimum-charge beam for free.
	- The no-walk lock was "time() + 2000" and was only lifted by a release: dying or
	  being sealed mid-charge left the next character unable to walk.
	- Beam and sphere were anchored server parts; the beam was walked in 100 raycasts of
	  2 studs. It is one raycast, and the explosion is one hitbox query, kept to the
	  legacy rule: the root must be within the sphere.
	- The hit test looped over every child of Workspace and of Workspace.Enemies.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

local EFFECT = "GasGastille"
local CHARGE_STATUS = "GasCharging"
local ROOT_NAME = "GasGastille"
local HAKI_STATUS = "Haki"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local RECAST_DELAY = 0.75

local BEAM_RANGE = 200
local MAX_DIAMETER = 125
local MAX_DAMAGE = 1000
local HAKI_MULTIPLIER = 2
local LOW_HEALTH_BONUS = 5 / 3
-- The beam starts this far in front of the head.
local MOUTH_DISTANCE = 1

local Gastille = Ability.extend()

function Gastille:CanBegin(): boolean
	return os.clock() - (self.LastRelease or 0) >= RECAST_DELAY
end

function Gastille:OnBegin()
	local entity = self.Entity

	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	entity:SetRooted(ROOT_NAME, true)

	-- The ball's size followed the melee stats in the legacy script (visual only).
	local ballScale = math.round(self:GetLevelScale("Melee") * self:GetAffinity("Melee") * 100)
	entity:SetStatus(CHARGE_STATUS, `{ballScale}|{self:GetColorString()}`, nil, true)
end

function Gastille:OnEnd(input)
	local entity = self.Entity
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	entity:SetRooted(ROOT_NAME, false)
	entity:ClearStatus(CHARGE_STATUS)
	if not charge then
		return
	end
	self.LastRelease = os.clock()
	self:StartCooldown(RECAST_DELAY)

	local head = entity.Model:FindFirstChild("Head")
	local headCFrame = if head and head:IsA("BasePart") then head.CFrame else entity.Root.CFrame
	local origin = headCFrame.Position + headCFrame.LookVector * MOUTH_DISTANCE

	local direction = input.AimPosition - origin
	if direction.Magnitude < 1e-3 then
		direction = headCFrame.LookVector
	end
	direction = direction.Unit

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	local result = Workspace:Raycast(origin, direction * BEAM_RANGE, params)
	local hitPosition = if result then result.Position else origin + direction * BEAM_RANGE

	local scale = self:GetLevelScale("Sniper") * self:GetAffinity("Sniper") * charge / 100
	local diameter = MAX_DIAMETER * scale
	local haki = entity:HasStatus(HAKI_STATUS)
	local damage = MAX_DAMAGE * scale * (if haki then HAKI_MULTIPLIER else 1)

	for _, target in Hitbox.Sphere(hitPosition, diameter / 2, entity) do
		-- Hitbox pads its radius with the body; the legacy test was on the root itself.
		if (target.Root.Position - hitPosition).Magnitude > diameter / 2 then
			continue
		end
		local bonus = math.clamp(damage * LOW_HEALTH_BONUS * (1 - target:GetHealthRatio()), 0, damage)
		self:Damage(target, damage + bonus, if haki then "Haki" else "Special", EFFECT, false)
	end

	self:PlayEffect(EFFECT, origin, {
		Target = hitPosition,
		Diameter = diameter,
		Haki = haki,
	})
end

function Gastille:OnInterrupt()
	self.ChargeStart = nil
	self.Entity:SetRooted(ROOT_NAME, false)
	self.Entity:ClearStatus(CHARGE_STATUS)
end

return Gastille
