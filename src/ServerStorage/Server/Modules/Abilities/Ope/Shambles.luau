--!strict
--[[
	Ope fruit - Shambles: teleport inside the Room.

	Needs the caster inside their open Room and 30 stamina.
	- Aiming at a character that is inside the Room (and not seated): the two swap places.
	- Otherwise, if the aimed point is inside the Room: the caster teleports there,
	  facing the world's default direction (the legacy `CFrame.new(point)` dropped the
	  caster's rotation).
	Both cost 30 stamina.

	Who is "aimed at": the legacy client first asked its aim assist (AimModule, "fov" 500)
	for the character closest to the line of sight - within min(500 / (distance along
	the line + 10), 20) degrees of it, anywhere between the camera and the point under
	the mouse - and only then fell back to the part under the mouse. The same cone is
	measured here, from the caster's head (the server does not know the camera), so a
	swap does not need the cursor on the target, only near it.

	After a swap, the swapped entity is left for one second in the caster's
	non-replicated "OpeShamblesSwap" status: Scalpel reads it to steal the heart of
	whoever was swapped while its hand was out (the legacy Scalpel + Shambles combo).

	Legacy problems fixed here:
	- The client sent the part under its mouse (or its aim assist pick) as the target;
	  the server now works it out from the validated aim point.
	- Aiming at a seated character teleported the caster to the mouse for free, without
	  checking that the point was inside the Room.
	- The teleport placed the root AT the aimed ground point (half buried, then pushed
	  out by the humanoid); it now lands the 3 studs above it where that ended.
	- Left out: the "SelfDestruct" check (another fruit's state, no equivalent yet) and
	  the Rock swap (its only source, Power5, was commented out in the legacy).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local OpeRoom = require(script.Parent.OpeRoom)

local SWAP_STATUS = "OpeShamblesSwap"

local COST = 30
-- Legacy aim assist: degrees = min(ASSIST_FOV / (distance along the line + 10), ASSIST_MAX).
local ASSIST_FOV = 500
local ASSIST_MAX_DEGREES = 20
local ASSIST_MIN_DISTANCE = 0.5
-- A character this close to the aim point is "under the mouse" (the legacy fallback).
local AIM_RADIUS = 1
local GROUND_OFFSET = Vector3.new(0, 3, 0)
local SWAP_MEMORY = 1

local Shambles = Ability.extend()

-- The character the legacy aim assist would have picked, if any.
local function assisted(entity: any, aim: Vector3): any
	local head = entity.Model:FindFirstChild("Head")
	local eye: Vector3 = if head and head:IsA("BasePart") then head.Position else entity.Root.Position
	local sight = aim - eye
	local reach = sight.Magnitude
	if reach < ASSIST_MIN_DISTANCE then
		return nil
	end
	local direction = sight.Unit

	local best: any = nil
	local bestAngle = ASSIST_MAX_DEGREES
	-- Every tracked character within the widest cone, then the legacy test on each.
	for _, candidate in Hitbox.Sphere(eye, reach, entity) do
		local offset = candidate.Root.Position - eye
		if offset.Magnitude < 1e-3 then
			continue
		end
		local angle = math.acos(math.clamp(direction:Dot(offset.Unit), -1, 1))
		local along = math.clamp(offset.Magnitude * math.cos(angle), ASSIST_MIN_DISTANCE, reach)
		local degrees = math.deg(angle)
		if degrees <= math.min(ASSIST_FOV / (along + 10), ASSIST_MAX_DEGREES) and degrees < bestAngle then
			best, bestAngle = candidate, degrees
		end
	end
	return best
end

function Shambles:CanBegin(): boolean
	local entity = self.Entity
	return not entity.Humanoid.Sit and not entity:HasStatus(OpeRoom.ProjectingStatus)
end

function Shambles:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	if not OpeRoom.Contains(entity, entity.Root.Position) or OpeRoom.GetStamina(entity) < COST then
		return
	end

	local aim = input.AimPosition
	local target = assisted(entity, aim) or Hitbox.Closest(Hitbox.Sphere(aim, AIM_RADIUS, entity), aim)
	if target and not target.Humanoid.Sit and OpeRoom.Contains(entity, target.Root.Position) then
		if not OpeRoom.Spend(entity, COST) then
			return
		end

		local mine = entity.Root.CFrame
		local theirs = target.Root.CFrame
		self.Services.Character:Teleport(entity, theirs)
		self.Services.Character:Teleport(target, mine)
		entity:SetStatus(SWAP_STATUS, target, SWAP_MEMORY)
		return
	end

	if OpeRoom.Contains(entity, aim) and OpeRoom.Spend(entity, COST) then
		self.Services.Character:Teleport(entity, CFrame.new(aim + GROUND_OFFSET))
	end
end

function Shambles:OnInterrupt()
	self.Entity:ClearStatus(SWAP_STATUS)
end

return Shambles
