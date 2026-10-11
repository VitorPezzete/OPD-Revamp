--!strict
--[[
	Spawns and drives every NPC enemy.

	Templates: ReplicatedStorage.Assets.Models.Enemies. Each template model is one spawn
	point: its pivot in the template is where it lives in the world, and its name is the
	key into EnemyConfig. Templates in Assets.Models.Bosses (and Events) are spawned on
	demand with SpawnEvent, unless BossConfig marks them as world spawns.
	Live models are parented by class: Workspace.Alive.NPCs for ordinary enemies,
	Workspace.Alive.Bosses for anything BossConfig knows or that comes from Models.Bosses.

	One loop thinks for every NPC. The legacy game gave each NPC its own script that
	recomputed a path every Heartbeat, plus ~60 status scripts cloned into every model.
	Here each enemy has a "next think" time and the loop only visits those that are due:

		a player is being chased        every 0.2 s (bosses 0.1 s)
		a player is close, no target    every 0.5 s
		a player is in the area         every 1 s
		nobody around                   every 3 s (asleep; sent straight home)

	Behaviour, as in the legacy game: chase the closest spawned player inside
	FollowDistance and hit it on contact; gun enemies (Config.Ranged) keep 50 to 65 studs
	away and shoot whenever they see their target (each shot is shown by the client effect
	"EnemyShot", the white line of the legacy game); walk home when nobody is around;
	respawn RespawnTime seconds after dying. Added: a leash to the spawn point (the legacy
	enemies could be dragged across the whole map) and bosses, whose attack patterns are
	classes in Server.Modules.Bosses.

	Movement is a straight Humanoid:MoveTo. Only an enemy that stops making progress asks
	for a real path, and the whole server shares a small budget of path computations per
	second: with the budget spent, enemies simply keep pushing in a straight line.

	Server API
		EnemyService:SpawnEvent(templateName, cframe, { Name?, Levels?, Damage?, Lifetime?, Respawn? }) -> CharacterEntity?
		EnemyService:Despawn(entity)
		EnemyService:SetControlled(entity, controlled)   -- a controlled NPC stops thinking
		EnemyService:GetName(entity) -> template name, nil when the entity is not an enemy
]]
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)
local World = require(ReplicatedStorage.Shared.Util.World)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local BossConfig = require(ServerStorage.Server.Configs.BossConfig)
local EnemyConfig = require(ServerStorage.Server.Configs.EnemyConfig)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local BossTypes = require(ServerStorage.Server.Types.BossTypes)

type CharacterEntity = CharacterEntity.CharacterEntity
type EnemyDefinition = EnemyConfig.EnemyDefinition

type Enemy = {
	Name: string,
	-- Name given to the live model when it is not the template's (SpawnConfig.Name).
	Label: string?,
	Template: Model,
	Definition: EnemyDefinition,
	Levels: StatConfig.Levels,
	Home: CFrame,
	Respawn: boolean,
	Leash: number,
	Removed: boolean,

	Entity: CharacterEntity?,
	Boss: BossTypes.BossBehaviour?,
	Controlled: boolean,
	Returning: boolean,
	ReturnDeadline: number,

	NextThink: number,
	NextAttack: number,
	Moving: boolean,
	RunTrack: AnimationTrack?,
	ShootTrack: AnimationTrack?,
	Muzzle: BasePart?,

	-- Progress tracking between two thinks, to notice a blocked straight line.
	LastPosition: Vector3,
	LastThink: number,
	Navigated: boolean,
	StuckTicks: number,

	Path: Path?,
	PathPending: boolean,
	NextPathTry: number,
	Waypoints: { PathWaypoint }?,
	WaypointIndex: number,
	PathGoal: Vector3,
	PathExpires: number,
}

export type SpawnConfig = {
	-- Name of the live model ("Lv650 Sword Marine") for an enemy whose level is decided
	-- at run time. GetName still answers with the template name.
	Name: string?,
	Levels: any?,
	Damage: number?,
	Lifetime: number?,
	Respawn: boolean?,
}

