--!strict
--[[
	Flare fruit - Fire Wave: a ring of fire bursts out of the caster.

	The ring expands to 50 studs in 0.5 s (sine ease-out) and stays there until 1.5 s.
	With k = defense affinity * (defense level / cap), everyone it touches takes, once:
	- 1000 * k damage, Special, not dodgeable (Haki with armament haki at cast time; the
	  legacy code did NOT double this one);
	- "FlareBurn": 125 * k every 0.5 s for 20 s, heat-proof or not.
	3 s cooldown.

	ONCE PER VICTIM, FOR GOOD (HIT_ONCE_PER_LIFE): in the legacy script the "already hit"
	table was the script's debounce table, keyed by character and never cleared, so a
	wave only ever touched a character that no earlier wave of this caster had touched:
	one hit (and one burn) per victim until the victim or the caster respawned. That is
	what players of the legacy game had, so it is reproduced; set the constant to false
	for a wave that hits everyone every cast.

	Rumble / Smelt / Hot / Magma / Plasma owners take no direct damage, and those plus
	Luck / Flare owners no burn tick (DamageModifiers.FlareBurnImmunity, tags "FlareHeat"
	and "FlareBurn").

	Hit test: while the ring expands, everyone inside its current radius has been swept
	by it; once it stands still only those within RING_THICKNESS of it are touched. The
	16 legacy wall parts are 25 wide, 10 high and 10 deep, centred on the caster's root
	height: RING_THICKNESS and HALF_HEIGHT are half their depth and height.

	KeepThroughStun: a ring already out keeps burning when its caster is stunned, as the
	legacy parts did. It cannot be cast while stunned.

	Legacy problems fixed here:
	- 16 server parts with a Touched connection each, tweened by the server.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

local EFFECT = "FlareWave"
local DAMAGE_TAG = "FlareHeat"
local BURN = "FlareBurn"
local STUN_STATUS = "Stunned"

local DAMAGE = 1000
local BURN_DAMAGE = 125
local BURN_INTERVAL = 0.5
local BURN_TICKS = 40

local RADIUS = 50
local EXPAND_TIME = 0.5
local LIFETIME = 1.5
local TICK_INTERVAL = 0.1
local RING_THICKNESS = 5
local HALF_HEIGHT = 5
-- See the header: a character is touched by this caster's waves once in its life.
local HIT_ONCE_PER_LIFE = false

type Wave = {
	Start: number,
	Center: Vector3,
	Damage: number,
	Burn: number,
	Trait: CombatTypes.DamageTrait,
	Hit: { [CharacterEntity]: boolean },
}

local FireWave = Ability.extend()

FireWave.Debounce = 3
FireWave.KeepThroughStun = true

local function sweep(self: any, wave: Wave, epoch: number)
	if (self.Epoch or 0) ~= epoch or self.Entity.Dead then
		return
	end

	local elapsed = os.clock() - wave.Start
	if elapsed > LIFETIME then
		return
	end

	local expanding = elapsed < EXPAND_TIME
	local radius = RADIUS * math.sin(math.min(elapsed / EXPAND_TIME, 1) * math.pi / 2)
	for _, target in Hitbox.Cylinder(wave.Center, radius + RING_THICKNESS, HALF_HEIGHT, self.Entity) do
		if not wave.Hit[target] and not (HIT_ONCE_PER_LIFE and self.EverHit and self.EverHit[target]) then
			local offset = target.Root.Position - wave.Center
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if expanding or flat >= radius - RING_THICKNESS then
				wave.Hit[target] = true
				if HIT_ONCE_PER_LIFE then
					-- Weak keys: an entity that is gone (death, leaving) is forgotten.
					self.EverHit = self.EverHit or setmetatable({}, { __mode = "k" })
					self.EverHit[target] = true
				end
				self:Damage(target, wave.Damage, wave.Trait, DAMAGE_TAG, false)
				self.Services.Status:ApplyDot(target, BURN, {
					Source = self.Entity,
					Damage = wave.Burn,
					Interval = BURN_INTERVAL,
					Ticks = BURN_TICKS,
					Trait = "Special",
				})
			end
		end
	end

	task.delay(TICK_INTERVAL, sweep, self, wave, epoch)
end

function FireWave:CanBegin(): boolean
	return not self.Entity:HasStatus(STUN_STATUS)
end

function FireWave:OnBegin()
	local entity = self.Entity
	-- Pressing the key grounds the flights for 3 s: AbilityService (Modules.FlightLock).

	local scale = self:GetAffinity("Defense") * self:GetLevelScale("Defense")
	local haki = self.Services.Haki:IsArmamentActive(entity)
	local wave: Wave = {
		Start = os.clock(),
		Center = entity.Root.Position,
		Damage = DAMAGE * scale,
		Burn = BURN_DAMAGE * scale,
		Trait = if haki then "Haki" else "Special",
		Hit = {},
	}

	self:PlayEffect(EFFECT, wave.Center, {
		Radius = RADIUS,
		ExpandTime = EXPAND_TIME,
		Lifetime = LIFETIME,
		Haki = haki,
	})

	task.spawn(sweep, self, wave, self.Epoch or 0)
end

function FireWave:OnInterrupt()
	-- A wave still in the air stops burning.
	self.Epoch = (self.Epoch or 0) + 1
end

return FireWave
