--!strict
--[[
	Venom fruit - Chloro Ball (charged): a ball of poison thrown at the aim point, which
	poisons whoever it passes through. The hands alternate, right first.

	Charge: 25 per second held, 4 to 100 (timed on the server). The legacy server kept
	the start of the charge in an IntValue, so it was ROUNDED to a whole second of
	`time()`: a release counts up to half a second more or less than was really held (a
	quick tap is worth anything from 4 to 16). Kept, since it decides the size. On
	release, with c = charge / 100 and f = sniper affinity * (sniper level / cap):
	- ball diameter = clamp(30 * c * f, 1, 2000);
	- it leaves the hand at 600 studs/s and loses 1% of its velocity per frame (the
	  legacy `velocity *= 0.99` on Heartbeat, taken at 60 Hz as a drag of DECAY per
	  second) while gravity pulls it down. Nothing stops it: the legacy ball was a
	  non-colliding part, so it goes through walls, sinks through the ground and is gone
	  when it falls under the world (Workspace.FallenPartsDestroyHeight), about 3 s
	  after the throw. On the way it covers 260 studs in the first half second (dropping
	  22) and 450 in the first second (dropping 80);
	- each character it touches is poisoned: 100 * f per hit, floor(30 * f) hits, Fast;
	  with Venom Demon (at the moment of release) 600 * f, floor(6 * f) hits, Slow;
	- 2 s between a release and the next charge.

	Why not Modules/Projectile with Gravity and IgnoreWorld: it has no drag, and the drag
	is most of this trajectory (the ball loses 45% of its speed every second; without it
	the ball would be 600 studs away after a second instead of 450, and the fall speed
	would not level off near 325 studs/s). Hence the closed formula below, which is the
	legacy per-frame rule integrated: the server stepped gravity then multiplied the
	whole velocity (fall included) by 0.99, sixty times a second.

	The whole flight is a closed formula, shared with Effects.OneShot.VenomChloro:
	  position(t) = origin + v0 / k * (1 - e^(-k t)) + g / k * (t - (1 - e^(-k t)) / k)
	with v0 = 600 * direction, k = DECAY and g = gravity, downwards. No per-frame work:
	the ball is tested ten times a second as the box it swept since the last test.

	Legacy problems fixed here:
	- The slowdown was per Heartbeat, so the range depended on the server frame rate.
	- "StopCharging" did not need a "StartCharging" (free full charge), `wavehand` was a
	  script variable (a second charge leaked the first hand ball and a release without
	  one errored), and the Touched handler used a script-level affinity.

	Kept as in the legacy game: the bigger Venom Demon ball (50 instead of 30) was
	computed into a shadowed local and never used, so the size is the same with or
	without the demon.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

-- Replicated while charging: "<hand ball size>|<fruit colors>|<Right|Left>".
local CHARGE_STATUS = "VenomChloroCharging"
local EFFECT = "VenomChloro"

local CHARGE_RATE = 25
local MIN_CHARGE = 4
local MAX_CHARGE = 100
local SIZE = 30
local MIN_SIZE = 1
local MAX_SIZE = 2000
-- Diameter the ball in the hand reaches after 5 s of charge, per f.
local HAND_SIZE = 10
local SPEED = 600
-- -ln(0.99) * 60: the legacy per-frame decay as a rate per second.
local DECAY = 0.603
-- Upper bound of the flight; the ball normally falls out of the world long before.
local LIFETIME = 10
local TICK = 0.1
local COOLDOWN = 2
local DAMAGE, HITS = 100, 30
local DEMON_DAMAGE, DEMON_HITS = 600, 6
-- Legacy: the position of the arm of that hand. Only used if the arm is missing.
local HAND_OFFSET = Vector3.new(1.5, 0, 0)

-- Where the ball is `age` seconds after leaving `origin` (see the header).
local function travel(direction: Vector3, gravity: number, age: number): Vector3
	local fade = 1 - math.exp(-DECAY * age)
	return direction * (SPEED / DECAY * fade) - Vector3.new(0, gravity / DECAY * (age - fade / DECAY), 0)
end

local ChloroBall = Ability.extend()

function ChloroBall:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0)
end

function ChloroBall:OnBegin()
	self:BeginCharge(MAX_CHARGE / CHARGE_RATE)
	self.Charging = true
	-- Legacy `P4Charge.Value = time()` on an IntValue (see the header).
	self.ChargeFrom = math.round(time())
	local size = HAND_SIZE * self:GetLevelScale("Sniper") * self:GetAffinity("Sniper")
	self.Entity:SetStatus(
		CHARGE_STATUS,
		`{string.format("%.2f", size)}|{self:GetColorString()}|{self.Hand or "Right"}`,
		nil,
		true
	)
	self.Entity:SetStatus(Shared.AIM_STATUS, true, nil, true)
end

function ChloroBall:OnEnd(input: Ability.AbilityInput)
	if not self:EndCharge(CHARGE_RATE, MIN_CHARGE, MAX_CHARGE) then
		return
	end
	local charge = math.floor(math.clamp((time() - (self.ChargeFrom or time())) * CHARGE_RATE, MIN_CHARGE, MAX_CHARGE))
	local entity = self.Entity
	entity:ClearStatus(CHARGE_STATUS)
	entity:ClearStatus(Shared.AIM_STATUS)
	self.Charging = false
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local hand: string = self.Hand or "Right"
	self.Hand = if hand == "Right" then "Left" else "Right"

	local factor = self:GetAffinity("Sniper") * self:GetLevelScale("Sniper")
	local size = math.clamp(SIZE * (charge / 100) * factor, MIN_SIZE, MAX_SIZE)
	local demon = Shared.IsDemon(entity)

	local side = if hand == "Left" then -1 else 1
	local arm = entity.Model:FindFirstChild(hand .. " Arm")
	local origin = if arm and arm:IsA("BasePart")
		then arm.Position
		else entity.Root.CFrame:PointToWorldSpace(HAND_OFFSET * Vector3.new(side, 1, 1))
	local offset = input.AimPosition - origin
	local direction = if offset.Magnitude < 0.05 then entity.Root.CFrame.LookVector else offset.Unit
	local gravity = Workspace.Gravity
	local floor = Workspace.FallenPartsDestroyHeight

	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		Size = size,
		Speed = SPEED,
		Decay = DECAY,
		Gravity = gravity,
		Floor = floor,
		Lifetime = LIFETIME,
		Demon = demon,
		Hand = hand,
	})

	-- Bounded chain (LIFETIME / TICK steps at most). It is deliberately NOT cancelled by
	-- OnInterrupt: the ball is already out in the world and every client is drawing it,
	-- so a stun or a seal of the thrower must not turn it into a harmless decoy. It only
	-- stops with the thrower's death.
	local start = os.clock()
	local previous = origin
	local function tick()
		if entity.Dead then
			return
		end
		local age = math.min(os.clock() - start, LIFETIME)
		local position = origin + travel(direction, gravity, age)

		-- Box swept since the last test: as wide as the ball, as long as the step.
		local length = (position - previous).Magnitude
		local middle = (previous + position) / 2
		local cframe = if length > 1e-3 then CFrame.lookAt(middle, position) else CFrame.new(middle)
		previous = position

		for _, target in Hitbox.Box(cframe, Vector3.new(size, size, size + length), entity) do
			if demon then
				Shared.Poison(self, target, DEMON_DAMAGE, DEMON_HITS, "Sniper", "Slow")
			else
				Shared.Poison(self, target, DAMAGE, HITS, "Sniper", "Fast")
			end
		end

		-- NaN compares false: a place without a destroy height falls back on LIFETIME.
		if age < LIFETIME and not (position.Y + size / 2 < floor) then
			task.delay(TICK, tick)
		end
	end
	tick()
end

function ChloroBall:OnInterrupt()
	self.ChargeStart = nil
	-- Only when this ability is the one aiming: OnInterrupt also runs for idle siblings.
	if self.Charging then
		self.Charging = false
		self.Entity:ClearStatus(Shared.AIM_STATUS)
	end
	self.Entity:ClearStatus(CHARGE_STATUS)
end

return ChloroBall