type Seen = { Entity: CharacterEntity, Position: Vector3, Visible: boolean }

local LOOP_STEP = 0.1

local THINK_ENGAGED = 0.2
local THINK_BOSS = 0.1
local THINK_ALERT = 0.5
local THINK_AREA = 1
local THINK_ASLEEP = 3
-- A player this far beyond the aggro range keeps the enemy alert.
local ALERT_MARGIN = 60
local AREA_DISTANCE = 300
-- With nobody closer than this, an enemy away from home is put back instead of walked.
local UNSEEN_DISTANCE = 350

local MELEE_REACH = 6
local MELEE_COOLDOWN = 0.7
local HOME_TOLERANCE = 8
local LEASH_FACTOR = 3
local MIN_LEASH = 80
-- An enemy that cannot walk home in this long is placed there.
local RETURN_TIMEOUT = 15

-- Gun enemies (legacy AIGun): hold between SAFE and SAFE + BAND studs from the target.
local RANGED_SAFE_DISTANCE = 50
local RANGED_BAND = 15
local RANGED_RETREAT_STEP = 10
local RANGED_DEFAULT_COOLDOWN = 0.7
local RANGED_WINDUP = 0.1
local RANGED_RANGE_MARGIN = 20
-- The legacy shot was instant; the projectile is fast enough to feel the same.
local BULLET_SPEED = 600
-- Client one-shot that draws the shot (Effects.OneShot.EnemyShot).
local SHOT_EFFECT = "EnemyShot"
local SHOOT_ANIMATION = "rbxassetid://92578670038340"
local SHOOT_ANIMATION_SPEED = 1.5
local SHOOT_ANIMATION_WEIGHT = 3
local SHOOT_ANIMATION_FADE = 0.1
local RUN_ANIMATION = "rbxassetid://180426354"

-- Fraction of the expected distance below which a walking enemy counts as blocked.
local STUCK_FRACTION = 0.25
-- Blocked thinks before asking for a path (the first one only makes it hop).
local STUCK_TICKS_FOR_PATH = 3
-- Path computations per second for the whole server, and how many can be saved up.
local PATH_BUDGET_PER_SECOND = 3
local PATH_BUDGET_BURST = 4
local PATH_LIFETIME = 4
local PATH_RETRY_DELAY = 3
-- A path is dropped when its goal has moved further than this.
local PATH_GOAL_DRIFT = 15
local WAYPOINT_REACH = 4

local CORPSE_TIME = 5

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	Client = {},
})

local CharacterService
local CombatService
local EffectService

local enemies: { Enemy } = {}
local byEntity: { [CharacterEntity]: Enemy } = {}
-- Outlives byEntity: kill listeners (rewards, boss drops) ask for the name of an enemy
-- that has just died. Weak keys, so a destroyed entity does not linger.
local names: { [CharacterEntity]: string } = setmetatable({}, { __mode = "k" }) :: any
local bossClasses: { [string]: BossTypes.BossClass | false } = {}
-- Workspace.Alive.NPCs and .Bosses: every enemy model lives in the folder of its class.
local npcContainer: Instance
local bossContainer: Instance
local pathTokens = PATH_BUDGET_BURST
local lastStep = os.clock()
local warned: { [string]: boolean } = {}

local function warnOnce(message: string)
	if not warned[message] then
		warned[message] = true
		warn(`[EnemyService] {message}`)
	end
end

