--!strict
--[[
	Halloween (October): a pumpkin sits at one of seven places of the map. Whoever clicks
	it releases a horde of zombies around it, which hit for three times the clicker's
	Melee level. A minute later, at the earliest, another pumpkin appears. Zombie kills
	count towards the Zombie Head (RewardService increments Combat.ZombiesKilled).

	Zombies are EnemyService event spawns (SpawnEvent, no respawn) removed with Despawn
	when their lifetime is over. SpawnEvent has no damage override yet, so the extra
	`Damage` field it is given is ignored until it does: zombies hit for the flat
	EnemyConfig.Zombie damage instead of three times the clicker's Melee level.

	Legacy problems fixed
	- The pumpkin's click was not checked for distance: it could be opened from anywhere.
	- Every zombie ran its own pathfinding script each Heartbeat and nothing ever removed
	  them or limited how many existed. They are EnemyService enemies with a lifetime and
	  a cap now.
	- Zombies were dropped at the pumpkin's height, often inside the terrain; they are
	  placed on the ground below.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local World = require(ReplicatedStorage.Shared.Util.World)

local SeasonConfig = require(ServerStorage.Server.Configs.SeasonConfig)
local WorldAssets = require(ServerStorage.Server.Modules.WorldAssets)

-- Folder of Workspace.Instances the pumpkin is shown in.
local PUMPKIN_FOLDER = "Halloween"

local CONFIG = SeasonConfig.Halloween
local GROUND_PROBE_HEIGHT = 150
local GROUND_CLEARANCE = 3

local Halloween = {}

local random = Random.new()
local warnedSpawn = false

local function findGround(position: Vector3): Vector3
	local origin = position + Vector3.new(0, GROUND_PROBE_HEIGHT, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -2 * GROUND_PROBE_HEIGHT, 0))
	if result then
		return result.Position + Vector3.new(0, GROUND_CLEARANCE, 0)
	end
	return position
end

function Halloween.Start(context: { OnMinute: (fn: () -> ()) -> () }): (() -> ())?
	local CharacterService = Knit.GetService("CharacterService")
	local DataService = Knit.GetService("DataService")
	local EnemyService: any = Knit.GetService("EnemyService")

	local stopped = false
	local pumpkin: BasePart? = nil
	local alive = 0

	local function spawnZombie(position: Vector3, damage: number)
		if type(EnemyService.SpawnEvent) ~= "function" then
			if not warnedSpawn then
				warnedSpawn = true
				warn("[Halloween] EnemyService:SpawnEvent is missing: pumpkins release no zombies")
			end
			return
		end

		local entity = EnemyService:SpawnEvent(CONFIG.ZombieTemplate, CFrame.new(findGround(position)), {
			Damage = damage,
			Respawn = false,
		})
		if entity then
			alive += 1
			entity.Model.Destroying:Once(function()
				alive -= 1
			end)
			task.delay(CONFIG.ZombieLifetime, function()
				if not entity.Dead then
					EnemyService:Despawn(entity)
				end
			end)
		end
	end

	local function release(origin: Vector3, damage: number)
		for _ = 1, CONFIG.ZombieCount do
			task.wait(CONFIG.ZombieDelay)
			if stopped then
				return
			end
			local spread = CONFIG.ZombieSpread
			spawnZombie(origin + Vector3.new(random:NextInteger(-spread, spread), 0, random:NextInteger(-spread, spread)), damage)
		end
	end

	local function onClicked(player: Player, clicked: BasePart)
		local entity = CharacterService:GetPlayerEntity(player)
		local data = DataService:GetData(player)
		if pumpkin ~= clicked or not entity or not data or entity.Dead or not entity.Spawned then
			return
		end
		if (entity.Root.Position - clicked.Position).Magnitude > CONFIG.ClickRange then
			return
		end

		pumpkin = nil
		local origin = clicked.Position
		clicked:Destroy()
		task.spawn(release, origin, data.Data.Skills.Melee.Level * CONFIG.DamagePerMeleeLevel)
	end

	local function spawnPumpkin()
		local template = WorldAssets.Find(CONFIG.PumpkinTemplate, "BasePart")
		if not template then
			return
		end

		local clone = template:Clone() :: BasePart
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end

		local detector = clone:FindFirstChildOfClass("ClickDetector")
		if not detector then
			detector = Instance.new("ClickDetector")
			detector.Parent = clone
		end
		local clickDetector = detector :: ClickDetector
		clickDetector.MaxActivationDistance = CONFIG.ClickRange
		clickDetector.MouseClick:Connect(function(player: Player)
			onClicked(player, clone)
		end)

		clone.Anchored = true
		clone.CFrame = CONFIG.PumpkinSpawns[random:NextInteger(1, #CONFIG.PumpkinSpawns)]
		clone.Parent = World.RuntimeFolder(PUMPKIN_FOLDER) or Workspace
		pumpkin = clone
	end

	context.OnMinute(function()
		if not stopped and not pumpkin and alive + CONFIG.ZombieCount <= CONFIG.MaxAlive then
			spawnPumpkin()
		end
	end)

	return function()
		stopped = true
		if pumpkin then
			pumpkin:Destroy()
			pumpkin = nil
		end
	end
end

return Halloween
