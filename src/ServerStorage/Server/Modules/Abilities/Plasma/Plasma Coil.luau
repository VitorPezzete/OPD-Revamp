--!strict
--[[
	Plasma fruit - Plasma Coil (toggle): a plasma sphere floats 10 studs above the user and
	arcs to everyone around it.

	Every 0.25 s, each character within the radius of the sphere takes
		185 * (sniper level / cap) * sniper affinity      (Special, not dodgeable)
	doubled and "Haki" while armament haki is on.
	Radius: 30 * sniper affinity * (sniper level / cap), fixed when the coil is turned on
	(as in the legacy game), measured from the sphere, which takes one second to rise
	from the body to its 10 studs (the legacy weld tween, Quad Out).

	A stun ends the coil, like death and a sealed fruit: the legacy loop stopped as soon
	as DF_Disabled was set, and every legacy stun set it.

	Visuals are all on the client: the sphere and its idle sparks come from the replicated
	status (Effects.Status.PlasmaCoil), the arcs to the victims from one small one-shot per
	pulse that actually hit someone (Effects.OneShot.PlasmaCoilArc).

	Legacy problems fixed here:
	- The on/off flag was one BoolValue under the fruit script while the sphere, colors and
	  radius were locals of the activation: toggling off and on within 0.25 s left two
	  loops running.
	- Up to dozens of neon parts per pulse were created on the server.
	- Targets were found with GetPartBoundsInRadius over the whole map every 0.25 s.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local STATUS = "PlasmaCoil"
local EFFECT = "PlasmaCoilArc"
local DAMAGE_TAG = "PlasmaCoil"

local BASE_DAMAGE = 185
local BASE_RADIUS = 30
local HAKI_MULTIPLIER = 2
local TICK = 0.25
local MAX_ARCS = 20
local SPHERE_HEIGHT = 10
local RISE_SECONDS = 1

local PlasmaCoil = Ability.extend()

function PlasmaCoil:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	local entity = self.Entity
	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	local affinity = self:GetAffinity("Sniper")
	local radius = BASE_RADIUS * affinity * self:GetLevelScale("Sniper")
	local began = os.clock()

	entity:SetStatus(STATUS, self:GetColorString(), nil, true)

	local function tick()
		if self.Run ~= run or not self.Active then
			return
		end

		local scale = self:GetLevelScale("Sniper")
		local damage = BASE_DAMAGE * scale * affinity
		local trait: CombatTypes.DamageTrait = "Special"
		local haki = self.Services.Haki:IsArmamentActive(entity)
		if haki then
			damage *= HAKI_MULTIPLIER
			trait = "Haki"
		end

		local rising = 1 - math.clamp((os.clock() - began) / RISE_SECONDS, 0, 1)
		local height = SPHERE_HEIGHT * (1 - rising * rising)
		local center = (entity.Root.CFrame * CFrame.new(0, height, 0)).Position
		local struck: { Vector3 } = {}
		for _, target in Hitbox.Sphere(center, radius, entity) do
			-- Effects travel on an unreliable remote with a small payload: draw at most
			-- MAX_ARCS arcs, damage everyone.
			if #struck < MAX_ARCS then
				table.insert(struck, target.Root.Position)
			end
			self:Damage(target, damage, trait, DAMAGE_TAG, false)
		end
		if #struck > 0 then
			self:PlayEffect(EFFECT, center, {
				Targets = struck,
				Haki = haki,
				Size = affinity,
				Thickness = math.clamp(scale, 0.25, 1),
			})
		end

		task.delay(TICK, tick)
	end
	task.delay(TICK, tick)
end

function PlasmaCoil:OnInterrupt()
	self.Active = false
	-- Invalidates the pending tick of the run that just ended.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return PlasmaCoil