local function horizontal(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function setMoving(enemy: Enemy, moving: boolean)
	if enemy.Moving == moving then
		return
	end
	enemy.Moving = moving
	local track = enemy.RunTrack
	if track then
		if moving then
			track:Play(0.2)
		else
			track:Stop(0.2)
		end
	end
end

local function clearPath(enemy: Enemy)
	enemy.Waypoints = nil
	enemy.WaypointIndex = 0
end

local function halt(enemy: Enemy)
	local entity = enemy.Entity
	clearPath(enemy)
	enemy.Navigated = false
	enemy.StuckTicks = 0
	if entity and enemy.Moving then
		entity.Humanoid:MoveTo(entity.Root.Position)
	end
	setMoving(enemy, false)
end

local function requestPath(enemy: Enemy, entity: CharacterEntity, goal: Vector3, now: number)
	if enemy.PathPending or now < enemy.NextPathTry or pathTokens < 1 then
		return
	end
	pathTokens -= 1
	enemy.PathPending = true

	local path = enemy.Path
	if not path then
		path = PathfindingService:CreatePath({ AgentCanClimb = false, AgentCanJump = true })
		enemy.Path = path
	end

	task.spawn(function()
		local ok = pcall(function()
			(path :: Path):ComputeAsync(entity.Root.Position, goal)
		end)
		enemy.PathPending = false
		if enemy.Entity ~= entity or entity.Dead then
			return
		end

		if ok and (path :: Path).Status == Enum.PathStatus.Success then
			enemy.Waypoints = (path :: Path):GetWaypoints()
			-- The first waypoint is where the enemy already stands.
			enemy.WaypointIndex = 2
			enemy.PathGoal = goal
			enemy.PathExpires = os.clock() + PATH_LIFETIME
		else
			enemy.NextPathTry = os.clock() + PATH_RETRY_DELAY
		end
		enemy.StuckTicks = 0
	end)
end

-- Walks towards goal. Returns nothing: progress is judged on the next call.
local function navigate(enemy: Enemy, entity: CharacterEntity, goal: Vector3, now: number)
	local humanoid = entity.Humanoid
	local position = entity.Root.Position
	setMoving(enemy, true)
	if humanoid.Sit then
		humanoid.Jump = true
	end

	local waypoints = enemy.Waypoints
	if waypoints then
		if now > enemy.PathExpires or (goal - enemy.PathGoal).Magnitude > PATH_GOAL_DRIFT then
			clearPath(enemy)
		else
			local waypoint = waypoints[enemy.WaypointIndex]
			while waypoint and horizontal(waypoint.Position - position).Magnitude <= WAYPOINT_REACH do
				enemy.WaypointIndex += 1
				waypoint = waypoints[enemy.WaypointIndex]
			end
			if waypoint then
				humanoid:MoveTo(waypoint.Position)
				if waypoint.Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end
				enemy.Navigated = true
				return
			end
			clearPath(enemy)
		end
	end

	humanoid:MoveTo(goal)

	-- Only judged when the previous think was already walking, so the first step of a
	-- chase is not mistaken for a wall.
	if enemy.Navigated and humanoid.WalkSpeed > 0 then
		local expected = humanoid.WalkSpeed * (now - enemy.LastThink)
		local moved = horizontal(position - enemy.LastPosition).Magnitude
		if expected > 0 and moved < expected * STUCK_FRACTION then
			enemy.StuckTicks += 1
			if enemy.StuckTicks == 1 then
				-- Most blockers are a step or a low ledge.
				humanoid.Jump = true
			elseif enemy.StuckTicks >= STUCK_TICKS_FOR_PATH then
				requestPath(enemy, entity, goal, now)
			end
		else
			enemy.StuckTicks = 0
		end
	end
	enemy.Navigated = true
end

local function face(entity: CharacterEntity, target: Vector3)
	local position = entity.Root.Position
	local flat = Vector3.new(target.X, position.Y, target.Z)
	if (flat - position).Magnitude > 0.1 then
		entity.Root.CFrame = CFrame.lookAt(position, flat)
	end
end

local function loadTrack(entity: CharacterEntity, animationId: string): AnimationTrack
	local animator = entity.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", entity.Humanoid)
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	return animator:LoadAnimation(animation)
end

local function getBossClass(name: string): BossTypes.BossClass?
	local definition = BossConfig.Bosses[name]
	if not definition then
		return nil
	end

	local cached = bossClasses[definition.Behaviour]
	if cached == nil then
		local folder = ServerStorage.Server.Modules:FindFirstChild("Bosses")
		local module = folder and folder:FindFirstChild(definition.Behaviour)
		local ok: boolean, class: any = false, nil
		if module and module:IsA("ModuleScript") then
			ok, class = pcall(require, module)
		end
		if ok and type(class) == "table" and type(class.new) == "function" then
			cached = class
		else
			warnOnce(`boss behaviour "{definition.Behaviour}" failed to load: {class}`)
			cached = false
		end
		bossClasses[definition.Behaviour] = cached
	end
	return if cached then cached else nil
end

local function removeEnemy(enemy: Enemy)
	enemy.Removed = true
	local index = table.find(enemies, enemy)
	if index then
		table.remove(enemies, index)
	end
end

local spawnEnemy: (enemy: Enemy) -> CharacterEntity?

-- A boss is anything BossConfig knows or that comes from Assets.Models.Bosses.
local function isBossTemplate(template: Model): boolean
	if BossConfig.Bosses[template.Name] then
		return true
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local bosses = models and models:FindFirstChild("Bosses")
	return bosses ~= nil and template:IsDescendantOf(bosses)
end

local function onDied(enemy: Enemy, entity: CharacterEntity, model: Model)
	if enemy.Entity ~= entity then
		return
	end

	byEntity[entity] = nil
	enemy.Entity = nil
	enemy.RunTrack = nil
	enemy.ShootTrack = nil
	enemy.Muzzle = nil
	clearPath(enemy)

	local boss = enemy.Boss
	enemy.Boss = nil
	if boss then
		boss:Destroy()
	end

	if enemy.Respawn and not enemy.Removed then
		task.delay(enemy.Definition.RespawnTime, function()
			model:Destroy()
			if not enemy.Removed then
				spawnEnemy(enemy)
			end
		end)
	else
		removeEnemy(enemy)
		task.delay(CORPSE_TIME, function()
			model:Destroy()
		end)
	end
end

function spawnEnemy(enemy: Enemy): CharacterEntity?
	local model = enemy.Template:Clone()
	if enemy.Label then
		model.Name = enemy.Label
	end
	model:PivotTo(enemy.Home)
	model.Parent = if isBossTemplate(enemy.Template) then bossContainer else npcContainer

	local entity: CharacterEntity? = CharacterService:RegisterNPC(model, enemy.Levels)
	if not entity then
		model:Destroy()
		return nil
	end

	local definition = enemy.Definition
	entity:SetBaseWalkSpeed(definition.WalkSpeed)
	entity.Root:SetNetworkOwner(nil)
	-- "Lv9 Bandit": the number feeds the level billboard (NameplateController).
	local level = tonumber(string.match(enemy.Label or enemy.Name, "^Lv(%d+)"))
	if level then
		model:SetAttribute("Level", level)
	end
	if definition.Fruit then
		-- Logia-type enemies shrug off plain melee and sword hits.
		entity:SetStatus("MeleeImmunity", true)
		entity:SetStatus("SwordImmunity", true)
	end

	local runTrack = loadTrack(entity, RUN_ANIMATION)
	runTrack.Looped = true

	local now = os.clock()
	enemy.Entity = entity
	enemy.RunTrack = runTrack
	enemy.ShootTrack = if definition.Ranged then loadTrack(entity, SHOOT_ANIMATION) else nil
	local muzzle = model:FindFirstChild("Weapon1")
	enemy.Muzzle = if muzzle and muzzle:IsA("BasePart") then muzzle else nil
	enemy.Controlled = false
	enemy.Returning = false
	enemy.Moving = false
	enemy.Navigated = false
	enemy.StuckTicks = 0
	enemy.NextAttack = 0
	enemy.NextPathTry = 0
	enemy.PathPending = false
	enemy.LastPosition = entity.Root.Position
	enemy.LastThink = now
	-- Spread the first think so a whole batch of spawns does not line up on one frame.
	enemy.NextThink = now + math.random() * THINK_ALERT
	byEntity[entity] = enemy
	names[entity] = enemy.Name

	local bossClass = getBossClass(enemy.Name)
	if bossClass then
		enemy.Boss = bossClass.new({
			Name = enemy.Name,
			Entity = entity,
			Definition = definition,
			Home = enemy.Home,
			Navigate = function(goal: Vector3)
				if enemy.Entity == entity and not entity.Dead then
					navigate(enemy, entity, goal, os.clock())
				end
			end,
			Halt = function()
				if enemy.Entity == entity then
					halt(enemy)
				end
			end,
		})
	end

	-- A model destroyed from outside (not a death, not Despawn) used to leave its enemy in
	-- the list for good: still thought, still counted, its boss behaviour still attacking.
	model.Destroying:Once(function()
		if byEntity[entity] == enemy then
			EnemyService:Despawn(entity)
		end
	end)

	entity.Died:Once(function()
		onDied(enemy, entity, model)
	end)
	return entity
end

local function hasLineOfSight(enemy: Enemy, entity: CharacterEntity, target: CharacterEntity): boolean
	local origin = if enemy.Muzzle then enemy.Muzzle.Position else entity.Root.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }

	local result = Workspace:Raycast(origin, target.Root.Position - origin, params)
	return result == nil or result.Instance:IsDescendantOf(target.Model)
