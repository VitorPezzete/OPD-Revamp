--!strict
--[[
	Barrier fruit - Slam: a square barrier launched from the user towards the aim point,
	hitting everyone in its path once.

	Side:    clamp(50 * melee affinity * (melee level / cap), 10, 100) studs, 5 thick
	Path:    starts 2 studs behind the root, 100 studs along the aim direction on a
	         1.5 s "Back / Out" curve, of which the first 1.2 s are played
	Damage:  melee level * melee affinity, "Melee"; armament haki doubles it and makes
	         it "Haki". Not dodgeable.
	Cooldown 2 s. Using it removes a standing Wall / Room / Prison, and the user holds
	the barrier pose (BarrierActive) for the 1.2 s of the flight.

	The slab is not an instance on the server: its position is the same easing curve the
	clients tween (Effects.OneShot.BarrierSlam), sampled twelve times, and each sample
	sweeps a box over the distance covered since the previous one.

	KeepThroughStun: a slab already launched keeps flying when its user is stunned, as in
	the legacy game. A stunned user cannot launch one.

	Legacy problems fixed here:
	- Damage came from a Touched connection on a tweened anchored part, which only fires
	  for characters that happen to move into it; a target standing still was often
	  missed. The sweep hits everyone the slab passes through.
	- Start position and direction came from a CFrame sent by the client.
]]
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Construct = require(script.Parent._Construct)

type CharacterEntity = CharacterEntity.CharacterEntity

local BASE_SIDE = 50
local MIN_SIDE = 10
local MAX_SIDE = 100
local THICKNESS = 5
local BACK_OFFSET = 2
local TRAVEL = 100
local TWEEN_SECONDS = 1.5
local LIFETIME = 1.2
local STEPS = 12
local HAKI_MULTIPLIER = 2

local Slam = Ability.extend()

Slam.Debounce = 2
Slam.KeepThroughStun = true

function Slam:CanBegin(): boolean
	return not self.Entity:HasStatus(Construct.StunStatus)
end

function Slam:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	Construct.Clear(entity)
	Construct.SetActive(entity, LIFETIME)

	local rootPosition = entity.Root.Position
	local offset = input.AimPosition - rootPosition
	local direction = if offset.Magnitude > 1e-3 then offset.Unit else entity.Root.CFrame.LookVector

	local side = math.clamp(BASE_SIDE * self:GetLevelScale("Melee") * self:GetAffinity("Melee"), MIN_SIDE, MAX_SIDE)
	local origin = rootPosition - direction * BACK_OFFSET
	local frame = Construct.Frame(origin, direction)

	local haki = self.Services.Haki:IsArmamentActive(entity)
	local damage = self:GetLevel("Melee") * self:GetAffinity("Melee")
	local trait: CombatTypes.DamageTrait = "Melee"
	if haki then
		damage *= HAKI_MULTIPLIER
		trait = "Haki"
	end

	self:PlayEffect("BarrierSlam", origin, {
		Direction = direction,
		Side = side,
		Thickness = THICKNESS,
		Travel = TRAVEL,
		TweenSeconds = TWEEN_SECONDS,
		Lifetime = LIFETIME,
	})

	self.Run = (self.Run or 0) + 1
	local run = self.Run
	local struck: { [CharacterEntity]: boolean } = {}
	local travelled = 0
	local step = 0

	local function advance()
		if self.Run ~= run then
			return
		end

		step += 1
		local alpha = (step * LIFETIME / STEPS) / TWEEN_SECONDS
		local reached = TRAVEL * TweenService:GetValue(alpha, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local near, far = math.min(travelled, reached), math.max(travelled, reached)
		travelled = reached

		local box = frame * CFrame.new(0, 0, -(near + far) / 2)
		for _, target in Hitbox.Box(box, Vector3.new(side, side, far - near + THICKNESS), entity) do
			if not struck[target] then
				struck[target] = true
				self:Damage(target, damage, trait, "BarrierSlam", false)
			end
		end

		if step < STEPS then
			task.delay(LIFETIME / STEPS, advance)
		end
	end
	task.delay(LIFETIME / STEPS, advance)
end

function Slam:OnInterrupt()
	-- Stops a slab in flight.
	self.Run = (self.Run or 0) + 1
end

return Slam
