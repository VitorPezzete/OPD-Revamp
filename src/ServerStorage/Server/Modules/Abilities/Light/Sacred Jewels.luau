--!strict
--[[
	Light fruit - Sacred Jewels (held): a stream of light bolts from alternating hands.

	While the key is held the user is held where it stands by a strong damper (the
	owner's client, Effects.Status.LightJewels: it barely sinks in the air and barely
	walks) and fires one bolt every 0.0875 s, at most 50 per use; then 2.5 s of
	cooldown. Each bolt, with a = defense affinity and s = defense level / cap:
	- leaves towards the aim point inside a 5 degree cone and flies at 400 studs/s to
	  the first thing a ray finds within 1000 studs when it is fired - a wall or a
	  character - and stays there for one second, enlarged;
	- every 0.1 s of its life, starting as it leaves the hand, deals 250 * s * a to
	  each character near it that it has not hit yet ("Special", not dodgeable; armament
	  haki doubles it and makes it "Haki"). Near is 5 studs: from the root of an NPC,
	  from any body part of a player (PLAYER_REACH from its root). As in the legacy
	  game a bolt covers 40 studs between two looks, so it mostly hurts where it stops.

	It cannot be started while Light Beam is firing, and blocks it.

	Aim: streamed by the owner's client as phase 3 inputs (Effects.Status.LightJewels ->
	OnAction). If none arrives for AIM_TIMEOUT seconds the volley ends.

	Legacy problems fixed here:
	- The CLIENT ran the firing loop and sent one "Fire" per bolt: the 50 bolt limit, the
	  0.0875 s interval and the 2.5 s cooldown did not exist for a modified client.
	- Each bolt was a server part with a tween and a thread scanning every body part of
	  every player; it is a position computed from the time elapsed now.
	- The alternating hand was a script variable shared by both fruit slots.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local Shared = require(script.Parent._Shared)

local STATUS = Shared.JEWELS_STATUS
local EFFECT = "LightJewel"

local BASE_DAMAGE = 250
local MAX_BOLTS = 50
local INTERVAL = 0.0875
local COOLDOWN = 2.5
local SPEED = 400
local RANGE = 1000
local SPREAD = math.rad(5)
-- Legacy: the root of an NPC, or any body part of a player, within 5 studs of the bolt.
-- A limb's centre is up to 1.5 studs from the root.
local NPC_REACH = 5
local PLAYER_REACH = 6.5
-- Same body allowance as Hitbox.
local BODY_RADIUS = 2.5
local SAMPLE_INTERVAL = 0.1
-- A bolt stays this long where it stopped, and never lives longer than MAX_LIFETIME.
local BURST_TIME = 1
local MAX_LIFETIME = 4
local AIM_TIMEOUT = 1

local SacredJewels = Ability.extend()

function SacredJewels:CanBegin(): boolean
	return not self.Active and os.clock() >= (self.ReadyAt or 0) and not self.Entity:HasStatus(Shared.BEAM_STATUS)
end

local function fire(self: any, left: boolean)
	local entity = self.Entity
	local origin = Shared.HandOrigin(entity, left)
	local aimed = Projectile.Lead(entity, origin, Shared.Direction(entity, origin, self.Aim), SPEED, RANGE)
	-- Random yaw and pitch of up to 5 degrees around the aim direction.
	local direction = (
		CFrame.lookAt(Vector3.zero, aimed)
		* CFrame.Angles((math.random() * 2 - 1) * SPREAD, (math.random() * 2 - 1) * SPREAD, 0)
	).LookVector

	local damage, trait, haki =
		Shared.Haki(self, BASE_DAMAGE * self:GetLevelScale("Defense") * self:GetAffinity("Defense"))
	local struck: { [any]: boolean } = {}

	-- Where the bolt stops is decided as it is fired, by one ray.
	local result = Workspace:Raycast(origin, direction * RANGE, Shared.RayParams(entity))
	local distance = if result then (result.Position - origin).Magnitude else RANGE

	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		Speed = SPEED,
		Range = distance,
		Haki = haki,
	})

	local started = os.clock()
	local lifetime = math.min(distance / SPEED + BURST_TIME, MAX_LIFETIME)
	local function look()
		local age = os.clock() - started
		if age > lifetime or entity.Dead or entity.Model.Parent == nil then
			return
		end
		local position = origin + direction * math.min(age * SPEED, distance)
		for _, target in Hitbox.Sphere(position, PLAYER_REACH - BODY_RADIUS, entity) do
			if not struck[target] then
				local reach = if target.Player then PLAYER_REACH else NPC_REACH
				if (target.Root.Position - position).Magnitude <= reach then
					struck[target] = true
					self:Damage(target, damage, trait, nil, false)
				end
			end
		end
		task.delay(SAMPLE_INTERVAL, look)
	end
	look()
end

function SacredJewels:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	self.Active = true
	self.Aim = input.AimPosition
	self.AimAt = os.clock()
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	-- "<fruit slot>;<ability slot>;<colors>".
	local context = self.Context
	entity:SetStatus(STATUS, `{context.FruitSlot};{context.Definition.Slot};{self:GetColorString()}`, nil, true)
	entity:SetStatus(Shared.AIM_STATUS, true, nil, true)

	local bolts = 0
	local function tick()
		if self.Run ~= run or not self.Active then
			return
		end
		if bolts >= MAX_BOLTS or os.clock() - self.AimAt > AIM_TIMEOUT then
			self:Stop()
			return
		end

		bolts += 1
		fire(self, bolts % 2 == 0)
		task.delay(INTERVAL, tick)
	end
	tick()
end

-- Aim stream of the owner's client.
function SacredJewels:OnAction(input: Ability.AbilityInput)
	self.Aim = input.AimPosition
	self.AimAt = os.clock()
end

function SacredJewels:Stop()
	if self.Active then
		self.ReadyAt = os.clock() + COOLDOWN
		self:StartCooldown(COOLDOWN)
	end
	self:OnInterrupt()
end

function SacredJewels:OnEnd()
	self:Stop()
end

-- Bolts already in flight keep going, as the legacy ones did.
function SacredJewels:OnInterrupt()
	if self.Active then
		self.Active = false
		self.Entity:ClearStatus(Shared.AIM_STATUS)
	end
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return SacredJewels
