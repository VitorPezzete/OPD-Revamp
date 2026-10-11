--!strict
--[[
	Alice fruit - Cards of Fate: throws a playing card that homes on the aimed character.

	Cost:      50 haki. 3 s between throws (the legacy client locked the key for 3 s
	           after every throw, so the server-side card charges never let anyone
	           throw sooner; the Neutral tea's charges are therefore not used here).
	Target:    the character under the aim point, else the one closest to the aimed line
	           inside the legacy auto-target cone (see pickTarget). With no character
	           the card is still thrown at the aimed point (haki spent, nothing hit).
	Card:      200 studs/s (300 with the Max tea); it always reaches its target.
	On impact, in the legacy order:
	1. Bleed:  floor(7 * sword affinity) ticks, each a random integer between
	           floor(90 * sword affinity * sword level / 500) and
	           floor(175 * sword affinity * sword level / 500) of "Bleed" damage,
	           followed by a random 0.2-1.1 s pause.
	2. The tea drunk last (read when the bleed ends):
	           Bad    - venom: 10 ticks of 125 * sniper affinity, the "Normal" speed of
	                    the Venom fruit's poison (every 0.4 s on a player, 0.6 s on an
	                    NPC), shown with the same status icon
	           Weird  - the caster is stunned for 2 s
	           Haki   - steals 75 haki from a player target
	           Health - takes 33% of the damage straight from the target's health
	                    (unmitigated) and heals the caster by it
	3. Damage: 500 * (haki level / 500) * sniper affinity, "Special", not dodgeable
	           (x1.25 when the Neutral tea was the last one at the throw).
	The main hit landing only after the whole bleed is how the legacy card behaved (its
	bleed loop ran first) and is kept.

	The card is not simulated: it cannot miss, so the server only waits the flight time
	(distance / speed at the throw) and then applies the hit. Effects.OneShot.AliceCard
	draws the homing card.

	KeepThroughStun: cards already thrown keep flying when their caster is stunned (the
	Weird tea stuns it on every hit), as in the legacy game. A stunned caster cannot throw.

	Legacy problems fixed here:
	- The client sent the part under its mouse (or its own auto-target) as the target,
	  and the server ran a Heartbeat connection per card that never ended if the target
	  was destroyed. The target is picked here from the validated aim point.
	- Cooldown and the active tea were script globals.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local EFFECT = "AliceCard"

local HAKI_COST = 50
local COOLDOWN = 3
-- How close to a character the aim point must be to pick it as the target.
local AIM_RADIUS = 8
-- Legacy auto-target (AimModule:GetAutoTarget with a field of view of 500): a character
-- is taken when its angle to the aimed line is at most FOV / (distance along the line
-- + 10) degrees, never more than 20; the smallest angle wins.
local ASSIST_FOV = 500
local ASSIST_MAX_ANGLE = 20
local ASSIST_MIN_DISTANCE = 0.5

local SPEED = 200
local MAX_TEA_SPEED = 300
local MAX_FLIGHT_TIME = 6
-- The legacy card vanished (and hit) within this many studs of its target.
local HIT_DISTANCE = 5

local DAMAGE = 500
local NEUTRAL_TEA_MULTIPLIER = 1.25
local DRAIN_FRACTION = 0.33
local HAKI_STEAL = 75
local SELF_STUN = 2

local BLEED_TICKS = 7
local BLEED_MIN_DAMAGE = 90
local BLEED_MAX_DAMAGE = 175
local BLEED_MIN_PAUSE = 0.2
local BLEED_PAUSE_SPREAD = 0.9
-- Legacy formulas divide the sword level by 500 (the old cap).
local SWORD_LEVEL_DIVISOR = 500
local VENOM_DAMAGE = 125
local VENOM_TICKS = 10
local VENOM_PLAYER_INTERVAL = 0.4
local VENOM_NPC_INTERVAL = 0.6
-- The Venom fruit's replicated status: the victim's poison icon.
local VENOM_STATUS = "VenomDoT"

-- Card faces of the legacy game (decal ids); the client only shows the one picked.
local CARD_IMAGES = { 86515756009031, 1041725392, 94472766225929 }

local random = Random.new()

local CardsOfFate = Ability.extend()

CardsOfFate.KeepThroughStun = true

--[[
	The legacy cone was measured from the camera; the server only has the aim point, so
	it is measured from the caster, which is the same line for anything further than
	the camera offset.
]]
local function pickTarget(entity: CharacterEntity, aimPosition: Vector3): CharacterEntity?
	local direct = Hitbox.Closest(Hitbox.Sphere(aimPosition, AIM_RADIUS, entity), aimPosition)
	if direct then
		return direct
	end

	local origin = entity.Root.Position
	local aim = aimPosition - origin
	local aimDistance = aim.Magnitude
	if aimDistance < 1e-3 then
		return nil
	end
	local unit = aim / aimDistance

	local best: CharacterEntity? = nil
	local bestAngle = ASSIST_MAX_ANGLE
	for _, candidate in Hitbox.Sphere(origin, AbilityConfig.MaxAimDistance, entity) do
		local offset = candidate.Root.Position - origin
		local distance = offset.Magnitude
		if distance < 1e-3 or not Shared.IsEnemy(entity, candidate) then
			continue
		end

		local cosine = math.clamp(unit:Dot(offset / distance), -1, 1)
		local angle = math.deg(math.acos(cosine))
		local along = math.min(math.max(distance * cosine, ASSIST_MIN_DISTANCE), aimDistance)
		if angle < bestAngle and angle <= ASSIST_FOV / (along + 10) then
			best, bestAngle = candidate, angle
		end
	end
	return best
end

local function land(self: any, target: CharacterEntity?, damage: number, epoch: number)
	if self.Epoch ~= epoch then
		return
	end

	local entity: CharacterEntity = self.Entity
	local services = self.Services
	local sniper = self:GetAffinity("Sniper")
	local sword = self:GetAffinity("Sword")

	if target then
		-- The bleed runs first and holds everything else back, as the legacy loop did.
		local swordScale = sword * self:GetLevel("Sword") / SWORD_LEVEL_DIVISOR
		local low = math.floor(BLEED_MIN_DAMAGE * swordScale)
		local high = math.floor(BLEED_MAX_DAMAGE * swordScale)
		for _ = 1, math.floor(BLEED_TICKS * sword) do
			if not target.Dead and target.Spawned then
				self:Damage(target, random:NextInteger(low, high), "Bleed", EFFECT, false)
			end
			task.wait(BLEED_MIN_PAUSE + random:NextNumber() * BLEED_PAUSE_SPREAD)
			if self.Epoch ~= epoch or entity.Dead then
				return
			end
		end
	end

	-- The tea that counts is the one in effect now, not the one at the throw.
	local tea = entity:GetStatus(Shared.TeaStatus)
	local alive = target ~= nil and not target.Dead and target.Spawned

	if tea == "Bad" and target and alive then
		services.Status:ApplyDot(target, "AliceVenom", {
			Source = entity,
			Damage = VENOM_DAMAGE * sniper,
			Interval = if target.Player then VENOM_PLAYER_INTERVAL else VENOM_NPC_INTERVAL,
			Ticks = VENOM_TICKS,
			Trait = "Special",
			Status = VENOM_STATUS,
		})
	end
	if tea == "Weird" then
		services.Status:ApplyStun(entity, SELF_STUN)
	end
	if not target or not alive then
		return
	end

	if tea == "Haki" then
		Shared.StealHaki(services, target, entity, HAKI_STEAL)
	elseif tea == "Health" then
		-- Straight out of the target's health, as the legacy drain was.
		local drain = damage * DRAIN_FRACTION
		entity:Heal(drain)
		target:TakeDamage(drain)
	end

	self:Damage(target, damage, "Special", EFFECT, false)
end

function CardsOfFate:CanBegin(): boolean
	return not self.Entity:HasStatus(Shared.StunStatus)
end

function CardsOfFate:OnBegin(input: Ability.AbilityInput)
	local entity: CharacterEntity = self.Entity

	-- The legacy client locked the key for 3 s on every release, accepted or not.
	local now = os.clock()
	if now - (self.LastThrow or 0) < COOLDOWN then
		return
	end
	self.LastThrow = now
	self:StartCooldown(COOLDOWN)

	if Shared.GetHaki(entity) < HAKI_COST then
		return
	end
	Shared.AddHaki(self.Services, entity, -HAKI_COST)

	local target: CharacterEntity? = pickTarget(entity, input.AimPosition)

	local tea = entity:GetStatus(Shared.TeaStatus)
	local speed = if tea == "Max" then MAX_TEA_SPEED else SPEED
	local damage = DAMAGE * (self:GetLevel("Haki") / Shared.HakiLevelDivisor) * self:GetAffinity("Sniper")
	if tea == "Neutral" then
		damage *= NEUTRAL_TEA_MULTIPLIER
	end

	local origin = entity.Root.Position
	local goal = if target then target.Root.Position else input.AimPosition
	local flightTime = math.clamp(((goal - origin).Magnitude - HIT_DISTANCE) / speed, 0, MAX_FLIGHT_TIME)

	-- With no character the card flies to the aimed point (the legacy card flew to
	-- whatever part was under the mouse) and only the tea's effect on the caster lands.
	self:PlayEffect(EFFECT, origin, {
		Target = if target then target.Model else nil,
		Position = if target then nil else input.AimPosition,
		Speed = speed,
		Image = CARD_IMAGES[random:NextInteger(1, #CARD_IMAGES)],
	})

	self.Epoch = self.Epoch or 0
	task.delay(flightTime, land, self, target, damage, self.Epoch)
end

function CardsOfFate:OnInterrupt()
	-- Cards still in flight fizzle.
	self.Epoch = (self.Epoch or 0) + 1
end

return CardsOfFate
