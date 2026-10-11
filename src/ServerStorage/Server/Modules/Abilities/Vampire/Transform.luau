--!strict
--[[
	Vampire fruit - Transform (toggle): half-bat form, with ears and wings.

	While transformed:
	- walk speed gains 0.75 * melee affinity * (melee level / cap) of its base;
	- every hit landed with a melee-slot weapon (Melee, Black Leg, Table Kick) heals the
	  vampire for the damage that hit dealt;
	- each jump is a wing beat that throws the vampire upwards at
	  melee level * melee affinity / 13 + 10 studs per second, in the air too
	  (done by the owner's client, which simulates the character).
	1 s between toggles.

	The replicated status VampireTransform is "<wing beat speed>|<fruit colors>";
	Effects.Status.VampireTransform welds the ears and wings and handles the jump.

	Life steal. The legacy weapon scripts healed the attacker themselves when its
	UsingVampireHZ flag was set. Here the ability listens to CombatService.Damaged while
	it is on. AttackService.Landed would say which weapon swung but not how much it
	dealt, so the damage signal is used and the weapon is read from the tool in hand.

	The legacy heal was the damage the weapon REQUESTED (before the target's defenses,
	and even when the hit was negated). CombatService only reports hits that landed, with
	the amount after the modifiers: that amount is used (not capped by the health the
	target had left). A negated hit heals nothing here - see the audit report.

	Legacy problems fixed here:
	- Ears and wings were welded by the server and only removed by the toggle, and the
	  speed bonus was recomputed by the global walk speed script.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)
local BodyTouch = require(ServerStorage.Server.Modules.BodyTouch)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local STATUS = "VampireTransform"
local SPEED_MODIFIER = "VampireTransform"

local SPEED_BONUS = 0.75
local JUMP_BASE = 10
local JUMP_LEVEL_DIVISOR = 13

local function holdsMeleeWeapon(entity: CharacterEntity.CharacterEntity): boolean
	local tool = entity.Model:FindFirstChildOfClass("Tool")
	local weapon = tool and (WeaponConfig.Weapons :: { [string]: any })[tool.Name]
	return weapon ~= nil and weapon.Slot == "Melee"
end

local Transform = Ability.extend()

Transform.Debounce = 1

function Transform:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	local entity = self.Entity
	local affinity = self:GetAffinity("Melee")
	self.Active = true

	entity:SetSpeedBonus(SPEED_MODIFIER, SPEED_BONUS * affinity * self:GetLevelScale("Melee"))

	local jumpSpeed = self:GetLevel("Melee") * affinity / JUMP_LEVEL_DIVISOR + JUMP_BASE
	entity:SetStatus(STATUS, `{string.format("%.3f", jumpSpeed)}|{self:GetColorString()}`, nil, true)

	self.DamagedConnection = self.Services.Combat.Damaged:Connect(
		function(context: CombatTypes.DamageContext, _dealt: number, amount: number)
			if context.Attacker == entity and context.Style == "Weapon" and amount > 0 and holdsMeleeWeapon(entity) then
				entity:Heal(amount)
			end
		end
	)

	-- Through a Gum punch of the same character (Modules.BodyTouch, DF Gum.server
	-- 111-112, 181-187): every character a punch reaches heals the vampire by the damage
	-- the punch asked for (after haki), up to full health - dodged or negated alike.
	BodyTouch.Set(entity, "Vampire", {
		OnHit = function(_target, punch)
			entity:Heal(punch.Damage)
		end,
	})
end

function Transform:OnInterrupt()
	self.Active = false
	BodyTouch.Set(self.Entity, "Vampire", nil)
	if self.DamagedConnection then
		self.DamagedConnection:Disconnect()
		self.DamagedConnection = nil
	end
	self.Entity:SetSpeedBonus(SPEED_MODIFIER, nil)
	self.Entity:ClearStatus(STATUS)
end

return Transform
