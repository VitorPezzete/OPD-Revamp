--!strict
--[[
	Vampire fruit - Bat Swarm (charged): hold to gather bats in the hand, release to
	send them at the aimed character. The hands alternate, right first.

	Charge: 25 per second, 4 to 100 (4 s for a full charge), timed on the server.

	Tap (charge of 5 or less): eats one raised bat and heals
	  bat health * 0.0005 * sniper affinity. Nothing happens without a bat.

	Release (charge above 5), aimed at a character:
	  The swarm chases it at 50 * sniper affinity studs per second (x1.5 by night) for
	  up to 20 s. Once within 10 studs it latches on and bites
	    floor(clamp(10 * sniper affinity * charge / 100, 3 * sniper affinity, 20)) times,
	  one bite every 0.25 s, each for 320 * sniper affinity * charge / 100
	  ("Special", not dodgeable; it does not scale with level - legacy numbers).
	  A quarter second after each bite the vampire heals a third of that bite's damage:
	  the nominal number, whatever the target's defenses left of it (legacy), and the
	  bites keep coming - and healing - on a target that died meanwhile, for as long as
	  its body is still there.
	  With the attack mode on (Necromancy) and a bat raised, that bat rides along: the
	  swarm flies at 60 * sniper affinity + bat health * 0.0005 * sniper affinity
	  instead, the first bite adds bat health * 0.05 * sniper affinity, the bat is
	  spent and the attack mode turns off.
	Release aimed at nobody: the bats just fly off in that direction (10 s). They never
	  did any damage that way and still do not.

	Who is "aimed at". The legacy client locked onto the character closest to the line
	of its cursor, inside a cone of fov / (distance + 10) degrees (20 at most), with
	fov 200 by day and 400 by night: a vampire locks on twice as easily at night. The
	server does the same here from what it is given - the character under the aim point,
	else that cone around the line from the vampire to the aim point.

	Design: the swarm is a point advanced ten times a second while it chases, then one
	delayed call per bite. Clients draw it from two one-shot effects: VampireBatSwarm
	(the flight, re-simulated locally against the same target) and VampireBatSwarmHit
	(the latched swarm). A swarm already released keeps going when its vampire is
	stunned or sealed, as the legacy one did; it ends with the vampire's death or fruit.

	Legacy problems fixed here:
	- Charge state lived in two Values shared by both fruit slots and a script-level
	  `charge` variable shared by every press.
	- The server waited for the release with `repeat task.wait()`; the chase was a
	  Heartbeat connection that was never disconnected when the target despawned.
	- The client chose the target by sending a part.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local VampireShared = require(script.Parent.VampireShared)

type CharacterEntity = CharacterEntity.CharacterEntity

local FRUIT_NAME = "Vampire"
-- Replicated while charging, "<Right|Left>|<fruit colors>": the bats swirling around the hand.
local CHARGING_STATUS = "VampireCharging"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local TAP_CHARGE = 5

-- A character whose root is this close to the aim point is under the cursor.
local AIM_RADIUS = 1
local AIM_RANGE = 1000
local AIM_FOV_DAY = 200
local AIM_FOV_NIGHT = 400
local AIM_FOV_OFFSET = 10
local AIM_MAX_ANGLE = 20

local BAT_HEAL_FRACTION = 0.0005
local BAT_SPEED_FRACTION = 0.0005
local BAT_BITE_FRACTION = 0.05

local BASE_SPEED = 50
local BAT_BASE_SPEED = 60
local NIGHT_SPEED_MULTIPLIER = 1.5
local BASE_DAMAGE = 320
local HEAL_DIVISOR = 3

local CHASE_TIME = 20
local FREE_FLIGHT_TIME = 10
local CHASE_TICK = 0.1
local LATCH_DISTANCE = 10
local BITE_INTERVAL = 0.25
local BITES_PER_AFFINITY = 10
local MIN_BITES_PER_AFFINITY = 3
local MAX_BITES = 20

local function isGone(target: CharacterEntity): boolean
	return target.Dead or not target.Spawned or target.Model.Parent == nil
end

local function findTarget(caster: CharacterEntity, aim: Vector3, isDay: boolean): CharacterEntity?
	local direct = Hitbox.Closest(Hitbox.Sphere(aim, AIM_RADIUS, caster), aim)
	if direct then
		return direct
	end

	local origin = caster.Root.Position
	local line = aim - origin
	local length = line.Magnitude
	if length < 1e-3 then
		return nil
	end
	local unit = line / length
	local fov = if isDay then AIM_FOV_DAY else AIM_FOV_NIGHT

	local best: CharacterEntity? = nil
	local bestAngle = AIM_MAX_ANGLE
	for _, candidate in Hitbox.Sphere(origin, AIM_RANGE, caster) do
		local offset = candidate.Root.Position - origin
		local distance = offset.Magnitude
		if distance < 1e-3 then
			continue
		end
		local cosine = math.clamp(unit:Dot(offset) / distance, -1, 1)
		local angle = math.deg(math.acos(cosine))
		-- The cone narrows with the distance along the aimed line, up to the aim point.
		local along = math.clamp(distance * cosine, 0.5, length)
		if angle < bestAngle and angle <= fov / (along + AIM_FOV_OFFSET) then
			best, bestAngle = candidate, angle
		end
	end
	return best
end

local BatSwarm = Ability.extend()

BatSwarm.Debounce = 0.5

function BatSwarm:OnBegin()
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	self.Entity:SetStatus(CHARGING_STATUS, `{self.Hand or "Right"}|{self:GetColorString()}`, nil, true)
end

function BatSwarm:OnEnd(input: Ability.AbilityInput)
	local entity = self.Entity
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	entity:ClearStatus(CHARGING_STATUS)
	if not charge or entity.Dead then
		return
	end

	local hand: string = self.Hand or "Right"
	self.Hand = if hand == "Right" then "Left" else "Right"

	local affinity = self:GetAffinity("Sniper")

	if charge <= TAP_CHARGE then
		local batHealth = VampireShared.TakeBat(entity)
		if batHealth then
			entity:Heal(batHealth * BAT_HEAL_FRACTION * affinity)
		end
		return
	end

	local isDay = VampireShared.IsDay()
	local arm = entity.Model:FindFirstChild(`{hand} Arm`)
	local origin = if arm and arm:IsA("BasePart") then arm.Position else entity.Root.Position
	local aimed = findTarget(entity, input.AimPosition, isDay)

	local speed = BASE_SPEED * affinity
	local biteBonus = 0
	local attackMode = VampireShared.Status.BatAttack
	if entity:HasStatus(attackMode) then
		local batHealth = VampireShared.TakeBat(entity)
		if batHealth then
			speed = BAT_BASE_SPEED * affinity + batHealth * BAT_SPEED_FRACTION * affinity
			biteBonus = batHealth * BAT_BITE_FRACTION * affinity
			entity:ClearStatus(attackMode)
		end
	end
	if not isDay then
		speed *= NIGHT_SPEED_MULTIPLIER
	end

	if not aimed then
		local offset = input.AimPosition - origin
		if offset.Magnitude > 1e-3 then
			self:PlayEffect("VampireBatSwarm", origin, {
				Direction = offset.Unit,
				Speed = speed,
				Duration = FREE_FLIGHT_TIME,
				Hand = hand,
				WithBat = biteBonus > 0,
			})
		end
		return
	end
	local target: CharacterEntity = aimed

	self:PlayEffect("VampireBatSwarm", origin, {
		Target = target.Model,
		Speed = speed,
		Duration = CHASE_TIME,
		LatchDistance = LATCH_DISTANCE,
		Hand = hand,
		WithBat = biteBonus > 0,
	})

	local damage = BASE_DAMAGE * affinity * charge / 100
	local bites = math.floor(
		math.clamp(BITES_PER_AFFINITY * affinity * charge / 100, MIN_BITES_PER_AFFINITY * affinity, MAX_BITES)
	)

	-- The swarm is out in the world: only its vampire's death, departure or lost fruit ends it.
	local player = self.Player
	local function casterGone(): boolean
		return entity.Dead or entity.Model.Parent == nil or not self.Services.Fruit:HasFruit(player, FRUIT_NAME)
	end

	local function bite()
		if casterGone() or target.Model.Parent == nil then
			return
		end

		-- CombatService ignores hits on a dead target by itself.
		if biteBonus > 0 then
			self:Damage(target, biteBonus, "Special", nil, false)
			biteBonus = 0
		end
		self:Damage(target, damage, "Special", nil, false)
		bites -= 1

		task.delay(BITE_INTERVAL, function()
			if casterGone() then
				return
			end
			entity:Heal(damage / HEAL_DIVISOR)
			if bites > 0 then
				bite()
			end
		end)
	end

	local position = origin
	local elapsed = 0
	local function chase()
		if casterGone() or isGone(target) or elapsed >= CHASE_TIME then
			return
		end

		local offset = target.Root.Position - position
		if offset.Magnitude < LATCH_DISTANCE then
			self:PlayEffect("VampireBatSwarmHit", target.Root.Position, {
				Target = target.Model,
				-- Legacy: the unfloored bite count times the interval.
				Duration = math.clamp(BITES_PER_AFFINITY * affinity * charge / 100, MIN_BITES_PER_AFFINITY * affinity, MAX_BITES)
					* BITE_INTERVAL,
				-- The legacy particle rate: the charge, never below 40.
				Rate = math.clamp(charge, 40, 100),
			})
			bite()
			return
		end

		position += offset.Unit * math.min(speed * CHASE_TICK, offset.Magnitude)
		elapsed += CHASE_TICK
		task.delay(CHASE_TICK, chase)
	end
	chase()
end

function BatSwarm:OnInterrupt()
	self.ChargeStart = nil
	self.Entity:ClearStatus(CHARGING_STATUS)
end

return BatSwarm
