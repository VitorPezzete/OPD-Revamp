--!strict
--[[
	Light fruit - Yata Mirror (charged): the user turns into a ray of light that bounces
	off the world, and reappears where it ends.

	Charge: 25 per second held, 4 to 100 (timed on the server). On release, with
	c = charge / 100 and a = melee affinity:
	- the ray leaves the mirror on the chest towards the aim point with a total length
	  of level * 2 * a * c studs; each surface reflects it (at most 50 times);
	- the first character it touches takes 2500 * (melee level / cap) * a * c,
	  "Special", not dodgeable (armament haki: doubled, "Haki"), and ends the ray. It
	  is thrown away from the caster by the legacy mover: a BodyVelocity of
	  clamp(2000 * a * c, 50, 4000) studs/s plus 25 upwards, MaxForce 100000 per axis,
	  P 1000, held for 0.3 s (Push caps the speed at Push.MaxSpeed);
	- the caster is teleported to the exact end of the ray (on the surface it last
	  touched, as in the legacy game), looking along the direction the ray would have
	  left that surface with, unless seated, and hangs there for 0.65 s
	  (Effects.Status.LightMirrorWarp). When a character was hit the legacy script
	  first waited out the 0.3 s of the knockback: so does the teleport here;
	- 3 s between a release and the next charge.

	The path is computed here only: the client sends an aim point, never a destination,
	and the ray cannot be longer than the charge allows, which is the distance check of
	the teleport.

	Legacy problems fixed here:
	- The start position came from the client and the release did not check that a
	  charge was running (free full charge by firing the remote).
	- Aiming at the mirror itself gave a NaN direction.

	Not ported: the legacy `SelfDestruct` check (a state of a fruit not ported yet).
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

local CHARGE_STATUS = "LightMirrorCharging"
local WARP_STATUS = "LightMirrorWarp"
local EFFECT = "LightMirror"

local CHARGE_RATE = 25
local MIN_CHARGE = 4
local MAX_CHARGE = 100
local BASE_DAMAGE = 2500
local RANGE_PER_LEVEL = 2
local MAX_REFLECTIONS = 50
local COOLDOWN = 3
local WARP_HOLD = 0.65
-- Legacy mirror attachment on the torso.
local MIRROR_OFFSET = Vector3.new(0, 0.25, -0.5)
local KNOCKBACK = 2000
local MIN_KNOCKBACK = 50
local MAX_KNOCKBACK = 4000
local KNOCKBACK_LIFT = 25
local KNOCKBACK_TIME = 0.3
local KNOCKBACK_FORCE = Vector3.new(100000, 100000, 100000)
local KNOCKBACK_POWER = 1000
-- The effect remote is unreliable (about 900 bytes): only this many corners are drawn.
local MAX_EFFECT_POINTS = 24
local EFFECT_RADIUS = 400

local YataMirror = Ability.extend()

function YataMirror:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0)
end

function YataMirror:OnBegin()
	self:BeginCharge(MAX_CHARGE / CHARGE_RATE)
	self.Charging = true
	-- "<range at full charge>|<colors>": the owner's client previews the bounces with it.
	local range = self:GetLevel("Melee") * RANGE_PER_LEVEL * self:GetAffinity("Melee")
	self.Entity:SetStatus(CHARGE_STATUS, `{math.floor(range)}|{self:GetColorString()}`, nil, true)
	self.Entity:SetStatus(Shared.AIM_STATUS, true, nil, true)
end

function YataMirror:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, MIN_CHARGE, MAX_CHARGE)
	if not charge then
		return
	end
	local entity = self.Entity
	entity:ClearStatus(CHARGE_STATUS)
	entity:ClearStatus(Shared.AIM_STATUS)
	self.Charging = false
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local fraction = charge / 100
	local affinity = self:GetAffinity("Melee")

	local start = entity.Root.CFrame:PointToWorldSpace(MIRROR_OFFSET)
	local position = start
	local direction = Shared.Direction(entity, position, input.AimPosition)
	local remaining = self:GetLevel("Melee") * RANGE_PER_LEVEL * affinity * fraction

	local params = Shared.RayParams(entity)
	local characterService = self.Services.Character
	local points: { Vector3 } = { position }
	local victim: any = nil
	-- Where the caster reappears: the end of the ray.
	local destination = position

	-- Characters that cannot be hit (dead, not spawned) are skipped without costing a
	-- reflection, hence the separate cap on the number of casts.
	local reflections = 0
	for _ = 1, MAX_REFLECTIONS * 2 do
		if remaining <= 0.01 or reflections >= MAX_REFLECTIONS then
			break
		end

		local result = Workspace:Raycast(position, direction * remaining, params)
		if not result then
			position += direction * remaining
			destination = position
			table.insert(points, position)
			break
		end

		local hit = characterService:GetEntityFromPart(result.Instance)
		if hit and (hit.Dead or not hit.Spawned) then
			params:AddToFilter(hit.Model)
			continue
		end

		remaining -= math.max((result.Position - position).Magnitude, 0.01)
		position = result.Position
		table.insert(points, position)
		reflections += 1

		destination = position
		-- The ray is reflected off a character too before it ends: the caster arrives
		-- looking that way.
		local reflected = direction - 2 * direction:Dot(result.Normal) * result.Normal
		if reflected.Magnitude > 0.05 then
			direction = reflected.Unit
		end
		if hit then
			victim = hit
			break
		end
	end

	if victim then
		local damage, trait = Shared.Haki(self, BASE_DAMAGE * self:GetLevelScale("Melee") * affinity * fraction)
		self:Damage(victim, damage, trait, nil, false)

		local away = victim.Root.Position - entity.Root.Position
		if away.Magnitude > 0.05 then
			local speed = math.clamp(KNOCKBACK * affinity * fraction, MIN_KNOCKBACK, MAX_KNOCKBACK)
			self:Impulse(
				victim,
				away.Unit * speed + Vector3.new(0, KNOCKBACK_LIFT, 0),
				KNOCKBACK_TIME,
				KNOCKBACK_FORCE,
				KNOCKBACK_POWER
			)
		end
	end

	local drawn = points
	if #points > MAX_EFFECT_POINTS then
		drawn = table.move(points, 1, MAX_EFFECT_POINTS, 1, {})
	end
	-- Sent around the start with a radius that also covers a long path.
	self.Services.Effect:Play(EFFECT, start, {
		Points = drawn,
		-- Thickness of the legacy beam: 1 + (level * 2 * affinity / 500) / 2.
		Thickness = 1 + self:GetLevel("Melee") * RANGE_PER_LEVEL * affinity / 1000,
		Colors = self:GetColorString(),
		Caster = entity.Model,
	}, EFFECT_RADIUS + (position - start).Magnitude)

	local function arrive()
		if entity.Dead or entity.Model.Parent == nil or entity.Humanoid.Sit then
			return
		end
		characterService:Teleport(entity, CFrame.lookAt(destination, destination + direction))
		entity:SetStatus(WARP_STATUS, true, WARP_HOLD, true)
	end
	if victim then
		task.delay(KNOCKBACK_TIME, arrive)
	else
		arrive()
	end
end

function YataMirror:OnInterrupt()
	self.ChargeStart = nil
	-- Only when this ability is the one aiming: OnInterrupt also runs for idle siblings.
	if self.Charging then
		self.Charging = false
		self.Entity:ClearStatus(Shared.AIM_STATUS)
	end
	self.Entity:ClearStatus(CHARGE_STATUS)
	self.Entity:ClearStatus(WARP_STATUS)
end

return YataMirror