end

local function shoot(enemy: Enemy, entity: CharacterEntity, target: CharacterEntity, range: number)
	local definition = enemy.Definition
	local track = enemy.ShootTrack
	if track then
		-- Legacy: Play(), AdjustSpeed(1.5), AdjustWeight(3, 0.1).
		track:Play(SHOOT_ANIMATION_FADE, SHOOT_ANIMATION_WEIGHT, SHOOT_ANIMATION_SPEED)
	end

	task.delay(RANGED_WINDUP, function()
		if enemy.Entity ~= entity or entity.Dead or target.Dead or enemy.Controlled then
			return
		end

		local origin = if enemy.Muzzle then enemy.Muzzle.Position else entity.Root.Position
		local direction = target.Root.Position - origin
		if direction.Magnitude < 1e-3 then
			return
		end

		-- Legacy numbers: a shot deals the Sniper level, twice that when it is Special damage.
		local amount = enemy.Levels.Sniper * (if definition.DamageTrait == "Special" then 2 else 1)
		local maxDistance = range + RANGED_RANGE_MARGIN
		-- The legacy trajectory: a line from the muzzle to where the target stands, drawn
		-- by each client (it used to be a part created here for every shot).
		EffectService:Play(SHOT_EFFECT, origin, { Target = origin + direction })
		Projectile.Fire({
			Origin = origin,
			Direction = direction,
			Speed = BULLET_SPEED,
			MaxDistance = maxDistance,
			Owner = entity,
			OnHit = function(hit: CharacterEntity)
				if hit.Player and not entity.Dead then
					CombatService:Damage({
						Target = hit,
						Attacker = entity,
						Amount = amount,
						Trait = definition.DamageTrait,
						Style = "Weapon",
						Dodgeable = true,
					})
				end
			end,
		})
	end)
