--!strict
--[[
	Flare fruit - Flame Pillar (charged): a spinning column of fire sent to the aim point.

	Charge: 25 per second held, 4 to 100 (timed on the server).
	With d = defense affinity and k = d * (defense level / cap) * charge / 100:
	- the pillar leaves the RIGHT arm (always: the legacy release message never told the
	  server which hand had punched) and moves to the aim point at 50 studs/s for at
	  most 2 s (100 studs), then stays; it lasts 8 s;
	- it grows linearly for 5 s up to (10, 40, 10) * k;
	- every 0.25 s everyone inside takes charge * 12 * d (no level term, as in the legacy
	  formula), Special, not dodgeable; armament haki at release doubles it and makes it
	  Haki;
	- every one of those ticks also (re)starts "FlareBurn" on them: 125 * (SNIPER level /
	  cap) * d every 0.5 s, for 20 s after the last tick inside. The mix of sniper level
	  and defense affinity is the legacy formula.
	The charging fire and the animations alternate hands, right first: the charge status
	carries the hand ("<Right|Left>|<colors>").

	Rumble / Smelt / Hot / Magma / Plasma owners take no direct damage, and those plus
	Luck / Flare owners no burn tick (DamageModifiers.FlareBurnImmunity, tags "FlareHeat"
	and "FlareBurn").

	Cooldown: the legacy server only had a 0.25 s debounce; the 5 s between two pillars
	came from a wait in the client script. It is enforced here. As in the legacy client
	it cannot be charged while Flame Emperor is.

	KeepThroughStun: a pillar already out keeps burning when its caster is stunned, as
	the legacy part did. A charge cannot start, and a release is dropped, while stunned.

	Legacy problems fixed here:
	- The pillar was a server part resized, moved and rotated by three Heartbeat
	  connections (the movement one was never disconnected if the part was destroyed
	  first) plus a Script looping GetPartBoundsInBox over the map.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local CHARGE_STATUS = "FlarePillarCharging"
local SUN_CHARGE_STATUS = "FlareSunCharging"
local EFFECT = "FlarePillar"
local DAMAGE_TAG = "FlareHeat"
local BURN = "FlareBurn"
local STUN_STATUS = "Stunned"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local COOLDOWN = 5

local DAMAGE_PER_CHARGE = 12
local HAKI_MULTIPLIER = 2
local BURN_DAMAGE = 125
local BURN_INTERVAL = 0.5
local BURN_TICKS = 40

local FULL_SIZE = Vector3.new(10, 40, 10)
local GROW_TIME = 5
local SPEED = 50
local TRAVEL_TIME = 2
local LIFETIME = 8
local TICK_INTERVAL = 0.25
-- The arm the pillar leaves from, whichever hand is punching.
local ORIGIN_ARM = "Right Arm"

type Pillar = {
	Start: number,
	Origin: Vector3,
	Direction: Vector3,
	Distance: number,
	Rotation: CFrame,
	Size: Vector3,
	Damage: number,
	Burn: number,
	Trait: CombatTypes.DamageTrait,
}

local FlamePillar = Ability.extend()

FlamePillar.KeepThroughStun = true

local function burn(self: any, pillar: Pillar, epoch: number)
	if (self.Epoch or 0) ~= epoch or self.Entity.Dead then
		return
	end

	local elapsed = os.clock() - pillar.Start
	if elapsed >= LIFETIME then
		return
	end

	local size = pillar.Size * math.min(elapsed / GROW_TIME, 1)
	local position = pillar.Origin + pillar.Direction * math.min(elapsed * SPEED, pillar.Distance)
	for _, target in Hitbox.Box(pillar.Rotation + position, size, self.Entity) do
		self:Damage(target, pillar.Damage, pillar.Trait, DAMAGE_TAG, false)
		-- A refresh keeps the running tick (StatusService), so this only extends the burn.
		self.Services.Status:ApplyDot(target, BURN, {
			Source = self.Entity,
			Damage = pillar.Burn,
			Interval = BURN_INTERVAL,
			Ticks = BURN_TICKS,
			Trait = "Special",
		})
	end

	task.delay(TICK_INTERVAL, burn, self, pillar, epoch)
end

function FlamePillar:CanBegin(): boolean
	local entity = self.Entity
	return os.clock() >= (self.ReadyAt or 0)
		and not entity:HasStatus(SUN_CHARGE_STATUS)
		and not entity:HasStatus(STUN_STATUS)
end

function FlamePillar:OnBegin()
	local entity = self.Entity
	-- Press and release ground the flights for 3 s: AbilityService (Modules.FlightLock).

	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	local hand = if self.UseLeft then "Left" else "Right"
	entity:SetStatus(CHARGE_STATUS, `{hand}|{self:GetColorString()}`, nil, true)
end

function FlamePillar:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	self.Entity:ClearStatus(CHARGE_STATUS)
	if not charge or self.Entity:HasStatus(STUN_STATUS) then
		return
	end
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)
	local left = self.UseLeft == true
	self.UseLeft = not left

	local entity = self.Entity
	local affinity = self:GetAffinity("Defense")
	local scale = affinity * self:GetLevelScale("Defense") * charge / CHARGE_MAX
	local haki = self.Services.Haki:IsArmamentActive(entity)

	local arm = entity.Model:FindFirstChild(ORIGIN_ARM)
	local origin: Vector3 = if arm and arm:IsA("BasePart") then arm.Position else entity.Root.Position
	local offset = input.AimPosition - origin
	local distance = math.min(offset.Magnitude, SPEED * TRAVEL_TIME)
	local direction = if offset.Magnitude > 0.05 then offset.Unit else Vector3.zero

	local pillar: Pillar = {
		Start = os.clock(),
		Origin = origin,
		Direction = direction,
		Distance = distance,
		Rotation = entity.Root.CFrame.Rotation,
		Size = FULL_SIZE * scale,
		Damage = charge * DAMAGE_PER_CHARGE * affinity * (if haki then HAKI_MULTIPLIER else 1),
		Burn = BURN_DAMAGE * self:GetLevelScale("Sniper") * affinity,
		Trait = if haki then "Haki" else "Special",
	}

	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		Distance = distance,
		Speed = SPEED,
		Size = pillar.Size,
		GrowTime = GROW_TIME,
		Lifetime = LIFETIME,
		Rotation = pillar.Rotation,
		-- The legacy server scaled the fire particles with the defense affinity.
		ParticleScale = affinity,
		Haki = haki,
		Hand = if left then "Left" else "Right",
	})

	task.delay(TICK_INTERVAL, burn, self, pillar, self.Epoch or 0)
end

function FlamePillar:OnInterrupt()
	self.ChargeStart = nil
	self.Entity:ClearStatus(CHARGE_STATUS)
	-- Pillars already out stop burning.
	self.Epoch = (self.Epoch or 0) + 1
end

return FlamePillar
