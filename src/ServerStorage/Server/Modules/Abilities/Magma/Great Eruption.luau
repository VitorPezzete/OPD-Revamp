--!strict
--[[
	Magma fruit - Great Eruption (charged): a fist of magma thrown at the aim point, from
	the right and the left hand in turn.

	Charge: 25 per second held, 4 to 100 (timed on the server).
	With m = melee affinity and s = melee level / cap:
	- damage = clamp(charge * 15 * m * s, 100 * m, 3000 * m), Special;
	  with armament haki at release it is doubled and Haki;
	- burn   = clamp(100 * s * m, 12.5 * m, 100 * m) every 0.5 s for 20 s ("MagmaBurn"),
	  applied to everyone the fist touches, heat-proof or not (as in the legacy game);
	- size   = max(template size * charge / 100, 4) * m * s on each axis (a ball).
	The fist goes through characters AND through the map (the legacy part did not
	collide with anything) and hits each character once.

	Rumble / Smelt / Hot / Plasma owners take no direct damage (DamageModifiers.
	MagmaBurnImmunity, tag "MagmaEruption").

	Flight. The legacy fist was an unanchored, non-colliding part launched at 800 studs/s:
	it lost 1% of its velocity every Heartbeat and fell with gravity, so it left fast,
	slowed down and sank through the ground a few hundred studs away. The same curve is
	followed here from the time elapsed instead of per frame (DRAG is the 1% per frame of
	a 60 Hz server), by the server for the hits and by every client for the visual
	(Effects.OneShot.MagmaEruption, which gets the same numbers):
		position(t) = origin + direction * SPEED / DRAG * (1 - e^(-DRAG * t))
		              - up * gravity / DRAG * (t - (1 - e^(-DRAG * t)) / DRAG)
	It is not a Projectile: that module stops on the map and flies straight.

	Legacy problems fixed here:
	- The decay ran once per server frame, so the range changed with the frame rate.
	  (The legacy loop also froze the fist for a frame when its speed dropped under 5
	  studs/s, which only a fist thrown straight up could reach; not reproduced.)
	- The legacy part lived until it fell under the world (the engine removes parts
	  below Workspace.FallenPartsDestroyHeight): a fist thrown level is gone in under
	  4 s, one lobbed upwards comes back down and still hits. The flight ends the same
	  way here, with MAX_LIFETIME as a bound.
	- A looping sound was added to the hand on every charge and never removed.

	The template size is read from the asset in ReplicatedStorage (FALLBACK_SIZE without it).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Allies = require(ServerStorage.Server.Modules.Allies)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

local CHARGE_STATUS = "MagmaCharging"
local EFFECT = "MagmaEruption"
local DAMAGE_TAG = "MagmaEruption"
local BURN = "MagmaBurn"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100

local DAMAGE_PER_CHARGE = 15
local DAMAGE_MIN = 100
local DAMAGE_MAX = 3000
local HAKI_MULTIPLIER = 2

local BURN_DAMAGE = 100
local BURN_MIN = 12.5
local BURN_INTERVAL = 0.5
local BURN_TICKS = 40

local MIN_SIZE = 4
local FALLBACK_SIZE = Vector3.new(30.6, 30.6, 30.6)
local SPEED = 800
local DRAG = -60 * math.log(0.99)
-- Bound on a flight; the fist normally ends by falling under the world well before.
local MAX_LIFETIME = 10
-- Seconds between two sweeps of the fists in flight (each covers the path since the last).
local STEP = 0.05
-- Same body allowance as Hitbox.
local BODY_RADIUS = 2.5
-- The fist is seen from further than a usual effect: it crosses that distance in a second.
local EFFECT_RADIUS = 900

type Fist = {
	Ability: any,
	Origin: Vector3,
	Direction: Vector3,
	Gravity: number,
	Start: number,
	Position: Vector3,
	Radius: number,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	Burn: number,
	Struck: { [CharacterEntity]: boolean },
}

local GreatEruption = Ability.extend()

local fists: { Fist } = {}
local connection: RBXScriptConnection? = nil
local elapsed = 0

local function getTemplateSize(): Vector3
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", "Magma", "Power1", "Great Eruption" } do
		current = if current then current:FindFirstChild(name) else nil
	end
	return if current and current:IsA("BasePart") then current.Size else FALLBACK_SIZE
end

local function positionAt(fist: Fist, age: number): Vector3
	local decayed = 1 - math.exp(-DRAG * age)
	return fist.Origin
		+ fist.Direction * (SPEED / DRAG * decayed)
		- Vector3.yAxis * (fist.Gravity / DRAG * (age - decayed / DRAG))
end

-- Everyone whose body the ball crossed between two steps.
local function sweep(fist: Fist, from: Vector3, to: Vector3)
	local self = fist.Ability
	local caster: CharacterEntity = self.Entity
	local segment = to - from
	local lengthSquared = segment:Dot(segment)
	local reach = fist.Radius + BODY_RADIUS

	for _, target: CharacterEntity in self.Services.Character:GetEntities() do
		if target == caster or fist.Struck[target] or target.Dead or not target.Spawned then
			continue
		end
		-- Walks the characters itself, not through Hitbox: the ally rule is asked here.
		if Allies.Spares(caster, target) then
			continue
		end
		local offset = target.Root.Position - from
		local along = if lengthSquared > 0 then math.clamp(offset:Dot(segment) / lengthSquared, 0, 1) else 0
		if (offset - segment * along).Magnitude <= reach then
			fist.Struck[target] = true
			self:Damage(target, fist.Damage, fist.Trait, DAMAGE_TAG, false)
			self.Services.Status:ApplyDot(target, BURN, {
				Source = caster,
				Damage = fist.Burn,
				Interval = BURN_INTERVAL,
				Ticks = BURN_TICKS,
				Trait = "Special",
			})
		end
	end
end

local function step(deltaTime: number)
	elapsed += deltaTime
	if elapsed < STEP then
		return
	end
	elapsed = 0

	local now = os.clock()
	for index = #fists, 1, -1 do
		local fist = fists[index]
		local caster: CharacterEntity = fist.Ability.Entity
		local age = math.min(now - fist.Start, MAX_LIFETIME)
		if not caster.Dead and caster.Model.Parent then
			local position = positionAt(fist, age)
			sweep(fist, fist.Position, position)
			fist.Position = position
			if position.Y < Workspace.FallenPartsDestroyHeight then
				age = MAX_LIFETIME
			end
		else
			age = MAX_LIFETIME
		end
		if age >= MAX_LIFETIME then
			table.remove(fists, index)
		end
	end

	if #fists == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

function GreatEruption:OnBegin()
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	-- "<hand>|<colors>": the hand that burns while charging and throws the fist.
	self.Entity:SetStatus(CHARGE_STATUS, `{if self.Left then "Left" else "Right"}|{self:GetColorString()}`, nil, true)
end

function GreatEruption:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	self.Entity:ClearStatus(CHARGE_STATUS)
	if not charge then
		return
	end

	local entity: CharacterEntity = self.Entity
	local left: boolean = self.Left == true
	self.Left = not left

	local affinity = self:GetAffinity("Melee")
	local scale = self:GetLevelScale("Melee")
	local percent = charge / CHARGE_MAX
	local multiplier = affinity * scale

	local damage = math.clamp(charge * DAMAGE_PER_CHARGE * multiplier, DAMAGE_MIN * affinity, DAMAGE_MAX * affinity)
	local trait: CombatTypes.DamageTrait = "Special"
	local haki = self.Services.Haki:IsArmamentActive(entity)
	if haki then
		damage *= HAKI_MULTIPLIER
		trait = "Haki"
	end
	local burn = math.clamp(BURN_DAMAGE * multiplier, BURN_MIN * affinity, BURN_DAMAGE * affinity)

	local template = getTemplateSize()
	local diameter = math.max(math.max(template.X, template.Y, template.Z) * percent, MIN_SIZE) * multiplier

	local arm = entity.Model:FindFirstChild(if left then "Left Arm" else "Right Arm")
	local origin = if arm and arm:IsA("BasePart") then arm.Position else entity.Root.Position
	local direction = input.AimPosition - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	direction = Projectile.Lead(entity, origin, direction.Unit, SPEED, nil, Workspace.Gravity, DRAG).Unit

	local gravity = Workspace.Gravity
	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		Speed = SPEED,
		Drag = DRAG,
		Gravity = gravity,
		Lifetime = MAX_LIFETIME,
		Percent = percent,
		Multiplier = multiplier,
		Haki = haki,
		Hand = if left then "Left" else "Right",
	}, EFFECT_RADIUS)

	table.insert(fists, {
		Ability = self,
		Origin = origin,
		Direction = direction,
		Gravity = gravity,
		Start = os.clock(),
		Position = origin,
		Radius = diameter / 2,
		Damage = damage,
		Trait = trait,
		Burn = burn,
		Struck = {},
	})
	if not connection then
		elapsed = 0
		connection = RunService.Heartbeat:Connect(step)
	end
end

-- A fist already thrown keeps flying, as the legacy one did.
function GreatEruption:OnInterrupt()
	self.ChargeStart = nil
	self.Entity:ClearStatus(CHARGE_STATUS)
end

return GreatEruption