end

local function thinkRanged(enemy: Enemy, entity: CharacterEntity, target: CharacterEntity, distance: number, now: number)
	local definition = enemy.Definition
	local range = definition.RangedRange or definition.FollowDistance
	local position = entity.Root.Position
	local targetPosition = target.Root.Position

	if not hasLineOfSight(enemy, entity, target) then
		-- The legacy gunner froze behind any wall; this one walks until it sees its target again.
		navigate(enemy, entity, targetPosition, now)
		return
	end

	if distance < RANGED_SAFE_DISTANCE then
		local away = horizontal(position - targetPosition)
		away = if away.Magnitude > 1e-3 then away.Unit else entity.Root.CFrame.LookVector
		navigate(enemy, entity, position + away * (RANGED_SAFE_DISTANCE - distance + RANGED_RETREAT_STEP), now)
	elseif distance > RANGED_SAFE_DISTANCE + RANGED_BAND then
		navigate(enemy, entity, targetPosition, now)
	else
		halt(enemy)
		face(entity, targetPosition)
	end

	if distance <= range and now >= enemy.NextAttack then
		enemy.NextAttack = now + (definition.RangedCooldown or RANGED_DEFAULT_COOLDOWN)
		shoot(enemy, entity, target, range)
	end
end

local function thinkMelee(enemy: Enemy, entity: CharacterEntity, target: CharacterEntity, distance: number, now: number)
	local definition = enemy.Definition
	local position = entity.Root.Position
	local targetPosition = target.Root.Position

	navigate(enemy, entity, targetPosition, now)
	if targetPosition.Y > position.Y + 3 and distance < 12 then
		entity.Humanoid.Jump = true
	end

	if distance <= MELEE_REACH and now >= enemy.NextAttack then
		enemy.NextAttack = now + MELEE_COOLDOWN
		CombatService:Damage({
			Target = target,
			Attacker = entity,
			Amount = definition.Damage,
			Trait = definition.DamageTrait,
			Style = if definition.DamageTrait == "Sword" then "Weapon" else "Ability",
			Dodgeable = true,
		})
	end
