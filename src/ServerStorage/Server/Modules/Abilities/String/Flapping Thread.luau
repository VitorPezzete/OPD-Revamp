--!strict
--[[
	String fruit - Flapping Thread (hold): a stream of string spikes thrown from behind
	the user's shoulders towards the mouse.

	- 15 spikes per second while the key is held. The legacy client loop waited
	  1 - 500 / sniper level seconds, which is zero or less for every reachable level:
	  it sent a request every 1 / 30 s (the shortest `wait`) and the 0.05 s server
	  debounce let every second one through.
	- Spike: starts 1 stud behind the user, 3 to 6 studs to one side (alternating) and
	  -2 to 5 studs up, flies 100 studs per second for 0.75 s inside a 15 degree spread
	  around the aim, pierces and hits each character once. It is as thin as the legacy
	  cone (a 1 x 2 x 1 stud part).
	- Damage: 150 * sniper affinity * (sniper level / cap), "Special", not dodgeable.
	  Armament haki doubles it and makes it "Haki".

	The spikes are thrown by a tick that only exists while the key is held and keeps to
	its schedule whatever the frame times. The owner's client refreshes the aim ten
	times a second (Effects.Status.StringFlapping, phase 3); if those updates stop for
	1.5 s the stream ends, so a lost release cannot keep it running.

	Legacy problems fixed here:
	- Every spike was a server part with a BodyVelocity and a Touched connection, pooled
	  in ReplicatedStorage between shots (a pooled spike could be re-used mid-flight).
	- Custom colors of a fruit in the second slot indexed the first slot's color string.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Projectile = require(ServerStorage.Server.Modules.Projectile)

local STATUS = "StringFlapping"
local EFFECT = "StringFlap"
local DAMAGE_TAG = "FlappingThread"
-- Armament haki status set by HakiService.
local HAKI_STATUS = "Haki"

local FIRE_INTERVAL = 1 / 15
local AIM_TIMEOUT = 1.5
local BASE_DAMAGE = 150
local HAKI_MULTIPLIER = 2
local SPEED = 100
local LIFETIME = 0.75
-- Half the width of the StringCone.
local RADIUS = 0.5
local SPREAD_DEGREES = 15

local FlappingThread = Ability.extend()

local function fire(self: any)
	local entity = self.Entity
	local root = entity.Root
	local rootCFrame: CFrame = root.CFrame

	-- Legacy `right` started true and the first spike left from the left side.
	if self.Right == nil then
		self.Right = true
	end
	self.Right = not self.Right
	local side = if self.Right then math.random(3, 6) else -math.random(3, 6)
	local origin = root.Position
		- rootCFrame.LookVector
		+ rootCFrame.RightVector * side
		+ Vector3.new(0, math.random(-2, 5), 0)

	local base = (self.Aim :: Vector3) - origin
	if base.Magnitude < 0.05 then
		base = rootCFrame.LookVector
	end
	base = Projectile.Lead(entity, origin, base, SPEED, SPEED * LIFETIME)
	local up = if math.abs(base.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local spread = math.rad(SPREAD_DEGREES)
	local direction = (CFrame.lookAt(Vector3.zero, base, up) * CFrame.Angles(
		(math.random() * 2 - 1) * spread,
		(math.random() * 2 - 1) * spread,
		0
	)).LookVector

	local haki = entity:HasStatus(HAKI_STATUS)
	local damage = BASE_DAMAGE * self:GetAffinity("Sniper") * self:GetLevelScale("Sniper")
	if haki then
		damage *= HAKI_MULTIPLIER
	end

	local range = SPEED * LIFETIME
	Projectile.Fire({
		Origin = origin,
		Direction = direction,
		Speed = SPEED,
		MaxDistance = range,
		Radius = RADIUS,
		Owner = entity,
		Pierce = true,
		-- A spike born on top of somebody touched it at once (legacy Touched).
		HitOverlapping = true,
		-- The legacy spike (Power3.StringCone) is CanCollide false: the map does not stop it.
		IgnoreWorld = true,
		OnHit = function(target)
			self:Damage(target, damage, if haki then "Haki" else "Special", DAMAGE_TAG, false)
		end,
	})
	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		Speed = SPEED,
		Range = range,
		Right = self.Right,
		Haki = haki,
	})
end

function FlappingThread:CanBegin(): boolean
	return not self.Active
end

function FlappingThread:OnBegin(input)
	local context = self.Context

	self.Active = true
	self.Aim = input.AimPosition
	self.LastAim = os.clock()
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	-- "<fruit slot>|<ability slot>": how the owner's client addresses its aim updates.
	self.Entity:SetStatus(STATUS, `{context.FruitSlot}|{context.Definition.Slot}`, nil, true)

	local nextFire = os.clock()
	local function tick()
		if self.Run ~= run or not self.Active then
			return
		end
		local now = os.clock()
		if now - self.LastAim > AIM_TIMEOUT then
			self:OnInterrupt()
			return
		end
		fire(self)
		-- Scheduled from the previous shot, not from this frame: no drift. A hitch is not
		-- made up for with a burst.
		nextFire = math.max(nextFire + FIRE_INTERVAL, now)
		task.delay(nextFire - now, tick)
	end
	tick()
end

-- Aim update from the owner's client while the key is held.
function FlappingThread:OnAction(input)
	self.Aim = input.AimPosition
	self.LastAim = os.clock()
end

function FlappingThread:OnEnd()
	if self.Active then
		self:OnInterrupt()
	end
end

function FlappingThread:OnInterrupt()
	self.Active = false
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return FlappingThread
