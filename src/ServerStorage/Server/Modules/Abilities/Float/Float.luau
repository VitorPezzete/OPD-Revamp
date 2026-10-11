--!strict
--[[
	Float fruit - Float (toggle): the caster rises for 0.4 s at 50 studs/s (20 studs) and
	then hovers at that height, moving horizontally at walk speed. Ascend (hold) climbs
	further; turning Float off drops the character.

	The server only owns the state. The hover itself runs on the owner's client
	(Effects/Status/FloatFloating), which is the side that simulates the character.

	Float and Levitate replace each other. The three Float abilities are separate
	objects that cannot see one another, so the statuses on the entity are the single
	source of truth instead of self.Active.

	Legacy problems fixed here:
	- The server ran one Heartbeat connection per floating player, writing a velocity
	  onto a character the client simulates (laggy, and a per-ability loop).
	- Death did not clean the float state up; only the toggle and DF_Disabled did.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)

-- Names shared by Float, Ascend, Levitate and the client effects.
local FLOATING = "FloatFloating"
local ASCENDING = "FloatAscending"
local LEVITATING = "FloatLevitating"

local Float = Ability.extend()

-- The legacy client waited 0.5 s between two presses.
Float.Debounce = 0.5

-- Float is not a `Flight`: the legacy client never landed it for the flight disabler
-- (only Levitate). The take-off was refused under NoMovement, though (DF Float.server 128).
function Float:CanBegin(): boolean
	local entity = self.Entity
	if entity:HasStatus(FLOATING) then
		-- Turning it off is always allowed.
		return true
	end
	if entity.Humanoid.Sit or entity:IsRooted() then
		return false
	end
	for _, status in MovementConfig.NoMovementStatuses do
		if entity:HasStatus(status) then
			return false
		end
	end
	return true
end

function Float:OnBegin()
	local entity = self.Entity
	if entity:HasStatus(FLOATING) then
		self:OnInterrupt()
		return
	end

	entity:ClearStatus(LEVITATING)
	entity:SetStatus(FLOATING, true, nil, true)
end

function Float:OnInterrupt()
	self.Entity:ClearStatus(ASCENDING)
	self.Entity:ClearStatus(FLOATING)
end

return Float
