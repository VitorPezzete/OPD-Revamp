--!strict
--[[
	Venom fruit - Poison Breath (held): a stream of poison clouds breathed at the aim.

	While the key is held one cloud leaves the mouth every 0.1 s, the first one 0.1 s
	after the press. Each cloud:
	- starts 3 studs in front of the head and flies towards the aim point at 80 studs/s
	  for 1 s, through walls (it is gas): its range is 80 studs, wherever the aim is;
	- is a cube growing from 0.54 to 15 studs (quadratic, slow then fast; 0.54 is the
	  size of the legacy template, Fruits.Venom.Power1.Part);
	- poisons each character it engulfs, once: 100 * f per hit (200 with Venom Demon),
	  floor(30 * f) hits, Fast, with f = sniper affinity * (sniper level / cap).
	Releasing the key stops the stream; 3 s before the next one.

	The clouds themselves are invisible, as they were (a transparent part): what players
	see is the particle stream at the mouth (Effects.Status.VenomBreath). The
	VenomBreathCloud one-shot only tells the other clients where that stream points; it
	is sent when the direction changes, not for every cloud.

	Range (the legacy changelog lists "Poison Breath Range" as fixed): the legacy file is
	already the fixed version - it tests the real volume of the moving cloud ("hitbox
	based on the real volume of the projectile") every frame instead of a Touched event.
	Here every live cloud is tested TICK seconds apart as the box it swept since its last
	test, at the size it has then: nothing on its path is skipped (a cloud moves 8 studs
	per test, more than its own size for half of its life), and the reach is 80 studs
	plus half the cloud, never more. The one range fault left was the direction, NaN
	when aiming at one's own mouth.

	Other legacy problems fixed here:
	- The CLIENT ran the loop and sent one "Fire" per cloud: the 0.1 s rate and the 3 s
	  cooldown did not exist for a modified client.
	- Each cloud was a server part with a BodyVelocity, a tween and a Heartbeat
	  connection running GetPartBoundsInBox over the map every frame.

	Aim: streamed by the owner's client as phase 3 inputs (Effects.Status.VenomBreath ->
	OnAction). If none arrives for AIM_TIMEOUT seconds the stream ends.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local STATUS = "VenomBreath"
local EFFECT = "VenomBreathCloud"

local DAMAGE = 100
local DEMON_DAMAGE = 200
local HITS = 30
local SPEED = 80
local LIFETIME = 1
local FIRE_INTERVAL = 0.1
local TICK = 0.1
local CLOUD_START_SIZE = 0.54
local CLOUD_END_SIZE = 15
-- Legacy: head CFrame * (0, 0, -3). The root offset is only used without a head.
local MOUTH_DISTANCE = 3
local MOUTH_OFFSET = Vector3.new(0, 1.5, -3)
local COOLDOWN = 3
local AIM_TIMEOUT = 1
-- The stream's direction is sent again when it turned by about 1.5 degrees, or after this long.
local AIM_RESEND_DOT = 0.9997
local AIM_RESEND_TIME = 0.5

type Cloud = {
	Origin: Vector3,
	Direction: Vector3,
	Start: number,
	-- Distance already tested along its line.
	Tested: number,
	Damage: number,
	Struck: { [any]: boolean },
}

local PoisonBreath = Ability.extend()

function PoisonBreath:CanBegin(): boolean
	return not self.Active and os.clock() >= (self.ReadyAt or 0)
end

local function spawnCloud(self: any, clouds: { Cloud }, now: number)
	local entity = self.Entity
	local head = entity.Model:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart")
		then head.CFrame:PointToWorldSpace(Vector3.new(0, 0, -MOUTH_DISTANCE))
		else entity.Root.CFrame:PointToWorldSpace(MOUTH_OFFSET)
	local offset = self.Aim - origin
	local direction = if offset.Magnitude < 0.05 then entity.Root.CFrame.LookVector else offset.Unit
	local demon = Shared.IsDemon(entity)

	table.insert(clouds, {
		Origin = origin,
		Direction = direction,
		Start = now,
		Tested = 0,
		Damage = if demon then DEMON_DAMAGE else DAMAGE,
		Struck = {},
	})

	local sent: Vector3? = self.SentDirection
	if not sent or sent:Dot(direction) < AIM_RESEND_DOT or now - self.SentAt >= AIM_RESEND_TIME then
		self.SentDirection = direction
		self.SentAt = now
		self:PlayEffect(EFFECT, origin, { Direction = direction })
	end
end

function PoisonBreath:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	self.Active = true
	self.Aim = input.AimPosition
	self.AimAt = os.clock()
	self.SentDirection = nil
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	-- "<fruit slot>;<ability slot>;<colors>".
	local context = self.Context
	entity:SetStatus(STATUS, `{context.FruitSlot};{context.Definition.Slot};{self:GetColorString()}`, nil, true)
	entity:SetStatus(Shared.AIM_STATUS, true, nil, true)

	-- One chain of ticks for the whole stream. It outlives the key by at most LIFETIME:
	-- clouds already breathed keep flying, after a release and after an interrupt alike
	-- (they were server parts on their own in legacy). The list is kept on the ability
	-- so a new stream takes over the clouds of the previous one.
	local clouds: { Cloud } = self.Clouds or {}
	self.Clouds = clouds
	local nextFire = os.clock() + FIRE_INTERVAL
	local function tick()
		if self.Run ~= run or entity.Dead then
			return
		end

		local now = os.clock()
		if self.Active and now - self.AimAt > AIM_TIMEOUT then
			-- No return: the clouds already in the air are still tested below.
			self:Stop()
		end
		if self.Active and now >= nextFire then
			nextFire = now + FIRE_INTERVAL
			spawnCloud(self, clouds, now)
		end

		for index = #clouds, 1, -1 do
			local cloud = clouds[index]
			local age = math.min(now - cloud.Start, LIFETIME)
			local alpha = age / LIFETIME
			local size = CLOUD_START_SIZE + (CLOUD_END_SIZE - CLOUD_START_SIZE) * alpha * alpha

			-- The box swept since the last test: as wide as the cloud, as long as the step.
			local distance = SPEED * age
			local center = cloud.Origin + cloud.Direction * ((cloud.Tested + distance) / 2)
			local cframe = CFrame.lookAt(center, center + cloud.Direction)
			local box = Vector3.new(size, size, size + (distance - cloud.Tested))
			cloud.Tested = distance

			for _, target in Hitbox.Box(cframe, box, entity) do
				if not cloud.Struck[target] then
					cloud.Struck[target] = true
					Shared.Poison(self, target, cloud.Damage, HITS, "Sniper", "Fast")
				end
			end
			if age >= LIFETIME then
				table.remove(clouds, index)
			end
		end

		if self.Active or #clouds > 0 then
			task.delay(TICK, tick)
		end
	end
	tick()
end

-- Aim stream of the owner's client.
function PoisonBreath:OnAction(input: Ability.AbilityInput)
	self.Aim = input.AimPosition
	self.AimAt = os.clock()
end

-- Normal end: the clouds in the air keep going (the tick chain stays valid).
function PoisonBreath:Stop()
	if self.Active then
		self.Active = false
		self.ReadyAt = os.clock() + COOLDOWN
		self:StartCooldown(COOLDOWN)
		self.Entity:ClearStatus(STATUS)
		self.Entity:ClearStatus(Shared.AIM_STATUS)
	end
end

function PoisonBreath:OnEnd()
	self:Stop()
end

-- Death, seal, stun: the stream stops; the clouds in the air finish their flight (the
-- tick chain ends by itself with the last of them, or with the caster's death).
function PoisonBreath:OnInterrupt()
	if self.Active then
		self.Active = false
		self.Entity:ClearStatus(Shared.AIM_STATUS)
	end
	self.Entity:ClearStatus(STATUS)
end

return PoisonBreath
