--!strict
--[[
	Candy fruit - Jawbreaker (charged): a hard candy ball thrown from the hand.

	Charge: 25 per second held, 4 to 100, timed on the server. The legacy game kept the
	start of the charge in an IntValue, which rounded it to the nearest whole second; that
	rounding (up to half a second more or less charge) is reproduced.

	With a = sniper affinity and s = a * (sniper level / 500):
	- damage clamp(charge * 15 * s, 25 * a, 1000 * a) * 1.5, "Melee" damage (logia bodies
	  let it through, as before), not dodgeable; armament haki doubles it and makes it
	  "Haki";
	- everyone hit is also stuck in syrup: CandyTouched for 3 s;
	- ball size max(template size * charge / 100, 4) on each axis, times s (the template
	  is a 50 stud ball);
	- hands alternate, right first; 0.35 s after a throw before the next charge;
	- KeepThroughStun: a press or a release while stunned is dropped.

	The ball is a real physical part, as in the legacy game, because everything about it
	is physics: it is the CandyJawbreaker template, unanchored and owned by the server,
	launched from the hand at 400 + 2 * charge studs per second towards the aim point. It
	falls, bounces and rolls; it does not collide for the first 0.1 s (so it can leave the
	thrower) and is solid afterwards, shoving whoever is in its way; its velocity loses
	0.5 % per frame (at 60 frames per second) until it is under 5 studs per second, where
	it is stopped. It then stays where it lies. Each character that touches it, flying or
	lying, is hit once.
	Lifetime, as in the legacy game: the balls of a thrower are removed 5 s after it dies.
	They also go when its character is removed (respawn, leaving). One thing is not
	legacy: a thrower keeps at most MAX_BALLS balls, the oldest going first, so that the
	server cannot be buried in 50 stud physics balls.

	This is the one place the fruit puts a visible instance on the server; since the part
	replicates, clients draw nothing for it (Effects.OneShot.CandyJawbreaker only plays
	the thrower's punch clip). Effects.Status.CandyCharging is the syrup in the hand.

	The thrower can never be hit: touches of its own character are ignored and
	CombatService refuses a hit whose attacker is its target.

	Not reproduced: a "Burn" value (100 * s) was written on the ball and never read.

	Legacy problem fixed here: a release without a start used the time of the previous
	shot and came out fully charged.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Allies = require(ServerStorage.Server.Modules.Allies)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local CandyShared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "CandyCharging"
local EFFECT = "CandyJawbreaker"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local RECAST_DELAY = 0.35

local DAMAGE_PER_CHARGE = 15
local MIN_DAMAGE = 25
local MAX_DAMAGE = 1000
local DAMAGE_MULTIPLIER = 1.5
local TOUCH_HITS = 3

local BASE_SPEED = 400
local SPEED_PER_CHARGE = 2
local MIN_AXIS = 4
local MIN_SIZE = 0.2
-- Used only when the template cannot be found.
local FALLBACK_DIAMETER = 50
local FALLBACK_COLOR = Color3.fromRGB(255, 120, 255)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

local SOLID_DELAY = 0.1
-- Share of the velocity kept per legacy frame, and the frame rate it was tuned at.
local DECAY = 0.995
local DECAY_RATE = 60
local STOP_SPEED = 5
-- The legacy cleanup removed a dead player's parts after this long.
local DEATH_LINGER = 5
local MAX_BALLS = 20
-- Not legacy (its balls stayed until the thrower died): a ball is removed after a while,
-- the longer the more it was charged, so they do not pile up on the server.
local LIFETIME_BASE = 10
local LIFETIME_PER_CHARGE = 0.5

local TEMPLATE_PATH = { "Models", "Fruits", "Candy", "Power3", "CandyJawbreaker" }

-- Balls lying around, per thrower; the cleanup of a thrower is wired once.
local live: { [CharacterEntity]: { BasePart } } = {}

local function findTemplate(): BasePart?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in TEMPLATE_PATH do
		current = if current then current:FindFirstChild(name) else nil
	end
	return if current and current:IsA("BasePart") then current else nil
end

local function clear(entity: CharacterEntity)
	local balls = live[entity]
	if balls then
		live[entity] = nil
		for _, ball in balls do
			ball:Destroy()
		end
	end
end

local function track(self: any, ball: BasePart)
	local entity: CharacterEntity = self.Entity
	local balls = live[entity]
	if not balls then
		balls = {}
		live[entity] = balls
		entity.Died:Once(function()
			task.delay(DEATH_LINGER, clear, entity)
		end)
		local connection: RBXScriptConnection
		connection = self.Services.Character.EntityRemoving:Connect(function(removed: CharacterEntity)
			if removed == entity then
				connection:Disconnect()
				clear(entity)
			end
		end)
	end

	table.insert(balls, ball)
	while #balls > MAX_BALLS do
		local oldest = table.remove(balls, 1)
		if oldest then
			oldest:Destroy()
		end
	end
end

local function makeBall(charge: number, scale: number, haki: boolean, colors: string): BasePart
	local ball: BasePart
	local template = findTemplate()
	if template then
		ball = template:Clone()
		-- The legacy template carried its damage script and the values it read.
		for _, descendant in ball:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("ValueBase") then
				descendant:Destroy()
			end
		end
	else
		local plain = Instance.new("Part")
		plain.Shape = Enum.PartType.Ball
		plain.Material = Enum.Material.SmoothPlastic
		plain.Color = FALLBACK_COLOR
		plain.Size = Vector3.new(FALLBACK_DIAMETER, FALLBACK_DIAMETER, FALLBACK_DIAMETER)
		ball = plain
	end

	local authored = ball.Size
	local percent = math.clamp(charge / 100, 0, 1)
	ball.Size = Vector3.new(
		math.max(math.max(authored.X * percent, MIN_AXIS) * scale, MIN_SIZE),
		math.max(math.max(authored.Y * percent, MIN_AXIS) * scale, MIN_SIZE),
		math.max(math.max(authored.Z * percent, MIN_AXIS) * scale, MIN_SIZE)
	)

	local primary = FruitColor.Parse(colors)
	if haki then
		ball.Color = HAKI_COLOR
	elseif primary then
		ball.Color = primary
	end

	ball.Name = "CandyJawbreaker"
	ball.Anchored = false
	ball.CanCollide = false
	return ball
end

local Jawbreaker = Ability.extend()

Jawbreaker.KeepThroughStun = true

function Jawbreaker:CanBegin(): boolean
	return not CandyShared.Stunned(self) and os.clock() - (self.LastRelease or 0) >= RECAST_DELAY
end

function Jawbreaker:OnBegin()
	if self.ChargeStart then
		return
	end

	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	-- The legacy start was `IntValue.Value = time()`: rounded to the nearest second.
	local now = time()
	self.ChargeStart -= now - math.round(now)

	local hand = if self.UseLeft then "Left" else "Right"
	self.Entity:SetStatus(STATUS, `{hand}|{self:GetColorString()}`, nil, true)
end

function Jawbreaker:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end

	local entity: CharacterEntity = self.Entity
	entity:ClearStatus(STATUS)
	if CandyShared.Stunned(self) then
		return
	end

	local left = self.UseLeft == true
	self.UseLeft = not left
	self.LastRelease = os.clock()
	self:StartCooldown(RECAST_DELAY)

	local affinity = self:GetAffinity("Sniper")
	local scale = affinity * self:GetLevelScale("Sniper")
	local multiplier, haki = CandyShared.Haki(self)
	local damage = math.clamp(charge * DAMAGE_PER_CHARGE * scale, MIN_DAMAGE * affinity, MAX_DAMAGE * affinity)
		* DAMAGE_MULTIPLIER
		* multiplier
	local speed = BASE_SPEED + SPEED_PER_CHARGE * charge

	local arm = entity.Model:FindFirstChild(if left then "Left Arm" else "Right Arm")
	local handFrame = if arm and arm:IsA("BasePart") then arm.CFrame else entity.Root.CFrame
	local origin = handFrame.Position
	local direction = input.AimPosition - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	-- The ball falls and loses DECAY of its speed every 1 / DECAY_RATE s: the lead allows for both.
	direction = Projectile.Lead(entity, origin, direction.Unit, speed, nil, Workspace.Gravity, -DECAY_RATE * math.log(DECAY)).Unit

	self:PlayEffect(EFFECT, origin, { Hand = if left then "Left" else "Right" })

	local ball = makeBall(charge, scale, haki, self:GetColorString())
	ball.CFrame = handFrame
	ball.Parent = World.Abilities()
	-- Simulated by the server for everyone, as the legacy part was.
	ball:SetNetworkOwner(nil)
	track(self, ball)
	Debris:AddItem(ball, LIFETIME_BASE + LIFETIME_PER_CHARGE * charge)

	task.delay(SOLID_DELAY, function()
		if ball.Parent then
			ball.CanCollide = true
		end
	end)

	local characterService = self.Services.Character
	local struck: { [CharacterEntity]: boolean } = {}
	ball.Touched:Connect(function(hit: BasePart)
		local target: CharacterEntity? = characterService:GetEntityFromPart(hit)
		if not target or target == entity or struck[target] or target.Dead or not target.Spawned then
			return
		end
		-- Found by touch, not by Hitbox: the ally rule is asked here.
		if Allies.Spares(entity, target) then
			return
		end
		struck[target] = true
		self:Damage(target, damage, if haki then "Haki" else "Melee", EFFECT, false)
		CandyShared.Touch(self, target, TOUCH_HITS)
	end)

	ball.AssemblyLinearVelocity = direction * speed

	-- The legacy decay: one Heartbeat connection per ball, gone once the ball has stopped.
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		if not ball.Parent then
			connection:Disconnect()
			return
		end
		local velocity = ball.AssemblyLinearVelocity * DECAY ^ (deltaTime * DECAY_RATE)
		if velocity.Magnitude < STOP_SPEED then
			ball.AssemblyLinearVelocity = Vector3.zero
			connection:Disconnect()
		else
			ball.AssemblyLinearVelocity = velocity
		end
	end)
end

function Jawbreaker:OnInterrupt()
	-- Balls already thrown are physical objects with a life of their own (see the header):
	-- only the charge is dropped here.
	self.ChargeStart = nil
	self.Entity:ClearStatus(STATUS)
end

return Jawbreaker
