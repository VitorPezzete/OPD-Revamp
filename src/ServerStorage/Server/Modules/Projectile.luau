--!strict
--[[
	Server-simulated projectiles with no instances: each one is a point advanced by a
	shape cast every frame. The legacy game spawned an unanchored Part with a
	LinearVelocity and a Touched connection per shot. Clients draw the visual
	themselves (EffectService:Play with the same origin, direction and speed).

	What the legacy parts did besides flying straight, as options:
	- Gravity: an acceleration (studs/s^2) added to the velocity every step, for shots that
	  arc. Speed and Direction are then only the launch velocity.
	- IgnoreWorld: walls, ground and props do not stop it (the legacy part was CanCollide
	  false and only reacted to characters); only characters and MaxDistance end it.
	- HitOverlapping: characters already inside the sphere when it is fired are hit too. A
	  shape cast only reports what the sphere runs INTO, and a large ball starts on top of
	  whoever stands next to the caster.

	Aim assistance: Projectile.Lead(owner, origin, direction, speed) bends a shot of a
	player on a gamepad or a touch screen (InputService:HasAimAssist) towards the target
	closest to where it was aimed, inside a narrow cone, and aims where that target will
	be when the shot arrives. Callers use it before drawing the shot, so the visual and
	the hit follow the same line:

		direction = Projectile.Lead(entity, origin, direction, SPEED, range)
		self:PlayEffect(EFFECT, origin, { Direction = direction, ... })
		Projectile.Fire({ Origin = origin, Direction = direction, ... })

	A shot that does not fly straight (it falls, or loses speed) passes how:
	Projectile.Lead(entity, origin, direction, speed, range, gravity, drag), gravity in
	studs/s^2 downwards and drag as the share of its velocity lost per second. The
	direction returned is then the LAUNCH direction that makes that arc meet the target,
	for the thrown balls and lobbed shots as much as for the straight ones.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Allies = require(ServerStorage.Server.Modules.Allies)

type CharacterEntity = CharacterEntity.CharacterEntity

export type ProjectileConfig = {
	Origin: Vector3,
	Direction: Vector3,
	Speed: number,
	MaxDistance: number,
	-- 0 casts a ray, anything larger casts a sphere of that radius.
	Radius: number?,
	Owner: CharacterEntity?,
	-- Keep flying after hitting an entity (each entity is hit once).
	Pierce: boolean?,
	Gravity: Vector3?,
	IgnoreWorld: boolean?,
	HitOverlapping: boolean?,
	OnHit: (target: CharacterEntity, position: Vector3) -> (),
	-- Called once when the projectile stops: world hit, entity hit or max distance.
	OnEnd: ((position: Vector3) -> ())?,
}

type Active = {
	Config: ProjectileConfig,
	Position: Vector3,
	Velocity: Vector3,
	Travelled: number,
	Params: RaycastParams,
	Hit: { [CharacterEntity]: boolean },
}

-- World parts an IgnoreWorld projectile may pass through in one step before it waits
-- for the next one.
local MAX_PASSES = 8

-- Widest angle (degrees) between the aimed line and a target the assistance takes.
local ASSIST_ANGLE = 9
-- Targets further than this (studs) are not helped, whatever the range of the shot.
local ASSIST_RANGE = 400
-- A target that would take longer than this to reach is aimed at where it is.
local MAX_LEAD_SECONDS = 1.5

local Projectile = {}

local active: { Active } = {}
local connection: RBXScriptConnection? = nil

local function finish(index: number, projectile: Active)
	table.remove(active, index)
	if projectile.Config.OnEnd then
		task.spawn(projectile.Config.OnEnd, projectile.Position)
	end
end

local function step(deltaTime: number)
	local characterService = Knit.GetService("CharacterService")

	for index = #active, 1, -1 do
		local projectile = active[index]
		local config = projectile.Config
		if config.Gravity then
			projectile.Velocity += config.Gravity * deltaTime
		end
		local speed = projectile.Velocity.Magnitude
		if speed < 1e-4 then
			continue
		end
		local direction = projectile.Velocity / speed
		local distance = math.min(speed * deltaTime, config.MaxDistance - projectile.Travelled)
		local displacement = direction * distance
		local radius = config.Radius or 0

		-- Whatever the cast meets and the projectile passes through (a character already
		-- hit, the world for an IgnoreWorld shot) is taken out of the cast, which is then
		-- repeated: nothing behind it in the same step is skipped.
		local stopped = false
		local result: RaycastResult? = nil
		for _ = 1, MAX_PASSES do
			result = if radius > 0
				then Workspace:Spherecast(projectile.Position, radius, displacement, projectile.Params)
				else Workspace:Raycast(projectile.Position, displacement, projectile.Params)
			if not result then
				break
			end

			local entity = characterService:GetEntityFromPart(result.Instance)
			-- A character the owner must leave alone (Allies.Spares: the other players of
			-- a raid) is flown through like one that is down: it falls to the branch below.
			if
				entity
				and entity ~= config.Owner
				and not entity.Dead
				and entity.Spawned
				and not Allies.Spares(config.Owner, entity)
			then
				if not projectile.Hit[entity] then
					projectile.Hit[entity] = true
					task.spawn(config.OnHit, entity, result.Position)
				end
				if not config.Pierce then
					stopped = true
					break
				end
				projectile.Params:AddToFilter(entity.Model)
			elseif entity then
				projectile.Params:AddToFilter(entity.Model)
			elseif config.IgnoreWorld then
				projectile.Params:AddToFilter(result.Instance)
			else
				stopped = true
				break
			end
		end

		if stopped and result then
			projectile.Position = result.Position
			finish(index, projectile)
			continue
		end
		projectile.Position += displacement
		projectile.Travelled += distance
		if projectile.Travelled >= config.MaxDistance then
			finish(index, projectile)
		end
	end

	if #active == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

-- Seconds for a shot from `origin` at `speed` to meet a target at `position` moving at
-- `velocity`, nil when it cannot.
local function interceptTime(origin: Vector3, speed: number, position: Vector3, velocity: Vector3): number?
	local offset = position - origin
	local a = velocity:Dot(velocity) - speed * speed
	local b = 2 * offset:Dot(velocity)
	local c = offset:Dot(offset)
	if math.abs(a) < 1e-6 then
		return if math.abs(b) > 1e-6 and -c / b > 0 then -c / b else nil
	end
	local discriminant = b * b - 4 * a * c
	if discriminant < 0 then
		return nil
	end
	local root = math.sqrt(discriminant)
	local first, second = (-b - root) / (2 * a), (-b + root) / (2 * a)
	local best = math.huge
	for _, time in { first, second } do
		if time > 0 and time < best then
			best = time
		end
	end
	return if best < math.huge then best else nil
end

-- Distance along its launch direction a shot has covered after `time` seconds, and how
-- far it has fallen by then. With drag k the velocity decays as e^(-k t).
local function travel(speed: number, gravity: number, drag: number, time: number): (number, number)
	if drag > 1e-4 then
		local decayed = 1 - math.exp(-drag * time)
		return speed / drag * decayed, gravity / drag * (time - decayed / drag)
	end
	return speed * time, gravity * time * time / 2
end

-- Seconds a shot needs to cover `distance` along its launch direction, nil when drag
-- stops it before that.
local function timeToCover(speed: number, drag: number, distance: number): number?
	if drag > 1e-4 then
		local share = distance * drag / speed
		return if share < 1 then -math.log(1 - share) / drag else nil
	end
	return distance / speed
end

--[[
	Launch direction that makes a falling / slowing shot meet a target at `position` moving
	at `velocity`, and the flight time; nil when it cannot get there. A few rounds of
	"where is the target after this long, how far must the shot fly to be there (the
	fall added back), how long does that take" settle within a frame's worth of error.
]]
local function ballistic(
	origin: Vector3,
	speed: number,
	gravity: number,
	drag: number,
	position: Vector3,
	velocity: Vector3
): (Vector3?, number?)
	local time = timeToCover(speed, drag, (position - origin).Magnitude)
	local launch: Vector3? = nil
	for _ = 1, 5 do
		if not time then
			return nil, nil
		end
		local _, fall = travel(speed, gravity, drag, time)
		local along = position + velocity * time - origin + Vector3.new(0, fall, 0)
		if along.Magnitude < 1e-4 then
			return nil, nil
		end
		launch = along.Unit
		time = timeToCover(speed, drag, along.Magnitude)
	end
	return launch, time
end

--[[
	Aim assistance for a shot (see the header). Returns `direction` unchanged for NPCs, for
	players on a mouse or with the setting off, and when no target is close to the line.
	The result keeps the magnitude of `direction`.
]]
function Projectile.Lead(
	owner: CharacterEntity?,
	origin: Vector3,
	direction: Vector3,
	speed: number,
	range: number?,
	gravity: number?,
	drag: number?
): Vector3
	local player = owner and owner.Player
	local length = direction.Magnitude
	if not owner or not player or length < 1e-4 or speed <= 0 then
		return direction
	end
	if not Knit.GetService("InputService"):HasAimAssist(player) then
		return direction
	end

	local unit = direction / length
	local reach = math.min(range or ASSIST_RANGE, ASSIST_RANGE)
	local limit = math.cos(math.rad(ASSIST_ANGLE))
	local best: CharacterEntity? = nil
	local bestDot = limit
	for _, entity in Knit.GetService("CharacterService"):GetEntities() do
		-- Never bent towards somebody the shot will not hit.
		if entity == owner or entity.Dead or not entity.Spawned or Allies.Spares(owner, entity) then
			continue
		end
		local offset = entity.Root.Position - origin
		local distance = offset.Magnitude
		if distance < 1 or distance > reach then
			continue
		end
		local dot = unit:Dot(offset / distance)
		if dot > bestDot then
			best, bestDot = entity, dot
		end
	end
	if not best then
		return direction
	end

	local root = best.Root
	local fall, slow = gravity or 0, drag or 0
	if fall > 0 or slow > 0 then
		local launch, flight = ballistic(origin, speed, fall, slow, root.Position, root.AssemblyLinearVelocity)
		if launch and flight and flight <= MAX_LEAD_SECONDS then
			return launch * length
		end
		-- Too far to lead: the arc that reaches where the target is now, if there is one.
		launch = ballistic(origin, speed, fall, slow, root.Position, Vector3.zero)
		return if launch then launch * length else direction
	end

	local time = interceptTime(origin, speed, root.Position, root.AssemblyLinearVelocity)
	local aimPoint = if time and time <= MAX_LEAD_SECONDS
		then root.Position + root.AssemblyLinearVelocity * time
		else root.Position
	local aimed = aimPoint - origin
	return if aimed.Magnitude > 1e-4 then aimed.Unit * length else direction
end

function Projectile.Fire(config: ProjectileConfig)
	if config.Direction.Magnitude < 1e-4 then
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if config.Owner then
		params.FilterDescendantsInstances = { config.Owner.Model }
	end

	local projectile: Active = {
		Config = config,
		Position = config.Origin,
		Velocity = config.Direction.Unit * config.Speed,
		Travelled = 0,
		Params = params,
		Hit = {},
	}

	local radius = config.Radius or 0
	if config.HitOverlapping and radius > 0 then
		local characterService = Knit.GetService("CharacterService")
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		if config.Owner then
			overlap.FilterDescendantsInstances = { config.Owner.Model }
		end
		for _, part in Workspace:GetPartBoundsInRadius(config.Origin, radius, overlap) do
			local entity = characterService:GetEntityFromPart(part)
			if
				entity
				and entity ~= config.Owner
				and not entity.Dead
				and entity.Spawned
				and not projectile.Hit[entity]
				and not Allies.Spares(config.Owner, entity)
			then
				projectile.Hit[entity] = true
				task.spawn(config.OnHit, entity, entity.Root.Position)
				if not config.Pierce then
					if config.OnEnd then
						task.spawn(config.OnEnd, config.Origin)
					end
					return
				end
				params:AddToFilter(entity.Model)
			end
		end
	end

	table.insert(active, projectile)

	-- The stepping connection only exists while something is in flight.
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
end

return Projectile
