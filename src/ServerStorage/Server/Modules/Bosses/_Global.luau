--!strict
--[[
	The engine behind CandyBoss, SandBoss and RandomBoss (legacy AI_Global, one 3700 line
	script cloned into each of the three models). NOT a boss: EnemyService only requires
	the module BossConfig names, and the three bosses are thin wrappers that hand this
	engine their fruits.

	A boss fights with the devil fruits it was given (one for Candy / Sand, two random
	ones for RandomBoss). The numbers come from AI_Global, not from the players' versions
	of the same powers: the script used its own levels (melee 850, defense / sniper /
	sword 750, affinity 1.7, each divided by 500) whatever the model's Config said.

	How the fruit moves are cast. The players' ability classes cannot be driven by a boss:
	they are built around a Player (saved affinities, levels over the cap, charge held on
	a key, cooldown reports to a HUD) and the boss versions differ from them in every
	number that matters (wind-up, size, timing, damage). So this engine owns the logic and
	the numbers, and reuses what the fruits already have for everything else: their
	client effects (CandyWave, SandSpike, MagmaEruption, QuakeStomp, PlasmaCannon ... get
	the boss's numbers as params), their status effects (CandyBody, CandyBlades,
	MagmaBody, SmeltBody, SmeltSword, PlasmaCoil, PlasmaRushing, SandRoped) and their
	shared helpers (Candy's sticky touch, Quake's resource lookup). A BossGlobal* effect
	exists only where the boss move has no player twin.

	One think (EnemyService, 10 per second while a player is near), in the legacy order:
	- kneel when enough skills were used (the opening to hit it): 3-6 skills the first
	  time, 6-7 afterwards; 6 to 10 s by fruit, 2 s more with two fruits;
	- below 65 % health: haki, every hit is "Haki" and doubled;
	- target hugging it while a third skill recharges     Shave 45 studs away
	- target a step above / below, or 65 studs above       lunge
	- target further than 14 studs                         Shave towards it (behind it
	                                                       when within one step)
	- every fruit, in the legacy order, picks one move from its own if / elseif chain;
	- otherwise walk at the target.
	The distance used by the chains is the one measured BEFORE the Shave, as in the
	legacy loop: the boss lands behind its target and still throws the ranged move it had
	picked from afar.

	The legacy script blocked its only loop with wait() inside every move. Here a move
	sets BusyUntil and schedules its release; nothing else is decided meanwhile. What is
	already in the air (balls, pools, walls) is advanced by one self-rescheduling pump
	that only runs while something is alive. Every delay, status and volume ends with the
	boss (Destroy).

	Legacy problems fixed here:
	- Every move created server parts with Touched / Heartbeat connections; hits are
	  shapes tested against the tracked characters, and only players are ever hit.
	- A target that left during a wind-up errored the script and froze the boss for good.
	- Smelt Spew tested "elapsed % 0.25 < 0.05" on Heartbeat, i.e. about three hits per
	  quarter second depending on the frame rate; it is one hit per 0.25 s.
	- The boss floated at sea level on a BodyPosition; it is put back at its spawn.
	- Energize followed the character that was targeted when it was cast and errored
	  when that character died; the contact damage simply stops then.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local Push = require(ReplicatedStorage.Shared.Util.Push)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local CandyShared = require(ServerStorage.Server.Modules.Abilities.Candy._Shared)
local QuakeShared = require(ServerStorage.Server.Modules.Abilities.Quake._Shared)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local BossTypes = require(ServerStorage.Server.Types.BossTypes)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity
type Trait = CombatTypes.DamageTrait
type Style = CombatTypes.DamageStyle

-- AI_Global's own levels, as the factors its formulas used.
local AFFINITY = 1.7
local MELEE = 850 / 500
local DEFENSE = 750 / 500
local SNIPER = 750 / 500
local SWORD = 750 / 500

local HAKI_HEALTH_FRACTION = 0.65
local HAKI_MULTIPLIER = 2

-- Order in which the legacy loop let its fruits act.
local ORDER = { "Magma", "Sand", "Candy", "Quake", "Flare", "Plasma", "Smelt" }
-- Children of the legacy model's Fruits folder: what RandomBoss rolls from.
local ROLLABLE = { "Candy", "Sand", "Quake", "Magma", "Plasma", "Flare", "Smelt" }
-- Seconds on its knees, by fruit (the longest of its fruits counts).
local KNEEL_SECONDS: { [string]: number } = {
	Magma = 10,
	Flare = 8,
	Quake = 9,
	Sand = 6,
	Candy = 7,
	Plasma = 8,
	Smelt = 9,
}
local KNEEL_MIN = 5
local KNEEL_EXTRA_TWO_FRUITS = 2
local KNEEL_ROOT = "BossGlobalKneel"

-- Effect colors of each fruit (legacy getColors), as fruit color strings.
local COLORS: { [string]: string } = {
	Candy = "31,128,29,212,209,154",
	Sand = "236,213,145,168,150,97",
	Quake = "255,255,255,139,80,55",
	Magma = "255,0,0,139,80,55",
	Flare = "255,85,0,226,155,64",
	Plasma = "221,117,255,221,117,255",
	-- Body: white with red sparks. Sword and pool: the third color, orange.
	Smelt = "242,242,242,214,35,35",
	SmeltMolten = "226,155,64,214,35,35",
}

local TAUNTS = {
	"You lagging or just bad?",
	"Do you need a tutorial?",
	"I wasn't even trying",
	"That's embarrassing",
	"Sit down",
	"Ez",
}

-- CombatService discards NPC hits from further than this; such hits are dealt unattributed.
local NPC_DAMAGE_RANGE = 200
-- Same body allowance as Hitbox.
local BODY_RADIUS = 2.5
-- Seconds between two steps of what is in the air.
local STEP = 0.05
-- A move whose cooldown starts at its release, with nothing after it, holds the move
-- this long past the wind-up: the think that follows BusyUntil can run a moment before
-- the delayed release does, and would cast the same move a second time.
local RELEASE_GRACE = 0.5
local MAX_PART_SIZE = Vector3.new(2048, 2048, 2048)
local EFFECT_RADIUS = AbilityConfig.EffectRadius
local FAR_EFFECT_RADIUS = 1200

local FLOOR_PROBE_UP = 10
local FLOOR_PROBE_DOWN = 20
local FLOOR_OFFSET = 3

local TELEPORT_MIN_DISTANCE = 14
local TELEPORT_STEP = 95
local TELEPORT_STEP_MAX_SCALE = 3
local TELEPORT_BEHIND = 4
local TELEPORT_COOLDOWN = 3.5
local RETREAT_BELOW_DISTANCE = 4
local RETREAT_DISTANCE = 45
local RETREAT_COOLDOWN = 4
local RETREAT_ANGLES = { 0, 45, -45, 90, -90 }
local DASH_SPEED = 160
local DASH_SECONDS = 0.4
local DASH_COOLDOWN = 1.2
local DASH_FORCE = Vector3.new(1e6, 1e6, 1e6)
local DASH_POWER = 1250

local ANTI_HEAL_FRACTION = 0.8
local ANTI_HEAL_HITS = 15
-- "A body part touched something": body contact range.
local BODY_CONTACT_RADIUS = 3.5

type Contact = {
	Radius: number,
	Cooldown: number,
	Last: { [CharacterEntity]: number },
	Hit: (target: CharacterEntity) -> (),
}

export type Options = {
	-- Fruit names among Global.Rollable.
	Fruits: { string },
	-- Walk speed of the legacy model's Humanoid.
	WalkSpeed: number,
}

local Global = {}
Global.__index = Global

Global.Rollable = ROLLABLE

type Self = typeof(setmetatable(
	{} :: {
		Handle: BossTypes.BossHandle,
		Entity: CharacterEntity,
		Fruits: { string },
		Active: { [string]: boolean },

		Combat: any,
		Characters: any,
		Effects: any,
		Status: any,
		FruitService: any,

		Haki: boolean,
		Destroyed: boolean,
		Kneeling: boolean,
		BusyUntil: number,
		-- Index in Fruits the interrupted round goes on from, with the distances it measured.
		Resume: number?,
		RoundDistance: number,
		RoundVertical: number,
		SkillsUsed: number,
		KneelAt: number,

		Ready: { [string]: number },
		TeleportReady: number,
		DashReady: number,

		Tracks: { [string]: AnimationTrack },
		Jobs: { [thread]: boolean },
		Volumes: { (now: number) -> boolean },
		Pumping: boolean,
		Contacts: { [string]: Contact },
		Statuses: { [string]: boolean },
		Roped: { [CharacterEntity]: string },
		Watched: CharacterEntity?,
		WatchConnection: any,
		FloorParams: RaycastParams,

		CandyOn: boolean,
		-- Shared by the Magma and the Smelt body, as the legacy `activebody` flag was:
		-- a boss with both fruits only ever wears the first one it turns on.
		BodyOn: boolean,
		SwordOn: boolean,
		Energized: boolean,
		SwingCount: number,
		LastSwing: number,
	},
	Global
))

local function unitOr(vector: Vector3, fallback: Vector3): Vector3
	return if vector.Magnitude > 1e-3 then vector.Unit else fallback
end

-- Size of a fruit model in ReplicatedStorage.Assets.Models.Fruits; only read so that a
-- hit shape is as large as the picture the clients draw from the same model.
local function assetSize(fallback: Vector3, ...: string): Vector3
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", ... } do
		current = if current then current:FindFirstChild(name) else nil
	end
	return if current and current:IsA("BasePart") then current.Size else fallback
end

-- Where a thrown thing is `age` seconds after its launch: `drag` is the share of its
-- velocity lost per second, `gravity` in studs/s^2 downwards. Mirrored by the clients.
local function ballistic(origin: Vector3, velocity: Vector3, gravity: number, drag: number, age: number): Vector3
	if drag > 1e-6 then
		local decayed = (1 - math.exp(-drag * age)) / drag
		return origin + velocity * decayed - Vector3.yAxis * (gravity / drag * (age - decayed))
	end
	return origin + velocity * age - Vector3.yAxis * (gravity * age * age / 2)
end

local function loadTracks(entity: CharacterEntity): { [string]: AnimationTrack }
	local animator = entity.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", entity.Humanoid)
	local config: any = AnimationConfig
	local fruitAnims: { [string]: string } = config.FruitAnims or {}
	local candy: { [string]: string } = (config.Fruits and config.Fruits.Candy) or {}

	-- The legacy models carried their own clips (Animations folder); they win when present.
	local own = entity.Model:FindFirstChild("Animations")
	local function fromModel(name: string, fallback: string?): string?
		local animation = own and own:FindFirstChild(name)
		return if animation and animation:IsA("Animation") then animation.AnimationId else fallback
	end

	local ids: { [string]: string? } = {
		Charge = fruitAnims.Punch1RightCharge,
		Release = fruitAnims.Punch1RightCharged,
		Final = fruitAnims.PunchRight,
		Blade = fromModel("Candy2", candy.Anim2),
		Kneel = fromModel("Kneeling", "rbxassetid://78262245057660"),
		Dash = config.Dash,
		Dagger1 = config.Dagger1,
		Dagger2 = config.Dagger2,
	}

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

function Global.new(handle: BossTypes.BossHandle, options: Options): Self
	local entity = handle.Entity
	entity:SetBaseWalkSpeed(options.WalkSpeed)

	local active: { [string]: boolean } = {}
	for _, fruit in options.Fruits do
		active[fruit] = true
	end
	local fruits: { string } = {}
	for _, fruit in ORDER do
		if active[fruit] then
			table.insert(fruits, fruit)
		end
	end
	-- For clients and for whoever spawned it (RandomBoss rolls its two).
	entity.Model:SetAttribute("BossFruits", table.concat(fruits, ","))

	local floorParams = RaycastParams.new()
	floorParams.FilterType = Enum.RaycastFilterType.Exclude
	floorParams.FilterDescendantsInstances = { entity.Model }

	return setmetatable({
		Handle = handle,
		Entity = entity,
		Fruits = fruits,
		Active = active,

		Combat = Knit.GetService("CombatService"),
		Characters = Knit.GetService("CharacterService"),
		Effects = Knit.GetService("EffectService"),
		Status = Knit.GetService("StatusService"),
		FruitService = Knit.GetService("FruitService"),

		Haki = false,
		Destroyed = false,
		Kneeling = false,
		BusyUntil = 0,
		Resume = nil :: number?,
		RoundDistance = math.huge,
		RoundVertical = 0,
		SkillsUsed = 0,
		KneelAt = math.random(3, 6),

		Ready = {},
		TeleportReady = 0,
		DashReady = 0,

		Tracks = loadTracks(entity),
		Jobs = {},
		Volumes = {},
		Pumping = false,
		Contacts = {},
		Statuses = {},
		Roped = setmetatable({}, { __mode = "k" }) :: any,
		Watched = nil :: CharacterEntity?,
		WatchConnection = nil :: any,
		FloorParams = floorParams,

		CandyOn = false,
		BodyOn = false,
		SwordOn = false,
		Energized = false,
		SwingCount = 0,
		LastSwing = 0,
	}, Global)
end

----------------------------------------------------------------------------------------
-- Plumbing
----------------------------------------------------------------------------------------

function Global._play(self: Self, name: string, fade: number?, weight: number?, speed: number?)
	local track = self.Tracks[name]
	if track then
		track:Play(fade, weight, speed)
	end
end

function Global._stop(self: Self, name: string)
	local track = self.Tracks[name]
	if track then
		track:Stop()
	end
end

-- A model destroyed without a death (removed directly, not through EnemyService) never
-- turns Dead and nobody calls Destroy: the boss ends itself the first time it notices.
function Global._gone(self: Self): boolean
	if self.Destroyed or self.Entity.Dead then
		return true
	end
	local entity = self.Entity
	if entity.Model.Parent == nil or entity.Root.Parent == nil then
		(self :: any):Destroy()
		return true
	end
	return false
end

-- Runs `callback` after `seconds` unless the boss is gone by then.
function Global._after(self: Self, seconds: number, callback: () -> ())
	local thread: thread
	thread = task.delay(seconds, function()
		self.Jobs[thread] = nil
		if self:_gone() then
			return
		end
		callback()
	end)
	self.Jobs[thread] = true
end

function Global._pump(self: Self)
	local now = os.clock()
	local volumes = self.Volumes
	for index = #volumes, 1, -1 do
		local ok, alive = pcall(volumes[index], now)
		if not ok or not alive then
			table.remove(volumes, index)
		end
	end
	if #volumes > 0 then
		self:_after(STEP, function()
			self:_pump()
		end)
	else
		self.Pumping = false
	end
end

-- Something in the air: `update` is called every STEP until it returns false.
function Global._track(self: Self, update: (now: number) -> boolean)
	table.insert(self.Volumes, update)
	if not self.Pumping then
		self.Pumping = true
		self:_after(STEP, function()
			self:_pump()
		end)
	end
end

-- A place that acts every `interval` seconds for `lifetime` seconds, the first time at once.
function Global._zone(self: Self, interval: number, lifetime: number, act: (elapsed: number, now: number) -> ())
	local started = os.clock()
	local nextAct = started
	self:_track(function(now: number): boolean
		local elapsed = now - started
		if elapsed >= lifetime then
			return false
		end
		if now >= nextAct then
			nextAct = math.max(nextAct + interval, now)
			act(elapsed, now)
		end
		return true
	end)
end

--[[
	A thrown thing that goes through the map and through characters (the legacy parts were
	CanCollide false): a sphere on the curve of `ballistic`, hitting each player once.
	Every step covers the stretch flown since the last one, so a fast ball skips nobody.
]]
function Global._launch(
	self: Self,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	drag: number,
	radius: number,
	lifetime: number,
	onHit: (target: CharacterEntity) -> ()
)
	local started = os.clock()
	local last = origin
	local struck: { [CharacterEntity]: boolean } = {}
	local reach = radius + BODY_RADIUS

	self:_track(function(now: number): boolean
		local age = math.min(now - started, lifetime)
		local position = ballistic(origin, velocity, gravity, drag, age)
		local segment = position - last
		local lengthSquared = segment:Dot(segment)

		local hit: { CharacterEntity } = {}
		for _, target: CharacterEntity in self.Characters:GetEntities() do
			if target.Player and not struck[target] and not target.Dead and target.Spawned then
				local offset = target.Root.Position - last
				local along = if lengthSquared > 0 then math.clamp(offset:Dot(segment) / lengthSquared, 0, 1) else 0
				if (offset - segment * along).Magnitude <= reach then
					struck[target] = true
					table.insert(hit, target)
				end
			end
		end
		for _, target in hit do
			onHit(target)
		end

		last = position
		return age < lifetime and position.Y > Workspace.FallenPartsDestroyHeight
	end)
end

function Global._trait(self: Self): (Trait, number)
	if self.Haki then
		return "Haki", HAKI_MULTIPLIER
	end
	return "Special", 1
end

-- Damage through the combat pipeline. Players only: a boss never hurts other NPCs.
function Global._hit(self: Self, target: CharacterEntity, amount: number, trait: Trait, style: Style?, dodgeable: boolean?): number
	-- A player who left mid-fight keeps an entity that never turns Dead.
	if not target.Player or target.Dead or target.Root.Parent == nil then
		return 0
	end
	local entity = self.Entity
	local inRange = not entity.Dead and (entity.Root.Position - target.Root.Position).Magnitude <= NPC_DAMAGE_RANGE
	return self.Combat:Damage({
		Target = target,
		Attacker = if inRange then entity else nil,
		Amount = amount,
		Trait = trait,
		Style = style or "Ability",
		Dodgeable = dodgeable == true,
	})
end

function Global._antiHeal(_self: Self, target: CharacterEntity)
	target.AntiHealFraction = math.max(target.AntiHealFraction, ANTI_HEAL_FRACTION)
	target.AntiHealHits = math.max(target.AntiHealHits, ANTI_HEAL_HITS)
end

-- Candy's sticky syrup, with the fruit's own helper (Luck owners are immune).
function Global._stick(self: Self, target: CharacterEntity)
	if target.Player then
		CandyShared.Touch({ Entity = self.Entity, Services = { Fruit = self.FruitService, Status = self.Status } }, target, 3)
	end
end

function Global._effect(self: Self, name: string, origin: Vector3, fruit: string, params: { [string]: any }, radius: number?)
	if params.Haki == nil then
		params.Haki = self.Haki
	end
	params.Colors = params.Colors or COLORS[fruit]
	params.Caster = self.Entity.Model
	self.Effects:Play(name, origin, params, radius)
end

-- Replicated state on the boss, undone in Destroy.
function Global._status(self: Self, name: string, value: any, duration: number?)
	self.Statuses[name] = true
	self.Entity:SetStatus(name, value, duration, true)
end

-- Damage on body contact while a body power is on: one hit per `cooldown` per victim.
function Global._contact(self: Self, name: string, radius: number, cooldown: number, hit: (target: CharacterEntity) -> ())
	self.Contacts[name] = {
		Radius = radius,
		Cooldown = cooldown,
		Last = setmetatable({}, { __mode = "k" }) :: any,
		Hit = hit,
	}
end

function Global._touch(self: Self, now: number)
	local entity = self.Entity
	for _, contact in self.Contacts do
		for _, target in Hitbox.Sphere(entity.Root.Position, contact.Radius, entity) do
			if target.Player and now - (contact.Last[target] or 0) >= contact.Cooldown then
				contact.Last[target] = now
				contact.Hit(target)
			end
		end
	end
end

function Global._isReady(self: Self, key: string, now: number): boolean
	return now > (self.Ready[key] or 0)
end

function Global._partCFrame(self: Self, name: string): CFrame
	local part = self.Entity.Model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part.CFrame else self.Entity.Root.CFrame
end

function Global._face(self: Self, target: CharacterEntity)
	local root = self.Entity.Root
	local position = target.Root.Position
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

-- Direction from `origin` to the target, or where the boss looks when the target is gone.
function Global._aim(self: Self, origin: Vector3, target: CharacterEntity): Vector3
	local look = self.Entity.Root.CFrame.LookVector
	if target.Dead then
		return look
	end
	return unitOr(target.Root.Position - origin, look)
end

function Global._floor(self: Self, position: Vector3): Vector3
	local result = Workspace:Raycast(
		position + Vector3.new(0, FLOOR_PROBE_UP, 0),
		Vector3.new(0, -FLOOR_PROBE_DOWN, 0),
		self.FloorParams
	)
	return if result then result.Position + Vector3.new(0, FLOOR_OFFSET, 0) else position
end

-- Max / current health, the ratio the legacy Shave scaled with.
function Global._missingScale(self: Self, limit: number): number
	local entity = self.Entity
	if entity.Health <= 0 then
		return limit
	end
	return math.clamp(entity.MaxHealth / entity.Health, 1, limit)
end

----------------------------------------------------------------------------------------
-- Movement
----------------------------------------------------------------------------------------

function Global._shave(self: Self, landing: Vector3, lookAt: Vector3)
	local entity = self.Entity
	local from = entity.Root.Position
	local flat = Vector3.new(lookAt.X, landing.Y, lookAt.Z)
	local cframe = if (flat - landing).Magnitude > 0.1 then CFrame.lookAt(landing, flat) else CFrame.new(landing)
	local rotation = entity.Root.CFrame.Rotation

	self.Handle.Halt()
	self.Characters:Teleport(entity, cframe)
	-- The flash MovementService plays for a player's Shave.
	self.Effects:Play("Shave", from, {
		Caster = entity.Model,
		Destination = landing,
		Rotation = rotation,
		Rumble = false,
		Colors = "None",
	})
end

-- A spot RETREAT_DISTANCE studs away from the target with ground under it and no wall in between.
function Global._retreatSpot(self: Self, targetPosition: Vector3): Vector3?
	local origin = self.Entity.Root.Position
	local away = unitOr((origin - targetPosition) * Vector3.new(1, 0, 1), -self.Entity.Root.CFrame.LookVector)
	for _, angle in RETREAT_ANGLES do
		local direction = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(away)
		local attempt = origin + direction * RETREAT_DISTANCE
		local ground = Workspace:Raycast(attempt + Vector3.new(0, 20, 0), Vector3.new(0, -50, 0), self.FloorParams)
		if ground then
			local wall = Workspace:Raycast(origin, ground.Position - origin, self.FloorParams)
			if not wall or wall.Instance == ground.Instance then
				return ground.Position + Vector3.new(0, FLOOR_OFFSET, 0)
			end
		end
	end
	return nil
end

function Global._dash(self: Self, target: CharacterEntity, now: number)
	if now < self.DashReady then
		return
	end
	self.DashReady = now + DASH_COOLDOWN

	local entity = self.Entity
	local offset = target.Root.Position - entity.Root.Position
	if offset.Magnitude < 1e-3 then
		return
	end
	self:_play("Dash")
	-- The legacy BodyVelocity, for as long as it lived.
	self.Characters:ApplyImpulse(entity, offset.Unit * DASH_SPEED, DASH_SECONDS, DASH_FORCE, DASH_POWER)
	self:_after(DASH_SECONDS, function()
		self:_stop("Dash")
	end)
end

-- True while a third skill of one of its fruits is recharging.
function Global._thirdSkillCooling(self: Self, now: number): boolean
	for _, fruit in self.Fruits do
		if now < (self.Ready[fruit .. "3"] or 0) then
			return true
		end
	end
	return false
end

function Global._reposition(self: Self, target: CharacterEntity, distance: number, vertical: number, now: number)
	local root = self.Entity.Root
	local targetRoot = target.Root

	if distance < RETREAT_BELOW_DISTANCE and now >= self.TeleportReady and self:_thirdSkillCooling(now) then
		local spot = self:_retreatSpot(targetRoot.Position)
		if spot then
			self.TeleportReady = now + RETREAT_COOLDOWN
			self:_shave(spot, targetRoot.Position)
		end
	end

	if (vertical > 4 and vertical < 11) or (vertical < -2 and vertical > -5) or vertical > 65 then
		self:_dash(target, now)
	end

	if distance > TELEPORT_MIN_DISTANCE and now >= self.TeleportReady then
		local step = TELEPORT_STEP * self:_missingScale(TELEPORT_STEP_MAX_SCALE)
		local destination: Vector3
		if distance < step then
			destination = targetRoot.Position - targetRoot.CFrame.LookVector * TELEPORT_BEHIND
		else
			destination = root.Position + unitOr(targetRoot.Position - root.Position, root.CFrame.LookVector) * step
		end
		self.TeleportReady = now + TELEPORT_COOLDOWN * (1 - self:_missingScale(5) / 10)
		self:_shave(self:_floor(destination), targetRoot.Position)
	end
end

----------------------------------------------------------------------------------------
-- Phases
----------------------------------------------------------------------------------------

function Global._kneel(self: Self, now: number)
	local duration = KNEEL_MIN
	for _, fruit in self.Fruits do
		duration = math.max(duration, KNEEL_SECONDS[fruit] or KNEEL_MIN)
	end
	if #self.Fruits > 1 then
		duration += KNEEL_EXTRA_TWO_FRUITS
	end

	local entity = self.Entity
	self.Kneeling = true
	self.BusyUntil = now + duration
	self.Handle.Halt()
	entity:SetRooted(KNEEL_ROOT, true)
	entity.Humanoid.AutoRotate = false
	self:_play("Kneel")

	self:_after(duration, function()
		self:_stop("Kneel")
		entity:SetRooted(KNEEL_ROOT, false)
		entity.Humanoid.AutoRotate = true
		self.KneelAt = math.random(6, 7)
		self.SkillsUsed = 0
		self.Kneeling = false
	end)
end

function Global._enterHaki(self: Self)
	self.Haki = true
	-- "Haki" is the attribute every fruit effect on the body turns dark for;
	-- BossGlobalHaki darkens the body itself, as the legacy script did.
	self:_status("Haki", true)
	self:_status("BossGlobalHaki", true)
end

-- The legacy boss mocked the player it was chasing when that player died.
function Global._watch(self: Self, target: CharacterEntity)
	if target == self.Watched then
		return
	end
	if self.WatchConnection then
		self.WatchConnection:Disconnect()
	end
	self.Watched = target

	local connection: any
	connection = target.Died:Connect(function()
		connection:Disconnect()
		if self.WatchConnection == connection then
			self.WatchConnection = nil
			self.Watched = nil
		end
		if self.Destroyed or self.Entity.Dead then
			return
		end
		self.Effects:Play("BossGlobalTaunt", self.Entity.Root.Position, {
			Model = self.Entity.Model,
			Text = TAUNTS[math.random(1, #TAUNTS)],
		})
	end)
	self.WatchConnection = connection
end

----------------------------------------------------------------------------------------
-- Magma
----------------------------------------------------------------------------------------

local ERUPTION_SPEED = 450
local ERUPTION_LIFT = 25
-- The legacy fist kept its speed; the fruit's effect needs some drag to draw the curve.
local ERUPTION_DRAG = 1e-3
local ERUPTION_LIFETIME = 5
local ERUPTION_FALLBACK_SIZE = Vector3.new(30.6, 30.6, 30.6)

local FLOW_ROWS = 15
local FLOW_ROW_SPACING = 20
local FLOW_SPREAD_PER_ROW = 15 / 4
local FLOW_MIN_DELAY = 1 / 60
local FLOW_PROBE = 50
local FLOW_START_SIZE = Vector3.new(10, 3, 10)
local FLOW_END_SIZE = Vector3.new(15, 4, 15)
local FLOW_BURN_TIME = 2.5

-- Landing points and delays of every blob. Identical to the layout of
-- Abilities/Magma/Magma Flow and Effects.OneShot.MagmaFlow, which draws from the seed.
local function flowLayout(seed: number, origin: Vector3, direction: Vector3): { { Point: Vector3, Delay: number } }
	local rng = Random.new(seed)
	local result = {}
	local delay = 0
	for row = 1, FLOW_ROWS do
		local count = rng:NextInteger(math.floor(1 + row / 3), row)
		local spread = math.floor(FLOW_SPREAD_PER_ROW * row)
		for _ = 1, count do
			local x = rng:NextInteger(-spread, spread)
			local z = rng:NextInteger(-spread, spread)
			table.insert(result, {
				Point = origin + direction * (row * FLOW_ROW_SPACING) + Vector3.new(x, 0, z),
				Delay = delay,
			})
			delay += math.max(rng:NextInteger(10 // row, 25 // row) / 100, FLOW_MIN_DELAY)
		end
	end
	return result
end

-- 0.5 s wind-up, then a fist of magma lobbed at the target. 8 s cooldown.
local function magmaEruption(self: Self, target: CharacterEntity, now: number): number?
	if not self:_isReady("Magma1", now) then
		return nil
	end
	self.SkillsUsed += 1
	self.Handle.Halt()
	self:_face(target)
	self:_play("Charge")

	self:_after(0.5, function()
		self:_stop("Charge")
		if target.Dead then
			self.BusyUntil = 0
			return
		end
		self:_face(target)
		self:_play("Release")
		self.Ready.Magma1 = os.clock() + 8

		local multiplier = AFFINITY * MELEE
		local trait, haki = self:_trait()
		local damage = math.clamp(1500 * multiplier, 100 * AFFINITY, 4000 * AFFINITY) * haki
		local size = assetSize(ERUPTION_FALLBACK_SIZE, "Magma", "Power1", "Great Eruption")
		local origin = self:_partCFrame("Right Arm").Position
		local velocity = self:_aim(origin, target) * ERUPTION_SPEED + Vector3.new(0, ERUPTION_LIFT, 0)
		local gravity = Workspace.Gravity

		self:_effect("MagmaEruption", origin, "Magma", {
			Direction = velocity.Unit,
			Speed = velocity.Magnitude,
			Drag = ERUPTION_DRAG,
			Gravity = gravity,
			Lifetime = ERUPTION_LIFETIME,
			Percent = 1,
			Multiplier = multiplier,
			Hand = "Right",
		}, FAR_EFFECT_RADIUS)
		self:_launch(
			origin,
			velocity,
			gravity,
			ERUPTION_DRAG,
			math.max(size.X, size.Y, size.Z) * multiplier / 2,
			ERUPTION_LIFETIME,
			function(victim: CharacterEntity)
				if self:_hit(victim, damage, trait) > 0 then
					self:_antiHeal(victim)
				end
			end
		)

		self:_after(0.5, function()
			self:_stop("Release")
		end)
	end)
	return 1
end

-- The body catches fire for good: 130 * defense * affinity to whoever touches it, twice a second.
local function magmaBody(self: Self): number?
	if self.BodyOn then
		return nil
	end
	self.BodyOn = true
	self:_status("MagmaBody", COLORS.Magma)
	self:_contact("Magma", BODY_CONTACT_RADIUS, 0.5, function(target: CharacterEntity)
		local trait, haki = self:_trait()
		self:_hit(target, 130 * DEFENSE * AFFINITY * haki, trait)
	end)
	return nil
end

-- A pool of magma spreads from under the boss for 13 s and recedes for 9. 27 s cooldown.
local function magmaPool(self: Self): number?
	self.SkillsUsed += 1
	self.Handle.Halt()
	self.Ready.Magma3 = os.clock() + 0.5 + RELEASE_GRACE

	self:_after(0.5, function()
		local entity = self.Entity
		self.Ready.Magma3 = os.clock() + 27

		local scale = DEFENSE * AFFINITY
		local diameter = 450 * scale
		local damage = 560 * scale / 2
		local center = entity.Root.Position - Vector3.new(0, 3, 0)
		local growTime, shrinkTime = 13, 9

		self:_effect("MagmaPool", center, "Magma", {
			Diameter = diameter,
			GrowTime = growTime,
			ShrinkTime = shrinkTime,
		}, EFFECT_RADIUS + diameter / 2)
		self:_zone(0.5, growTime + shrinkTime, function(elapsed: number)
			local alpha = if elapsed < growTime then elapsed / growTime else 1 - (elapsed - growTime) / shrinkTime
			local across = diameter * alpha
			-- Haki as it is now: the legacy pool read it on every tick.
			local trait, haki = self:_trait()
			for _, target in Hitbox.Box(CFrame.new(center), Vector3.new(across, 7, across), entity) do
				self:_hit(target, damage * haki, trait)
			end
		end)
	end)
	return 0.5
end

-- Fifteen rows of magma blobs rain towards the target. 13 s cooldown.
local function magmaFlow(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self.Handle.Halt()
	self:_face(target)

	local entity = self.Entity
	local origin = entity.Root.Position
	local direction = self:_aim(origin, target)
	local factor = AFFINITY * SNIPER
	local trait, haki = self:_trait()
	local damage = 400 * factor * haki
	local seed = math.random(1, 2 ^ 30)
	self.Ready.Magma4 = now + 13

	-- Blobs land on the map, never on characters.
	local ignored: { Instance } = {}
	for model in self.Characters:GetEntities() do
		table.insert(ignored, model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored

	local blobs: { { Center: Vector3, Start: number } } = {}
	local lifetime = 0
	for _, entry in flowLayout(seed, origin, direction) do
		local result = Workspace:Raycast(entry.Point + Vector3.new(0, FLOW_PROBE, 0), Vector3.new(0, -2 * FLOW_PROBE, 0), params)
		-- No ground: the blob cools on the sea and hurts nobody.
		if result then
			table.insert(blobs, { Center = result.Position, Start = now + entry.Delay })
			lifetime = math.max(lifetime, entry.Delay + FLOW_BURN_TIME)
		end
	end

	self:_effect("MagmaFlow", origin, "Magma", { Direction = direction, Seed = seed, Factor = factor })

	if #blobs > 0 then
		-- Each blob burns ten times, 0.25 s apart, while it grows.
		self:_zone(0.25, lifetime, function(_elapsed: number, tick: number)
			for _, blob in blobs do
				local age = tick - blob.Start
				if age >= 0 and age < FLOW_BURN_TIME then
					local alpha = 1 - (1 - age / FLOW_BURN_TIME) ^ 5
					local box = FLOW_START_SIZE:Lerp(FLOW_END_SIZE, alpha) * factor
					for _, victim in Hitbox.Box(CFrame.new(blob.Center), box, entity) do
						self:_hit(victim, damage, trait)
					end
				end
			end
		end)
	end
	return 0.8
end

local function magmaChain(self: Self, target: CharacterEntity, distance: number, vertical: number, now: number): number?
	if vertical > 5 then
		return magmaEruption(self, target, now)
	elseif distance < 5 and self:_isReady("Magma3", now) then
		return magmaPool(self)
	elseif distance < 40 then
		-- Once the body burns this branch does nothing, and still shadows the two below.
		return magmaBody(self)
	elseif distance > 15 and distance < 3000 and self:_isReady("Magma1", now) then
		return magmaEruption(self, target, now)
	elseif distance > 25 and distance < 100 and self:_isReady("Magma4", now) then
		return magmaFlow(self, target, now)
	end
	return nil
end

----------------------------------------------------------------------------------------
-- Sand
----------------------------------------------------------------------------------------

local SPIKE_FALLBACK_SIZE = Vector3.new(49, 140, 49)
local SPIKE_TILT = 35
local STORM_SPEED = 30
local STORM_RADIUS = 30
local STORM_PULL_HEIGHT = 3.33
local ROPE_STATUS = "SandRoped"
local ROPE_SECONDS = 3
local SPADA_BLADES = 7
local SPADA_INTERVAL = 0.05
local SPADA_STAND_SECONDS = 2
local SPADA_THICKNESS = 0.2

function Global._bleed(self: Self, target: CharacterEntity, left: number, minimum: number, maximum: number)
	if left <= 0 or target.Dead then
		return
	end
	self:_hit(target, math.random(minimum, maximum), "Bleed")
	self:_after(0.2 + math.random() * 0.9, function()
		self:_bleed(target, left - 1, minimum, maximum)
	end)
end

-- A spike bursts out where the target stands, with no warning. 5 s cooldown.
local function sandSpike(self: Self, target: CharacterEntity, now: number): number?
	if not self:_isReady("Sand1", now) then
		return nil
	end
	self.SkillsUsed += 1
	self.Handle.Halt()
	self:_face(target)
	self.Ready.Sand1 = now + 5

	local entity = self.Entity
	local scale = AFFINITY * SNIPER
	local trait, haki = self:_trait()
	local damage = 600 * scale * haki
	local size = assetSize(SPIKE_FALLBACK_SIZE, "Sand", "Power2", "SandSpike") * scale
	local cframe = CFrame.new(target.Root.Position)
		* CFrame.Angles(math.rad(math.random(-SPIKE_TILT, SPIKE_TILT)), 0, math.rad(math.random(-SPIKE_TILT, SPIKE_TILT)))

	self:_effect("SandSpike", cframe.Position, "Sand", { CFrame = cframe, Scale = scale, Animation = 1 })

	-- The legacy spike listened to touches for its first second.
	local struck: { [CharacterEntity]: boolean } = {}
	self:_zone(0, 1, function()
		for _, victim in Hitbox.Box(cframe, size, entity) do
			if not struck[victim] then
				struck[victim] = true
				self:_hit(victim, damage, trait)
			end
		end
	end)
	return 0.5
end

-- A tornado drifts at the target and ropes whoever it reaches for 3 s. No damage. 16 s cooldown.
local function sandTornado(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self.Handle.Halt()
	self:_face(target)
	self.Ready.Sand2 = now + 16

	local entity = self.Entity
	local origin = entity.Root.Position
	local velocity = self:_aim(self:_partCFrame("Right Arm").Position, target) * STORM_SPEED
	local duration = math.clamp(2 * AFFINITY, 2, 9)
	local pullPoint = origin + Vector3.new(0, STORM_PULL_HEIGHT, 0)
	-- Path of the pull point, for the victim's own client (Effects.Status.SandRoped).
	local rope = string.format(
		"%.2f|%.2f|%.2f|%.3f|%.3f|%.3f|%.3f",
		pullPoint.X,
		pullPoint.Y,
		pullPoint.Z,
		velocity.X,
		velocity.Y,
		velocity.Z,
		Workspace:GetServerTimeNow()
	)

	self:_effect("SandSandstorm", origin, "Sand", {
		Velocity = velocity,
		Duration = duration,
		Power = AFFINITY,
		RightHand = true,
	})
	self:_zone(0.5, duration, function(elapsed: number)
		local center = pullPoint + velocity * elapsed
		for _, victim in Hitbox.Sphere(center, STORM_RADIUS, entity) do
			if
				victim.Player
				and (victim.Root.Position - center).Magnitude <= STORM_RADIUS
				and not victim:HasStatus(ROPE_STATUS)
			then
				victim:SetStatus(ROPE_STATUS, rope, ROPE_SECONDS, true)
				self.Roped[victim] = rope
			end
		end
	end)
	return 1
end

-- Seven blades, each longer than the last, shoot out in a line. 7 s cooldown.
local function sandSpada(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self.Handle.Halt()
	self:_face(target)
	self.Ready.Sand3 = now + 7

	local entity = self.Entity
	local scale = AFFINITY * SWORD
	local trait, haki = self:_trait()
	local damage = 500 * scale * haki
	local bleedMin, bleedMax = math.floor(90 * scale), math.floor(175 * scale)
	local bleedTicks = math.floor(10 * AFFINITY)
	local base = 10 * scale
	local origin = entity.Root.Position
	local direction = self:_aim(origin, target)
	local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis

	local blades: { { CFrame: CFrame, Size: Vector3, From: number } } = {}
	local center = origin
	for index = 1, SPADA_BLADES do
		local length = base * index
		center += direction * (length / 2)
		blades[index] = {
			CFrame = CFrame.lookAt(center, center + direction, up),
			Size = Vector3.new(SPADA_THICKNESS, length, length),
			From = SPADA_INTERVAL * (index - 1),
		}
	end

	self:_effect("BossGlobalSpada", origin, "Sand", {
		Direction = direction,
		Base = base,
		Count = SPADA_BLADES,
		Interval = SPADA_INTERVAL,
		StandSeconds = SPADA_STAND_SECONDS,
	}, FAR_EFFECT_RADIUS)

	-- One hit list for the whole line, as in the legacy script.
	local struck: { [CharacterEntity]: boolean } = {}
	self:_zone(0, SPADA_INTERVAL * SPADA_BLADES + SPADA_STAND_SECONDS, function(elapsed: number)
		for _, blade in blades do
			if elapsed >= blade.From and elapsed < blade.From + SPADA_STAND_SECONDS then
				for _, victim in Hitbox.Box(blade.CFrame, blade.Size, entity) do
					if victim.Player and not struck[victim] then
						struck[victim] = true
						self:_hit(victim, damage, trait)
						self:_bleed(victim, bleedTicks, bleedMin, bleedMax)
					end
				end
			end
		end
	end)
	return 1
end

local function sandChain(self: Self, target: CharacterEntity, distance: number, vertical: number, now: number): number?
	if vertical > 5 then
		return sandSpike(self, target, now)
	elseif distance < 15 and self:_isReady("Sand3", now) then
		return sandSpada(self, target, now)
	elseif distance < 40 and self:_isReady("Sand2", now) then
		return sandTornado(self, target, now)
	elseif distance > 15 and distance < 3000 and self:_isReady("Sand1", now) then
		return sandSpike(self, target, now)
	end
	return nil
end

----------------------------------------------------------------------------------------
-- Candy
----------------------------------------------------------------------------------------

local JAW_FALLBACK_SIZE = Vector3.new(50, 50, 50)
local JAW_MIN_AXIS = 4
local JAW_SPEED = 600
-- The legacy ball kept 99.5 % of its velocity per frame, at 60 frames per second.
local JAW_DRAG = -60 * math.log(0.995)
local JAW_LIFETIME = 6
local WAVE_SIZE = Vector3.new(45, 5, 15)
local WAVE_SPEED = 150
local WAVE_LIFETIME = 3

-- The first hit it takes: the body hardens into spiked candy and a blade grows on each arm, for good.
function Global._candyBody(self: Self)
	self.CandyOn = true
	self:_status("CandyBody", COLORS.Candy)
	-- "<fruit slot>|<ability slot>|<colors>": no slots, nobody clicks for a boss.
	self:_status("CandyBlades", `0|0|{COLORS.Candy}`)

	-- Haki as it was when the body came out (the legacy script read it once).
	local trait, haki = self:_trait()
	local damage = 50 * DEFENSE * AFFINITY * haki
	self:_contact("Candy", BODY_CONTACT_RADIUS, 1, function(target: CharacterEntity)
		self:_hit(target, damage, trait)
	end)
end

-- A swing of the arm blades, twice a second while the target is in reach. Not a skill.
local function candySlash(self: Self, target: CharacterEntity, now: number): number?
	local entity = self.Entity
	if not self:_isReady("Candy1", now) or (target.Root.Position - entity.Root.Position).Magnitude > 15 then
		return nil
	end
	self:_face(target)
	self:_play("Blade", 0.1, 3, 8)
	self.Ready.Candy1 = now + 0.6

	local trait, haki = self:_trait()
	local damage = 300 * AFFINITY * SWORD * haki
	self:_after(0.1, function()
		for _, victim in Hitbox.Box(entity.Root.CFrame * CFrame.new(0, 0, -3), Vector3.new(6, 8, 6), entity) do
			-- The legacy call named no style: no resistance perk applies.
			self:_hit(victim, damage, trait, "Plain")
		end
	end)
	return 0.3
end

-- A pool of syrup spreads around the boss: 2.5 s out, 8 s there, 2.5 s back. 9.5 s cooldown.
local function candyPool(self: Self, now: number): number?
	self.SkillsUsed += 1
	local trait, haki = self:_trait()

	self:_after(0.3, function()
		local entity = self.Entity
		self.Ready.Candy3 = os.clock() + 9.5

		local scale = DEFENSE * AFFINITY
		local width, thickness = 44 * scale, scale
		local damage = 95 * scale * haki
		-- At the height of its root, where the legacy pool was put.
		local center = entity.Root.Position
		local growTime, holdTime, shrinkTime = 2.5, 8, 2.5

		self:_effect("BossGlobalCandyPool", center, "Candy", {
			Diameter = width,
			Thickness = thickness,
			GrowTime = growTime,
			HoldTime = holdTime,
			ShrinkTime = shrinkTime,
			Haki = trait == "Haki",
		})
		self:_zone(0.35, growTime + holdTime + shrinkTime, function(elapsed: number)
			local alpha = 1
			if elapsed < growTime then
				alpha = elapsed / growTime
			elseif elapsed > growTime + holdTime then
				alpha = 1 - (elapsed - growTime - holdTime) / shrinkTime
			end
			-- The legacy test was the bounding box of the lying cylinder.
			local box = Vector3.new(width * alpha, thickness * alpha, width * alpha)
			for _, victim in Hitbox.Box(CFrame.new(center), box, entity) do
				self:_hit(victim, damage, trait)
				self:_stick(victim)
			end
		end)
	end)
	return 0.8
end

-- A wide wave of syrup thrown at the target. 8.5 s cooldown.
local function candyWave(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self:_face(target)
	local trait, haki = self:_trait()

	self:_after(0.3, function()
		local entity = self.Entity
		self.Ready.Candy4 = os.clock() + 8.5

		local scale = MELEE * AFFINITY
		local damage = 100 * scale * haki
		local size = WAVE_SIZE * scale
		local origin = entity.Root.Position
		local direction = self:_aim(origin, target)
		local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
		local orientation = CFrame.lookAt(origin, origin + direction, up)

		self:_effect("CandyWave", origin, "Candy", {
			Direction = direction,
			Speed = WAVE_SPEED,
			Lifetime = WAVE_LIFETIME,
			Scale = scale,
			Haki = trait == "Haki",
		}, FAR_EFFECT_RADIUS)

		local travelled = 0
		local struck: { [CharacterEntity]: boolean } = {}
		self:_zone(0, WAVE_LIFETIME, function(elapsed: number)
			local reached = elapsed * WAVE_SPEED
			local box = Vector3.new(size.X, size.Y, reached - travelled + size.Z)
			local middle = orientation * CFrame.new(0, 0, -(travelled + reached) / 2)
			travelled = reached
			for _, victim in Hitbox.Box(middle, box, entity) do
				if not struck[victim] then
					struck[victim] = true
					self:_hit(victim, damage, trait)
					self:_stick(victim)
				end
			end
		end)
	end)
	return 0.7
end

-- 1.5 s standing still, then a candy ball the size of a house. 9 s cooldown.
local function candyJawbreaker(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self:_face(target)
	-- Read before the wait, and never doubled: the legacy damage ignored the haki multiplier.
	local trait = self:_trait()

	self:_after(1.5, function()
		if target.Dead then
			self.BusyUntil = 0
			return
		end
		self.Ready.Candy2 = os.clock() + 9

		local scale = AFFINITY * SNIPER
		local damage = math.clamp(80 * 15 * scale, 25 * AFFINITY, 1000 * AFFINITY)
		local template = assetSize(JAW_FALLBACK_SIZE, "Candy", "Power3", "CandyJawbreaker")
		local diameter = math.max(template.X, template.Y, template.Z, JAW_MIN_AXIS) * scale
		local origin = self:_partCFrame("Right Arm").Position
		local velocity = self:_aim(origin, target) * JAW_SPEED
		local gravity = Workspace.Gravity

		self:_effect("BossGlobalJawbreaker", origin, "Candy", {
			Velocity = velocity,
			Gravity = gravity,
			Drag = JAW_DRAG,
			Lifetime = JAW_LIFETIME,
			Scale = scale,
			Haki = trait == "Haki",
		}, FAR_EFFECT_RADIUS)
		self:_launch(origin, velocity, gravity, JAW_DRAG, diameter / 2, JAW_LIFETIME, function(victim: CharacterEntity)
			self:_hit(victim, damage, trait)
			self:_stick(victim)
		end)
	end)
	return 2.1
end

local function candyChain(self: Self, target: CharacterEntity, distance: number, _vertical: number, now: number): number?
	if distance < 12 and self.CandyOn then
		-- In reach with the blades out it only slashes: the pool is never reached.
		return candySlash(self, target, now)
	elseif distance < 15 and self:_isReady("Candy3", now) then
		return candyPool(self, now)
	elseif distance >= 20 and distance < 120 and self:_isReady("Candy4", now) then
		return candyWave(self, target, now)
	elseif distance >= 25 and distance < 120 and self:_isReady("Candy2", now) then
		return candyJawbreaker(self, target, now)
	end
	return nil
end

----------------------------------------------------------------------------------------
-- Quake
----------------------------------------------------------------------------------------

local SEISMIC_FACTOR = ((1.5 * 90) + 1) / 10 * (0.004 * 750) * AFFINITY
local TSUNAMI_FACTOR = (0.425 * 10 + 2) * (0.004 * 750) * AFFINITY
local TSUNAMI_FALLBACK_SIZE = Vector3.new(72, 16, 24)
local TSUNAMI_TRAVEL = 88
local TSUNAMI_DAMAGE = 4700
local TSUNAMI_HEALTH_FRACTION = 0.45
local STOMP_PERCENT = 56 / 60
local STOMP_BALL_OFFSET = 5
local STOMP_BALL_SPEED = 200
local STOMP_GROUND_REACH = 10

-- 0.5 s wind-up, then the air shatters around where the target stands. 6.5 s cooldown.
local function quakeSeismic(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self:_face(target)
	self:_play("Charge")
	self.Ready.Quake1 = now + 0.75 + RELEASE_GRACE

	self:_after(0.5, function()
		self:_stop("Charge")
		if target.Dead then
			self.BusyUntil = 0
			return
		end
		self:_play("Release")

		local entity = self.Entity
		local scale = AFFINITY * SNIPER * 0.9
		local trait, haki = self:_trait()
		local damage = 1600 * scale * haki
		local side = 4 * SEISMIC_FACTOR
		local center = target.Root.Position
		local slam = Vector3.new(0, -125 * scale, 0)

		for _, victim in Hitbox.Box(CFrame.new(center), Vector3.new(side, side, side), entity) do
			if victim.Player then
				self.Status:ApplyStun(victim, 0.25, "QuakeSeismic")
				if victim.Humanoid.Sit then
					victim.Humanoid.Sit = false
				end
				local force = 1e7 * victim.Root.AssemblyMass
				self.Characters:ApplyImpulse(victim, slam, 0.25, Vector3.new(force, force, force), 1250)
				self:_hit(victim, damage, trait)
			end
		end

		self:_effect("QuakeSeismic", center, "Quake", {
			Size = side,
			Force = SEISMIC_FACTOR / 5,
			RightHand = true,
		}, (center - entity.Root.Position).Magnitude + EFFECT_RADIUS)

		self:_after(0.25, function()
			self.Ready.Quake1 = os.clock() + 6.5
			self:_stop("Release")
		end)
	end)
	return 0.75
end

--[[
	Under 45 % health: two walls of water rise from the sea 2800 studs to either side,
	cross where the boss stood 21 s later and sink again. 4700 damage per wall, 125 s
	cooldown. Unlike a player's tsunami the walls leave twice as fast as they came and
	sink by one height only (the legacy boss built its second tween from the middle).
]]
local function quakeTsunami(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self.Handle.Halt()
	self:_face(target)
	self:_play("Charge")
	self.Ready.Quake2 = now + 0.5 + RELEASE_GRACE

	self:_after(0.5, function()
		self:_stop("Charge")
		self:_play("Release")
		self:_after(0.5, function()
			self:_stop("Release")
		end)
		self.Ready.Quake2 = os.clock() + 125

		local entity = self.Entity
		local trait = self:_trait()
		local template = QuakeShared.FindResource("Tsunami")
		-- No part is larger than 2048 studs: the legacy wall, and the one clients draw,
		-- stop there, and so must the box that hurts.
		local size = ((if template then template.Size else TSUNAMI_FALLBACK_SIZE) * TSUNAMI_FACTOR):Min(MAX_PART_SIZE)
		local legDistance = TSUNAMI_TRAVEL * TSUNAMI_FACTOR
		local legTime = TSUNAMI_FACTOR / DEFENSE
		local seaLevel = WorldConfig.SeaLevel
		local height = size.Y
		local position = entity.Root.Position
		local right = unitOr(entity.Root.CFrame.RightVector * Vector3.new(1, 0, 1), Vector3.xAxis)

		self.Effects:Play("BossGlobalTsunami", position, {
			Right = right,
			Size = size,
			LegDistance = legDistance,
			LegTime = legTime,
			SeaLevel = seaLevel,
			Scale = TSUNAMI_FACTOR,
			Haki = self.Haki,
			Colors = COLORS.Quake,
			-- The walls are taken away with the boss (the hits stop then).
			Caster = entity.Model,
		}, 3 * legDistance + EFFECT_RADIUS)

		local walls = {}
		for _, side in { 1, -1 } do
			table.insert(walls, {
				From = position + right * (legDistance * side),
				Direction = right * -side,
				Swept = 0,
				Hit = {} :: { [CharacterEntity]: boolean },
			})
		end

		self:_zone(0.1, 2 * legTime, function(elapsed: number)
			-- 0 at the start, 1 over the boss, 2 at the end.
			local alpha = math.clamp(elapsed / legTime, 0, 2)
			local distance = if alpha <= 1 then legDistance * alpha else legDistance * (1 + 2 * (alpha - 1))
			local centerY = if alpha <= 1
				then seaLevel - height / 2 + height * alpha
				else seaLevel + height / 2 - height * (alpha - 1)
			for _, wall in walls do
				local flat = wall.From + wall.Direction * ((distance + wall.Swept) / 2)
				local middle = Vector3.new(flat.X, centerY, flat.Z)
				local box = Vector3.new(size.X, height, size.Z + distance - wall.Swept)
				wall.Swept = distance
				for _, victim in Hitbox.Box(CFrame.lookAt(middle, middle + wall.Direction), box, entity) do
					if not wall.Hit[victim] then
						wall.Hit[victim] = true
						self:_hit(victim, TSUNAMI_DAMAGE, trait)
					end
				end
			end
		end)
	end)
	return 0.5
end

-- 0.6 s wind-up, then a shock ball hits the ground under the boss: a 95 stud blast and a ring of rocks. 12 s cooldown.
local function quakeStomp(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self.Handle.Halt()
	self:_face(target)
	self:_play("Charge")
	self.Ready.Quake3 = now + 0.6 + RELEASE_GRACE

	self:_after(0.6, function()
		self:_stop("Charge")
		self:_play("Release")
		self:_after(0.5, function()
			self:_stop("Release")
		end)
		self.Ready.Quake3 = os.clock() + 12

		local entity = self.Entity
		local trait, haki = self:_trait()
		local damage = 1600 * AFFINITY * DEFENSE * STOMP_PERCENT * haki
		local push = 65 * AFFINITY ^ 2 * DEFENSE
		local start = entity.Root.Position - Vector3.new(0, STOMP_BALL_OFFSET, 0)
		local ground = self:_floor(entity.Root.Position)
		local fallTime = (ground - start).Magnitude / STOMP_BALL_SPEED

		self:_effect("QuakeStomp", start, "Quake", {
			Ground = ground,
			FallTime = fallTime,
			Charge = 56,
			Percent = STOMP_PERCENT,
			Affinity = AFFINITY,
			LevelScale = DEFENSE,
		})

		self:_after(fallTime, function()
			for _, victim in Hitbox.Sphere(ground, 56 * AFFINITY, entity) do
				if victim.Player then
					-- The legacy call named no style.
					self:_hit(victim, damage, trait, "Plain")
					if not victim.Dead then
						local away = victim.Root.Position - ground
						local direction = Vector3.yAxis
						if away.Magnitude > 0.01 then
							local unit = away.Unit
							direction = Vector3.new(unit.X, 0.25, unit.Z).Unit
						end
						self.Characters:ApplyImpulse(victim, direction * push, 0.2, Vector3.new(1e5, 1e5, 1e5), 1250)
					end
				end
			end
		end)
	end)
	return 0.6
end

local function quakeChain(self: Self, target: CharacterEntity, distance: number, _vertical: number, now: number): number?
	local entity = self.Entity
	if distance > 12 and distance < 250 and self:_isReady("Quake1", now) then
		return quakeSeismic(self, target, now)
	elseif
		distance > 5
		and distance < 300
		and self:_isReady("Quake2", now)
		and entity:GetHealthRatio() <= TSUNAMI_HEALTH_FRACTION
	then
		return quakeTsunami(self, target, now)
	elseif distance < 25 and self:_isReady("Quake3", now) then
		-- Only with ground within 10 studs under it.
		if Workspace:Raycast(entity.Root.Position, Vector3.new(0, -STOMP_GROUND_REACH, 0), self.FloorParams) then
			return quakeStomp(self, target, now)
		end
	end
	return nil
end

----------------------------------------------------------------------------------------
-- Flare
----------------------------------------------------------------------------------------

local FIST_SPEED = 500
local FIST_LIFETIME = 6
local FIST_SIZE = 20 * AFFINITY * SNIPER
local FIRE_WAVE_RADIUS = 50
local FIRE_WAVE_EXPAND = 0.5
local FIRE_WAVE_LIFETIME = 1.5
local FIRE_WAVE_THICKNESS = 5
local FIRE_WAVE_HALF_HEIGHT = 6
local PILLAR_SPEED = 150
local PILLAR_MAX_TRAVEL = 2
local PILLAR_LIFETIME = 10
local PILLAR_GROW_TIME = 5
local PILLAR_SIZE = Vector3.new(10, 40, 10) * DEFENSE * AFFINITY

function Global._handFire(self: Self, arm: string, duration: number)
	self:_effect("BossCharge", self.Entity.Root.Position, "Flare", {
		Model = self.Entity.Model,
		Arm = arm,
		Duration = duration,
	})
end

-- 0.5 s with the right arm on fire, then a 51 stud fist flies 3000 studs. 6 s cooldown.
local function flareFist(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self.Handle.Halt()
	self:_face(target)
	self:_handFire("Right Arm", 0.5)
	self:_play("Charge")
	local trait, haki = self:_trait()

	self:_after(0.5, function()
		self:_stop("Charge")
		self:_play("Final")
		self.Ready.Flare1 = os.clock() + 6

		local entity = self.Entity
		local damage = 800 * SNIPER * AFFINITY * haki
		local origin = (self:_partCFrame("Right Arm") * CFrame.new(0, 0, -2)).Position
		local direction = self:_aim(entity.Root.Position, target)

		self:_effect("BossFireFist", origin, "Flare", {
			Direction = direction,
			Speed = FIST_SPEED,
			Range = FIST_SPEED * FIST_LIFETIME,
			Size = FIST_SIZE,
			Haki = trait == "Haki",
		}, FAR_EFFECT_RADIUS)
		self:_launch(origin, direction * FIST_SPEED, 0, 0, FIST_SIZE / 2, FIST_LIFETIME, function(victim: CharacterEntity)
			if self:_hit(victim, damage, trait) > 0 then
				self:_antiHeal(victim)
			end
		end)

		self:_after(0.5, function()
			self:_stop("Final")
		end)
	end)
	return 1
end

-- 0.5 s wind-up, then a ring of fire sweeps 50 studs around the boss. 8 s cooldown.
local function flareWave(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self.Handle.Halt()
	self:_face(target)
	self:_play("Charge")
	local trait, haki = self:_trait()

	self:_after(0.5, function()
		self:_stop("Charge")
		self.Ready.Flare2 = os.clock() + 8

		local entity = self.Entity
		local damage = 1000 * DEFENSE * AFFINITY * haki
		local center = entity.Root.Position

		self:_effect("BossFireWave", center, "Flare", {
			Radius = FIRE_WAVE_RADIUS,
			ExpandTime = FIRE_WAVE_EXPAND,
			Lifetime = FIRE_WAVE_LIFETIME,
			Haki = trait == "Haki",
		})

		local struck: { [CharacterEntity]: boolean } = {}
		self:_zone(0, FIRE_WAVE_LIFETIME, function(elapsed: number)
			-- While the ring expands everyone inside it has been swept; afterwards only
			-- those standing on it are touched.
			local expanding = elapsed < FIRE_WAVE_EXPAND
			local radius = FIRE_WAVE_RADIUS * math.sin(math.min(elapsed / FIRE_WAVE_EXPAND, 1) * math.pi / 2)
			for _, victim in Hitbox.Cylinder(center, radius + FIRE_WAVE_THICKNESS, FIRE_WAVE_HALF_HEIGHT, entity) do
				if not struck[victim] then
					local offset = victim.Root.Position - center
					if expanding or Vector3.new(offset.X, 0, offset.Z).Magnitude >= radius - FIRE_WAVE_THICKNESS then
						struck[victim] = true
						self:_hit(victim, damage, trait)
					end
				end
			end
		end)
	end)
	return 1
end

-- 0.5 s with the left arm on fire, then a growing column travels to where the target stood and burns for 10 s. 10 s cooldown.
local function flarePillar(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self.Handle.Halt()
	self:_face(target)
	self:_handFire("Left Arm", 0.5)
	self:_play("Charge")
	local trait, haki = self:_trait()

	self:_after(0.5, function()
		self:_stop("Charge")
		self.Ready.Flare3 = os.clock() + 10

		local entity = self.Entity
		local damage = 1200 * AFFINITY * DEFENSE * haki
		local origin = self:_partCFrame("Left Arm").Position
		local offset = if target.Dead then entity.Root.CFrame.LookVector else target.Root.Position - origin
		local direction = unitOr(offset, entity.Root.CFrame.LookVector)
		local distance = math.min(offset.Magnitude, PILLAR_SPEED * PILLAR_MAX_TRAVEL)

		self:_effect("BossFirePillar", origin, "Flare", {
			Direction = direction,
			Distance = distance,
			Speed = PILLAR_SPEED,
			Size = PILLAR_SIZE,
			GrowTime = PILLAR_GROW_TIME,
			Lifetime = PILLAR_LIFETIME,
			-- The legacy boss pillar always stood turned 45 degrees.
			Rotation = CFrame.Angles(0, math.rad(45), 0),
			ParticleScale = AFFINITY * DEFENSE,
			Haki = trait == "Haki",
		})
		self:_zone(0.25, PILLAR_LIFETIME, function(elapsed: number)
			local size = PILLAR_SIZE * math.min(elapsed / PILLAR_GROW_TIME, 1)
			local position = origin + direction * math.min(elapsed * PILLAR_SPEED, distance)
			for _, victim in Hitbox.Box(CFrame.new(position), size, entity) do
				self:_hit(victim, damage, trait)
			end
		end)
	end)
	return 1.5
end

local function flareChain(self: Self, target: CharacterEntity, distance: number, _vertical: number, now: number): number?
	if distance < 25 and self:_isReady("Flare2", now) then
		return flareWave(self, target, now)
	elseif distance < 100 and self:_isReady("Flare1", now) then
		return flareFist(self, target, now)
	elseif distance < 80 and self:_isReady("Flare3", now) then
		return flarePillar(self, target, now)
	end
	return nil
end

----------------------------------------------------------------------------------------
-- Plasma
----------------------------------------------------------------------------------------

local CANNON_RANGE = 250
local CANNON_RADIUS = 5
local CANNON_TICKS = 6
local CANNON_INTERVAL = 0.25
local COIL_SECONDS = 5
local COIL_HEIGHT = 10
local COIL_RADIUS = 30 * AFFINITY * SNIPER
local ENERGIZE_REACH = 6
local ENERGIZE_COOLDOWN = 1.5

-- Six rays in 1.5 s, each bursting on the target, then a blast three times as strong. 8 s cooldown.
local function plasmaCannon(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self:_play("Charge")

	local entity = self.Entity
	local trait, haki = self:_trait()
	local tickDamage = 250 * SNIPER * AFFINITY * haki
	local thickness = math.clamp(SNIPER, 0.5, 1)

	local function fire(damage: number)
		local origin = self:_partCFrame("Right Arm").Position
		local offset = target.Root.Position - origin
		local burst = if offset.Magnitude > CANNON_RANGE then origin + offset.Unit * CANNON_RANGE else target.Root.Position
		self:_effect("PlasmaCannon", origin, "Plasma", {
			Target = burst,
			Burst = burst,
			Size = AFFINITY,
			Thickness = thickness,
			Haki = trait == "Haki",
		})
		for _, victim in Hitbox.Sphere(burst, CANNON_RADIUS, entity) do
			self:_hit(victim, damage, trait)
		end
	end

	for index = 0, CANNON_TICKS - 1 do
		self:_after(index * CANNON_INTERVAL, function()
			if not target.Dead then
				self:_face(target)
				fire(tickDamage)
			end
		end)
	end
	self:_after(CANNON_TICKS * CANNON_INTERVAL, function()
		self:_stop("Charge")
		self:_play("Release")
		if not target.Dead then
			fire(tickDamage * 3)
		end
		self.Ready.Plasma3 = os.clock() + 8
		self:_after(0.6, function()
			self:_stop("Release")
		end)
	end)
	return CANNON_TICKS * CANNON_INTERVAL + 0.6
end

-- A 60 stud cube of lightning around the boss, at once. 10 s cooldown.
local function plasmaBurst(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self:_face(target)
	self.Ready.Plasma1 = now + 0.25 + 10

	local entity = self.Entity
	local trait, haki = self:_trait()
	local damage = 1800 * AFFINITY * DEFENSE * haki
	for _, victim in Hitbox.Box(entity.Root.CFrame, Vector3.new(60, 60, 60), entity) do
		self:_hit(victim, damage, trait)
	end
	self:_effect("PlasmaBurst", entity.Root.Position, "Plasma", { Thickness = math.clamp(SNIPER, 0.25, 1) })
	return 0.75
end

-- A sphere of plasma hangs over the boss for 5 s and arcs to everyone within 76 studs, four times a second. 15 s cooldown.
local function plasmaCoil(self: Self, now: number): number?
	self.SkillsUsed += 1
	self:_status("PlasmaCoil", COLORS.Plasma, COIL_SECONDS)
	self.Ready.Plasma2 = now + COIL_SECONDS + 15

	local entity = self.Entity
	local trait, haki = self:_trait()
	local damage = 185 * SNIPER * AFFINITY * haki
	self:_zone(0.25, COIL_SECONDS, function(elapsed: number)
		-- The sphere rises to its place over the first second.
		local center = entity.Root.Position + Vector3.new(0, COIL_HEIGHT * math.min(elapsed, 1), 0)
		local struck: { Vector3 } = {}
		for _, victim in Hitbox.Sphere(center, COIL_RADIUS, entity) do
			if victim.Player then
				table.insert(struck, victim.Root.Position)
				self:_hit(victim, damage, trait)
			end
		end
		if #struck > 0 then
			self:_effect("PlasmaCoilArc", center, "Plasma", {
				Targets = struck,
				Size = AFFINITY,
				Thickness = math.clamp(SNIPER, 0.25, 1),
				Haki = trait == "Haki",
			})
		end
	end)
	return COIL_SECONDS + 0.5
end

-- Once: plasma under its feet for the rest of the fight. It walks at 96 and shocks the
-- player it was chasing whenever it gets within 6 studs (every 1.5 s at most).
local function plasmaEnergize(self: Self, target: CharacterEntity): number?
	if self.Energized then
		return nil
	end
	self.Energized = true
	self.SkillsUsed += 1
	self:_status("PlasmaRushing", COLORS.Plasma)
	self.Entity:SetBaseWalkSpeed(16 * math.clamp(3.5 + 2.5 * MELEE, 3.5, 6))

	local trait, haki = self:_trait()
	local damage = 350 * AFFINITY * MELEE * haki
	local readyAt = 0
	-- One cooldown for the move, not one per victim; reach measured root to root.
	self:_contact("Plasma", ENERGIZE_REACH, 0, function(victim: CharacterEntity)
		local now = os.clock()
		if victim ~= target or now < readyAt then
			return
		end
		if (victim.Root.Position - self.Entity.Root.Position).Magnitude < ENERGIZE_REACH then
			readyAt = now + ENERGIZE_COOLDOWN
			-- The only boss hit that can be dodged; the legacy call named no style.
			self:_hit(victim, damage, trait, "Plain", true)
		end
	end)
	return nil
end

local function plasmaChain(self: Self, target: CharacterEntity, distance: number, _vertical: number, now: number): number?
	if distance > 10 and distance < 300 and self:_isReady("Plasma3", now) then
		return plasmaCannon(self, target, now)
	elseif distance > 1 and distance < 15 and self:_isReady("Plasma1", now) then
		return plasmaBurst(self, target, now)
	elseif distance > 2 and distance < 100 and self:_isReady("Plasma2", now) then
		return plasmaCoil(self, now)
	elseif distance > 15 and distance < 200 then
		return plasmaEnergize(self, target)
	end
	return nil
end

----------------------------------------------------------------------------------------
-- Smelt
----------------------------------------------------------------------------------------

local SWING_INTERVAL = 0.6
-- The legacy box hung in front of the right arm; the arm at rest, seen from the root.
local SWING_OFFSET = CFrame.new(1.5, 0.5, -3)
local SWING_SIZE = Vector3.new(6, 4, 6)
local SPEW_GROW_TIME = 5
local SPEW_LINGER_TIME = 3
local SPEW_HEIGHT = 8

-- A swing of the molten sword. Not a skill.
local function smeltSwing(self: Self, now: number): number?
	if now - self.LastSwing < SWING_INTERVAL then
		return nil
	end
	self.LastSwing = now
	self.SwingCount += 1
	self:_play(if self.SwingCount % 2 == 1 then "Dagger1" else "Dagger2", nil, nil, 8)

	local entity = self.Entity
	local trait, haki = self:_trait()
	local damage = 600 * AFFINITY * SWORD * haki
	self:_after(0.1, function()
		for _, victim in Hitbox.Box(entity.Root.CFrame * SWING_OFFSET, SWING_SIZE, entity) do
			-- Dodgeable, and the legacy call named no style.
			self:_hit(victim, damage, trait, "Plain", true)
		end
	end)
	return 0.4
end

-- A pool of molten metal slides 153 studs towards the target while it grows for 5 s, then stays 3 s. 6 s cooldown.
local function smeltSpew(self: Self, target: CharacterEntity, now: number): number?
	self.SkillsUsed += 1
	self:_face(target)
	self.Ready.Smelt3 = now + 6

	local entity = self.Entity
	local scale = DEFENSE * AFFINITY
	local trait, haki = self:_trait()
	local damage = 150 * scale * haki
	local origin = entity.Root.Position - Vector3.new(0, 3, 0)
	local look = entity.Root.CFrame.LookVector
	local direction = unitOr((target.Root.Position - origin) * Vector3.new(1, 0, 1), unitOr(look * Vector3.new(1, 0, 1), Vector3.zAxis))
	local travel = 60 * scale
	local length = 120 * scale

	self:_effect("SmeltSpew", origin, "Smelt", {
		Direction = direction,
		Travel = travel,
		Length = length,
		GrowTime = SPEW_GROW_TIME,
		LingerTime = SPEW_LINGER_TIME,
		Colors = COLORS.SmeltMolten,
		Haki = trait == "Haki",
	})
	self:_zone(0.25, SPEW_GROW_TIME + SPEW_LINGER_TIME, function(elapsed: number)
		local alpha = math.min(elapsed / SPEW_GROW_TIME, 1)
		local center = origin + direction * (travel * alpha)
		-- Half as wide as it is long, as the legacy part was.
		local box = Vector3.new(length / 2 * alpha, SPEW_HEIGHT, length * alpha)
		for _, victim in Hitbox.Box(CFrame.lookAt(center, center + direction), box, entity) do
			-- The legacy call passed "Special" as its style, which is none.
			self:_hit(victim, damage, trait, "Plain")
		end
	end)
	return nil
end

local function smeltChain(self: Self, target: CharacterEntity, distance: number, _vertical: number, now: number): number?
	if not self.SwordOn then
		self.SwordOn = true
		-- "<fruit slot>;<ability slot>;<colors>": no slots, nobody clicks for a boss.
		self:_status("SmeltSword", `0;0;{COLORS.SmeltMolten}`)
	end
	if not self.BodyOn and distance < 150 then
		self.BodyOn = true
		self:_status("SmeltBody", COLORS.Smelt)
		-- Haki as it was when the shell came out (the legacy script read it once).
		local trait, haki = self:_trait()
		local damage = 150 * DEFENSE * AFFINITY * haki
		self:_contact("Smelt", BODY_CONTACT_RADIUS, 0.5, function(victim: CharacterEntity)
			self:_hit(victim, damage, trait)
		end)
	end

	if distance < 6 then
		return smeltSwing(self, now)
	elseif distance > 10 and distance < 100 and self:_isReady("Smelt3", now) then
		return smeltSpew(self, target, now)
	end
	return nil
end

----------------------------------------------------------------------------------------
-- The loop
----------------------------------------------------------------------------------------

local CHAINS: { [string]: (self: Self, target: CharacterEntity, distance: number, vertical: number, now: number) -> number? } = {
	Magma = magmaChain,
	Sand = sandChain,
	Candy = candyChain,
	Quake = quakeChain,
	Flare = flareChain,
	Plasma = plasmaChain,
	Smelt = smeltChain,
}

function Global.Think(self: Self, target: CharacterEntity?, distance: number, now: number)
	local entity = self.Entity
	if self:_gone() then
		return
	end

	if not self.Haki and entity:GetHealthRatio() < HAKI_HEALTH_FRACTION then
		self:_enterHaki()
	end
	self:_touch(now)

	if entity.Root.Position.Y <= WorldConfig.SeaLevel then
		self.Handle.Halt()
		self.Characters:Teleport(entity, self.Handle.Home)
	end
	if target then
		self:_watch(target)
	end

	-- In the middle of a move or on its knees. A stun does not stop it: the legacy AI
	-- never looked at one.
	if self.Kneeling or now < self.BusyUntil then
		return
	end

	local first = self.Resume
	self.Resume = nil
	if not first then
		if self.SkillsUsed >= self.KneelAt then
			self:_kneel(now)
			return
		end
		if self.Active.Candy and not self.CandyOn and entity.Health < entity.MaxHealth then
			self:_candyBody()
		end
		if not target then
			return
		end

		-- Measured once per round, before any Shave (see the header).
		self.RoundDistance = distance
		self.RoundVertical = target.Root.Position.Y - entity.Root.Position.Y
		self:_reposition(target, distance, self.RoundVertical, now)
		first = 1
	end
	if not target or target.Dead then
		return
	end

	for index = first, #self.Fruits do
		local chain = CHAINS[self.Fruits[index]]
		local busy = if chain then chain(self, target, self.RoundDistance, self.RoundVertical, now) else nil
		if busy and busy > 0 then
			-- The legacy loop went on with the next fruit once the move returned.
			self.BusyUntil = now + busy
			self.Resume = if index < #self.Fruits then index + 1 else nil
			return
		end
	end

	if entity:IsRooted() then
		-- Rooted it cannot walk; everything above still happened.
		self.Handle.Halt()
	else
		self.Handle.Navigate(target.Root.Position)
	end
end

function Global.Destroy(self: Self)
	if self.Destroyed then
		return
	end
	self.Destroyed = true

	for thread in self.Jobs do
		pcall(task.cancel, thread)
	end
	table.clear(self.Jobs)
	-- Whatever is still in the air ends with the boss: nothing steps it any more.
	table.clear(self.Volumes)
	table.clear(self.Contacts)

	if self.WatchConnection then
		self.WatchConnection:Disconnect()
		self.WatchConnection = nil
	end
	self.Watched = nil

	local entity = self.Entity
	for name in self.Statuses do
		entity:ClearStatus(name)
	end
	table.clear(self.Statuses)
	-- Let go of whoever a tornado still holds.
	for victim, rope in self.Roped do
		if victim:GetStatus(ROPE_STATUS) == rope then
			victim:ClearStatus(ROPE_STATUS)
		end
	end
	table.clear(self.Roped)

	entity:SetRooted(KNEEL_ROOT, false)
	if entity.Humanoid.Parent then
		entity.Humanoid.AutoRotate = true
	end
	if entity.Root.Parent then
		Push.Clear(entity.Root)
	end

	for _, track in self.Tracks do
		track:Stop()
	end
	table.clear(self.Tracks)
end

return Global
