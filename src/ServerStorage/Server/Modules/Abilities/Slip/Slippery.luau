--!strict
--[[
	Slip fruit - Slippery (toggle): slide at increased walk speed.

	Speed bonus (fraction of base walk speed): (1 + melee affinity) * (melee level / cap).

	Legacy problems fixed here:
	- The bonus was added by a walk speed script listening to a BoolValue, computed once;
	  it is now a named modifier on the entity, removed by name, so it cannot stack or leak.
	- The leg particles were created on the server and never removed on death. The trail
	  is a client effect driven by the replicated status, which carries the fruit colors.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)

local STATUS = AbilityConfig.Status.SlipRushing
local SPEED_MODIFIER = "SlipRushing"

local Slippery = Ability.extend()

function Slippery:OnBegin()
	self.Active = not self.Active

	if self.Active then
		local bonus = (1 + self:GetAffinity("Melee")) * self:GetLevelScale("Melee")
		self.Entity:SetSpeedBonus(SPEED_MODIFIER, bonus)
		-- The status value is the color string the client paints the trail with.
		self.Entity:SetStatus(STATUS, self:GetColorString(), nil, true)
	else
		self:OnInterrupt()
	end
end

function Slippery:OnInterrupt()
	self.Active = false
	self.Entity:SetSpeedBonus(SPEED_MODIFIER, nil)
	self.Entity:ClearStatus(STATUS)
end

return Slippery
