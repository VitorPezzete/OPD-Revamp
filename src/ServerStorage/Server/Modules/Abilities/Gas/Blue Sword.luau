--!strict
--[[
	Gas fruit - Blue Sword (toggle + swing).

	The key toggles a blade of burning gas on the right arm. While it is out, every
	click is a swing: a box in front of the character, each target hit once.

	Swing damage: 600 * sword affinity * (sword level / cap) * (1 + BuffWeapons / 100),
	"Special" damage, not dodgeable. Armament haki doubles it and makes it "Haki".
	Swing cooldown 0.3s. Pressing the key grounds the flights for 3s
	(AbilityService, Modules.FlightLock).

	The click reaches the server as the ability's secondary input (phase 3, OnAction),
	sent by the owner's GasBlueSword status effect, which also plays the swing animation.

	Legacy problems fixed here:
	- The server decided on/off by looking for the sword part while the client kept its
	  own flag and its own click binding, so a dropped remote left them disagreeing.
	- A `while not sword` recolor loop was started on every activation and never ended
	  (its condition was a script-level variable shared by every activation).
	- The blade was not removed on death / seal; it now goes through OnInterrupt.
	- The swing hitbox (5 x 4 x 5, centred 2 studs ahead) followed the animated arm; it
	  is the same box in front of the root.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

local STATUS = "GasBlueSword"
local DAMAGE_TAG = "GasBlueSword"
-- Replicated by HakiService while armament is on.
local HAKI_STATUS = "Haki"

local BASE_DAMAGE = 600
local HAKI_MULTIPLIER = 2
local SWING_COOLDOWN = 0.3
local HITBOX_SIZE = Vector3.new(5, 4, 5)
local HITBOX_DISTANCE = 2

local BlueSword = Ability.extend()
-- Already running, it outlives a seal as it did in the legacy game.
BlueSword.KeepThroughSeal = true

-- The legacy blade stayed on the arm through a stun; only drawing, sheathing and
-- swinging were refused while stunned.
BlueSword.KeepThroughStun = true

function BlueSword:CanBegin(): boolean
	return not self.Entity:HasStatus("Stunned")
end

function BlueSword:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	self.Active = true
	local entity = self.Entity
	local context = self.Context
	-- "<fruit slot>|<ability slot>|<colors>": the owner's client needs the slots to
	-- address its swing inputs, everyone needs the colors to paint the blade.
	entity:SetStatus(STATUS, `{context.FruitSlot}|{context.Definition.Slot}|{self:GetColorString()}`, nil, true)
end

-- A click while the blade is out.
function BlueSword:OnAction()
	if self.Entity:HasStatus("Stunned") then
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

	for _, target in Hitbox.InFront(self.Entity, HITBOX_SIZE, HITBOX_DISTANCE) do
		self:Damage(target, damage, if haki then "Haki" else "Special", DAMAGE_TAG, false)
	end
end

function BlueSword:OnInterrupt()
	self.Active = false
	self.Entity:ClearStatus(STATUS)
end

return BlueSword
