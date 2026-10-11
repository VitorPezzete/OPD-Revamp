--!strict
--[[
	What the three raid bosses (ChillyBoss, MagmaBoss, QuakeBoss) have in common. Not a
	behaviour: EnemyService only requires the module BossConfig names.

	The legacy AI scripts (ServerStorage.Boss.Normal.<Boss>.AI_*) opened with the same
	300 lines: Shave towards the target, Shave away from it, a lunge, and two BodyMovers
	that kept the boss afloat. That is Mover. The numbers are the same for the three.

		Shave towards   target further than 14 studs: a step of 95 studs, up to three
		                times that as health drops; lands 4 studs behind a target that is
		                within one step. Every 3.15 s at full health, down to 1.75 s.
		Shave away      a free spot 45 studs from the target (straight back, then 45 and
		                90 degrees to either side). 4 s before the next Shave.
		Lunge           160 studs/s at the target for 0.4 s, every 1.2 s.
		Sea             held at sea level instead of sinking; hops out (50 studs/s for
		                0.2 s) when its target is 5 studs above the water.

	Timeline: the legacy scripts were coroutines full of task.wait. A behaviour owns no
	thread here, so what happens "later" is an entry with a time, run by Think. Dropping
	the list (Destroy) cancels everything that had not happened yet.

	Legacy problems fixed here:
	- Hits were GetPartBoundsInBox / Touched over the whole map and hurt anything with a
	  Humanoid, other NPCs included. Players only, through Hitbox.
	- The Shave flash and its sound were instances created by the server.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local Push = require(ReplicatedStorage.Shared.Util.Push)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local BossTypes = require(ServerStorage.Server.Types.BossTypes)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

local Shared = {}

-- Fruit color string of an attack made with haki (the legacy 25, 12, 25 on everything).
Shared.HAKI_COLORS = "25,12,25,25,12,25"
Shared.HAKI_MULTIPLIER = 2

-- CombatService discards NPC hits from further than this; such hits are dealt unattributed.
local NPC_DAMAGE_RANGE = 200

local TELEPORT_MIN_DISTANCE = 14
local TELEPORT_STEP = 95
local TELEPORT_STEP_MAX_SCALE = 3
local TELEPORT_BEHIND = 4
local TELEPORT_COOLDOWN = 3.5
local TELEPORT_COOLDOWN_MAX_SCALE = 5
local RETREAT_DISTANCE = 45
local RETREAT_COOLDOWN = 4
local RETREAT_ANGLES = { 0, 45, -45, 90, -90 }
local RETREAT_PROBE_UP = 20
local RETREAT_PROBE_DOWN = 50

local FLOOR_PROBE_UP = 10
local FLOOR_PROBE_DOWN = 20
local FLOOR_OFFSET = 3

local DASH_SPEED = 160
local DASH_DURATION = 0.4
local DASH_COOLDOWN = 1.2
local DASH_FORCE = Vector3.new(1e6, 1e6, 1e6)
local DASH_POWER = 1250

local FLOAT_POWER = 10000
local FLOAT_RELEASE_MARGIN = 2
local ESCAPE_TARGET_MARGIN = 5
local ESCAPE_SPEED = 50
local ESCAPE_DURATION = 0.2
local VERTICAL_FORCE = Vector3.new(0, math.huge, 0)

------------------------------------------------------------------------------------------
-- Timeline

export type Timeline = { { At: number, Run: (at: number) -> () } }

-- `run` receives the time it was due, so a chain of entries does not drift with the think rate.
function Shared.After(timeline: Timeline, at: number, run: (at: number) -> ())
	table.insert(timeline, { At = at, Run = run })
end

function Shared.RunDue(timeline: Timeline, now: number)
	local index = 1
	while index <= #timeline do
		local entry = timeline[index]
		if entry.At <= now then
			-- Removed first: an entry that errors is not run again. Whatever it
			-- schedules lands at the end of the list and is looked at by this same pass.
			table.remove(timeline, index)
			entry.Run(entry.At)
		else
			index += 1
		end
	end
end

------------------------------------------------------------------------------------------
-- Combat

-- Only players are ever hit by a raid boss.
function Shared.Players(found: { CharacterEntity }): { CharacterEntity }
	local result: { CharacterEntity } = {}
	for _, entity in found do
		if entity.Player then
			table.insert(result, entity)
		end
	end
	return result
end

--[[
	Dead, or its model is no longer in the world. An entity whose model was destroyed
	without a death (a player who left, a boss model removed directly) never turns Dead:
	it would go on being hit, or go on attacking from where it stood.
]]
function Shared.Gone(entity: CharacterEntity): boolean
	return entity.Dead or entity.Model.Parent == nil or entity.Root.Parent == nil
end

function Shared.Damage(
	attacker: CharacterEntity,
	target: CharacterEntity,
	amount: number,
	trait: CombatTypes.DamageTrait,
	dodgeable: boolean,
	style: CombatTypes.DamageStyle?,
	tag: string?
): number
	if Shared.Gone(attacker) or Shared.Gone(target) or not target.Player then
		return 0
	end
	local inRange = (attacker.Root.Position - target.Root.Position).Magnitude <= NPC_DAMAGE_RANGE
	return Knit.GetService("CombatService"):Damage({
		Target = target,
		Attacker = if inRange then attacker else nil,
		Amount = amount,
		Trait = trait,
		Style = style or "Ability",
		Dodgeable = dodgeable,
		Tag = tag,
	})
end

function Shared.Stun(target: CharacterEntity, seconds: number, name: string)
	if not Shared.Gone(target) then
		Knit.GetService("StatusService"):ApplyStun(target, seconds, name)
	end
end

------------------------------------------------------------------------------------------
-- Body

function Shared.Face(entity: CharacterEntity, position: Vector3)
	local root = entity.Root
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

function Shared.LimbCFrame(entity: CharacterEntity, name: string): CFrame
	local limb = entity.Model:FindFirstChild(name)
	return if limb and limb:IsA("BasePart") then limb.CFrame else entity.Root.CFrame
end

-- Tracks by name; an id left out (nil) simply has no track.
function Shared.LoadTracks(entity: CharacterEntity, ids: { [string]: string? }): { [string]: AnimationTrack }
	local animator = entity.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", entity.Humanoid)
	local tracks: { [string]: AnimationTrack } = {}
	for name, id in ids do
		if id then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			tracks[name] = animator:LoadAnimation(animation)
		end
	end
	return tracks
end

-- Ground under `position` (3 studs above it, where a root stands), or `position` itself.
function Shared.Floor(position: Vector3, params: RaycastParams): Vector3
	local result = Workspace:Raycast(
		position + Vector3.new(0, FLOOR_PROBE_UP, 0),
		Vector3.new(0, -FLOOR_PROBE_DOWN, 0),
		params
	)
	return if result then result.Position + Vector3.new(0, FLOOR_OFFSET, 0) else position
end

------------------------------------------------------------------------------------------
-- Mover

local Mover = {}
Mover.__index = Mover

export type Mover = typeof(setmetatable(
	{} :: {
		Handle: BossTypes.BossHandle,
		Entity: CharacterEntity,
		Params: RaycastParams,
		DashTrack: AnimationTrack?,
		TeleportReady: number,
		DashReady: number,
		DashEnds: number,
		Swimming: boolean,
		Float: BodyPosition?,
		Escape: BodyVelocity?,
	},
	Mover
))

function Shared.NewMover(handle: BossTypes.BossHandle, dashTrack: AnimationTrack?): Mover
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { handle.Entity.Model }

	return setmetatable({
		Handle = handle,
		Entity = handle.Entity,
		Params = params,
		DashTrack = dashTrack,
		TeleportReady = 0,
		DashReady = 0,
		DashEnds = 0,
		Swimming = false,
		Float = nil :: BodyPosition?,
		Escape = nil :: BodyVelocity?,
	}, Mover)
end

-- Health lost so far as max / current, the way the legacy scripts scaled their Shave.
function Mover._missingScale(self: Mover, limit: number): number
	local entity = self.Entity
	if entity.Health <= 0 then
		return limit
	end
	return math.clamp(entity.MaxHealth / entity.Health, 1, limit)
end

function Mover._shave(self: Mover, landing: Vector3, lookAt: Vector3)
	local entity = self.Entity
	local from = entity.Root.Position
	local flat = Vector3.new(lookAt.X, landing.Y, lookAt.Z)
	local cframe = if (flat - landing).Magnitude > 0.1 then CFrame.lookAt(landing, flat) else CFrame.new(landing)
	local rotation = entity.Root.CFrame.Rotation

	self.Handle.Halt()
	Knit.GetService("CharacterService"):Teleport(entity, cframe)
	-- The flash MovementService plays for a player's Shave.
	Knit.GetService("EffectService"):Play("Shave", from, {
		Caster = entity.Model,
		Destination = landing,
		Rotation = rotation,
		Rumble = false,
		Colors = "None",
	})
end

function Mover.CanShave(self: Mover, now: number): boolean
	return now >= self.TeleportReady
end

-- Shave at the target when it is further than 14 studs. Returns whether it moved.
function Mover.ShaveTowards(self: Mover, target: CharacterEntity, distance: number, now: number): boolean
	if distance <= TELEPORT_MIN_DISTANCE or now < self.TeleportReady then
		return false
	end

	local position = self.Entity.Root.Position
	local targetRoot = target.Root
	local offset = targetRoot.Position - position
	local step = TELEPORT_STEP * self:_missingScale(TELEPORT_STEP_MAX_SCALE)
	local destination: Vector3
	if offset.Magnitude < step then
		destination = targetRoot.Position - targetRoot.CFrame.LookVector * TELEPORT_BEHIND
	else
		destination = position + offset.Unit * step
	end

	self.TeleportReady = now + TELEPORT_COOLDOWN * (1 - self:_missingScale(TELEPORT_COOLDOWN_MAX_SCALE) / 10)
	self:_shave(Shared.Floor(destination, self.Params), targetRoot.Position)
	return true
end

-- Shave to a reachable spot 45 studs from the target. Nothing happens without one.
function Mover.ShaveAway(self: Mover, target: CharacterEntity, now: number): boolean
	if now < self.TeleportReady then
		return false
	end

	local origin = self.Entity.Root.Position
	local targetPosition = target.Root.Position
	local away = origin - targetPosition
	away = if away.Magnitude > 1e-3 then away.Unit else -target.Root.CFrame.LookVector

	for _, angle in RETREAT_ANGLES do
		local direction = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(away)
		local attempt = origin + direction * RETREAT_DISTANCE
		local ground = Workspace:Raycast(
			attempt + Vector3.new(0, RETREAT_PROBE_UP, 0),
			Vector3.new(0, -RETREAT_PROBE_DOWN, 0),
			self.Params
		)
		if ground then
			-- Nothing between the boss and that spot but the ground it stands on.
			local wall = Workspace:Raycast(origin, ground.Position - origin, self.Params)
			if not wall or wall.Instance == ground.Instance then
				self.TeleportReady = now + RETREAT_COOLDOWN
				self:_shave(ground.Position + Vector3.new(0, FLOOR_OFFSET, 0), targetPosition)
				return true
			end
		end
	end
	return false
end

-- The legacy mover: a BodyVelocity of 1e6 on every axis for 0.4 s.
function Mover.Dash(self: Mover, target: CharacterEntity, now: number)
	if now < self.DashReady then
		return
	end
	self.DashReady = now + DASH_COOLDOWN

	local root = self.Entity.Root
	local offset = target.Root.Position - root.Position
	if offset.Magnitude < 1e-3 then
		return
	end

	local track = self.DashTrack
	if track then
		track:Play()
	end
	self.DashEnds = now + DASH_DURATION
	Push.Apply(root, offset.Unit * DASH_SPEED, DASH_DURATION, DASH_FORCE, DASH_POWER)
end

local function drop(mover: Instance?)
	if mover then
		mover:Destroy()
	end
end

-- Call on every think: ends the lunge clip and keeps the boss out of the sea.
function Mover.Update(self: Mover, target: CharacterEntity?, now: number)
	if self.DashEnds > 0 and now >= self.DashEnds then
		self.DashEnds = 0
		local track = self.DashTrack
		if track then
			track:Stop()
		end
	end

	local root = self.Entity.Root
	local sea = WorldConfig.SeaLevel

	-- Debris ends the hop after its 0.2 s, whatever the think rate.
	local escape = self.Escape
	if escape and not escape.Parent then
		self.Escape = nil
		self.Swimming = false
		escape = nil
	end

	if self.Swimming and not escape and target and target.Root.Position.Y > sea + ESCAPE_TARGET_MARGIN then
		drop(self.Float)
		self.Float = nil

		local hop = Instance.new("BodyVelocity")
		hop.MaxForce = VERTICAL_FORCE
		hop.Velocity = Vector3.new(0, ESCAPE_SPEED, 0)
		hop.Parent = root
		Debris:AddItem(hop, ESCAPE_DURATION)
		self.Escape = hop
		return
	end

	if root.Position.Y <= sea and not self.Swimming and not escape then
		self.Swimming = true
		local float = Instance.new("BodyPosition")
		float.MaxForce = VERTICAL_FORCE
		float.Position = Vector3.new(0, sea, 0)
		float.P = FLOAT_POWER
		float.Parent = root
		self.Float = float
	end

	if self.Float and root.Position.Y > sea + FLOAT_RELEASE_MARGIN then
		drop(self.Float)
		self.Float = nil
		self.Swimming = false
	end
end

function Mover.Destroy(self: Mover)
	drop(self.Float)
	drop(self.Escape)
	self.Float = nil
	self.Escape = nil
	self.Swimming = false
	local track = self.DashTrack
	if track then
		track:Stop()
	end
	local root = self.Entity.Root
	if root.Parent then
		Push.Clear(root)
	end
end

return Shared
