--!strict
--[[
	Candy fruit - Syrup Wave: a wide wave of syrup thrown towards the aim point.

	With f = melee affinity * (melee level / cap):
	- the wave is 45 * f wide, 5 * f tall and 15 * f deep; it leaves from the root at
	  150 studs per second and lives 1 s (it goes through walls and characters);
	- each character it crosses takes 100 * f once, Special, not dodgeable (doubled and
	  "Haki" with armament haki) and is stuck: CandyTouched for floor(3 * f) s;
	- 1 s between two waves.
	- KeepThroughStun: a wave already thrown keeps going when its caster is stunned, as in
	  the legacy game (it cannot be thrown while stunned).

	Visual: Effects.OneShot.CandyWave.

	Legacy problem fixed here: the wave was an unanchored server part pushed by a
	BodyVelocity with a Touched connection; it is a box swept against the tracked
	characters now (CandyShared.Sweep).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local CandyShared = require(script.Parent._Shared)

local EFFECT = "CandyWave"

local DAMAGE = 100
local TOUCH_HITS = 3
local SPEED = 150
local LIFETIME = 1
-- Width, height, depth at f = 1.
local SIZE = Vector3.new(45, 5, 15)

local SyrupWave = Ability.extend()

SyrupWave.Debounce = 1
SyrupWave.KeepThroughStun = true

function SyrupWave:CanBegin(): boolean
	return not CandyShared.Stunned(self)
end

function SyrupWave:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local factor = self:GetAffinity("Melee") * self:GetLevelScale("Melee")
	local multiplier, haki = CandyShared.Haki(self)
	local damage = DAMAGE * factor * multiplier

	local origin = entity.Root.Position
	local direction = input.AimPosition - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	direction = direction.Unit

	CandyShared.Sweep(self, origin, direction, SPEED, LIFETIME, SIZE * factor, function(target: CharacterEntity.CharacterEntity)
		CandyShared.Touch(self, target, TOUCH_HITS * factor)
		self:Damage(target, damage, if haki then "Haki" else "Special", EFFECT, false)
	end)

	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		Speed = SPEED,
		Lifetime = LIFETIME,
		Scale = factor,
		Haki = haki,
	})
end

function SyrupWave:OnInterrupt()
	-- A wave still in flight vanishes.
	self.Epoch = (self.Epoch or 0) + 1
end

return SyrupWave
