--!strict
--[[
	Light fruit - Light Sword (toggle + swing).

	The key toggles a blade of light on the right arm. While it is out, every click of
	the owner is a swing (phase 3 input sent by Effects.Status.LightSword -> OnAction): a
	box in front of the character, each target hit once.

	Swing damage: 600 * sword affinity * (sword level / cap) * (1 + BuffWeapons / 100),
	"Special", not dodgeable (the legacy call passed no dodge flag). Armament haki
	doubles it and makes it "Haki". Cooldown 0.4 s.

	Legacy problems fixed here:
	- A `while not sword` recolor loop was started on every activation and never ended
	  (its condition was a script variable shared by every activation).
	- The blade was a server part found by name to decide on / off, and survived death.
	- `power == "LightAnim1" or power == "LightAnim7" and <has sword>` let LightAnim1
	  through without a blade (operator precedence), and the swing had no level check.
	- The hitbox followed the animated arm; it is the same 7 x 3 x 9 box, 3 studs ahead
	  and half a stud above where the right arm hangs (1.5 studs beside the root).

	A stun does not put the blade away (nothing but the key did in the legacy game); it
	only cannot be swung or toggled meanwhile.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local STATUS = "LightSword"

local BASE_DAMAGE = 600
local SWING_COOLDOWN = 0.4
-- Legacy: a 7 x 3 x 9 box at arm CFrame * (0, 0.5, -3).
local HITBOX_SIZE = Vector3.new(7, 3, 9)
local HITBOX_OFFSET = CFrame.new(1.5, 0.5, -3)
local STUN_STATUS = "Stunned"

local LightSword = Ability.extend()
-- The legacy script dealt this damage without a style: ResistAbilities does not apply.
LightSword.DamageStyle = "Plain"
-- Already running, it outlives a seal as it did in the legacy game.
LightSword.KeepThroughSeal = true

LightSword.KeepThroughStun = true

function LightSword:CanBegin(): boolean
	-- KeepThroughStun also lets presses through during a stun.
	return not self.Entity:HasStatus(STUN_STATUS)
end

function LightSword:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	self.Active = true
	-- "<fruit slot>;<ability slot>;<colors>": the owner's client needs the slots to
	-- address its swings, everyone needs the colors to paint the blade.
	local context = self.Context
	self.Entity:SetStatus(STATUS, `{context.FruitSlot};{context.Definition.Slot};{self:GetColorString()}`, nil, true)
end

function LightSword:OnAction()
	local now = os.clock()
	if now - (self.LastSwing or 0) < SWING_COOLDOWN or self.Entity:HasStatus(STUN_STATUS) then
		return
	end
	self.LastSwing = now

	local perks = self.Context.Data.Data.Expertise.Perks
	local damage, trait = Shared.Haki(
		self,
		BASE_DAMAGE * self:GetAffinity("Sword") * self:GetLevelScale("Sword") * (1 + perks.BuffWeapons.Value / 100)
	)

	for _, target in Hitbox.Box(self.Entity.Root.CFrame * HITBOX_OFFSET, HITBOX_SIZE, self.Entity) do
		-- No "Slash" tag: the legacy swing passed none, so Chop owners are not immune.
		self:Damage(target, damage, trait, nil, false)
	end
end

function LightSword:OnInterrupt()
	self.Active = false
	self.Entity:ClearStatus(STATUS)
end

return LightSword
