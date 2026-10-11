--!strict
--[[
	Candy fruit - Syrup Blades (toggle + swing).

	The key grows a candy blade on each arm. While they are out, every click is a direct
	swing: a 3 x 7 x 3 box on the swinging arm (left first, then alternating), each
	target hit once.

	Swing damage: 300 * sword affinity * (sword level / cap) * (1 + BuffWeapons / 100),
	"Sword" damage, not dodgeable (so logia bodies let it through, as before). Armament
	haki doubles it and makes it "Haki". 0.25 s between swings.

	The click reaches the server as phase 3 of this ability, sent by the owner's
	CandyBlades status effect, which also plays the swing animation.

	Legacy problems fixed here:
	- The server decided on/off by looking for the blade part while the client kept its
	  own flag, so a lost remote left the click binding and the blades disagreeing.
	- A `while not sword` recolor loop was started on every activation and only ended when
	  a script-level variable shared by every activation changed.
	- The blades were not removed on death / seal; they now go through OnInterrupt.

	The legacy hitbox was read at the arm's CFrame on the click; it is rebuilt from the
	root with the arm at rest (1.5 studs to the side).

	KeepThroughStun: the blades stay on the arms when their user is stunned, as in the
	legacy game (the stun only switched Spike Body off). A stunned user can neither
	swing nor toggle them.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CandyShared = require(script.Parent._Shared)

local STATUS = "CandyBlades"

local BASE_DAMAGE = 300
local SWING_COOLDOWN = 0.25
local HITBOX_SIZE = Vector3.new(3, 7, 3)
-- Arms at rest, seen from the root.
local RIGHT_ARM = CFrame.new(1.5, 0, 0)
local LEFT_ARM = CFrame.new(-1.5, 0, 0)

local SyrupBlades = Ability.extend()

SyrupBlades.KeepThroughStun = true

function SyrupBlades:CanBegin(): boolean
	return not CandyShared.Stunned(self)
end

function SyrupBlades:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	self.Active = true
	local context = self.Context
	-- "<fruit slot>|<ability slot>|<colors>": the owner's client needs the slots to
	-- address its swing inputs.
	self.Entity:SetStatus(STATUS, `{context.FruitSlot}|{context.Definition.Slot}|{self:GetColorString()}`, nil, true)
end

function SyrupBlades:OnAction()
	local now = os.clock()
	if now - (self.LastSwing or 0) < SWING_COOLDOWN or CandyShared.Stunned(self) then
		return
	end
	self.LastSwing = now
	-- The legacy `right` flag: the first swing is the left arm's.
	local arm = if self.SwingRight then RIGHT_ARM else LEFT_ARM
	self.SwingRight = not self.SwingRight

	local perks = self.Context.Data.Data.Expertise.Perks
	local multiplier, haki = CandyShared.Haki(self)
	local damage = BASE_DAMAGE
		* self:GetAffinity("Sword")
		* self:GetLevelScale("Sword")
		* (1 + perks.BuffWeapons.Value / 100)
		* multiplier

	for _, target in Hitbox.Box(self.Entity.Root.CFrame * arm, HITBOX_SIZE, self.Entity) do
		self:Damage(target, damage, if haki then "Haki" else "Sword", nil, false)
	end
end

function SyrupBlades:OnInterrupt()
	self.Active = false
	self.Entity:ClearStatus(STATUS)
end

return SyrupBlades
