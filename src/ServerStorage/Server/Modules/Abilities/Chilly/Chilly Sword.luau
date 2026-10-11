--!strict
--[[
	Chilly fruit - Chilly Sword (toggle + swing).

	The key toggles an ice blade on the right arm. While it is out, every click of the
	owner is a swing (phase 3 input sent by Effects.Status.ChillySword -> OnAction): a
	5 x 3 x 5 box ahead of the right arm, each target hit once.

	Swing damage: 600 * sword affinity * (sword level / cap) * (1 + BuffWeapons / 100),
	"Special", dodgeable. Armament haki doubles it and makes it "Haki". Cooldown 0.25 s.

	Legacy problems fixed here:
	- A `while not sword` recolor loop was started on every activation and never ended.
	- The blade was a server part found by name to decide on / off, and survived death.

	The legacy hitbox was the right arm's CFrame * (0, 0.5, -2.5), read on the click
	(before the swing animation moved the arm). It is rebuilt from the root with the arm
	at rest, 1.5 studs to the right.

	KeepThroughStun: the blade stays on the arm when its user is stunned, as in the
	legacy game (a stun only ended Ice Path). A stunned user can neither swing nor
	toggle it.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

local STATUS = "ChillySword"

local BASE_DAMAGE = 600
local HAKI_MULTIPLIER = 2
local SWING_COOLDOWN = 0.25
local HITBOX_SIZE = Vector3.new(5, 3, 5)
-- Right arm at rest (1.5 studs right of the root), then the legacy offset from the arm.
local HITBOX_OFFSET = CFrame.new(1.5, 0, 0) * CFrame.new(0, 0.5, -2.5)
local STUN_STATUS = "Stunned"

local ChillySword = Ability.extend()

ChillySword.KeepThroughStun = true

function ChillySword:CanBegin(): boolean
	return not self.Entity:HasStatus(STUN_STATUS)
end

function ChillySword:OnBegin()
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

function ChillySword:OnAction()
	local now = os.clock()
	if now - (self.LastSwing or 0) < SWING_COOLDOWN or self.Entity:HasStatus(STUN_STATUS) then
		return
	end
	self.LastSwing = now

	local perks = self.Context.Data.Data.Expertise.Perks
	local damage = BASE_DAMAGE
		* self:GetAffinity("Sword")
		* self:GetLevelScale("Sword")
		* (1 + perks.BuffWeapons.Value / 100)
	local haki = self.Services.Haki:IsArmamentActive(self.Entity)
	if haki then
		damage *= HAKI_MULTIPLIER
	end

	for _, target in Hitbox.Box(self.Entity.Root.CFrame * HITBOX_OFFSET, HITBOX_SIZE, self.Entity) do
		self:Damage(target, damage, if haki then "Haki" else "Special", nil, true)
	end
end

function ChillySword:OnInterrupt()
	self.Active = false
	self.Entity:ClearStatus(STATUS)
end

return ChillySword
