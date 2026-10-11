--!strict
--[[
	Phoenix fruit - Soar (toggle): run and leap on flaming wings, hovering above the ground.

	With m = melee affinity * (melee level / cap), while on:
	- walk speed + 3 * m (as a fraction of base speed, the legacy WS multiplier);
	- jump power + 75 * m.
	The replicated "PhoenixSoaring" status (value: fruit colors) draws the wings on every
	client; the owner's client also raises the hip height to 10 and keeps the legacy
	invisible floor at Y = 210 under the soaring animations (Effects.Status.PhoenixSoaring).

	Fly and Soar replace each other (the Used signal below). Flight disabler
	(Server.Modules.FlightLock, `Flight = true`; the legacy client called its "disable
	soar" function from the same counter watcher, Phoenix.client 112-118): any power of
	the character that raised the counter ends it and locks it for 3 s. The legacy server
	also refused it under the NoMovement flag (DF Phoenix.server 236). Sitting ends it.

	Legacy problems fixed here:
	- The client kept the on/off state and sent the opposite word ("Off" to turn on); the
	  two could drift apart, leaving the speed bonus on with no wings or the reverse.
	- Wings were server parts with a per-frame recolor loop each, and the server stopped
	  every animation track of the character 0.5 s after each toggle.

	Jump power: CharacterEntity has no jump modifier, so the bonus is added to the
	humanoid directly and the same amount is taken back, which stays correct whatever
	else changed the property meanwhile.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local STATUS = "PhoenixSoaring"
-- The sibling toggle this one replaces and is replaced by.
local SIBLING = "Fly"
local SPEED_SOURCE = "PhoenixSoar"

local SPEED_BONUS = 3
local JUMP_BONUS = 75

local Soar = Ability.extend()

Soar.Flight = true

function Soar:CanBegin(): boolean
	local entity = self.Entity
	-- Turning it off is always allowed.
	return self.Active or not (entity.Humanoid.Sit or entity:IsRooted() or self:IsFlightBlocked())
end

function Soar:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	local entity = self.Entity
	local scale = self:GetAffinity("Melee") * self:GetLevelScale("Melee")

	self.Active = true
	self.JumpBonus = JUMP_BONUS * scale
	entity.Humanoid.JumpPower += self.JumpBonus
	entity:SetSpeedBonus(SPEED_SOURCE, SPEED_BONUS * scale)
	entity:SetStatus(STATUS, self:GetColorString(), nil, true)

	self.SeatConnection = entity.Humanoid.Seated:Connect(function(seated: boolean)
		if seated then
			self:OnInterrupt()
		end
	end)

	local fruitName = self.Context.FruitName
	self.UsedConnection = self.Services.Ability.Used:Connect(function(user: any, usedFruit: string, usedAbility: string)
		if user == entity and usedFruit == fruitName and usedAbility == SIBLING then
			self:OnInterrupt()
		end
	end)
end

function Soar:OnInterrupt()
	if self.SeatConnection then
		self.SeatConnection:Disconnect()
		self.SeatConnection = nil
	end
	if self.UsedConnection then
		self.UsedConnection:Disconnect()
		self.UsedConnection = nil
	end
	if not self.Active then
		return
	end
	self.Active = false

	local entity = self.Entity
	if self.JumpBonus then
		entity.Humanoid.JumpPower -= self.JumpBonus
		self.JumpBonus = nil
	end
	entity:SetSpeedBonus(SPEED_SOURCE, nil)
	entity:ClearStatus(STATUS)
end

return Soar
