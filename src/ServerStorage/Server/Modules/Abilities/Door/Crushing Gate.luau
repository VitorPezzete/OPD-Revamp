--!strict
--[[
	Door fruit - Crushing Gate: two gates appear on either side of the aimed point and
	slam shut, crushing everyone between them.

	DESIGNED, NOT PORTED (see Door Strike: the legacy Door fruit had no server logic and
	no assets). The legacy client sent, on key release, the auto-aimed character's
	position or else the mouse position; the gate is Melee 250. Placeholder numbers:

		range:    120 studs (a further aim point is shortened to it)
		area:     12 x 12 x 12 box centred 3 studs above the aimed point, facing away
		          from the caster
		delay:    0.4 s while the gates close (the hit is tested when they meet)
		damage:   1.5 * melee level * melee affinity  (Melee; doubled and Haki with
		          armament). Dodgeable.
		stun:     1 s on everyone damaged
		cooldown: 6 s
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

local HAKI_STATUS = "Haki"
local STUN_NAME = "DoorCrushed"

local RANGE = 120
local SIZE = Vector3.new(12, 12, 12)
local CENTER_HEIGHT = 3
local CLOSE_DELAY = 0.4
local DAMAGE_MULTIPLIER = 1.5
local STUN_SECONDS = 1

local CrushingGate = Ability.extend()

CrushingGate.Debounce = 6

function CrushingGate:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local origin = entity.Root.Position

	local offset = input.AimPosition - origin
	if offset.Magnitude > RANGE then
		offset = offset.Unit * RANGE
	end

	local flat = Vector3.new(offset.X, 0, offset.Z)
	local facing = if flat.Magnitude > 0.1 then flat.Unit else entity.Root.CFrame.LookVector
	local center = origin + offset + Vector3.new(0, CENTER_HEIGHT, 0)
	local cframe = CFrame.lookAt(center, center + facing)

	self:PlayEffect("DoorCrushingGate", center, { CFrame = cframe, Size = SIZE, Delay = CLOSE_DELAY })

	self.Run = (self.Run or 0) + 1
	local run = self.Run

	task.delay(CLOSE_DELAY, function()
		if self.Run ~= run or entity.Dead then
			return
		end

		local damage = DAMAGE_MULTIPLIER * self:GetLevel("Melee") * self:GetAffinity("Melee")
		local trait = "Melee"
		if entity:HasStatus(HAKI_STATUS) then
			damage *= 2
			trait = "Haki"
		end

		for _, target in Hitbox.Box(cframe, SIZE, entity) do
			if self:Damage(target, damage, trait, "DoorCrushingGate", true) > 0 then
				self.Services.Status:ApplyStun(target, STUN_SECONDS, STUN_NAME)
			end
		end
	end)
end

function CrushingGate:OnInterrupt()
	-- Cancels gates that have not closed yet.
	self.Run = (self.Run or 0) + 1
end

return CrushingGate
