--!strict
--[[
	Clear fruit - Invisibility (toggle).

	Legacy problems fixed here:
	- The client told the server "Hide" or "Show", so a dropped input left both sides
	  disagreeing about the state. The server owns the toggle now.
	- Hiding was done by forcing Transparency on every part on the server, with one
	  property connection per part, and "show" restored from per-part attributes that
	  could be lost (stuck invisible limbs, haki arms reappearing). The server now only
	  flips one replicated status; each client hides the character locally.
	- Sealing, dying or losing the fruit always goes through OnInterrupt.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)

local STATUS = AbilityConfig.Status.Invisible

local Invisibility = Ability.extend()

function Invisibility:CanBegin(): boolean
	-- Turning it off is always allowed; turning it on is not while seated or rooted.
	return self.Active or not (self.Entity.Humanoid.Sit or self.Entity:IsRooted())
end

function Invisibility:OnBegin()
	self.Active = not self.Active
	self.Entity:SetStatus(STATUS, self.Active, nil, true)
end

function Invisibility:OnInterrupt()
	self.Active = false
	self.Entity:ClearStatus(STATUS)
end

return Invisibility
