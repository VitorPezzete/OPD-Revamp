--!strict
--[[
	Paw fruit - Pressure Bubble (charged): a paw of compressed air thrown from the right
	hand that bursts where it lands and blows everyone away.

	With f = (sniper level / cap) * sniper affinity / 2 * clamp(seconds held / 5, 0.1, 1):
	- the paw is 4 f x 4 f x 2.666 f studs and leaves from 2 studs in front of the right
	  arm towards the aim point at 200 studs/s, for clamp(5 f, 1, 5) seconds at most; it
	  stops at the first thing it touches, wall or character;
	- where it stops, everyone within 80 f studs (paw width * 20) takes 3500 f "Melee",
	  not dodgeable, and is carried away from the burst at 250 f studs/s for 0.25 s (the
	  source BodyVelocity: unlimited force, P 10000);
	- armament haki at the moment the charge STARTED doubles the damage (7000 f) and makes
	  it "Haki", as in the source;
	- 1 s cooldown after the release. Nothing else of the fruit can be used while it charges.

	Source problems fixed here:
	- The release carried the mouse CFrame and was trusted as it came; the charge start
	  time was one script variable. The aim is the validated point of the release now and
	  the charge is timed by the server.
	- The paw was a CFrame walked on Heartbeat with a GetPartBoundsInBox every frame, and
	  the burst a GetPartBoundsInRadius over the whole map (160 studs wide at full power).
	  It is a server-simulated Projectile and a Hitbox query over the tracked characters.

	The flying paw and the burst are drawn by the clients (Effects.OneShot.PawPressureBubble);
	the paw in the hand while charging by Effects.Status.PawBubbleCharging.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Paw = require(script.Parent._Shared)

local NAME = "Pressure Bubble"
local SKILL = "Sniper"
local CHARGE_STATUS = "PawBubbleCharging"
local EFFECT = "PawPressureBubble"

local MAX_CHARGE = 5
local COOLDOWN = 1
local MAX_DAMAGE = 7000
-- Without armament haki the paw deals half.
local PLAIN_DAMAGE_SHARE = 0.5
local MAX_SPEED = 200
-- Width (and height) of the flying paw per unit of factor: (2 * factor) * 2.
local PAW_WIDTH = 4
local FLIGHT_SECONDS = 5
local MIN_FLIGHT_SECONDS = 1
-- Burst radius: paw width * 20.
local BURST_RADIUS = PAW_WIDTH * 20
local KNOCKBACK_SPEED = 250
local KNOCKBACK_SECONDS = 0.25
local KNOCKBACK_FORCE = Vector3.new(math.huge, math.huge, math.huge)
local KNOCKBACK_POWER = 10000
-- The paw starts this far in front of the right arm (the arm's own -Z).
local ARM_OFFSET = CFrame.new(0, 0, -2)
-- Where the arm is when the model has none: beside the root, as the arm hangs.
local ARM_FALLBACK = CFrame.new(1.5, 0, 0)

local PressureBubble = Ability.extend()
-- The source dealt this damage without a style: ResistAbilities does not apply.
PressureBubble.DamageStyle = "Plain"

local function burst(self: any, position: Vector3, factor: number, damage: number, trait: CombatTypes.DamageTrait)
	local entity = self.Entity
	if entity.Dead then
		return
	end
	for _, target in Hitbox.Sphere(position, BURST_RADIUS * factor, entity) do
		self:Damage(target, damage, trait, nil, false)

		local away = target.Root.Position - position
		if away.Magnitude > 1e-3 then
			self:Impulse(target, away.Unit * (KNOCKBACK_SPEED * factor), KNOCKBACK_SECONDS, KNOCKBACK_FORCE, KNOCKBACK_POWER)
		end
	end
end

function PressureBubble:CanBegin(): boolean
	return not self.ChargeStart and os.clock() >= (self.ReadyAt or 0) and not Paw.IsBusy(self.Entity)
end

function PressureBubble:OnBegin()
	local entity = self.Entity
	self:BeginCharge(MAX_CHARGE)
	Paw.SetBusy(entity, NAME)

	-- Read once, here: the paw keeps the colour and the damage type it was charged with.
	local haki: boolean = self.Services.Haki:IsArmamentActive(entity)
	self.Haki = haki
	-- "<factor>|<colors>|<1 with haki>": the paw in the hand is drawn at the uncharged factor.
	entity:SetStatus(
		CHARGE_STATUS,
		string.format("%.4f|%s|%d", Paw.Factor(self, SKILL), self:GetColorString(), if haki then 1 else 0),
		nil,
		true
	)
end

function PressureBubble:OnEnd(input: Ability.AbilityInput)
	local started: number? = self.ChargeStart
	if not self:EndCharge(1, 0, MAX_CHARGE) or not started then
		return
	end

	local entity = self.Entity
	entity:ClearStatus(CHARGE_STATUS)
	Paw.ClearBusy(entity, NAME)
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local factor = Paw.Factor(self, SKILL) * Paw.ChargeFraction(started, MAX_CHARGE)
	if factor <= 0 then
		return
	end
	local haki: boolean = self.Haki == true
	self.Haki = false
	local damage = MAX_DAMAGE * factor * (if haki then 1 else PLAIN_DAMAGE_SHARE)
	local trait: CombatTypes.DamageTrait = if haki then "Haki" else "Melee"

	local arm = entity.Model:FindFirstChild("Right Arm")
	local armCFrame: CFrame = if arm and arm:IsA("BasePart") then arm.CFrame else entity.Root.CFrame * ARM_FALLBACK
	local origin = (armCFrame * ARM_OFFSET).Position
	local speed = MAX_SPEED
	local range = speed * math.clamp(FLIGHT_SECONDS * factor, MIN_FLIGHT_SECONDS, FLIGHT_SECONDS)
	local direction = Projectile.Lead(entity, origin, Paw.Direction(entity, origin, input.AimPosition), speed, range)

	local radius = PAW_WIDTH * factor / 2

	local id = Paw.NextId()
	self:PlayEffect(EFFECT, origin, {
		Phase = "Fly",
		Id = id,
		Direction = direction,
		Speed = speed,
		Range = range,
		-- The paw that flies is the one that was in the hand: it keeps the size of the
		-- uncharged factor. The charged one sizes the burst.
		Base = Paw.Factor(self, SKILL),
		Factor = factor,
		Haki = haki,
	}, Paw.EFFECT_RADIUS + range)

	-- `position`: the middle of the paw where it stopped.
	local function finish(position: Vector3)
		self:PlayEffect(EFFECT, position, {
			Phase = "Burst",
			Id = id,
			Direction = direction,
			Factor = factor,
			Haki = haki,
			-- Wide enough to reach whoever was sent the paw from where it started.
		}, Paw.EFFECT_RADIUS + math.max((position - origin).Magnitude, BURST_RADIUS * factor))
		burst(self, position, factor, damage, trait)
	end

	-- Thrown against a wall: it bursts there instead of flying through it.
	local blocked = Paw.Blocked(self, origin, radius)
	if blocked then
		finish(blocked)
		return
	end

	Projectile.Fire({
		Origin = origin,
		Direction = direction,
		Speed = speed,
		MaxDistance = range,
		Radius = radius,
		Owner = entity,
		-- The source paw burst on whatever was already inside it when it left the hand.
		HitOverlapping = true,
		-- The burst below hits everyone around, the character that stopped the paw included.
		OnHit = function() end,
		OnEnd = function(position: Vector3)
			finish(Paw.Centre(origin, direction, range, radius, position))
		end,
	})
end

function PressureBubble:OnInterrupt()
	self.ChargeStart = nil
	self.Haki = false
	self.Entity:ClearStatus(CHARGE_STATUS)
	Paw.ClearBusy(self.Entity, NAME)
end

return PressureBubble
