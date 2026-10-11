--!strict
--[[
	Diamond fruit - Diamond Blade (toggle + swing).

	The key toggles a diamond blade on the right arm. While it is out, every click is a
	direct swing: a 5 x 3 x 5 box carried by the right arm (half a stud up, 2.5 studs
	ahead in the arm's own frame, so it follows the swing animation as it did in the
	legacy game). A swing cuts ONE character, as in the legacy game.

	Swing damage: 600 * sword affinity * (sword level / cap) * (1 + BuffWeapons / 100),
	"Sword" damage. Armament haki doubles it and makes it "Haki". Swing cooldown 0.5s.
	The hit carries no "Slash" tag: the legacy swing passed none, so a haki-coated blade
	still cuts Chop owners (their sword immunity already stops the plain one).

	How the click reaches the server: the framework has one input channel per ability
	(pressed / released). The owner's DiamondSword status effect sends a *release* of
	this ability for every click, so OnEnd is the swing. The release of the key press
	that toggled the blade on is swallowed.

	Legacy problems fixed here:
	- "Already damaged" was one script-level variable that started as nil and was reset
	  to false after each swing, so the first swing after spawning never hit. (That it
	  let a swing hit only one character is kept: the closest to the box is the one cut.)
	- The server decided on/off by looking for the sword part while the client kept its
	  own flag, so a dropped remote left the click binding and the blade disagreeing.
	- A recolor loop polled twice a second for as long as the blade existed.
	- The blade was not removed on death / seal; it now goes through OnInterrupt.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

local STATUS = "DiamondSword"
-- Replicated by HakiService while armament is on.
local HAKI_STATUS = "Haki"

local BASE_DAMAGE = 600
local HAKI_MULTIPLIER = 2
local SWING_COOLDOWN = 0.5
local HITBOX_SIZE = Vector3.new(5, 3, 5)
local HITBOX_ARM = "Right Arm"
-- In the arm's frame.
local HITBOX_OFFSET = CFrame.new(0, 0.5, -2.5)

local DiamondBlade = Ability.extend()

function DiamondBlade:OnBegin()
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

function DiamondBlade:OnEnd()
	if self.IgnoreRelease then
		self.IgnoreRelease = false
		return
	end
	if not self.Active then
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

	local entity = self.Entity
	local arm = entity.Model:FindFirstChild(HITBOX_ARM)
	local box = (if arm and arm:IsA("BasePart") then arm.CFrame else entity.Root.CFrame) * HITBOX_OFFSET
	local target = Hitbox.Closest(Hitbox.Box(box, HITBOX_SIZE, entity), box.Position)
	if target then
		self:Damage(target, damage, if haki then "Haki" else "Sword", nil, false)
	end
end

function DiamondBlade:OnInterrupt()
	self.Active = false
	self.IgnoreRelease = false
	self.Entity:ClearStatus(STATUS)
end

return DiamondBlade