end

-- Returns the delay until this enemy has to think again.
local function think(enemy: Enemy, entity: CharacterEntity, seen: { Seen }, now: number): number
	if enemy.Controlled then
		return THINK_ALERT
	end

	local definition = enemy.Definition
	local position = entity.Root.Position
	local aggro = math.max(definition.FollowDistance, definition.RangedRange or 0)

	local target: CharacterEntity? = nil
	local targetDistance = aggro
	local nearest = math.huge
	for _, candidate in seen do
		local distance = (candidate.Position - position).Magnitude
		if distance < nearest then
			nearest = distance
		end
		if candidate.Visible and distance <= targetDistance then
			target, targetDistance = candidate.Entity, distance
		end
	end

	local home = enemy.Home.Position
	local fromHome = (position - home).Magnitude
	local boss = enemy.Boss

	if enemy.Returning then
		-- Leashed: players are ignored until it is back at its spawn.
		target = nil
		if fromHome <= HOME_TOLERANCE then
			enemy.Returning = false
		elseif now >= enemy.ReturnDeadline then
			entity.Model:PivotTo(enemy.Home)
			enemy.Returning = false
		end
	elseif target and fromHome > enemy.Leash then
		enemy.Returning = true
		enemy.ReturnDeadline = now + RETURN_TIMEOUT
		target = nil
	end

	if boss then
		boss:Think(target, if target then targetDistance else math.huge, now)
	end

	if not target then
		if fromHome <= HOME_TOLERANCE then
			if enemy.Moving then
				halt(enemy)
			end
		elseif nearest > UNSEEN_DISTANCE and not entity:IsRooted() then
			-- Nobody can see it: skip the walk.
			halt(enemy)
			entity.Model:PivotTo(enemy.Home)
			enemy.Returning = false
		elseif not entity:IsRooted() then
			navigate(enemy, entity, home, now)
			return THINK_ENGAGED
		end

		if nearest <= aggro + ALERT_MARGIN then
			return if boss then THINK_ENGAGED else THINK_ALERT
		elseif nearest <= AREA_DISTANCE then
			return THINK_AREA
		end
		return THINK_ASLEEP
	end

	if boss then
		return THINK_BOSS
	end

	if entity:IsRooted() then
		halt(enemy)
	elseif definition.Ranged then
		thinkRanged(enemy, entity, target, targetDistance, now)
	else
		thinkMelee(enemy, entity, target, targetDistance, now)
	end
	return THINK_ENGAGED
end

local function step()
	local now = os.clock()
	pathTokens = math.min(PATH_BUDGET_BURST, pathTokens + (now - lastStep) * PATH_BUDGET_PER_SECOND)
	lastStep = now

	local seen: { Seen } = {}
	for _, player in Players:GetPlayers() do
		local entity = CharacterService:GetPlayerEntity(player)
		if entity and entity.Spawned and not entity.Dead then
			table.insert(seen, {
				Entity = entity,
				Position = entity.Root.Position,
				Visible = not entity:HasStatus("Invisible"),
			})
		end
	end

	-- Backwards: a think can remove the enemy it is visiting (event spawns that die).
	for index = #enemies, 1, -1 do
		local enemy = enemies[index]
		local entity = enemy.Entity
		if not entity or entity.Dead or now < enemy.NextThink then
			continue
		end

		local ok, delay = pcall(think, enemy, entity, seen, now)
		if not ok then
			warnOnce(`think failed for "{enemy.Name}": {delay}`)
			delay = THINK_AREA
		end
		enemy.NextThink = now + (delay :: number)
		enemy.LastThink = now
		enemy.LastPosition = entity.Root.Position
	end
