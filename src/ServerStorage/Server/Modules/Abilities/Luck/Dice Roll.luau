--!strict
--[[
	Luck fruit - Dice Roll (charged): throws a die that explodes two seconds later; the
	face it shows (1-6, 4-6 while lucky) multiplies everything.

	Charge:    25 per second held, 4 to 100 (4 s for a full charge). 5 s cooldown from
	           the release (the legacy client waited 5 s after the throw).
	Throw:     the die leaves 10 studs above the caster with a velocity of
	           200 * charge% studs/s along the line from the caster to the aim point,
	           and from there it is a thrown object: it falls, bounces and slides until
	           its fuse runs out. How far it goes is decided by the charge, not by where
	           the aim point is.
	           If a character stands on the aimed line (Shared.AimTarget, the legacy auto
	           target) it is thrown at that character at 350 * charge% instead, and the
	           moment it comes within 10 * DEFENSE affinity studs of it, it sticks to it.
	Blast:     after 2 s, where the die is (on the character it stuck to, wherever that
	           character went): radius 25 * sniper affinity * (sniper level / 500) * face / 2
	Damage:    500 * sniper affinity * face * 2, "Special", not dodgeable
	Luck:      +2.5 * sniper affinity per character in the blast, then
	           + face ^ sniper affinity

	The legacy die was a physical part on the server. Its two seconds are worked out
	here at the throw (simulate): gravity, a bounce that keeps half of the speed into the
	surface, and the friction of a part that cannot roll (the die was held face up by an
	AlignOrientation, so it slid) - the default elasticity 0.5 and friction 0.3 of a
	Roblox part. Characters do not stop it. Effects.OneShot.LuckDice draws the same path.

	Like the other Luck powers it had no "powers disabled" check in the legacy game: it
	can be charged and thrown while stunned, and a die in the air explodes whatever
	happens to its caster short of death or a seal.

	Legacy problems fixed here:
	- The charge was stored under Power6's key and the cooldown returned *after* the
	  charge had started, so a press during the cooldown still armed a full charge.
	- The direction came from a client position and a client-chosen target part.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local EFFECT = "LuckDice"
local CHARGE_STATUS = "LuckCharging"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local COOLDOWN = 5
-- How far away a character on the aimed line can be picked as the target.
local AIM_RANGE = 500
local SPEED = 200
local HOMING_SPEED = 350
local STICK_RADIUS = 10
local FUSE = 2
-- The die leaves from above the caster, as the legacy one did.
local THROW_HEIGHT = 10
local DAMAGE = 500
local BLAST_DIAMETER = 25
local LUCK_PER_HIT = 2.5

-- Flight of the die: step of the simulation, default elasticity and friction of a part.
local SIM_STEP = 1 / 30
local RESTITUTION = 0.5
local FRICTION = 0.3
-- Distance kept from a surface after touching it.
local SKIN = 0.05
-- One point of the path out of this many steps is sent to the clients (every 0.1 s).
local SAMPLE_EVERY = 3

local DiceRoll = Ability.extend()
-- The legacy script never checked for disabled powers: a seal does not stop it.
DiceRoll.IgnoreSeal = true

DiceRoll.KeepThroughStun = true

--[[
	The two seconds of a thrown die. Returns the points it passes (one every
	SAMPLE_EVERY steps, the last one being where it is when the fuse runs out or where
	it stuck) and whether it stuck to `target`.
]]
local function simulate(
	self: any,
	origin: Vector3,
	velocity: Vector3,
	target: CharacterEntity?,
	stickRadius: number
): ({ Vector3 }, boolean)
	local ignored: { Instance } = {}
	for model in self.Services.Character:GetEntities() do
		table.insert(ignored, model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored
	params.RespectCanCollide = true

	local gravity = Workspace.Gravity
	local restingSpeed = 2 * gravity * SIM_STEP
	local targetPosition = if target then target.Root.Position else nil

	local points: { Vector3 } = { origin }
	local position = origin
	local steps = math.round(FUSE / SIM_STEP)
	for step = 1, steps do
		velocity += Vector3.new(0, -gravity * SIM_STEP, 0)
		local move = velocity * SIM_STEP
		local result = if move.Magnitude > 1e-4 then Workspace:Raycast(position, move, params) else nil
		if result then
			local normal = result.Normal
			position = result.Position + normal * SKIN
			local into = -velocity:Dot(normal)
			local along = velocity + normal * into
			local speed = along.Magnitude
			if into > restingSpeed then
				-- A bounce: half of the speed into the surface comes back, and friction
				-- takes its share of the rest.
				local loss = FRICTION * (1 + RESTITUTION) * into
				along = if speed > loss then along * (1 - loss / speed) else Vector3.zero
				velocity = along + normal * (into * RESTITUTION)
			else
				-- Lying on it: it slides and friction slows it down.
				local loss = FRICTION * gravity * SIM_STEP
				velocity = if speed > loss then along * (1 - loss / speed) else Vector3.zero
			end
		else
			position += move
		end

		if targetPosition and (targetPosition - position).Magnitude < stickRadius then
			table.insert(points, targetPosition)
			return points, true
		end
		if step % SAMPLE_EVERY == 0 or step == steps then
			table.insert(points, position)
		end
	end
	return points, false
end

local function explode(self: any, landing: Vector3, stuck: CharacterEntity?, face: number, run: number)
	if self.Run ~= run then
		return
	end
	local entity: CharacterEntity = self.Entity
	local sniper = self:GetAffinity("Sniper")

	local center = landing
	if stuck and not stuck.Dead and stuck.Model.Parent ~= nil then
		center = stuck.Root.Position
	end

	local radius = BLAST_DIAMETER * sniper * self:GetLevelScale("Sniper") * face / 2
	local damage = DAMAGE * sniper * face * 2
	for _, target in Hitbox.Sphere(center, radius, entity) do
		self:Damage(target, damage, "Special", EFFECT, false)
		Shared.Add(entity, LUCK_PER_HIT * sniper)
	end
	Shared.Add(entity, face ^ sniper)
end

function DiceRoll:CanBegin(): boolean
	return not self.ChargeStart and os.clock() >= (self.ReadyAt or 0)
end

function DiceRoll:OnBegin()
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	self.Entity:SetStatus(CHARGE_STATUS, true, nil, true)
end

function DiceRoll:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end

	local entity: CharacterEntity = self.Entity
	entity:ClearStatus(CHARGE_STATUS)
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local face = Shared.RollDie(entity)
	local fraction = charge / CHARGE_MAX
	local rootPosition = entity.Root.Position
	local origin = rootPosition + Vector3.new(0, THROW_HEIGHT, 0)

	-- The direction is taken from the caster, not from the die above it.
	local aimed = Shared.AimTarget(entity, input.AimPosition, AIM_RANGE)
	local goal = if aimed then aimed.Root.Position else input.AimPosition
	local offset = goal - rootPosition
	local direction = if offset.Magnitude > 0.05 then offset.Unit else entity.Root.CFrame.LookVector
	local speed = (if aimed then HOMING_SPEED else SPEED) * fraction

	local points, sticks =
		simulate(self, origin, direction * speed, aimed, STICK_RADIUS * self:GetAffinity("Defense"))
	local stuck: CharacterEntity? = if sticks then aimed else nil
	local landing = points[#points]

	self:PlayEffect(EFFECT, origin, {
		Path = points,
		PathStep = SIM_STEP * SAMPLE_EVERY,
		Landing = landing,
		Target = if stuck then stuck.Model else nil,
		Face = face,
		Fuse = FUSE,
		Size = BLAST_DIAMETER * self:GetAffinity("Sniper") * self:GetLevelScale("Sniper") * face,
	})

	self.Run = (self.Run or 0) + 1
	task.delay(FUSE, explode, self, landing, stuck, face, self.Run)
end

function DiceRoll:OnInterrupt()
	-- Drops the charge (Ability.Destroy already cleared its start) and any die in the air.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(CHARGE_STATUS)
end

return DiceRoll
