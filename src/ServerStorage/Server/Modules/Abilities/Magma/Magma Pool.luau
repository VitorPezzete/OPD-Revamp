--!strict
--[[
	Magma fruit - Magma Pool: a pool of magma spreads from under the caster.

	With k = defense affinity * (defense level / cap):
	- the pool stays where it was cast, 3 studs under the root; its diameter grows
	  linearly to 450 * k over 13 s, then shrinks back to nothing over 6 s;
	- whoever is inside (root at a flat distance <= current radius and within 8 studs
	  vertically, measured on the root's centre with no allowance for the body, as the
	  legacy check did) takes 560 * k the moment it enters and every 0.4 s after that, Special, not
	  dodgeable; armament haki at cast time doubles it and makes it Haki;
	- 26 s cooldown.

	Rumble owners take 1 Melee instead and Smelt / Hot / Plasma owners nothing
	(DamageModifiers.MagmaBurnImmunity, tag "MagmaHeat"). The pool leaves no burn.

	The pool goes on burning when its caster is stunned or sealed and only ends with the
	caster's death, as the legacy pool (a part with its own script inside the character)
	did. The visual (Effects.OneShot.MagmaPool) disappears with the caster too.

	Legacy problems fixed here:
	- Each pool carried a Script with a Heartbeat loop over every player and enemy that
	  spawned a coroutine per victim and was never disconnected; the pool was resized by
	  the server every frame. It is one bounded chain of delayed cylinder queries now.
	- Stepping out and back in within 0.4 s started a second damage coroutine on the same
	  victim. The 0.4 s are counted per victim from its last hit, in or out of the pool.
	- The damage and its type were written to values shared by every pool of the caster.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

local EFFECT = "MagmaPool"
local DAMAGE_TAG = "MagmaHeat"

local DAMAGE = 560
local HAKI_MULTIPLIER = 2
local DIAMETER = 450
local GROW_TIME = 13
local SHRINK_TIME = 6
local HIT_INTERVAL = 0.4
-- How often the pool looks for who is inside (an entering victim is hit at once).
local SCAN_INTERVAL = 0.1
local GROUND_OFFSET = 3
local HALF_HEIGHT = 8
-- Hitbox widens every shape by this body allowance; the legacy pool tested the centre of
-- the root, so it is taken back out.
local BODY_RADIUS = 2.5
local COOLDOWN = 26
-- Added to the pool's final radius: who gets the visual.
local EFFECT_RADIUS = 400

type Pool = {
	Start: number,
	Center: Vector3,
	Diameter: number,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	NextHit: { [CharacterEntity]: number },
}

local MagmaPool = Ability.extend()

MagmaPool.Debounce = COOLDOWN

-- One look at who is inside; reschedules itself until the pool is gone.
local function burn(self: any, pool: Pool)
	local entity: CharacterEntity = self.Entity
	local now = os.clock()
	local elapsed = now - pool.Start
	if elapsed >= GROW_TIME + SHRINK_TIME or entity.Dead or not entity.Model.Parent then
		return
	end

	local alpha = if elapsed <= GROW_TIME
		then elapsed / GROW_TIME
		else 1 - (elapsed - GROW_TIME) / SHRINK_TIME
	local radius = pool.Diameter * alpha / 2
	if radius > 0 then
		for _, target in Hitbox.Cylinder(pool.Center, radius - BODY_RADIUS, HALF_HEIGHT - BODY_RADIUS, entity) do
			if now >= (pool.NextHit[target] or 0) then
				pool.NextHit[target] = now + HIT_INTERVAL
				self:Damage(target, pool.Damage, pool.Trait, DAMAGE_TAG, false)
			end
		end
	end

	task.delay(SCAN_INTERVAL, burn, self, pool)
end

function MagmaPool:OnBegin()
	local entity = self.Entity
	local scale = self:GetAffinity("Defense") * self:GetLevelScale("Defense")
	local haki = self.Services.Haki:IsArmamentActive(entity)

	local pool: Pool = {
		Start = os.clock(),
		Center = entity.Root.Position - Vector3.new(0, GROUND_OFFSET, 0),
		Diameter = DIAMETER * scale,
		Damage = DAMAGE * scale * (if haki then HAKI_MULTIPLIER else 1),
		Trait = if haki then "Haki" else "Special",
		NextHit = setmetatable({}, { __mode = "k" }) :: any,
	}

	self:StartCooldown(COOLDOWN)
	self:PlayEffect(EFFECT, pool.Center, {
		Diameter = pool.Diameter,
		GrowTime = GROW_TIME,
		ShrinkTime = SHRINK_TIME,
		Haki = haki,
	}, EFFECT_RADIUS + pool.Diameter / 2)

	task.delay(SCAN_INTERVAL, burn, self, pool)
end

return MagmaPool
