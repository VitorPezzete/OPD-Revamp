--!strict
--[[
	Door fruit - Door Strike: a door opens in front of the aimed character and slams
	into it.

	DESIGNED, NOT PORTED. The Door fruit was a stub in the legacy game: its server script
	("Meme Fruit, No plans on doing this for now") kicked whoever fired the remote and had
	an empty branch per power, and the fruit has no models, animations or sounds. All
	that exists is the ability name, its gate (Melee 100) and the client input: on key
	release it sent the mouse position and the auto-aimed character. Every number below
	is a placeholder chosen to sit next to the other ported fruits; change them freely.

		target:    the character closest to the aim point (within 6 studs), up to 100 studs away
		damage:    melee level * melee affinity   (Melee; doubled and Haki with armament),
		           the same guess as Spin's Spinning Punch. Dodgeable.
		knockback: 60 studs/s away from the caster, 20 up
		cooldown:  1.5 s

	The legacy client chose the victim (it sent the part under its auto-aim); the server
	picks it from the validated aim point.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

local HAKI_STATUS = "Haki"

local RANGE = 100
local AIM_RADIUS = 6
local KNOCKBACK = 60
local KNOCKBACK_LIFT = 20
-- How far in front of the victim the door stands.
local DOOR_DISTANCE = 3

local DoorStrike = Ability.extend()

DoorStrike.Debounce = 1.5

function DoorStrike:CanBegin(input: Ability.AbilityInput): boolean
	return (input.AimPosition - self.Entity.Root.Position).Magnitude <= RANGE + AIM_RADIUS
end

function DoorStrike:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local target = Hitbox.Closest(Hitbox.Sphere(input.AimPosition, AIM_RADIUS, entity), input.AimPosition)
	if not target then
		return
	end

	local origin = entity.Root.Position
	local targetPosition = target.Root.Position
	local flat = Vector3.new(targetPosition.X - origin.X, 0, targetPosition.Z - origin.Z)
	local direction = if flat.Magnitude > 0.1 then flat.Unit else entity.Root.CFrame.LookVector

	local doorPosition = targetPosition - direction * DOOR_DISTANCE
	self:PlayEffect("DoorPanel", doorPosition, { CFrame = CFrame.lookAt(doorPosition, doorPosition + direction) })

	local damage = self:GetLevel("Melee") * self:GetAffinity("Melee")
	local trait = "Melee"
	if entity:HasStatus(HAKI_STATUS) then
		damage *= 2
		trait = "Haki"
	end

	if self:Damage(target, damage, trait, "DoorStrike", true) > 0 then
		self:Impulse(target, direction * KNOCKBACK + Vector3.new(0, KNOCKBACK_LIFT, 0))
	end
end

return DoorStrike
