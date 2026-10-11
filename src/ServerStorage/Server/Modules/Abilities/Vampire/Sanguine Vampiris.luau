--!strict
--[[
	Vampire fruit - Sanguine Vampiris: a pair of giant fangs snaps shut in front of the
	user and curses every player caught between them.

	Hold to aim, release to bite, as in the legacy game: while the key is down the owner
	sees a faint preview of the fangs following its aim (the replicated
	VampireFangsAiming status, "<fang scale>|<cooldown seconds left>|<fruit colors>",
	drawn by Effects.Status.VampireFangsAiming). The preview also shows during the
	cooldown, nearly invisible; releasing then does nothing.

	Bite area: a 10 x 10 box reaching 9 studs ahead, along the horizontal aim direction.
	A player is caught when its root is inside the box (the legacy test, tighter than a
	body overlap). Only players can be cursed, and only while they carry no curse yet.
	Cooldown 7 s from the bite. It deals no damage.

	What the curse does (max health by day / night, burning in sunlight, Hypnosis) is
	described and run by VampireShared, because it lives on the victim and outlasts this
	key press. The marker the vampire sees over its victims reaches
	sword level * sword affinity studs.

	Legacy problems fixed here:
	- The bite area was a real part created (once per player in the server) just to
	  read its CFrame, and left in the workspace for two seconds.
	- Curses were remembered per fruit script, so they silently outlived the vampire's
	  character: see VampireShared.
	- The fangs were server parts tweened by the server (and destroyed before their
	  fade-out could play); they are the VampireFangs client effect, scaled like before
	  by 1 + sword level / 1000 * sword affinity.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local VampireShared = require(script.Parent.VampireShared)

local AIM_STATUS = "VampireFangsAiming"

local COOLDOWN = 7
local REACH = 9
local BOX_SIZE = Vector3.new(10, 10, REACH)
local FANG_SCALE_LEVELS = 1000

local SanguineVampiris = Ability.extend()

function SanguineVampiris:OnBegin()
	self.Aiming = true
	local scale = 1 + self:GetLevel("Sword") / FANG_SCALE_LEVELS * self:GetAffinity("Sword")
	local cooldownLeft = math.max(0, (self.ReadyAt or 0) - os.clock())
	self.Entity:SetStatus(
		AIM_STATUS,
		`{string.format("%.3f", scale)}|{string.format("%.2f", cooldownLeft)}|{self:GetColorString()}`,
		nil,
		true
	)
end

function SanguineVampiris:OnEnd(input: Ability.AbilityInput)
	if not self.Aiming then
		return
	end
	local entity = self.Entity
	self.Aiming = false
	entity:ClearStatus(AIM_STATUS)

	local now = os.clock()
	if entity.Dead or now < (self.ReadyAt or 0) then
		return
	end

	local origin = entity.Root.Position
	local look = entity.Root.CFrame.LookVector
	local flat = Vector3.new(input.AimPosition.X - origin.X, 0, input.AimPosition.Z - origin.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(look.X, 0, look.Z)
	end
	if flat.Magnitude < 1e-3 then
		return
	end
	local direction = flat.Unit

	self.ReadyAt = now + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local swordLevel = self:GetLevel("Sword")
	local affinity = self:GetAffinity("Sword")

	self:PlayEffect("VampireFangs", origin, {
		Direction = direction,
		Scale = 1 + swordLevel / FANG_SCALE_LEVELS * affinity,
	})

	local center = origin + direction * (REACH / 2)
	local box = CFrame.lookAt(center, center + direction)
	local half = BOX_SIZE / 2
	for _, target in Hitbox.Box(box, BOX_SIZE, entity) do
		if not target.Player then
			continue
		end
		-- Hitbox.Box pads the box by a body radius; the legacy test was the root alone.
		local offset = box:PointToObjectSpace(target.Root.Position)
		if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
			VampireShared.Bite(target, entity, swordLevel * affinity)
		end
	end
end

function SanguineVampiris:OnInterrupt()
	-- Only when this ability is the one aiming: OnInterrupt also runs for idle siblings.
	if self.Aiming then
		self.Aiming = false
		self.Entity:ClearStatus(AIM_STATUS)
	end
end

return SanguineVampiris
