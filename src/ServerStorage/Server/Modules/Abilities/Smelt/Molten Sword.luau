--!strict
--[[
	Smelt fruit - Molten Sword (toggle + swing).

	The key toggles a molten blade on the right arm. While it is out, every click is a
	direct swing: a box in front of the character, each target hit once.

	Swing damage: 600 * sword affinity * (sword level / cap) * (1 + BuffWeapons / 100),
	"Special" damage. Armament haki doubles it and makes it "Haki". Owners of a
	heat-proof fruit take it as plain "Sword" damage instead (so their own immunity can
	negate it). Swing cooldown 0.4s.

	A stun does not put the blade away (the legacy one stayed out through every stun);
	it can be neither swung nor toggled until the stun is over. Death and a seal remove it.

	How the click reaches the server: the framework has one input channel per ability
	(pressed / released). The owner's SmeltSword status effect sends a *release* of this
	ability for every click, so OnEnd is the swing. The release of the key press that
	toggled the blade on is swallowed.

	Legacy problems fixed here:
	- The server decided on/off by looking for the sword part while the client kept its
	  own flag, so a dropped remote left the click binding and the blade disagreeing.
	- A `while not sword` recolor loop was started on every activation and never ended
	  (its condition was a script-level variable shared by every activation).
	- The blade was not removed on death / seal; it now goes through OnInterrupt.
	- The swing hitbox followed the animated arm (a 6 x 4 x 6 box centred half a stud
	  above and 3 studs ahead of the right arm); it is the same box at the resting place
	  of that arm, 1.5 studs to the right of the root.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local STATUS = "SmeltSword"
-- Replicated by HakiService while armament is on.
local HAKI_STATUS = "Haki"
local STUN_STATUS = "Stunned"

local BASE_DAMAGE = 600
local HAKI_MULTIPLIER = 2
local SWING_COOLDOWN = 0.4
local HITBOX_SIZE = Vector3.new(6, 4, 6)
-- Legacy box: RightArm.CFrame * CFrame.new(0, 0.5, -3); the arm rests at (1.5, 0, 0).
local HITBOX_OFFSET = CFrame.new(1.5, 0.5, -3)
-- Fruits whose users are made of something hotter than molten metal.
local HEAT_PROOF_FRUITS = { "Rumble", "Hot", "Plasma" }

local MoltenSword = Ability.extend()
-- The legacy script dealt this damage without a style: ResistAbilities does not apply.
MoltenSword.DamageStyle = "Plain"

MoltenSword.KeepThroughStun = true

local function isHeatProof(target: any): boolean
	local player = target.Player
	if not player then
		return false
	end

	local fruitService = Knit.GetService("FruitService")
	for _, fruitName in HEAT_PROOF_FRUITS do
		if fruitService:HasFruit(player, fruitName) then
			return true
		end
	end
	return false
end

function MoltenSword:CanBegin(): boolean
	return not self.Entity:HasStatus(STUN_STATUS)
end

function MoltenSword:OnBegin()
	self.Active = not self.Active

	if self.Active then
		-- The key that drew the blade is still held: its release is not a swing.
		self.IgnoreRelease = true
		-- "<fruit slot>;<ability slot>;<colors>": the owner's client needs the slots to
		-- address its swing inputs, everyone needs the colors to paint the blade.
		local context = self.Context
		self.Entity:SetStatus(STATUS, `{context.FruitSlot};{context.Definition.Slot};{self:GetColorString()}`, nil, true)
	else
		self:OnInterrupt()
	end
end

function MoltenSword:OnEnd()
	if self.IgnoreRelease then
		self.IgnoreRelease = false
		return
	end
	if not self.Active or self.Entity:HasStatus(STUN_STATUS) then
		return
	end

	local now = os.clock()
	if now - (self.LastSwing or 0) < SWING_COOLDOWN then
		return
	end
	self.LastSwing = now

	local perks = self.Context.Data.Data.Expertise.Perks
	local damage = BASE_DAMAGE
		* self:GetAffinity("Sword")
		* self:GetLevelScale("Sword")
		* (1 + perks.BuffWeapons.Value / 100)
	local haki = self.Entity:HasStatus(HAKI_STATUS)
	if haki then
		damage *= HAKI_MULTIPLIER
	end

	for _, target in Hitbox.Box(self.Entity.Root.CFrame * HITBOX_OFFSET, HITBOX_SIZE, self.Entity) do
		local trait: CombatTypes.DamageTrait = if haki then "Haki" elseif isHeatProof(target) then "Sword" else "Special"
		self:Damage(target, damage, trait, "Slash", false)
	end
end

function MoltenSword:OnInterrupt()
	self.Active = false
	self.IgnoreRelease = false
	self.Entity:ClearStatus(STATUS)
end

return MoltenSword
