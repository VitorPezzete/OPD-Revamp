--!strict
--[[
	Blood fruit - Blood Convergence: a piercing lance of blood fired at the aim point.

	Cost:    10% of max health (doubled by Concentrate)
	Lance:   350 studs per second for 5 s (1750 studs); 3 studs wide, 6 with Concentrate.
	         Like the legacy part (not collidable, only its Touched on characters
	         mattered) it flies through walls and hits whoever stands on it at launch.
	Reach:   besides touching, every 0.1 s the lance strikes the first thing on the
	         100 studs ahead of it, if that is a character (walls stop this ray). This
	         is the legacy raycast loop: a target within 100 studs in the open is hit at
	         once, before the lance arrives.
	Damage:  2000 * sniper affinity * (sniper level / 500), doubled by Concentrate.
	         "Special", not dodgeable. Pierces: after the first character it hits, the
	         lance keeps cutting for 0.75 s more and is gone (the legacy part was
	         scheduled for removal 0.75 s after its first hit). The clients are told about
	         that first hit so the lance they draw ends with it.
	Heal:    10% * defense affinity of that damage per character hit, whatever the
	         target actually lost, as in the legacy game.
	Cooldown 1.5 s.

	Legacy problems fixed here:
	- An unanchored part with a LinearVelocity, a Touched connection and a
	  `while pierce.Parent` raycast loop per shot, all inside the remote handler. It is
	  one Projectile plus a bounded 0.1 s tick now, and the lance itself is the
	  BloodConvergence client effect.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Allies = require(ServerStorage.Server.Modules.Allies)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local BloodShared = require(script.Parent.BloodShared)

type CharacterEntity = CharacterEntity.CharacterEntity

local EFFECT = "BloodConvergence"

local COOLDOWN = 1.5
local HEALTH_COST = 10
local BASE_DAMAGE = 2000
local HEAL_FRACTION = 0.1
local SPEED = 350
local RANGE = SPEED * 5
local RADIUS = 1.5
local PIERCE_TIME = 0.75
local LIFETIME = 5
-- The legacy loop: a ray this long ahead of the lance, this often.
local REACH = 100
local REACH_INTERVAL = 0.1

local Convergence = Ability.extend()

function Convergence:CanBegin(): boolean
	return os.clock() - (self.LastCast or 0) >= COOLDOWN
end

function Convergence:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local origin = entity.Root.Position
	local offset = input.AimPosition - origin
	if offset.Magnitude < 1e-3 then
		return
	end
	local direction = Projectile.Lead(entity, origin, offset.Unit, SPEED, RANGE)

	self.LastCast = os.clock()
	self:StartCooldown(COOLDOWN)
	BloodShared.PayHealth(entity, HEALTH_COST)
	if entity.Dead then
		return
	end

	local scale = BloodShared.GetScale(entity)
	local damage = BASE_DAMAGE * self:GetAffinity("Sniper") * self:GetLevelScale("Sniper") * scale
	local healFraction = HEAL_FRACTION * self:GetAffinity("Defense")
	local radius = RADIUS * scale

	-- Tells the lances of one caster apart on the clients.
	self.Shots = (self.Shots or 0) + 1
	local shot: number = self.Shots

	self:PlayEffect(EFFECT, origin, {
		Shot = shot,
		Direction = direction,
		Speed = SPEED,
		Range = RANGE,
		Width = radius * 2,
		Concentrate = scale > 1,
	})

	local firstHit: number? = nil
	local struck: { [CharacterEntity]: boolean } = {}
	local function strike(target: CharacterEntity)
		local now = os.clock()
		if struck[target] or entity.Dead or (firstHit and now - firstHit > PIERCE_TIME) then
			return
		end
		struck[target] = true
		if not firstHit then
			firstHit = now
			-- Same origin as the launch: it must reach the clients that drew the lance.
			self:PlayEffect(EFFECT, origin, { Shot = shot, EndIn = PIERCE_TIME })
		end

		self:Damage(target, damage, "Special", nil, false)
		BloodShared.Heal(entity, damage * healFraction)
	end

	Projectile.Fire({
		Origin = origin,
		Direction = direction,
		Speed = SPEED,
		MaxDistance = RANGE,
		Radius = radius,
		Owner = entity,
		Pierce = true,
		IgnoreWorld = true,
		HitOverlapping = true,
		OnHit = strike,
	})

	local unit = direction.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	local firedAt = os.clock()
	local characterService = self.Services.Character
	local function reach()
		local now = os.clock()
		local elapsed = now - firedAt
		if entity.Dead or elapsed >= LIFETIME or (firstHit and now - firstHit > PIERCE_TIME) then
			return
		end

		local result = Workspace:Raycast(origin + unit * (SPEED * elapsed), unit * REACH, params)
		local hit = result and result.Instance
		if hit and hit:IsA("BasePart") then
			local target = characterService:GetEntityFromPart(hit)
			-- Found by its own ray, not by Hitbox: the ally rule is asked here.
			if
				target
				and target ~= entity
				and not target.Dead
				and target.Spawned
				and not Allies.Spares(entity, target)
			then
				strike(target)
			end
		end
		task.delay(REACH_INTERVAL, reach)
	end
	reach()
end

return Convergence
