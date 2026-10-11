--!strict
--[[
	Paw fruit - what its four abilities share (not an ability: AbilityService only loads
	modules by ability name).

	The power factor. Every size, speed and damage of the fruit is its maximum times
		factor = (level / cap) * affinity / 2            (the source's ((level / 500) * affinity) / 2)
	of the ability's own skill, times the charge fraction clamp(seconds held / full, 0.1, 1)
	for the charged ones. It is 1 at the level cap with an affinity of 2.

	One power at a time. The source scripts kept a single `using` variable: while one power
	is charging the keys of the other three do nothing. It is the server-only "PawBusy"
	status here (the name of the ability that holds it), since sibling ability objects do
	not see each other.

	Armament haki turns the paws dark for everyone and makes the hit "Haki" damage; each
	ability applies its own multiplier.

	Sea contact. Ursus Shock throws its paw the moment its user touches the sea. Nothing
	watches the world for that: WaterService already hits every fruit user in the water,
	DamageModifiers.PawUrsusShock sees that hit and calls TouchedWater, and the ability
	object that is holding a paw has left its handler here (OnWater), the two modules
	having no other way to reach each other.
]]
local Workspace = game:GetService("Workspace")

local Paw = {}

Paw.BUSY_STATUS = "PawBusy"

-- Clients are sent the paws of an ability within this distance of where they are drawn,
-- plus however far they can fly.
Paw.EFFECT_RADIUS = 400

local MIN_CHARGE_FRACTION = 0.1
-- Studs within which a stop is the end of the range (or the start), not a contact.
local END_TOLERANCE = 0.5
local nextId = 0

function Paw.Factor(ability: any, skill: string): number
	return ability:GetLevelScale(skill) * ability:GetAffinity(skill) / 2
end

-- Share of the full charge reached after holding since `started` (os.clock()).
function Paw.ChargeFraction(started: number, fullSeconds: number): number
	return math.clamp((os.clock() - started) / fullSeconds, MIN_CHARGE_FRACTION, 1)
end

function Paw.IsBusy(entity: any): boolean
	return entity:HasStatus(Paw.BUSY_STATUS)
end

function Paw.SetBusy(entity: any, abilityName: string)
	entity:SetStatus(Paw.BUSY_STATUS, abilityName)
end

-- Only the ability that holds the flag lifts it: OnInterrupt also runs for idle siblings.
function Paw.ClearBusy(entity: any, abilityName: string)
	if entity:GetStatus(Paw.BUSY_STATUS) == abilityName then
		entity:ClearStatus(Paw.BUSY_STATUS)
	end
end

-- Not weak: a handler holds its ability, which holds the entity. Whoever sets one clears it.
local waterHandlers: { [any]: () -> () } = {}

-- What to run when `entity` is hit by the sea; nil removes it. One per entity.
function Paw.OnWater(entity: any, handler: (() -> ())?)
	waterHandlers[entity] = handler
end

--[[
	Called from inside the damage pipeline (a modifier's Apply), so the handler runs
	deferred: it may clear statuses and start a projectile, neither of which belongs in
	the middle of someone's hit. The handler checks for itself that it is still wanted.
]]
function Paw.TouchedWater(entity: any)
	local handler = waterHandlers[entity]
	if handler then
		task.defer(handler)
	end
end

-- Unit direction from `origin` to the aim point; the look vector when they coincide.
function Paw.Direction(entity: any, origin: Vector3, aim: Vector3): Vector3
	local offset = aim - origin
	if offset.Magnitude < 0.05 then
		return entity.Root.CFrame.LookVector
	end
	return offset.Unit
end

--[[
	Where the MIDDLE of a paw of `radius` was when Projectile stopped it at `stopped`.
	Projectile reports the point of contact of a hit, on the surface of what was touched;
	the source burst around the middle of the paw, a radius behind that (37.5 studs for a
	full Ursus Shock). The end of the range and a paw stopped where it started are already
	the middle.
]]
function Paw.Centre(origin: Vector3, direction: Vector3, range: number, radius: number, stopped: Vector3): Vector3
	local unit = direction.Unit
	local offset = stopped - origin
	local along = offset:Dot(unit)
	local across = (offset - unit * along).Magnitude
	if across < END_TOLERANCE and (math.abs(along) < END_TOLERANCE or math.abs(along - range) < END_TOLERANCE) then
		return stopped
	end
	local behind = if across < radius then math.sqrt(radius * radius - across * across) else 0
	return origin + unit * math.clamp(along - behind, 0, range)
end

--[[
	Middle of a paw of `radius` that cannot reach `origin` from the user's root because a
	wall is in the way, nil when it can. A shape cast never reports what the shape already
	overlaps, so a paw started against (or behind) a wall would fly through it; the source
	paw burst on whatever it was in when it left the hand.
]]
function Paw.Blocked(ability: any, origin: Vector3, radius: number): Vector3?
	local entity = ability.Entity
	local from: Vector3 = entity.Root.Position
	local offset = origin - from
	if offset.Magnitude < 1e-3 or radius <= 0 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	local result = Workspace:Spherecast(from, radius, offset, params)
	-- A character in the way is Projectile's business (HitOverlapping).
	if not result or ability.Services.Character:GetEntityFromPart(result.Instance) then
		return nil
	end
	return from + offset.Unit * result.Distance
end

-- Names one paw in flight, so the effect that ends it can find the one that drew it.
function Paw.NextId(): number
	nextId += 1
	return nextId
end

return Paw
