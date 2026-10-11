--!strict
--[[
	Blood fruit - Blood Hemomancy: rips blood out of the aimed character and drinks it.

	Range:   100 * defense affinity studs (doubled by Concentrate)
	Cost:    5% of max health (doubled by Concentrate)
	Damage:  with h = min(5% * defense affinity * target max health, 3000) and
	         f = defense level / 500:
	           (500 * defense affinity + h) * f
	           500 * defense affinity * f * 2 + h     with Concentrate (the legacy
	           formula as written: the max-health part is not scaled by the level there)
	         "Special", not dodgeable.
	Heal:    75% * defense affinity of that damage (doubled by Concentrate), whatever the
	         target actually lost, as in the legacy game.
	Cooldown 5 s. As in the legacy game it starts on any press, even one aimed at nobody;
	only a press at a character that is out of range leaves it alone.

	Legacy problems fixed here:
	- The client sent the target (its own auto-aim, else the part under the mouse). The
	  server runs that auto-aim itself on the validated aim point (BloodShared.FindTarget).
	- The beam and splash were created by the server; they are the BloodHemomancy effect.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)
local BloodShared = require(script.Parent.BloodShared)

local COOLDOWN = 5
local BASE_RANGE = 100
local HEALTH_COST = 5
local BASE_DAMAGE = 500
local HEALTH_FRACTION = 0.05
local HEALTH_DAMAGE_CAP = 3000
local HEAL_FRACTION = 0.75

local Hemomancy = Ability.extend()

function Hemomancy:CanBegin(): boolean
	return os.clock() - (self.LastCast or 0) >= COOLDOWN
end

function Hemomancy:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local affinity = self:GetAffinity("Defense")
	local scale = BloodShared.GetScale(entity)
	-- The legacy auto-aim had no range of its own; the range was checked afterwards.
	local target = BloodShared.FindTarget(entity, input.AimPosition, AbilityConfig.MaxAimDistance)
	if target and (target.Root.Position - entity.Root.Position).Magnitude > BASE_RANGE * affinity * scale then
		return
	end

	self.LastCast = os.clock()
	self:StartCooldown(COOLDOWN)
	if not target then
		return
	end
	BloodShared.PayHealth(entity, HEALTH_COST)
	if entity.Dead then
		return
	end

	self:PlayEffect("BloodHemomancy", entity.Root.Position, {
		Target = target.Model,
		Concentrate = scale > 1,
	})

	local healthDamage = math.clamp(HEALTH_FRACTION * affinity * target.MaxHealth, 0, HEALTH_DAMAGE_CAP)
	local factor = self:GetLevelScale("Defense")
	local damage = if scale > 1
		then BASE_DAMAGE * affinity * factor * 2 + healthDamage
		else (BASE_DAMAGE * affinity + healthDamage) * factor
	self:Damage(target, damage, "Special", nil, false)
	BloodShared.Heal(entity, damage * HEAL_FRACTION * affinity)
end

return Hemomancy
