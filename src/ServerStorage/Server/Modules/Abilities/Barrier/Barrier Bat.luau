--!strict
--[[
	Barrier fruit - Barrier Bat (toggle + swing): a barrier blade on the right arm.
	While it is out every click is a swing: a box in front of the user, each target hit
	once.

	Swing damage: 600 * melee affinity * (melee level / cap), "Melee"; armament haki
	doubles it and makes it "Haki". Swing cooldown 0.25 s.

	The click arrives as the ability's secondary input (phase 3), sent by the owner's
	BarrierBat status effect, so OnAction is the swing. Swings are impossible during
	Barrier Body because that seals every power of the user.

	KeepThroughStun: the blade stays on the arm when its user is stunned, as in the
	legacy game, but a stunned user can neither swing it nor toggle it.

	Legacy problems fixed here:
	- The swing cooldown table was keyed by player but the alternating-hand flag and the
	  press cooldown were script-level variables.
	- A `while blade.Parent` loop recolored the blade five times a second to follow haki;
	  the client now repaints on the haki attribute.
	- The blade was not removed on death / seal.

	The legacy hitbox was a 4 x 3 x 8 box at the right arm's CFrame * (0, 0.5, -2.5),
	read on the click (before the swing animation moved the arm). It is rebuilt from the
	root with the arm at rest, 1.5 studs to the right.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

-- Replicated: "<fruit slot>|<ability slot>|<fruit colors>".
local STATUS = "BarrierBat"
local STUN_STATUS = "Stunned"

local BASE_DAMAGE = 600
local HAKI_MULTIPLIER = 2
local SWING_COOLDOWN = 0.25
local HITBOX_SIZE = Vector3.new(4, 3, 8)
-- Right arm at rest (1.5 studs right of the root), then the legacy offset from the arm.
local HITBOX_OFFSET = CFrame.new(1.5, 0, 0) * CFrame.new(0, 0.5, -2.5)

local BarrierBat = Ability.extend()

BarrierBat.KeepThroughStun = true

function BarrierBat:CanBegin(): boolean
	return not self.Entity:HasStatus(STUN_STATUS)
end

function BarrierBat:OnBegin()
	self.Active = not self.Active
	if not self.Active then
		self:OnInterrupt()
		return
	end

	local context = self.Context
	self.Entity:SetStatus(STATUS, `{context.FruitSlot}|{context.Definition.Slot}|{self:GetColorString()}`, nil, true)
end

function BarrierBat:OnAction()
	local now = os.clock()
	if now - (self.LastSwing or 0) < SWING_COOLDOWN or self.Entity:HasStatus(STUN_STATUS) then
		return
	end
	self.LastSwing = now

	local damage = BASE_DAMAGE * self:GetAffinity("Melee") * self:GetLevelScale("Melee")
	local trait: CombatTypes.DamageTrait = "Melee"
	if self.Services.Haki:IsArmamentActive(self.Entity) then
		damage *= HAKI_MULTIPLIER
		trait = "Haki"
	end

	for _, target in Hitbox.Box(self.Entity.Root.CFrame * HITBOX_OFFSET, HITBOX_SIZE, self.Entity) do
		self:Damage(target, damage, trait, "BarrierBat", false)
	end
end

function BarrierBat:OnInterrupt()
	self.Active = false
	self.Entity:ClearStatus(STATUS)
end

return BarrierBat