end

-- Non-gun enemies were given a Special level of at least half of their other levels
-- (legacy Enemies script); it only matters for the kill reward.
local function resolveLevels(definition: EnemyDefinition, override: any?): StatConfig.Levels
	local source: any = if type(override) == "table" then override else definition.Levels
	local levels: StatConfig.Levels = {
		Melee = tonumber(source.Melee) or definition.Levels.Melee,
		Defense = tonumber(source.Defense) or definition.Levels.Defense,
		Sniper = tonumber(source.Sniper) or definition.Levels.Sniper,
		Sword = tonumber(source.Sword) or definition.Levels.Sword,
		Haki = tonumber(source.Haki) or definition.Levels.Haki,
		Special = tonumber(source.Special) or definition.Levels.Special or 0,
	}
	if not definition.Ranged then
		local others = levels.Melee + levels.Defense + levels.Sniper + levels.Sword + levels.Haki
		levels.Special = math.max(levels.Special or 0, math.floor(others / 2))
	end
	return levels
end

local function createEnemy(template: Model, definition: EnemyDefinition, home: CFrame, levels: any?, respawn: boolean): Enemy
	return {
		Name = template.Name,
		Label = nil,
		Template = template,
		Definition = definition,
		Levels = resolveLevels(definition, levels),
		Home = home,
		Respawn = respawn,
		Leash = definition.LeashDistance or math.max(definition.FollowDistance * LEASH_FACTOR, MIN_LEASH),
		Removed = false,

		Entity = nil,
		Boss = nil,
		Controlled = false,
		Returning = false,
		ReturnDeadline = 0,

		NextThink = 0,
		NextAttack = 0,
		Moving = false,
		RunTrack = nil,
		ShootTrack = nil,
		Muzzle = nil,

		LastPosition = home.Position,
		LastThink = 0,
		Navigated = false,
		StuckTicks = 0,

		Path = nil,
		PathPending = false,
		NextPathTry = 0,
		Waypoints = nil,
		WaypointIndex = 0,
		PathGoal = home.Position,
		PathExpires = 0,
	}
end

