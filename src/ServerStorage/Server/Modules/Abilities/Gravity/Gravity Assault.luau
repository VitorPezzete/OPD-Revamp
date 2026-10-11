--!strict
--[[
	Gravity fruit - Gravity Assault (hold): rocks are torn out of the ground in front of
	the user and thrown at the aim point, one every 0.2 s, up to 12 per press.

	With n = sniper affinity and s = sniper level / cap, each rock:
	- rises 25 studs away from the user towards the aim point (flat), at root height,
	  and needs ground within 10 studs under that point; with armament haki the rock
	  is made of haki and needs no ground (as in the legacy game);
	- is 10 * n * s studs wide and is thrown 0.8 s later along the aim direction at
	  550 studs per second, hitting each character once;
	- deals 562.5 * n * s as Melee damage (a thrown rock: logia bodies let it through),
	  or twice that as Haki damage with armament haki; not dodgeable.
	The barrage ends when the key is released or after 12 rocks; 1.5 s cooldown after.

	Aim. The legacy client sent one message per rock with the current sight point. The
	first rock uses the aim of the press; the owner's client then streams its aim as
	phase 3 inputs while the GravityAssault status is on (Effects.Status.GravityAssault)
	and each accepted one throws the next rock. The pace and the count are enforced
	here, so a client cannot throw faster or more.

	Flight of the rock. The legacy rock was an unanchored part launched at 550 studs/s
	with nothing holding it up: it fell under gravity, went through the map for its first
	0.2 s (CanCollide off, about 110 studs), collided after that, and damaged whoever
	it touched, once each, for 4 s. The server projectile follows the same arc in two
	legs: 0.2 s through walls, then until it meets the map (4 s after the throw at most).
	What the legacy rock still touched while bouncing and rolling after its first impact
	is not simulated. Clients throw a real rock of their own (Effects.OneShot.GravityRock).
	Rocks already out of the ground are thrown even if the user is interrupted in the
	0.8 s before the throw: they are projectiles by then, and every client is already
	showing them (a dead caster deals no damage anyway).

	Legacy problems fixed here:
	- The server only debounced rocks at 0.05 s: a client could throw 20 per second.
	- The level check was "melee level 50" for an ability that needs sniper 100.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "GravityAssault"
local EFFECT = "GravityRock"
local DAMAGE_TAG = "GravityAssault"

local MAX_ROCKS = 12
local ROCK_INTERVAL = 0.2
-- Network jitter allowance on the pace of the aim stream.
local INTERVAL_TOLERANCE = 0.04
local COOLDOWN = 1.5

local DISTANCE = 25
local GROUND_REACH = 10
local THROW_DELAY = 0.8
local SPEED = 550
-- Seconds after the throw during which the rock goes through the map, and during which
-- it can hurt.
local GHOST_TIME = 0.2
local LIVE_TIME = 4
-- Only for the aim assistance, which bends a straight line: how far it looks.
local ASSIST_RANGE = 300
local SIZE = 10
local MIN_RADIUS = 0.5
local DAMAGE = 562.5
local HAKI_MULTIPLIER = 2

local GravityAssault = Ability.extend()

-- Length of the path flown in `seconds` from `velocity` under `gravity`.
local function arcLength(velocity: Vector3, gravity: Vector3, seconds: number): number
	local steps = 20
	local length = 0
	local previous = Vector3.zero
	for step = 1, steps do
		local time = seconds * step / steps
		local point = velocity * time + gravity * (time * time / 2)
		length += (point - previous).Magnitude
		previous = point
	end
	return length
end

function GravityAssault:CanBegin(): boolean
	return not self.Active and os.clock() >= (self.ReadyAt or 0)
end

function GravityAssault:Finish()
	if not self.Active then
		return
	end
	self.Active = false
	self.Epoch = (self.Epoch or 0) + 1
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)
	self.Entity:ClearStatus(STATUS)
end

function GravityAssault:Throw(aim: Vector3)
	local entity: CharacterEntity = self.Entity
	self.Thrown += 1
	self.LastRock = os.clock()

	local rootPosition = entity.Root.Position
	local offset = aim - rootPosition
	if offset.Magnitude < 0.05 then
		offset = entity.Root.CFrame.LookVector
	end
	local direction = offset.Unit
	local reach = direction * DISTANCE

	local haki = self.Services.Haki:IsArmamentActive(entity)
	local grounded = haki
	if not grounded then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { entity.Model }
		grounded = Workspace:Raycast(rootPosition + reach, Vector3.new(0, -GROUND_REACH, 0), params) ~= nil
	end

	if grounded then
		local scale = self:GetAffinity("Sniper") * self:GetLevelScale("Sniper")
		local size = SIZE * scale
		local damage = DAMAGE * scale * (if haki then HAKI_MULTIPLIER else 1)
		local trait: CombatTypes.DamageTrait = if haki then "Haki" else "Melee"
		local origin = rootPosition + Vector3.new(reach.X, 0, reach.Z)
		direction = Projectile.Lead(entity, origin, direction, SPEED, ASSIST_RANGE, Workspace.Gravity)

		self:PlayEffect(EFFECT, origin, {
			Direction = direction,
			Speed = SPEED,
			GhostTime = GHOST_TIME,
			Size = size,
			Delay = THROW_DELAY,
			Haki = haki,
			-- Where the ground was looked for: the rock takes its material from there.
			Probe = rootPosition + reach,
		})

		task.delay(THROW_DELAY, function()
			if entity.Dead then
				return
			end
			local gravity = Vector3.new(0, -Workspace.Gravity, 0)
			local velocity = direction.Unit * SPEED
			local radius = math.max(size / 2, MIN_RADIUS)
			-- One rock hurts a character once, whichever leg meets it.
			local damaged: { [CharacterEntity]: boolean } = {}
			local function onHit(target: CharacterEntity)
				if not damaged[target] then
					damaged[target] = true
					self:Damage(target, damage, trait, DAMAGE_TAG, false)
				end
			end

			Projectile.Fire({
				Origin = origin,
				Direction = velocity,
				Speed = SPEED,
				MaxDistance = arcLength(velocity, gravity, GHOST_TIME),
				Radius = radius,
				Owner = entity,
				Pierce = true,
				Gravity = gravity,
				IgnoreWorld = true,
				HitOverlapping = true,
				OnHit = onHit,
				OnEnd = function(position: Vector3)
					local carried = velocity + gravity * GHOST_TIME
					Projectile.Fire({
						Origin = position,
						Direction = carried,
						Speed = carried.Magnitude,
						MaxDistance = arcLength(carried, gravity, LIVE_TIME - GHOST_TIME),
						Radius = radius,
						Owner = entity,
						Pierce = true,
						Gravity = gravity,
						OnHit = onHit,
					})
				end,
			})
		end)
	end

	if self.Thrown >= MAX_ROCKS then
		self:Finish()
	end
end

function GravityAssault:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity

	self.Active = true
	self.Thrown = 0
	self.Epoch = (self.Epoch or 0) + 1
	entity:SetStatus(STATUS, `{self.Context.FruitSlot};{self.Context.Definition.Slot}`, nil, true)

	-- A press whose release never arrives must not leave the barrage (and its status) on.
	local epoch = self.Epoch
	task.delay(MAX_ROCKS * ROCK_INTERVAL + 1, function()
		if self.Epoch == epoch then
			self:Finish()
		end
	end)

	self:Throw(input.AimPosition)
end

function GravityAssault:OnAction(input: Ability.AbilityInput)
	if os.clock() - (self.LastRock or 0) < ROCK_INTERVAL - INTERVAL_TOLERANCE then
		return
	end
	self:Throw(input.AimPosition)
end

function GravityAssault:OnEnd()
	self:Finish()
end

function GravityAssault:OnInterrupt()
	self:Finish()
end

return GravityAssault
