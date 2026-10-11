--!strict
--[[
	Rumble fruit - Lightning Blitz (charged): a lightning bolt from the casting hand to
	the aim point; fully charged, the user travels with it.

	Charge: 25 per second held, 4 to 100 (timed on the server, from the rounded start the
	legacy server used - see _Shared).
	With a = melee affinity and s = melee level / cap, on release:
	- nothing happens if the aim point is further than 2000 * s studs from the user, or
	  if there is nothing there (the sky): the bolt needs something to strike;
	- damage: 4000 * a * s * charge / 100 ("Special", not dodgeable; "Melee" on Gum
	  users) to everyone touching the ball of lightning at the aim point, whose size is
	  the FinalPart template size * a;
	- charge above 80: the user is teleported to the aim point, unless seated.
	Cannot start while El Thor is charging. The hands alternate (see _Shared).

	Legacy problems fixed / readings chosen:
	- The ball damaged through a Touched connection during the 0.5 s it existed; it is one
	  sphere test at release (largest template dimension * a as the diameter).
	- The template size is not in the instance dump: the server reads it from the asset in
	  ReplicatedStorage and falls back to FALLBACK_SIZE (a guess).
	- The legacy teleport put the root part exactly on the clicked surface, with the
	  camera ray's orientation: half the character ended up in the ground, tilted. The
	  user keeps its orientation and lands TELEPORT_HEIGHT above the point.
	- The legacy server also refused to teleport a user whose "SelfDestruct" flag was on;
	  that state belongs to something not ported yet.
	- "Needs something under the mouse" (the legacy `mousetarget` check) was a client
	  value; the server looks for a part at the aim point itself.
	- The bolt was up to 400 server parts recycled through a per player pool.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local ThrownSlashes = require(ServerStorage.Server.Modules.ThrownSlashes)
local Shared = require(script.Parent._Shared)

local EFFECT = "RumbleBlitz"
local DAMAGE_TAG = "RumbleBlitz"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100

local BASE_DAMAGE = 4000
local BASE_RANGE = 2000
local TELEPORT_CHARGE = 80
local TELEPORT_HEIGHT = 3
local FALLBACK_SIZE = Vector3.new(8, 8, 8)
-- How close to the aim point something has to be for the bolt to have a target.
local SURFACE_REACH = 3
local TARGET_CANDIDATES = 16
-- The bolt can end 1000 studs from the hand: send it to everyone who could see it.
local EFFECT_RADIUS = 1500

local LightningBlitz = Ability.extend()
-- The legacy script dealt this damage without a style: ResistAbilities does not apply.
LightningBlitz.DamageStyle = "Plain"
-- Legacy accepted aim points this far away.
LightningBlitz.MaxAimDistance = 2000

local function getTemplateSize(): Vector3
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", "Rumble", "Power3", "FinalPart" } do
		current = if current then current:FindFirstChild(name) else nil
	end
	return if current and current:IsA("BasePart") then current.Size else FALLBACK_SIZE
end

-- True when the aim point lies on something. The bounds query only shortlists parts
-- (a large mesh's box is mostly air); the surface distance decides.
local function hasTarget(aim: Vector3, caster: Instance): boolean
	-- A thrown sword slash counted as something under the mouse in the old game (it was
	-- an ordinary part). It has no instance here for the query below to find.
	if ThrownSlashes.IsAt(aim, SURFACE_REACH) then
		return true
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { caster }
	params.MaxParts = TARGET_CANDIDATES
	for _, part in Workspace:GetPartBoundsInRadius(aim, SURFACE_REACH, params) do
		if (part:GetClosestPointOnSurface(aim) - aim).Magnitude <= SURFACE_REACH then
			return true
		end
	end
	return false
end

function LightningBlitz:CanBegin(): boolean
	return not self.Entity:HasStatus(Shared.ThorChargeStatus)
end

function LightningBlitz:OnBegin()
	Shared.BeginCharge(self, CHARGE_MAX / CHARGE_RATE)
	-- "<level scale>|<colors>|<hand>": the sparks around the hand reach further the
	-- higher the level.
	local value = string.format(
		"%.3f|%s|%s",
		self:GetLevelScale("Melee"),
		self:GetColorString(),
		Shared.GetHand(self.Entity)
	)
	self.Entity:SetStatus(Shared.BlitzChargeStatus, value, nil, true)
end

function LightningBlitz:OnEnd(input: Ability.AbilityInput)
	local charge = Shared.EndCharge(self, CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	self.Entity:ClearStatus(Shared.BlitzChargeStatus)
	if not charge then
		return
	end

	local entity = self.Entity
	local hand = Shared.GetHand(entity)
	Shared.SwapHand(entity)

	local affinity = self:GetAffinity("Melee")
	local scale = self:GetLevelScale("Melee")
	local aim = input.AimPosition
	if (entity.Root.Position - aim).Magnitude > BASE_RANGE * scale then
		return
	end

	if not hasTarget(aim, entity.Model) then
		return
	end

	local origin = Shared.GetHandPosition(entity, hand)

	self.Services.Effect:Play(EFFECT, origin, {
		Colors = self:GetColorString(),
		Caster = entity.Model,
		Target = aim,
		Size = affinity,
		Thickness = math.clamp(scale, 0.5, 1),
	}, EFFECT_RADIUS)

	local size = getTemplateSize()
	local radius = math.max(size.X, size.Y, size.Z) * affinity / 2
	local damage = BASE_DAMAGE * affinity * scale * charge / CHARGE_MAX
	for _, target in Hitbox.Sphere(aim, radius, entity) do
		self:Damage(target, damage, Shared.TraitFor(self.Services, target), DAMAGE_TAG, false)
	end

	if charge > TELEPORT_CHARGE and not entity.Humanoid.Sit then
		local destination = aim + Vector3.new(0, TELEPORT_HEIGHT, 0)
		self.Services.Character:Teleport(entity, entity.Root.CFrame.Rotation + destination)
	end
end

function LightningBlitz:OnInterrupt()
	self.ChargeStart = nil
	self.ChargeBegan = nil
	self.Entity:ClearStatus(Shared.BlitzChargeStatus)
end

return LightningBlitz
