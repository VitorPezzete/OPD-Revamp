--!strict
--[[
	Rumble fruit - El Thor (charged).

	Charge: 25 per second held, 4 to 200 (timed on the server, from the rounded start the
	legacy server used - see _Shared).
	With a = sniper affinity and s = sniper level / cap:

	Charge below 20 - a lightning beam from the casting hand towards the aim point.
	- length: up to 200 * a studs, stopped by the first thing in the way;
	- damage: 300 * a * s to everyone along it (a 12 x 12 box over its whole length) and
	  within 7.5 studs of where it ends.

	Charge 20 and above - a thunder cloud forms over the aim point and strikes 1.5 s later.
	- damage: 6000 * a * s * charge / 200 to everyone whose root centre is inside the
	  bolt, a vertical square column (world aligned) over the aim point of
	      side        800 * a * (charge / 200) * s / 19.23 studs,
	      height      clamp(130 * a * charge / 200, 75, 260) studs,
	      centered    (33 or 38) + charge / 20 studs above the aim point
	                  (33 up to charge 60, 38 above: the legacy "place" offsets).
	  It is narrow at low charge (about 4 studs at charge 20, level 500, affinity 1).
	Once released the strike is on its way like a projectile: stunning or sealing the user
	does not call it off, only the user's death does.

	Both: "Special" damage, not dodgeable ("Melee" on Gum users), and the players hit are
	electrocuted (see _Shared). Cannot start while Lightning Blitz is charging.
	The hands alternate (see _Shared); while the key is held the replicated
	"RumbleThorCharging" status (value: the hand) drives the charge pose on the clients.

	Legacy problems fixed / readings chosen:
	- The beam was hit-tested three ways at once (a box around a part half as long as the
	  beam and placed past its end, plus Touched on two parts tweened to 15 studs) with a
	  Touched connection never disconnected. It is one box along the real beam and one
	  sphere at its end.
	- The "place" ladder had four unreachable branches (> 70, > 100, > 170, > 180 came
	  after > 60); the two values that could actually happen are kept.
	- The handler yielded 3.5 s inside the remote connection and created every part of
	  the cloud on the server.
	- The shared `charge` upvalue was read by the hit test after the 1.5 s wait, so another
	  release in between changed the column. Everything is captured at release.
	- A Gum user could be struck twice by one beam (that branch skipped the "already
	  damaged" mark).
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local BEAM_EFFECT = "RumbleThorBeam"
local STRIKE_EFFECT = "RumbleElThor"
local DAMAGE_TAG = "RumbleElThor"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 200
local STRIKE_CHARGE = 20

local BEAM_DAMAGE = 300
local BEAM_RANGE = 200
local BEAM_WIDTH = 12
local BEAM_END_RADIUS = 7.5

local STRIKE_DAMAGE = 6000
local STRIKE_DELAY = 1.5
-- Studs of the legacy bolt mesh per unit of mesh scale.
local MESH_UNIT = 19.23076923
local STRIKE_WIDTH = 800
local STRIKE_HEIGHT = 130
local STRIKE_HEIGHT_MIN = 75
local STRIKE_HEIGHT_MAX = 260
local STRIKE_PLACE_LOW = 160
local STRIKE_PLACE_HIGH = 165
local STRIKE_PLACE_CHARGE = 60
local STRIKE_CENTER_DROP = 127
-- The cloud can be 1000 studs from the user: send it to everyone who could see it.
local STRIKE_EFFECT_RADIUS = 1500

local ElThor = Ability.extend()
-- The legacy script dealt this damage without a style: ResistAbilities does not apply.
ElThor.DamageStyle = "Plain"

function ElThor:CanBegin(): boolean
	return not self.Entity:HasStatus(Shared.BlitzChargeStatus)
end

function ElThor:OnBegin()
	Shared.BeginCharge(self, CHARGE_MAX / CHARGE_RATE)
	self.Entity:SetStatus(Shared.ThorChargeStatus, Shared.GetHand(self.Entity), nil, true)
end

function ElThor:_strike(target: CharacterEntity, damage: number)
	self:Damage(target, damage, Shared.TraitFor(self.Services, target), DAMAGE_TAG, false)
	Shared.Electrocute(self.Services, target)
end

function ElThor:_beam(aim: Vector3, hand: string)
	local entity: CharacterEntity = self.Entity
	local affinity = self:GetAffinity("Sniper")
	local damage = BEAM_DAMAGE * affinity * self:GetLevelScale("Sniper")

	local origin = Shared.GetHandPosition(entity, hand)
	local direction = aim - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	direction = direction.Unit

	local range = BEAM_RANGE * affinity
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	local result = Workspace:Raycast(origin, direction * range, params)
	local finish = if result then result.Position else origin + direction * range
	local length = (finish - origin).Magnitude

	self:PlayEffect(BEAM_EFFECT, origin, { Target = finish })

	local struck: { [CharacterEntity]: boolean } = {}
	if length > 0.1 then
		local center = CFrame.lookAt(origin, finish) * CFrame.new(0, 0, -length / 2)
		for _, target in Hitbox.Box(center, Vector3.new(BEAM_WIDTH, BEAM_WIDTH, length), entity) do
			struck[target] = true
			self:_strike(target, damage)
		end
	end
	for _, target in Hitbox.Sphere(finish, BEAM_END_RADIUS, entity) do
		if not struck[target] then
			struck[target] = true
			self:_strike(target, damage)
		end
	end
end

function ElThor:_thunder(aim: Vector3, charge: number)
	local entity: CharacterEntity = self.Entity
	local affinity = self:GetAffinity("Sniper")
	local scale = self:GetLevelScale("Sniper")
	local percent = charge / CHARGE_MAX

	local damage = STRIKE_DAMAGE * affinity * scale * percent
	local side = STRIKE_WIDTH * affinity * percent * scale / MESH_UNIT
	local height = math.clamp(STRIKE_HEIGHT * affinity * percent, STRIKE_HEIGHT_MIN, STRIKE_HEIGHT_MAX)
	local place = if charge <= STRIKE_PLACE_CHARGE then STRIKE_PLACE_LOW else STRIKE_PLACE_HIGH
	local center = aim + Vector3.new(0, place - STRIKE_CENTER_DROP + charge / 20, 0)

	-- Not self:PlayEffect: this one needs a wider audience than the default radius.
	self.Services.Effect:Play(STRIKE_EFFECT, aim, {
		Colors = self:GetColorString(),
		Caster = entity.Model,
		Charge = charge,
		Affinity = affinity,
		Scale = scale,
		Place = place,
		Delay = STRIKE_DELAY,
	}, STRIKE_EFFECT_RADIUS)

	task.delay(STRIKE_DELAY, function()
		if entity.Dead then
			return
		end
		-- Legacy tested the centre of the root against the box, with no margin for the body.
		local half = Vector3.new(side, height, side) / 2
		for _, target in Hitbox.Box(CFrame.new(center), half * 2, entity) do
			local offset = target.Root.Position - center
			if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
				self:_strike(target, damage)
			end
		end
	end)
end

function ElThor:OnEnd(input: Ability.AbilityInput)
	local charge = Shared.EndCharge(self, CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	self.Entity:ClearStatus(Shared.ThorChargeStatus)
	if not charge then
		return
	end

	local hand = Shared.GetHand(self.Entity)
	Shared.SwapHand(self.Entity)

	if charge < STRIKE_CHARGE then
		self:_beam(input.AimPosition, hand)
	else
		self:_thunder(input.AimPosition, charge)
	end
end

function ElThor:OnInterrupt()
	self.ChargeStart = nil
	self.ChargeBegan = nil
	self.Entity:ClearStatus(Shared.ThorChargeStatus)
end

return ElThor
