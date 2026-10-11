--!strict
--[[
	Creates and tracks a CharacterEntity for every player character and registered NPC.

	Players have no character until they ask for one. Players.CharacterAutoLoads is off:
	a player sits on the spawn screen (no body anywhere, the legacy lobby box is gone)
	until RequestSpawn loads the character on the selected spawn point. A death removes
	the body WorldConfig.RespawnDelay seconds later and nothing respawns by itself: the
	player is back on the spawn screen.

	Every character is parented by class under Workspace.Alive: player characters in
	Alive.Players (moved there right after the engine has put them in the Workspace),
	NPCs wherever their owner put them (EnemyService: Alive.NPCs / Alive.Bosses).

	One 1 Hz loop regenerates every player (the legacy game ran two polling scripts
	inside each character). Max health is recomputed only when one of its inputs changes.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local World = require(ReplicatedStorage.Shared.Util.World)
local Push = require(ReplicatedStorage.Shared.Util.Push)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local NetworkConfig = require(ServerStorage.Server.Configs.NetworkConfig)

type CharacterEntity = CharacterEntity.CharacterEntity
type PlayerData = PlayerData.PlayerData

local REGEN_INTERVAL = 1
-- How long a fresh character may take to show up with its Humanoid and root.
local PART_TIMEOUT = 10
-- Folder of Workspace.Instances with the streaming focus part of each spawn point.
local FOCUS_FOLDER = "SpawnFocus"

-- Data paths that feed a player's derived stats (max health, walk speed).
local STAT_PATHS = {
	"Skills.Melee.Level",
	"Skills.Defense.Level",
	"Skills.Sniper.Level",
	"Skills.Sword.Level",
	"Skills.Haki.Level",
	"Expertise.Perks",
}

local CharacterService = Knit.CreateService({
	Name = "CharacterService",
	Client = {
		-- Server -> owning client: (velocity) to apply to its own character.
		Impulse = Knit.CreateSignal(),
	},
})

CharacterService.EntityAdded = Signal.new() :: Signal.Signal<CharacterEntity>
CharacterService.EntityRemoving = Signal.new() :: Signal.Signal<CharacterEntity>
-- Fires when a player entity finishes its spawn protection and can fight.
CharacterService.EntitySpawned = Signal.new() :: Signal.Signal<CharacterEntity>

local DataService

local entities: { [Model]: CharacterEntity } = {}
local playerEntities: { [Player]: CharacterEntity } = {}
local spawnLimiter = RateLimiter.new(NetworkConfig.Actions.Spawn[1], NetworkConfig.Actions.Spawn[2])
-- Players whose LoadCharacter is in flight (it yields): no second request meanwhile.
local loading: { [Player]: boolean } = {}
-- Where the character being loaded by SpawnAt goes, instead of the saved spawn point.
local spawnDestinations: { [Player]: CFrame } = {}

local function removeEntity(entity: CharacterEntity)
	if entities[entity.Model] ~= entity then
		return
	end

	CharacterService.EntityRemoving:Fire(entity)
	entities[entity.Model] = nil
	if entity.Player and playerEntities[entity.Player] == entity then
		playerEntities[entity.Player] = nil
	end
	entity:Destroy()
end

local function applyPlayerStats(entity: CharacterEntity, data: PlayerData)
	local skills = data.Data.Skills
	entity.Levels = {
		Melee = skills.Melee.Level,
		Defense = skills.Defense.Level,
		Sniper = skills.Sniper.Level,
		Sword = skills.Sword.Level,
		Haki = skills.Haki.Level,
	}

	local healthPerk = data.Data.Expertise.Perks.BuffHealth.Value
	local base = StatConfig.BasePlayerHealth + StatConfig.GetHealthFromLevels(entity.Levels)
	entity:SetBaseMaxHealth(base * (1 + StatConfig.HealthPerPerkPoint * healthPerk))

	local speedPerk = data.Data.Expertise.Perks.BuffSpeed.Value
	entity:SetBaseWalkSpeed(StatConfig.BaseWalkSpeed * (1 + StatConfig.SpeedPerPerkPoint * speedPerk))
end

--[[
	With streaming, a player without a character receives the map around its
	ReplicationFocus. One invisible anchored part per spawn point (ten for the whole
	server, made on first use) lets the spawn screen show the place it is looking at.
]]
local focusParts: { [number]: BasePart } = {}

local function getFocusPart(index: number): BasePart
	local existing = focusParts[index]
	if existing then
		return existing
	end

	do
		local part = Instance.new("Part")
		part.Name = `Spawn{index}`
		part.Size = Vector3.one
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Position = WorldConfig.GetSpawnPosition(index)
		part.Parent = World.RuntimeFolder(FOCUS_FOLDER)
		focusParts[index] = part
		return part
	end
end

local function updateFocus(player: Player)
	if player.Parent ~= Players then
		return
	end
	local data = DataService:GetData(player)
	if player.Character or not data then
		player.ReplicationFocus = nil
	else
		player.ReplicationFocus = getFocusPart(WorldConfig.GetSpawnIndex(data.Data.SpawnNumber))
	end
end

-- The body of a dead (or otherwise finished) character goes away; no respawn follows.
local function removeCharacter(player: Player, character: Model)
	if player.Character == character then
		player.Character = nil
	end
	if character.Parent then
		character:Destroy()
	end
	-- Nobody is left to carry them, and the next spawn starts from a new Backpack anyway:
	-- without this the hotbar would keep showing tools on the spawn screen.
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and player.Character == nil then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end
	updateFocus(player)
end

--[[
	A character only ever appears through RequestSpawn, so everything a spawn needs
	happens here: class folder, spawn point, entity, spawn protection, removal on death.
]]
local function onCharacterAdded(player: Player, character: Model)
	local data = DataService:GetData(player)
	local humanoid = character:WaitForChild("Humanoid", PART_TIMEOUT)
	local root = character:WaitForChild("HumanoidRootPart", PART_TIMEOUT)
	if not data or not humanoid or not root then
		-- Never leave a body nobody tracks standing in the world.
		removeCharacter(player, character)
		return
	end

	-- CharacterAdded can fire before the model is parented to the world.
	if not character:IsDescendantOf(Workspace) then
		character.AncestryChanged:Wait()
	end
	--[[
		The engine is (or was a moment ago) inside its own `Parent = Workspace`. Setting
		the parent from within that change is refused ("something unexpectedly tried to
		set the parent"), so the move to Alive.Players waits for the next resumption.
	]]
	task.wait()
	if player.Character ~= character or not character:IsDescendantOf(Workspace) or entities[character] then
		return
	end

	local folder = World.Alive("Players")
	if folder and character.Parent ~= folder then
		character.Parent = folder
	end
	player.ReplicationFocus = nil

	-- The destination is the saved rotation, never something the client sent; a spawn
	-- asked by a service (SpawnAt) goes where that service said and leaves the rotation alone.
	local destination = spawnDestinations[player]
	spawnDestinations[player] = nil
	if destination then
		character:PivotTo(destination)
	else
		local spawnNumber = WorldConfig.GetSpawnIndex(data.Data.SpawnNumber)
		character:PivotTo(WorldConfig.GetSpawnCFrame(spawnNumber))
		data:Set("SpawnNumber", spawnNumber % WorldConfig.SpawnCount + 1)
	end
	(root :: BasePart).AssemblyLinearVelocity = Vector3.zero

	local entity = CharacterEntity.new(character, humanoid :: Humanoid, root :: BasePart, player)
	applyPlayerStats(entity, data)

	entities[character] = entity
	playerEntities[player] = entity
	character.Destroying:Once(function()
		removeEntity(entity)
	end)

	entity.Died:Once(function()
		task.delay(WorldConfig.RespawnDelay, removeCharacter, player, character)
	end)

	-- Protected (and harmless) until the timer below: Spawned is what combat checks.
	entity:SetStatus("Spawning", true, NetworkConfig.SpawnProtectionSeconds)
	CharacterService.EntityAdded:Fire(entity)

	-- It died while it was being set up: Humanoid.Died fired before anyone listened.
	if (humanoid :: Humanoid).Health <= 0 then
		entity:Kill()
	end

	task.delay(NetworkConfig.SpawnProtectionSeconds, function()
		if entities[character] == entity and not entity.Dead then
			entity:SetSpawned(true)
			CharacterService.EntitySpawned:Fire(entity)
		end
	end)
end

local function onDataLoaded(player: Player, data: PlayerData)
	for _, path in STAT_PATHS do
		data:Observe(path, function()
			local entity = playerEntities[player]
			if entity then
				applyPlayerStats(entity, data)
			end
		end)
	end

	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function(character: Model)
		local entity = entities[character]
		if entity then
			removeEntity(entity)
		end
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	-- The spawn screen looks at the selected spawn: keep that area streamed in.
	data:Observe("SpawnNumber", function()
		updateFocus(player)
	end)
	updateFocus(player)
end

local function regenerate()
	for player, entity in playerEntities do
		if entity.Dead or not entity.Spawned or entity.Health >= entity.MaxHealth then
			continue
		end

		local data = DataService:GetData(player)
		if not data then
			continue
		end

		local fraction = StatConfig.BaseRegen
			+ data.Data.Expertise.Perks.BuffRegen.Value * StatConfig.RegenPerPerkPoint
		-- Several systems scale regen at once (Phoenix speeds it up, Gum's 2nd Gear stops it):
		-- every status whose name starts with "RegenMultiplier" multiplies in.
		fraction *= entity:GetStatusProduct("RegenMultiplier")

		if entity.AntiHealHits > 0 then
			fraction *= 1 - entity.AntiHealFraction
			entity.AntiHealHits -= 1
			if entity.AntiHealHits <= 0 then
				entity.AntiHealFraction = 0
			end
		end

		entity:Heal(entity.MaxHealth * fraction)
	end
end

function CharacterService:GetEntity(model: Model?): CharacterEntity?
	return if model then entities[model] else nil
end

-- Every tracked character, players and NPCs. Do not mutate.
function CharacterService:GetEntities(): { [Model]: CharacterEntity }
	return entities
end

function CharacterService:GetPlayerEntity(player: Player): CharacterEntity?
	return playerEntities[player]
end

-- Resolves the entity that owns a part (hitbox results).
function CharacterService:GetEntityFromPart(part: BasePart): CharacterEntity?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local entity = entities[model]
		if entity then
			return entity
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

--[[
	Knockback / launch (Shared.Util.Push). Players simulate their own character, so the
	push is sent to the owning client; NPCs are simulated here and get it directly.

	Without `duration` the velocity is set once. With it the character is carried at that
	velocity for that long, like the short-lived BodyVelocity of the legacy game:
	`maxForce` and `power` are that mover's MaxForce and P (its defaults when left out).
	An axis with no force in `maxForce` is left to gravity and to the character.
]]
function CharacterService:ApplyImpulse(
	entity: CharacterEntity,
	velocity: Vector3,
	duration: number?,
	maxForce: Vector3?,
	power: number?
)
	if entity.Dead or velocity ~= velocity or (duration ~= nil and duration ~= duration) then
		return
	end

	if entity.Player then
		CharacterService.Client.Impulse:Fire(entity.Player, velocity, duration, maxForce, power)
	else
		Push.Apply(entity.Root, velocity, duration, maxForce, power)
	end
end

-- Moves a character. Server-authoritative for players and NPCs alike.
function CharacterService:Teleport(entity: CharacterEntity, cframe: CFrame)
	if not entity.Dead then
		entity.Model:PivotTo(cframe)
	end
end

-- NPCs are always in the world: no spawn protection, health straight from their levels.
function CharacterService:RegisterNPC(model: Model, levels: StatConfig.Levels): CharacterEntity?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end

	local entity = CharacterEntity.new(model, humanoid, root, nil)
	entity.Levels = levels
	entity:SetBaseMaxHealth(StatConfig.GetHealthFromLevels(levels))
	entity:SetSpawned(true)

	entities[model] = entity
	model.Destroying:Once(function()
		removeEntity(entity)
	end)

	CharacterService.EntityAdded:Fire(entity)
	return entity
end

-- Whether a character may be loaded for this player right now.
local function canLoad(player: Player): boolean
	if loading[player] then
		return false
	end

	-- A body that died or was destroyed before it got an entity (fell into the void
	-- while loading) has nobody to remove it: it must not lock its owner out.
	local stale = player.Character
	if stale and not entities[stale] then
		local humanoid = stale:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or not stale:IsDescendantOf(Workspace) then
			removeCharacter(player, stale)
		end
	end
	return player.Character == nil and playerEntities[player] == nil and DataService:GetData(player) ~= nil
end

local function load(player: Player): boolean
	loading[player] = true
	-- Yields until the character is in the world; errors when the player leaves meanwhile.
	local ok, problem = pcall(player.LoadCharacter, player)
	loading[player] = nil
	if not ok then
		warn(`[CharacterService] LoadCharacter failed for {player.Name}: {problem}`)
	end
	return ok and player.Character ~= nil
end

--[[
	Gives the caller a body on its selected spawn point. Takes no argument: the
	destination is the saved SpawnNumber (SpawnSelectService walks it), so this cannot be
	used as a teleport. Refused while the player has a character (alive, or dead and not
	removed yet) or while one is loading; rate limited on top of that.
]]
function CharacterService.Client:RequestSpawn(player: Player): boolean
	-- The raid place has no spawn screen: RaidRunService decides who gets a body and where.
	-- (The AFK place has no bodies at all: it does not load this service, see PlaceManifest.)
	-- Nor has the development place: DevPlaceService hands the bodies out.
	if PlaceConfig.Role == "Raid" or PlaceConfig.Role == "Dev" then
		return false
	end
	if not canLoad(player) or not spawnLimiter:Consume(player) then
		return false
	end
	return load(player)
end

--[[
	Server-only spawn at a place of the caller's choosing, for places where the player
	does not pick a spawn point (the raid). Same guards as RequestSpawn, no rate limit.
]]
function CharacterService:SpawnAt(player: Player, cframe: CFrame): boolean
	if player.Parent ~= Players or not canLoad(player) then
		return false
	end
	spawnDestinations[player] = cframe
	local loaded = load(player)
	if not loaded then
		spawnDestinations[player] = nil
	end
	return loaded
end

-- True while the player has no body: on the spawn screen (or still loading in).
function CharacterService:IsWaitingToSpawn(player: Player): boolean
	return player.Character == nil and not loading[player]
end

function CharacterService:KnitInit()
	DataService = Knit.GetService("DataService")

	-- Before any player can join: nobody gets a body they did not ask for.
	Players.CharacterAutoLoads = false
	for _, kind in World.AliveKinds do
		World.Alive(kind)
	end
end

function CharacterService:KnitStart()
	DataService:ObserveData(onDataLoaded)

	Players.PlayerRemoving:Connect(function(player: Player)
		spawnLimiter:Forget(player)
		loading[player] = nil
		spawnDestinations[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(REGEN_INTERVAL)
			regenerate()
		end
	end)
end

return CharacterService
