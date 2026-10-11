--!strict
--[[
	Rumble fruit - Rumble Staff (toggle + swing).

	The key toggles a staff on the right arm. While it is out, every click of the owner is
	a swing (phase 3 input sent by Effects.Status.RumbleStaff -> OnAction): a box in front
	of the character, each target hit once.

	Swing damage: 600 * sword affinity * (sword level / cap) * (1 + BuffWeapons / 100),
	"Special", not dodgeable. Armament haki doubles it and makes it "Haki". A Gum user is
	hit with "Melee" damage instead, unless the swing carries haki. Cooldown 0.25 s.
	Hitbox: 10 wide, 8 high, 5 deep, centered 2.5 studs ahead of and 0.5 above the RIGHT
	ARM, in the arm's own frame (legacy size, offset and origin): it sits to the right of
	the body and follows the arm, wherever the previous swing left it.
	Each swing is announced to the clients around (Effects.OneShot.RumbleStaffSwing: the
	swing sound, and the staff spinning in the hand on every third swing). The toggle
	itself can be pressed every 0.5 s, as on the legacy client.

	Legacy problems fixed here:
	- A `while not sword` recolor loop was started on every activation and never ended
	  (its condition was a script-level variable shared by every activation).
	- The staff was a server part, found by name to decide on / off, and survived death.
	- NPCs were only damaged if they had a CharacterTrait folder; every tracked character
	  is a valid target now.
	- The legacy server gated the staff at sword level 50 while the client asked for 100
	  (the Power1 value); the requirement is the 100 of FruitConfig.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Shared = require(script.Parent._Shared)

local STATUS = "RumbleStaff"
local SWING_EFFECT = "RumbleStaffSwing"
local DAMAGE_TAG = "RumbleStaff"

local BASE_DAMAGE = 600
local HAKI_MULTIPLIER = 2
local SWING_COOLDOWN = 0.25
local HITBOX_SIZE = Vector3.new(10, 8, 5)
local HITBOX_OFFSET = CFrame.new(0, 0.5, -2.5)
local ARM_NAME = "Right Arm"

local RumbleStaff = Ability.extend()
-- The legacy script dealt this damage without a style: ResistAbilities does not apply.
RumbleStaff.DamageStyle = "Plain"

RumbleStaff.Debounce = 0.5

function RumbleStaff:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	self.Active = true
	self.SwingIndex = 0
	-- "<fruit slot>;<ability slot>;<colors>": the owner's client needs the slots to
	-- address its swings, everyone needs the colors to paint the staff.
	local context = self.Context
	self.Entity:SetStatus(STATUS, `{context.FruitSlot};{context.Definition.Slot};{self:GetColorString()}`, nil, true)
end

function RumbleStaff:OnAction()
	local now = os.clock()
	if now - (self.LastSwing or 0) < SWING_COOLDOWN then
		return
	end
	self.LastSwing = now

	-- 1, 2, 3, 1... since the staff came out: the owner's client counts the same way.
	self.SwingIndex = (self.SwingIndex or 0) % 3 + 1
	self:PlayEffect(SWING_EFFECT, self.Entity.Root.Position, { Swing = self.SwingIndex })

	local perks = self.Context.Data.Data.Expertise.Perks
	local damage = BASE_DAMAGE
		* self:GetAffinity("Sword")
		* self:GetLevelScale("Sword")
		* (1 + perks.BuffWeapons.Value / 100)
	local haki = self.Services.Haki:IsArmamentActive(self.Entity)
	if haki then
		damage *= HAKI_MULTIPLIER
	end

	local arm = self.Entity.Model:FindFirstChild(ARM_NAME)
	local origin: CFrame = if arm and arm:IsA("BasePart") then arm.CFrame else self.Entity.Root.CFrame
	for _, target in Hitbox.Box(origin * HITBOX_OFFSET, HITBOX_SIZE, self.Entity) do
		local trait: CombatTypes.DamageTrait = if haki then "Haki" else Shared.TraitFor(self.Services, target)
		self:Damage(target, damage, trait, DAMAGE_TAG, false)
	end
end

function RumbleStaff:OnInterrupt()
	self.Active = false
	self.Entity:ClearStatus(STATUS)
end

return RumbleStaff
