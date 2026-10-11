--!strict
--[[
	Vampire fruit - Shadow Step: three seconds as a shadow.

	For 3 s: damage taken is halved (DamageModifiers/VampireShadowStep) and walk speed
	gains (1 + 2.5 * melee affinity) * (melee level / cap) of its base.
	By night the shadow also flies: melee level / 5 * melee affinity + 30 studs per
	second straight away from the camera (the legacy direction: camera position to
	character). By day it crawls on the ground instead.
	Cooldown 11 s (the 3 s plus the legacy 8 s).

	The replicated status VampireShadowStep is "<fly speed, 0 by day>|<fruit colors>":
	Effects.Status.VampireShadowStep draws the shadow on the body for everyone and, for
	the owner, flies it or plays the crawl.

	Day or night is decided here, when the key is pressed (Lighting.ClockTime, through
	VampireShared). The legacy client decided it on its own and also kept its own 11 s
	timer, so the two could disagree about whether a press had counted.

	Legacy problems fixed here:
	- One `task.delay` per body part (six of them) each cleared the state after 3 s.
	- The halved damage and the speed stayed for the full 3 s after death.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local VampireShared = require(script.Parent.VampireShared)

-- Also read by DamageModifiers/VampireShadowStep.
local STATUS = "VampireShadowStep"
local SPEED_MODIFIER = "VampireShadowStep"

local COOLDOWN = 11
local DURATION = 3
local BASE_SPEED_BONUS = 1
local AFFINITY_SPEED_BONUS = 2.5
local FLY_BASE_SPEED = 30
local LEVELS_PER_FLY_SPEED = 5

local ShadowStep = Ability.extend()

function ShadowStep:CanBegin(): boolean
	return os.clock() - (self.LastCast or 0) >= COOLDOWN
end

function ShadowStep:OnBegin()
	local entity = self.Entity
	local affinity = self:GetAffinity("Melee")

	self.LastCast = os.clock()
	self:StartCooldown(COOLDOWN)
	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	entity:SetSpeedBonus(SPEED_MODIFIER, (BASE_SPEED_BONUS + AFFINITY_SPEED_BONUS * affinity) * self:GetLevelScale("Melee"))

	local flySpeed = 0
	if not VampireShared.IsDay() then
		flySpeed = self:GetLevel("Melee") / LEVELS_PER_FLY_SPEED * affinity + FLY_BASE_SPEED
	end
	entity:SetStatus(STATUS, `{string.format("%.3f", flySpeed)}|{self:GetColorString()}`, nil, true)

	task.delay(DURATION, function()
		if self.Run == run then
			self:OnInterrupt()
		end
	end)
end

function ShadowStep:OnInterrupt()
	self.Active = false
	-- Invalidates the pending end of the step that was running.
	self.Run = (self.Run or 0) + 1
	self.Entity:SetSpeedBonus(SPEED_MODIFIER, nil)
	self.Entity:ClearStatus(STATUS)
end

return ShadowStep
