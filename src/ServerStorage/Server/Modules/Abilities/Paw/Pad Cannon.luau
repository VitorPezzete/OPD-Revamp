--!strict
--[[
	Paw fruit - Pad Cannon (charged): a salvo of paws fired where the camera looks.

	With f = (sniper level / cap) * sniper affinity / 2 * clamp(seconds held / 5, 0.1, 1):
	- on release ceil(10 f) paws leave 0.125 s apart;
	- each paw is 6 f x 6 f x 4 f studs, starts 3.5 studs in front of the root, up to 2
	  studs off to the side and up or down (random), and flies at 350 f studs/s for 5 s.
	  It goes through walls and stops at the first character it touches;
	- that character takes 500 f "Melee"; with armament haki at the moment the paw leaves,
	  1000 f "Haki". Dodgeable;
	- 5 s cooldown once the last paw has left. The other powers of the fruit are free
	  again as soon as the key is released.

	Aim. The source asked the client for its mouse before every paw (InvokeClient: a client
	that never answers hangs the server thread for good) and used the LOOK VECTOR of the
	mouse CFrame, i.e. the direction of the camera ray, not the direction from the paw to
	the point under the cursor: the paws fly parallel to the line of sight. The server
	never asks now. While the power is charging and firing, the owner's client streams its
	aim as the ability's secondary input (Effects.Status.PawCannonCharging / PawCannonSalvo)
	as a point along that ray measured from its root, so root -> point is the camera
	direction the source used. Until the first of those arrives the direction is the one
	to the validated aim point of the release.

	Source problems fixed here:
	- Each paw was an unanchored server part pushed by a BodyVelocity, with a Heartbeat
	  GetPartsInPart per paw. They are server-simulated Projectiles; every client draws its
	  own copy (Effects.OneShot.PawPadCannon).
	- The number of paws and their power came from one script-level charge variable.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Paw = require(script.Parent._Shared)

local NAME = "Pad Cannon"
local SKILL = "Sniper"
local CHARGE_STATUS = "PawCannonCharging"
local SALVO_STATUS = "PawCannonSalvo"
local EFFECT = "PawPadCannon"

local MAX_CHARGE = 5
local COOLDOWN = 5
local MAX_PAWS = 10
local SHOT_INTERVAL = 0.125
local MAX_DAMAGE = 1000
-- Without armament haki a paw deals half.
local PLAIN_DAMAGE_SHARE = 0.5
local MAX_SPEED = 350
local LIFETIME = 5
-- Width (and height) of a paw per unit of factor: (2 * 3) * factor.
local PAW_WIDTH = 6
-- Start of a paw in the root's space: X and Y are random within +-SPREAD, in 1/50 steps.
local FORWARD_OFFSET = -3.5
local SPREAD_STEPS = 100
local SPREAD_DIVISOR = 50

local random = Random.new()

local PadCannon = Ability.extend()
-- The source dealt this damage without a style: ResistAbilities does not apply.
PadCannon.DamageStyle = "Plain"

local function firePaw(self: any, factor: number)
	local entity = self.Entity
	local root = entity.Root
	local haki: boolean = self.Services.Haki:IsArmamentActive(entity)
	local damage = MAX_DAMAGE * factor * (if haki then 1 else PLAIN_DAMAGE_SHARE)
	local trait: CombatTypes.DamageTrait = if haki then "Haki" else "Melee"

	local origin = (root.CFrame * CFrame.new(
		random:NextInteger(-SPREAD_STEPS, SPREAD_STEPS) / SPREAD_DIVISOR,
		random:NextInteger(-SPREAD_STEPS, SPREAD_STEPS) / SPREAD_DIVISOR,
		FORWARD_OFFSET
	)).Position
	local speed = MAX_SPEED * factor
	local range = speed * LIFETIME
	-- Measured from the root, not from the paw: see "Aim" in the header.
	local direction = Paw.Direction(entity, root.Position, self.Aim or (root.Position + root.CFrame.LookVector))
	direction = Projectile.Lead(entity, origin, direction, speed, range)

	local id = Paw.NextId()
	self:PlayEffect(EFFECT, origin, {
		Phase = "Fly",
		Id = id,
		Direction = direction,
		Speed = speed,
		Range = range,
		Factor = factor,
		Haki = haki,
	}, Paw.EFFECT_RADIUS + range)

	Projectile.Fire({
		Origin = origin,
		Direction = direction,
		Speed = speed,
		MaxDistance = range,
		Radius = PAW_WIDTH * factor / 2,
		Owner = entity,
		-- The source paw only looked for characters: walls never stopped it.
		IgnoreWorld = true,
		HitOverlapping = true,
		OnHit = function(target)
			self:Damage(target, damage, trait, nil, true)
		end,
		-- A hit or the end of its 5 s: the source played the impact in both cases.
		OnEnd = function(stopped: Vector3)
			-- The source played it where the paw was (its middle), not where it touched.
			local position = Paw.Centre(origin, direction, range, PAW_WIDTH * factor / 2, stopped)
			-- Wide enough to reach whoever was sent the paw from where it started.
			self:PlayEffect(
				EFFECT,
				position,
				{ Phase = "Impact", Id = id, Factor = factor, Haki = haki },
				Paw.EFFECT_RADIUS + (position - origin).Magnitude
			)
		end,
	})
end

function PadCannon:CanBegin(): boolean
	return not self.ChargeStart
		and not self.Active
		and os.clock() >= (self.ReadyAt or 0)
		and not Paw.IsBusy(self.Entity)
end

function PadCannon:OnBegin()
	local entity = self.Entity
	local context = self.Context
	self:BeginCharge(MAX_CHARGE)
	Paw.SetBusy(entity, NAME)
	-- Active from the press: the aim stream (OnAction) is only delivered to an active ability.
	self.Active = true
	self.Aim = nil
	-- "<colors>|<fruit slot>|<ability slot>": the orb in front of the chest; the slots are
	-- where the owner's client sends its aim.
	entity:SetStatus(
		CHARGE_STATUS,
		`{self:GetColorString()}|{context.FruitSlot}|{context.Definition.Slot}`,
		nil,
		true
	)
end

function PadCannon:OnEnd(input: Ability.AbilityInput)
	local started: number? = self.ChargeStart
	if not self:EndCharge(1, 0, MAX_CHARGE) or not started then
		return
	end

	local entity = self.Entity
	local context = self.Context
	entity:ClearStatus(CHARGE_STATUS)
	Paw.ClearBusy(entity, NAME)

	local factor = Paw.Factor(self, SKILL) * Paw.ChargeFraction(started, MAX_CHARGE)
	local paws = math.ceil(MAX_PAWS * factor)
	if factor <= 0 or paws < 1 then
		self.Active = false
		return
	end
	local window = paws * SHOT_INTERVAL
	self.ReadyAt = os.clock() + window + COOLDOWN
	self:StartCooldown(window + COOLDOWN)

	if not self.Aim then
		self.Aim = input.AimPosition
	end
	self.Run = (self.Run or 0) + 1
	local run = self.Run
	-- "<fruit slot>|<ability slot>": the owner's client keeps streaming its aim.
	entity:SetStatus(SALVO_STATUS, `{context.FruitSlot}|{context.Definition.Slot}`, nil, true)

	local function fire()
		if self.Run == run and not entity.Dead then
			firePaw(self, factor)
		end
	end
	fire()
	for shot = 1, paws - 1 do
		task.delay(shot * SHOT_INTERVAL, fire)
	end
	task.delay(window, function()
		if self.Run == run then
			self.Active = false
			entity:ClearStatus(SALVO_STATUS)
		end
	end)
end

-- The aim of the paws still to leave, streamed by the owner's client.
function PadCannon:OnAction(input: Ability.AbilityInput)
	self.Aim = input.AimPosition
end

function PadCannon:OnInterrupt()
	self.ChargeStart = nil
	self.Active = false
	-- Paws that have not left yet are dropped; those in flight go on.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(CHARGE_STATUS)
	self.Entity:ClearStatus(SALVO_STATUS)
	Paw.ClearBusy(self.Entity, NAME)
end

return PadCannon