local function getModelsFolder(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	return models and models:FindFirstChild(name)
end

local function loadWorldSpawns(folder: Instance?, bossesOnly: boolean)
	if not folder then
		return
	end
	for _, template in folder:GetChildren() do
		local definition = EnemyConfig[template.Name]
		if not template:IsA("Model") or not definition or not template:FindFirstChildOfClass("Humanoid") then
			continue
		end
		-- Raid enemies: their template is not a spawn point, they only come from SpawnEvent.
		if definition.OnDemand then
			continue
		end
		local boss = BossConfig.Bosses[template.Name]
		if bossesOnly and not (boss and boss.WorldSpawn) then
			continue
		end
		table.insert(enemies, createEnemy(template, definition, template:GetPivot(), nil, true))
	end
end

local function findTemplate(name: string): Model?
	for _, folderName in { "Bosses", "Enemies", "Events" } do
		local folder = getModelsFolder(folderName)
		local template = folder and folder:FindFirstChild(name)
		if template and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") then
			return template
		end
		-- Event templates sit in sub-folders, sometimes inside a folder of the same name.
		if folder and folderName == "Events" then
			for _, descendant in folder:GetDescendants() do
				if descendant.Name == name and descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
					return descendant
				end
			end
		end
	end
	return nil
end

function EnemyService:GetCount(): number
	return #enemies
end

-- Template name of an enemy entity (the key into EnemyConfig / BossConfig). Still
-- answers for an enemy that has just been killed.
function EnemyService:GetName(entity: CharacterEntity): string?
	return names[entity]
end

--[[
	Spawns one enemy outside of the world spawn list (boss fights, raids, events).
	config.Levels overrides the levels of EnemyConfig (any subset of them) and
	config.Damage its contact damage; with config.Respawn the enemy comes back at
	`cframe` like a world spawn, otherwise it is gone for good a few seconds after dying;
	config.Lifetime removes it after that many seconds if it is still alive. Returns nil
	when the template or its EnemyConfig entry does not exist.
]]
function EnemyService:SpawnEvent(templateName: string, cframe: CFrame, config: SpawnConfig?): CharacterEntity?
	local definition = EnemyConfig[templateName]
	local template = findTemplate(templateName)
	if not definition or not template or not npcContainer then
		warnOnce(`SpawnEvent: no template or EnemyConfig entry for "{templateName}"`)
		return nil
	end

	local damage = config and config.Damage
	if type(damage) == "number" and damage == damage then
		local override = table.clone(definition)
		override.Damage = math.max(0, damage)
		definition = override
	end

	local enemy = createEnemy(template, definition, cframe, config and config.Levels, config ~= nil and config.Respawn == true)
	local label = config and config.Name
	enemy.Label = if type(label) == "string" and label ~= "" then label else nil
	local entity = spawnEnemy(enemy)
	if not entity then
		return nil
	end
	table.insert(enemies, enemy)

	local lifetime = config and config.Lifetime
	if type(lifetime) == "number" and lifetime > 0 then
		task.delay(lifetime, function()
			-- Whatever body it has by then (a respawning one has been replaced).
			enemy.Respawn = false
			local current = enemy.Entity
			if current then
				EnemyService:Despawn(current)
			else
				removeEnemy(enemy)
			end
		end)
	end
	return entity
end

-- Removes an enemy for good, without a death (island teardown, event end).
function EnemyService:Despawn(entity: CharacterEntity)
	local enemy = byEntity[entity]
	if not enemy then
		return
	end

	byEntity[entity] = nil
	enemy.Entity = nil
	removeEnemy(enemy)
	local boss = enemy.Boss
	enemy.Boss = nil
	if boss then
		boss:Destroy()
	end
	entity.Model:Destroy()
end

--[[
	A controlled NPC (Hobby's toys) stops thinking: no chase, no attacks, no walk home.
	Whoever controls it moves it; it resumes from where it stands when released.
]]
function EnemyService:SetControlled(entity: CharacterEntity, controlled: boolean)
	local enemy = byEntity[entity]
	if not enemy or enemy.Controlled == controlled then
		return
	end

	if controlled then
		halt(enemy)
	end
	enemy.Controlled = controlled
	enemy.Returning = false
	enemy.NextThink = 0
end

function EnemyService:IsControlled(entity: CharacterEntity): boolean
	local enemy = byEntity[entity]
	return enemy ~= nil and enemy.Controlled
end

function EnemyService:KnitInit()
	CharacterService = Knit.GetService("CharacterService")
	CombatService = Knit.GetService("CombatService")
	EffectService = Knit.GetService("EffectService")

	-- Created here so SpawnEvent works from any other service's KnitStart.
	npcContainer = World.Alive("NPCs") :: Instance
	bossContainer = World.Alive("Bosses") :: Instance
end

function EnemyService:KnitStart()
	-- The world spawns belong to the main map; elsewhere enemies only come from SpawnEvent.
	if PlaceConfig.Role == "Main" then
		loadWorldSpawns(getModelsFolder("Enemies"), false)
		loadWorldSpawns(getModelsFolder("Bosses"), true)
	end

	-- A copy: SpawnEvent may add (already spawned) enemies to the list meanwhile.
	for _, enemy in table.clone(enemies) do
		if not enemy.Entity and not enemy.Removed then
			spawnEnemy(enemy)
		end
	end

	task.spawn(function()
		while true do
			task.wait(LOOP_STEP)
			step()
		end
	end)
end

return EnemyService
