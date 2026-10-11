--!strict
--[[
	Hollow fruit - the "Negative" debuff. NOT an ability: a library shared by Projection
	(ghost contact) and Negative Hollow (the ghosts sent at a target).

	Negative: the victim is stunned (rooted, abilities interrupted) for a given time,
	slumped in the legacy "Negative" animation. A character can only be made negative
	once every 20 seconds, whoever the source is (the legacy Cooldown value on the victim).

	The stun is a StatusService stun named "HollowNegative"; the replicated
	"HollowNegative" status on the victim is drawn by Effects.Status.HollowNegative.

	The legacy control script restored WalkSpeed from Config.WalkSpeed when it ended,
	wiping any other slow or root on the victim; roots are named now.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "HollowNegative"
local COOLDOWN_STATUS = "HollowNegativeCooldown"
local COOLDOWN = 20

local HollowNegative = {}

-- Shared by the Hollow abilities: set by Projection while the ghost body is out.
HollowNegative.ProjectingStatus = "HollowProjecting"
-- Replicated Vector3: where the ghost body is.
HollowNegative.GhostStatus = "HollowGhost"
HollowNegative.FadedStatus = "HollowFaded"

-- Returns whether the target was affected (false while it is on cooldown).
function HollowNegative.Apply(statusService: any, target: CharacterEntity, duration: number): boolean
	if target.Dead or duration <= 0 or target:HasStatus(COOLDOWN_STATUS) then
		return false
	end

	target:SetStatus(COOLDOWN_STATUS, true, COOLDOWN)
	statusService:ApplyStun(target, duration, STATUS)
	target:SetStatus(STATUS, true, duration, true)
	return true
end

-- Where the caster's hollows come out: the ghost body while projecting, else the real one.
function HollowNegative.GetOrigin(entity: CharacterEntity): Vector3
	if entity:HasStatus(HollowNegative.ProjectingStatus) then
		local ghost = entity:GetStatus(HollowNegative.GhostStatus)
		if typeof(ghost) == "Vector3" then
			return ghost
		end
	end
	return entity.Root.Position
end

return HollowNegative
