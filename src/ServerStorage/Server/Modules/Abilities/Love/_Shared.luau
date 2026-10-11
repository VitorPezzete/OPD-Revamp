--!strict
--[[
	Love fruit - shared petrification ("LoveStunned" in the legacy game), the love
	arrows and the cooldowns the charged powers share. Not an ability: every Love
	ability and DamageModifiers/LoveStunned require it.

	Two kinds of petrification share one state:
	- Victim (Pistol Kiss, Beam, arrows): rooted and sealed for `duration` seconds or
	  until the damage threshold is used up, whichever comes first. The duration is a
	  whole number of seconds, rounded to the nearest (the legacy timer was an IntValue
	  counted down once a second): under half a second there is no stun at all. Hits on a victim are
	  amplified (see the damage modifier). After the stun starts a player cannot be
	  petrified again for 1.2 * duration seconds; Luck users are immune. NPC enemies have
	  neither protection, as in the legacy game: every new hit petrifies them again and
	  no amount of damage breaks their stone.
	- Self (Petrify): set and removed by the Petrify ability; hits are reduced.

	State on the petrified entity:
	- "LoveStunned"   replicated, value = fruit colors of the Love user (stone shell and
	                  HUD icon, Effects.Status.LoveStunned).
	- "LoveStunState" server only: { Threshold, SniperAffinity, Self, Owner }.

	Shared cooldowns (the legacy client flags CanP4 / CanP5 / CanP6): Glare, Beam, Slave
	Arrow and Arrow Storm exclude each other while one is held or firing, and the
	cooldown that follows a salvo also closes some of the others:
		after Beam          Glare, Slave Arrow and Arrow Storm
		after Slave Arrow   Glare, Beam and Arrow Storm
		after Arrow Storm   Slave Arrow
	Each ability passes the names of the locks it obeys and of the abilities its own
	lock closes; the locks are timed statuses "LoveLock<Ability>" on the entity.

	Legacy problems fixed here:
	- Every character carried a control Script: one loop per second for the timer plus a
	  new 0.1 s threshold-polling loop spawned every second and never stopped.
	- Victims were handed to the server (SetNetworkOwner(nil)) with a VectorForce and
	  welded limb to limb. A victim is now simply rooted, like every other stun of the
	  new game; its pose is frozen by the client effect.
	- The arrows were unanchored server models with two Touched connections and a
	  Heartbeat connection each, never destroyed. They are simulated points now and end
	  at the first wall or floor.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity

export type State = {
	-- Damage left before the petrification breaks.
	Threshold: number,
	-- Sniper affinity of the Love user who caused it.
	SniperAffinity: number,
	-- True for the Love user's own Petrify.
	Self: boolean,
	Owner: CharacterEntity,
}

export type VolleyConfig = {
	-- Seconds between two volleys and between two arrows of one volley.
	VolleyInterval: number,
	ArrowInterval: number,
	ArrowsPerVolley: number,
	Speed: number,
	StunTime: number,
	-- Seconds the heart takes to reach its full size.
	GrowTime: number,
	-- Returns where the next arrow starts and its unit direction.
	Launch: () -> (Vector3, Vector3),
	-- False once the cast was interrupted: arrows that have not left yet are dropped.
	IsLive: () -> boolean,
}

local Love = {}

Love.STATUS = "LoveStunned"
Love.STATE = "LoveStunState"
-- Replicated while Beam / Slave Arrow / Arrow Storm is charged and fired
-- (Effects.Status.LoveCharging), and while Glare is held (Effects.Status.LoveGlare).
Love.CHARGE_STATUS = "LoveCharging"
Love.GLARE_STATUS = "LoveGlare"
-- Replicated during an aimed salvo: the owner's client streams its aim
-- (Effects.Status.LoveSalvo).
Love.SALVO_STATUS = "LoveSalvo"

local FRUIT_NAME = "Love"
local LOCK_PREFIX = "LoveLock"

-- StatusService stun key and AbilityService seal source of a victim.
local STUN_NAME = "LoveStunned"
local RECENT_STATUS = "LoveRecentlyStunned"
local RECENT_FACTOR = 1.2
local VICTIM_THRESHOLD = 2500
local IMMUNE_FRUITS = { "Luck" }

local ARROW_EFFECT = "LoveArrow"
local RELEASE_EFFECT = "LoveRelease"
-- Full width of the heart on an arrow, times sniper affinity.
local ARROW_HEART_SIZE = 17.5
local ARROW_START_RADIUS = 1
local ARROW_STEP = 0.1
-- The legacy arrows stopped being steered after 10 s.
local ARROW_MAX_FLIGHT = 10

--[[
	Petrifies `target` for `duration` seconds on behalf of the Love ability `ability`.
	Threshold: 2500 * (defense level / cap) * sniper affinity of the Love user.
	Returns whether the target was petrified.
]]
function Love.Stun(ability: any, target: CharacterEntity, duration: number): boolean
	duration = math.floor(duration + 0.5)
	if duration <= 0 or target.Dead or target == ability.Entity then
		return false
	end

	local player = target.Player
	if player then
		if target:HasStatus(RECENT_STATUS) then
			return false
		end
		for _, fruitName in IMMUNE_FRUITS do
			if ability.Services.Fruit:HasFruit(player, fruitName) then
				return false
			end
		end
	end

	local affinity: number = ability:GetAffinity("Sniper")
	local threshold = VICTIM_THRESHOLD * ability:GetLevelScale("Defense") * affinity
	if threshold <= 0 then
		return false
	end

	-- Both calls interrupt the target's abilities. A Love user caught while using its own
	-- Petrify drops it here, before the victim state below is written.
	ability.Services.Status:ApplyStun(target, duration, STUN_NAME)
	ability.Services.Ability:SetSealed(target, true, duration, STUN_NAME)

	local state: State = {
		Threshold = threshold,
		SniperAffinity = affinity,
		Self = false,
		Owner = ability.Entity,
	}
	if player then
		target:SetStatus(RECENT_STATUS, true, duration * RECENT_FACTOR)
	end
	target:SetStatus(Love.STATE, state, duration)
	target:SetStatus(Love.STATUS, ability:GetColorString(), duration, true)
	return true
end

-- Ends a petrification early (threshold used up, or the Love user is gone).
function Love.Release(entity: CharacterEntity)
	local state: State? = entity:GetStatus(Love.STATE)
	if not state then
		return
	end

	entity:ClearStatus(Love.STATE)
	entity:ClearStatus(Love.STATUS)

	local abilityService = Knit.GetService("AbilityService")
	if state.Self then
		-- Everything else of the user is already off: this only reaches Petrify, whose
		-- OnInterrupt removes its root and its seal.
		abilityService:Interrupt(entity)
	else
		Knit.GetService("StatusService"):Clear(entity, STUN_NAME)
		abilityService:SetSealed(entity, false, nil, STUN_NAME)
	end
end

-- True while Glare is held or one of the charged powers is charging or firing.
function Love.IsBusy(entity: CharacterEntity): boolean
	return entity:HasStatus(Love.CHARGE_STATUS) or entity:HasStatus(Love.GLARE_STATUS)
end

-- True while the cooldown of one of the named abilities is running.
function Love.IsLocked(entity: CharacterEntity, abilityNames: { string }): boolean
	for _, abilityName in abilityNames do
		if entity:HasStatus(LOCK_PREFIX .. abilityName) then
			return true
		end
	end
	return false
end

--[[
	Starts the cooldown of `ability` for `seconds`. `closes` names the sibling abilities
	this cooldown also keeps shut: their own CanBegin checks the lock, this only makes
	their HUD slot show it (the HUD is told per ability, so the service is handed a
	stand-in carrying the sibling's slot).
]]
function Love.Lock(ability: any, seconds: number, closes: { string })
	local context = ability.Context
	ability.Entity:SetStatus(LOCK_PREFIX .. context.Definition.Name, true, seconds)
	ability:StartCooldown(seconds)

	local fruit = FruitConfig.Fruits[FRUIT_NAME]
	local skills = context.Data.Data.Skills
	for _, definition in fruit.Abilities do
		if table.find(closes, definition.Name) and skills[definition.Skill].Level >= definition.Requirement then
			ability.Services.Ability:Report({
				Player = ability.Player,
				Context = { FruitSlot = context.FruitSlot, Definition = definition },
			}, "Cooldown", seconds)
		end
	end
end

-- Tells the clients a salvo of `kind` ("Beam", "Arrow", "Storm") is over: the caster's
-- own plays the release animation.
function Love.PlayRelease(ability: any, kind: string)
	ability:PlayEffect(RELEASE_EFFECT, ability.Entity.Root.Position, { Kind = kind })
end

-- Unit direction within a square cone around `base`; yaw and pitch in degrees.
function Love.Spread(base: Vector3, minDegrees: number, maxDegrees: number): Vector3
	local random = Random.new()
	local yaw = math.rad(random:NextNumber(minDegrees, maxDegrees))
	local pitch = math.rad(random:NextNumber(minDegrees, maxDegrees))
	local up = if math.abs(base.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return (CFrame.lookAt(Vector3.zero, base, up) * CFrame.Angles(pitch, yaw, 0)).LookVector
end

--[[
	One love arrow: a point under gravity, sampled every 0.1 s. Everyone within the heart
	(which grows to 17.5 * affinity studs wide over `growTime`) along the path is
	petrified once. Ends at the first wall or floor, or after 10 s. An arrow that has
	left keeps flying whatever happens to its caster, short of dying.
]]
local function fireArrow(ability: any, origin: Vector3, velocity: Vector3, config: VolleyConfig)
	local entity: CharacterEntity = ability.Entity
	local affinity: number = ability:GetAffinity("Sniper")
	local maxRadius = ARROW_HEART_SIZE * affinity / 2
	local gravity = Vector3.new(0, -Workspace.Gravity, 0)
	local characterService = ability.Services.Character

	ability:PlayEffect(ARROW_EFFECT, origin, {
		Velocity = velocity,
		GrowTime = config.GrowTime,
		HeartSize = ARROW_HEART_SIZE * affinity,
		Lifetime = ARROW_MAX_FLIGHT,
	})

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }

	local hit: { [CharacterEntity]: boolean } = {}
	local function stunAll(targets: { CharacterEntity })
		for _, target in targets do
			if not hit[target] then
				hit[target] = true
				Love.Stun(ability, target, config.StunTime)
			end
		end
	end

	task.spawn(function()
		local position = origin
		local elapsed = 0
		while elapsed < ARROW_MAX_FLIGHT do
			task.wait(ARROW_STEP)
			if entity.Dead or entity.Model.Parent == nil then
				return
			end

			elapsed += ARROW_STEP
			local nextPosition = origin + velocity * elapsed + gravity * (elapsed * elapsed / 2)
			local segment = nextPosition - position

			-- Characters do not stop an arrow; anything else does.
			local wall: RaycastResult? = nil
			for _ = 1, 4 do
				local result = Workspace:Raycast(position, segment, params)
				if not result then
					break
				end
				local owner = characterService:GetEntityFromPart(result.Instance)
				if not owner then
					wall = result
					break
				end
				params:AddToFilter(owner.Model)
			end
			if wall then
				nextPosition = wall.Position
				segment = nextPosition - position
			end

			local radius = ARROW_START_RADIUS
				+ (maxRadius - ARROW_START_RADIUS) * math.clamp(elapsed / config.GrowTime, 0, 1)
			local length = segment.Magnitude
			if length > 0.05 then
				local up = if math.abs(segment.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
				local middle = position + segment / 2
				stunAll(Hitbox.Box(
					CFrame.lookAt(middle, nextPosition, up),
					Vector3.new(radius * 2, radius * 2, length),
					entity
				))
			end
			if wall then
				stunAll(Hitbox.Sphere(nextPosition, radius, entity))
				return
			end
			position = nextPosition
		end
	end)
end

--[[
	The legacy release of Slave Arrow / Arrow Storm: the client sent `volleys` requests
	0.1 s apart, each starting a loop of arrows, then a last request that aborted every
	loop. What actually flew is every arrow whose turn came before that last request;
	the same schedule is rebuilt here from the server's own numbers.
	Returns the seconds until the last arrow has left.
]]
function Love.Volley(ability: any, volleys: number, config: VolleyConfig): number
	local window = volleys * config.VolleyInterval
	for volley = 0, volleys - 1 do
		for arrow = 0, config.ArrowsPerVolley - 1 do
			local delay = volley * config.VolleyInterval + arrow * config.ArrowInterval
			if delay >= window then
				break
			end
			task.delay(delay, function()
				if not config.IsLive() or ability.Entity.Dead then
					return
				end
				local origin, direction = config.Launch()
				fireArrow(ability, origin, direction * config.Speed, config)
			end)
		end
	end
	return window
end

return Love
