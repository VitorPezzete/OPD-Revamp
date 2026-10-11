--!strict
--[[
	Chilly fruit - Freezing Punch (charged).

	While the key is held the fist is cased in ice (Effects.Status.ChillyPunchCharging)
	and anything it touches is frozen. On release, a charge above 25 also throws an ice
	ball towards the aim point that freezes whoever touches it.

	With s = melee affinity * (melee level / 500):
	- Freeze: 25 * s damage per second for 5 * s seconds (see Freeze.luau). The punch and
	  the ball deal no other damage, as in the legacy game.
	- Charge: 25 per second held, 4 to 100 (measured on the server). The legacy game kept
	  the start of the charge in an IntValue, which rounded it to the nearest whole
	  second; that rounding (up to half a second more or less charge) is reproduced.
	- Hands alternate, right first.
	- Cannot be started while Ice Wave is charging, as on the legacy client.

	The ball is a real physical part, as in the legacy game, because everything about it
	is physics: it is the Rock1 template, unanchored and owned by the server, sized
	template size * charge / 100 * (level / 500) / (3 - affinity) and launched from the
	hand at 350 * charge / 100 * affinity / 2 studs per second towards the aim point. It
	falls, bounces and rolls; it does not collide for the first 0.25 s and is solid
	afterwards; its velocity loses 0.0005 % per frame (the legacy 0.999995, at 60 frames
	per second) and it is stopped under 5 studs per second. It freezes whoever touches it
	during its first 5 s (the legacy "Decay" counter) and is a harmless rock after that.
	A character it touched is left alone by this user's balls for 5 s.
	Lifetime, as in the legacy game: the balls of a thrower are removed 5 s after it dies.
	They also go when its character is removed (respawn, leaving). One thing is not
	legacy: a thrower keeps at most MAX_BALLS balls, the oldest going first.
	Since the part replicates, clients draw nothing for it.

	Body of the ball: the Rock1 template is a MeshPart whose collision is its bounding box
	(CollisionFidelity Box, which a script cannot change), so a round rock rolled and hit
	like a crate. The mesh is now only the look - massless, touching and colliding with
	nothing - welded inside an invisible Part of Shape Ball whose diameter is the mean of
	the mesh's three axes. That sphere is the ball: it carries the velocity, the
	collisions, the Touched contacts and the network ownership.

	Legacy problems fixed here:
	- Freeze values lived in NumberValues shared by the script, the hand and every ball in
	  flight, so a later cast rewrote the freeze of an earlier ball.
	- The charge was only started when the previous one had been released; a lost release
	  blocked the power until respawn.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Allies = require(ServerStorage.Server.Modules.Allies)

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local Freeze = require(script.Parent.Freeze)

local STATUS = "ChillyPunchCharging"
local WAVE_STATUS = "ChillyWaveCharging"

local FREEZE_DAMAGE = 25
local FREEZE_DURATION = 5
local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local BALL_MIN_CHARGE = 25
local BALL_SPEED = 350
-- The ball freezes for this long after the throw (legacy "Decay").
local BALL_FREEZE_TIME = 5
-- A character a ball touched is left alone by this user's balls for this long.
local BALL_REHIT_DELAY = 5
local BALL_SOLID_DELAY = 0.25
-- Share of the velocity kept per legacy frame, and the frame rate it was tuned at.
local BALL_DECAY = 0.999995
local BALL_DECAY_RATE = 60
local BALL_STOP_SPEED = 5
local BALL_MIN_SIZE = 0.05
-- The legacy cleanup removed a dead player's parts after this long.
local DEATH_LINGER = 5
local MAX_BALLS = 20
-- Not legacy (its balls stayed until the thrower died): a ball is removed after a while,
-- the longer the more it was charged, so they do not pile up on the server.
local LIFETIME_BASE = 10
local LIFETIME_PER_CHARGE = 0.5
-- Used only when the Rock1 template cannot be found (guess).
local BALL_DEFAULT_SIZE = Vector3.new(6, 6, 6)
local BALL_DEFAULT_COLOR = Color3.fromRGB(128, 187, 219)
-- The iced fist is checked this often while held, within this radius of the arm.
local TOUCH_TICK = 0.2
local TOUCH_RADIUS = 2
-- A charge held longer than this is dropped, so the touch tick is bounded.
local MAX_HOLD = 30

local FreezingPunch = Ability.extend()

FreezingPunch.Debounce = 0.1

type CharacterEntity = CharacterEntity.CharacterEntity

-- Balls lying around, per thrower; the cleanup of a thrower is wired once.
local live: { [CharacterEntity]: { BasePart } } = {}

local function findTemplate(): BasePart?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", "Chilly", "Power2", "Rock1" } do
		current = current and current:FindFirstChild(name)
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

-- The ball at `cframe`: the spherical body (see the header), with the rock mesh inside it.
local function makeBall(sizeScale: number, colors: string, cframe: CFrame): BasePart
	local body = Instance.new("Part")
	body.Name = "ChillyIceBall"
	body.Shape = Enum.PartType.Ball
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Anchored = false
	body.CanCollide = false
	body.CFrame = cframe

	-- First fruit color when the user saved one; the legacy ball had no haki color.
	local primary = FruitColor.Parse(colors)

	local template = findTemplate()
	if not template then
		local diameter = math.max(BALL_DEFAULT_SIZE.X * sizeScale, BALL_MIN_SIZE)
		body.Size = Vector3.new(diameter, diameter, diameter)
		body.Material = Enum.Material.Ice
		body.Color = primary or BALL_DEFAULT_COLOR
		return body
	end

	local mesh = template:Clone()
	for _, descendant in mesh:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("ValueBase") then
			descendant:Destroy()
		end
	end
	local size = mesh.Size * sizeScale
	mesh.Size = Vector3.new(
		math.max(size.X, BALL_MIN_SIZE),
		math.max(size.Y, BALL_MIN_SIZE),
		math.max(size.Z, BALL_MIN_SIZE)
	)
	if primary then
		mesh.Color = primary
	end
	mesh.Name = "Rock"
	mesh.Anchored = false
	mesh.CanCollide = false
	mesh.CanTouch = false
	mesh.CanQuery = false
	mesh.Massless = true
	mesh.CFrame = cframe

	local diameter = (mesh.Size.X + mesh.Size.Y + mesh.Size.Z) / 3
	body.Size = Vector3.new(diameter, diameter, diameter)
	body.Transparency = 1
	body.CastShadow = false
	-- It weighs, slides and bounces like the rock's own material.
	body.Material = mesh.Material
	body.CustomPhysicalProperties = mesh.CustomPhysicalProperties

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = mesh
	weld.Parent = mesh
	mesh.Parent = body
	return body
end

local function getHandPosition(self: any): Vector3
	local arm = self.Entity.Model:FindFirstChild(if self.UseLeft then "Left Arm" else "Right Arm")
	if arm and arm:IsA("BasePart") then
		return arm.Position
	end
	return self.Entity.Root.Position
end

local function freezeAtHand(self: any)
	local scale = self:GetAffinity("Melee") * self:GetLevelScale("Melee")
	for _, target in Hitbox.Sphere(getHandPosition(self), TOUCH_RADIUS, self.Entity) do
		Freeze.Apply(self, target, FREEZE_DAMAGE * scale, FREEZE_DURATION * scale)
	end
end

function FreezingPunch:CanBegin(): boolean
	return not self.Entity:HasStatus(WAVE_STATUS)
end

function FreezingPunch:OnBegin()
	if self.ChargeStart then
		return
	end

	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	-- The legacy start was `IntValue.Value = time()`: rounded to the nearest second.
	local now = time()
	self.ChargeStart -= now - math.round(now)
	self.Run = (self.Run or 0) + 1
	local run = self.Run
	local started = os.clock()

	local hand = if self.UseLeft then "Left" else "Right"
	self.Entity:SetStatus(STATUS, `{hand}|{self:GetColorString()}`, nil, true)

	local function touch()
		if self.Run ~= run then
			return
		end
		if os.clock() - started > MAX_HOLD then
			self:OnInterrupt()
			return
		end
		freezeAtHand(self)
		task.delay(TOUCH_TICK, touch)
	end
	task.delay(TOUCH_TICK, touch)
end

function FreezingPunch:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end

	-- Stops the touch tick; the punch itself is one last contact check.
	self.Run = (self.Run or 0) + 1
	freezeAtHand(self)

	local origin = getHandPosition(self)
	self.UseLeft = not self.UseLeft
	self.Entity:ClearStatus(STATUS)

	if charge <= BALL_MIN_CHARGE then
		return
	end

	local entity: CharacterEntity = self.Entity
	local affinity = self:GetAffinity("Melee")
	local levelScale = self:GetLevelScale("Melee")
	local scale = affinity * levelScale

	local direction = input.AimPosition - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	direction = direction.Unit

	local speed = BALL_SPEED * charge / 100 * affinity / 2
	-- Affinity is 1 to 2; the clamp only guards the division.
	local sizeScale = charge / 100 * levelScale / math.max(3 - affinity, 0.5)
	if speed <= 0 or sizeScale <= 0 then
		return
	end
	direction = Projectile.Lead(entity, origin, direction, speed, nil, workspace.Gravity).Unit

	-- The hand that punched (the turn has already passed to the other one).
	local arm = entity.Model:FindFirstChild(if self.UseLeft then "Right Arm" else "Left Arm")
	local ball = makeBall(
		sizeScale,
		self:GetColorString(),
		if arm and arm:IsA("BasePart") then arm.CFrame else CFrame.new(origin)
	)
	ball.Parent = World.Abilities()
	-- Simulated by the server for everyone, as the legacy part was.
	ball:SetNetworkOwner(nil)
	track(self, ball)
	Debris:AddItem(ball, LIFETIME_BASE + LIFETIME_PER_CHARGE * charge)

	task.delay(BALL_SOLID_DELAY, function()
		if ball.Parent then
			ball.CanCollide = true
		end
	end)

	local characterService = self.Services.Character
	local thrownAt = os.clock()
	local freezeDamage = FREEZE_DAMAGE * scale
	local freezeDuration = FREEZE_DURATION * scale
	local touchConnection: RBXScriptConnection
	touchConnection = ball.Touched:Connect(function(hit: BasePart)
		local now = os.clock()
		if now - thrownAt > BALL_FREEZE_TIME then
			touchConnection:Disconnect()
			return
		end
		local target: CharacterEntity? = characterService:GetEntityFromPart(hit)
		if not target or target == entity or target.Dead or not target.Spawned then
			return
		end
		-- Found by touch, not by Hitbox: the ally rule is asked here.
		if Allies.Spares(entity, target) then
			return
		end
		local touched: { [CharacterEntity]: number } = self.BallTouched
		if not touched then
			touched = setmetatable({}, { __mode = "k" }) :: any
			self.BallTouched = touched
		end
		if now < (touched[target] or 0) then
			return
		end
		touched[target] = now + BALL_REHIT_DELAY
		Freeze.Apply(self, target, freezeDamage, freezeDuration)
	end)

	ball.AssemblyLinearVelocity = direction * speed

	-- The legacy decay: one Heartbeat connection per ball, gone once the ball has stopped.
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		if not ball.Parent then
			connection:Disconnect()
			return
		end
		local velocity = ball.AssemblyLinearVelocity * BALL_DECAY ^ (deltaTime * BALL_DECAY_RATE)
		if velocity.Magnitude < BALL_STOP_SPEED then
			ball.AssemblyLinearVelocity = Vector3.zero
			connection:Disconnect()
		else
			ball.AssemblyLinearVelocity = velocity
		end
	end)
end

function FreezingPunch:OnInterrupt()
	-- Balls already thrown are physical objects with a life of their own (see the header):
	-- only the charge and the iced fist are dropped here.
	self.ChargeStart = nil
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return FreezingPunch
