--!strict
--[[
	Chop fruit - Chop Car (toggle): roll on wheels at increased walk speed.

	Speed bonus (fraction of base walk speed): 1 + 5 * (melee level / cap). No affinity
	in the legacy formula.

	The wheels and the looped pose are client effects driven by the replicated status,
	whose value is the fruit color string (Effects.Status.ChopCar). A stun does not end
	it (KeepThroughStun), as in the legacy game; death, seal and losing the fruit do.

	Legacy problems fixed here:
	- The bonus was added by the walk speed script watching a BoolValue; it is a named
	  modifier on the entity now, removed by name.
	- The wheels were welded on the server and the looped animation was loaded on the
	  server humanoid at every toggle; neither was removed when the fruit was sealed.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local STATUS = "ChopCar"
local SPEED_MODIFIER = "ChopCar"
local STUN_STATUS = "Stunned"

local ChopCar = Ability.extend()

-- A stun did not fold the car in the legacy game; a stunned user cannot toggle it.
ChopCar.KeepThroughStun = true

function ChopCar:CanBegin(): boolean
	return not self.Entity:HasStatus(STUN_STATUS)
end

function ChopCar:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	self.Active = true
	self.Entity:SetSpeedBonus(SPEED_MODIFIER, 1 + 5 * self:GetLevelScale("Melee"))
	self.Entity:SetStatus(STATUS, self:GetColorString(), nil, true)
end

function ChopCar:OnInterrupt()
	self.Active = false
	self.Entity:SetSpeedBonus(SPEED_MODIFIER, nil)
	self.Entity:ClearStatus(STATUS)
end

return ChopCar
