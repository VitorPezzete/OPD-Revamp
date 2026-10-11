--!strict
--[[
	The Burning Compass and its fire island.

	Flow
	1. LegendaryService hands the compass out (CompassService:Give): a Tool carrying the
	   point it leads to (CompassConfig.TargetAttribute), a random spot of the western sea.
	2. The owner follows it by day. Its client says "I am there" (Arrive, no arguments);
	   the server checks the compass is held, that it is day and that the character
	   really stands within reach of the target.
	3. The compass is consumed, a private copy of the island is placed at a free location
	   far from the map, the fire boss is spawned on it and the owner is moved there.
	4. When the boss dies, whoever or whatever killed it, the way out opens: the island's
	   boat appears, the Divine Axe prompt is enabled for the owner and the leave part sends
	   the owner back to the map. Dying or leaving the game also removes the island.

	The Divine Axe pickup (DivineAxeService) and the boat driving belong to other
	systems: this service only reveals them and offers the axe to the island's owner.

	Legacy problems fixed here:
	- The compass tool polled its holder every 0.1 s on the server and, on arrival, was
	  destroyed even when no island location was free: the compass was simply lost.
	- A location was only freed when the owner died, never when the fight was won or the
	  owner left the game: after twelve trips the compass stopped doing anything.
	- Two pairs of the twelve locations were identical, so islands could overlap.
	- The leave part kept its Touched connection after use, and every boss kill added one.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local BoatConfig = require(ReplicatedStorage.Shared.Configs.BoatConfig)

local CompassConfig = require(ReplicatedStorage.Shared.Configs.CompassConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local World = require(ReplicatedStorage.Shared.Util.World)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

type CharacterEntity = CharacterEntity.CharacterEntity

type Compass = { Tool: Tool, Target: Vector3 }

type Session = {
	Player: Player,
	Slot: number,
	Island: Model,
	Boss: CharacterEntity?,
	Cleared: boolean,
	Closing: boolean,
	Connections: { RBXScriptConnection },
}

-- Slack on the arrival distance for replication lag of a moving boat.
local ARRIVAL_TOLERANCE = 10
local ISLAND_TEMPLATE = "IslandFire"

local CompassService = Knit.CreateService({
	Name = "CompassService",
	Client = {
		-- Client -> server, no arguments: "my compass says I have arrived".
		Arrive = Knit.CreateSignal(),
	},
})

local CharacterService
local DivineAxeService
local EnemyService
local NotifyService

local compasses: { [Player]: Compass } = {}
local sessions: { [Player]: Session } = {}
local usedSlots: { [number]: Player } = {}
local arriveLimiter = RateLimiter.new(2, 0.5)
local random = Random.new()
local warned: { [string]: boolean } = {}

local function warnOnce(message: string)
	if not warned[message] then
		warned[message] = true
		warn(`[CompassService] {message}`)
	end
end

-- The assets were moved out of the legacy scripts; their folder is not known for sure.
local function findAsset(name: string, className: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	if not models then
		return nil
	end
	for _, folderName in { "World", "Items", "Events", "Bosses" } do
		local folder = models:FindFirstChild(folderName)
		local found = folder and folder:FindFirstChild(name, true)
		if found and found:IsA(className) then
			return found
		end
	end
	local found = models:FindFirstChild(name, true)
	return if found and found:IsA(className) then found else nil
end

local function isDay(): boolean
	local clock = Lighting.ClockTime
	return clock > CompassConfig.DayStart and clock < CompassConfig.DayEnd
end

local function rollTarget(): Vector3
	return Vector3.new(
		-random:NextInteger(CompassConfig.TargetMinX, CompassConfig.TargetMaxX),
		CompassConfig.TargetY,
		-random:NextInteger(CompassConfig.TargetMinZ, CompassConfig.TargetMaxZ)
	)
end

local function closeSession(player: Player)
	local session = sessions[player]
	if not session then
		return
	end

	sessions[player] = nil
	if usedSlots[session.Slot] == player then
		usedSlots[session.Slot] = nil
	end
	for _, connection in session.Connections do
		connection:Disconnect()
	end
	local boss = session.Boss
	if boss and not boss.Dead then
		EnemyService:Despawn(boss)
	end
	session.Island:Destroy()
end

local function closeLater(session: Session)
	if session.Closing then
		return
	end
	session.Closing = true
	task.delay(CompassConfig.TeardownDelay, function()
		if sessions[session.Player] == session then
			closeSession(session.Player)
		end
	end)
end

local function openExit(session: Session)
	if session.Cleared then
		return
	end
	session.Cleared = true

	local island = session.Island
	local player = session.Player

	local boat = island:FindFirstChild("Boat4")
	if boat then
		for _, part in boat:GetChildren() do
			if part:IsA("BasePart") then
				part.Transparency = 0
			end
		end
	end

	local axe = island:FindFirstChild("Divine Axe")
	if axe then
		axe:SetAttribute("PlayerId", player.UserId)
		local owner = axe:FindFirstChild("PlayerId")
		if owner and owner:IsA("IntValue") then
			owner.Value = player.UserId
		elseif owner and owner:IsA("NumberValue") then
			owner.Value = player.UserId
		end
		DivineAxeService:Offer(player, axe)
		local prompt = axe:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Enabled = true
		end
	end

	local leave = island:FindFirstChild("LeavePart")
	if leave and leave:IsA("BasePart") then
		leave.Transparency = 0.6
		local connection: RBXScriptConnection
		connection = leave.Touched:Connect(function(hit: BasePart)
			local entity = CharacterService:GetPlayerEntity(player)
			if not entity or entity.Dead or not hit:IsDescendantOf(entity.Model) or session.Closing then
				return
			end
			connection:Disconnect()

			CharacterService:Teleport(
				entity,
				WorldConfig.GetSpawnCFrame(CompassConfig.ExitSpawn, CompassConfig.ExitHeight)
			)
			closeLater(session)
		end)
		table.insert(session.Connections, connection)
	else
		warnOnce("the island has no LeavePart: its owner can only leave by boat")
	end

	NotifyService:Send(player, "You can now return using your boat.", "Announcement", 4)
end

local function openIsland(player: Player, entity: CharacterEntity): boolean
	local template = findAsset(ISLAND_TEMPLATE, "Model")
	if not template then
		warnOnce(`island template "{ISLAND_TEMPLATE}" not found under ReplicatedStorage.Assets.Models`)
		return false
	end

	local slot: number? = nil
	for index in CompassConfig.IslandLocations do
		if not usedSlots[index] then
			slot = index
			break
		end
	end
	if not slot then
		return false
	end

	-- A previous island of the same player (left by boat without winning) goes first.
	closeSession(player)
	usedSlots[slot] = player

	local location = CompassConfig.IslandLocations[slot]
	local island = template:Clone() :: Model
	island.Name = "FireIsland"
	island:PivotTo(CFrame.new(location.X, CompassConfig.IslandY, location.Z))
	island.Parent = World.RuntimeParent()

	local session: Session = {
		Player = player,
		Slot = slot,
		Island = island,
		Boss = nil,
		Cleared = false,
		Closing = false,
		Connections = {},
	}
	sessions[player] = session

	local bossSpawn = island:FindFirstChild("BossSpawn")
	local bossCFrame = if bossSpawn and bossSpawn:IsA("BasePart")
		then bossSpawn.CFrame * CompassConfig.BossSpawnOffset
		else CFrame.new(location.X, CompassConfig.IslandY + 30, location.Z)
	if not bossSpawn then
		warnOnce("the island has no BossSpawn part: the boss is spawned above its pivot")
	end
	local boss = EnemyService:SpawnEvent(CompassConfig.BossName, bossCFrame, { Respawn = false })
	session.Boss = boss
	if boss then
		-- Not BossService.BossKilled: that needs a player's killing blow, and a boss lost
		-- to anything else would leave its challenger stranded.
		boss.Died:Once(function()
			if sessions[player] == session then
				openExit(session)
			end
		end)
	else
		warnOnce(`boss "{CompassConfig.BossName}" could not be spawned: the island opens its exit at once`)
		task.defer(openExit, session)
	end

	-- The boat the player came with would be dragged along by the seat weld.
	local humanoid = entity.Humanoid
	if humanoid.SeatPart then
		humanoid.Sit = false
	end
	local boats = World.RuntimeFolder(BoatConfig.FolderName)
	local boat = boats and boats:FindFirstChild(player.Name .. "#")
	if boat then
		boat:Destroy()
	end

	entity.Root.AssemblyLinearVelocity = Vector3.zero
	entity.Root.AssemblyAngularVelocity = Vector3.zero
	CharacterService:Teleport(entity, CFrame.new(location))
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(location)
		end)
	end)

	table.insert(session.Connections, entity.Died:Once(function()
		closeLater(session)
	end) :: any)
	return true
end

local function onArrive(player: Player)
	if not arriveLimiter:Consume(player) then
		return
	end

	local compass = compasses[player]
	local entity = CharacterService:GetPlayerEntity(player)
	if not compass or not entity or entity.Dead or not entity.Spawned then
		return
	end
	-- Held, by day, and really there.
	if compass.Tool.Parent ~= entity.Model or not isDay() then
		return
	end
	if (entity.Root.Position - compass.Target).Magnitude > CompassConfig.ArrivalRadius + ARRIVAL_TOLERANCE then
		return
	end

	if not openIsland(player, entity) then
		NotifyService:Send(player, "The compass trembles, but the way is closed for now. Try again later.", "Error")
		return
	end
	compasses[player] = nil
	compass.Tool:Destroy()
end

function CompassService:HasCompass(player: Player): boolean
	local compass = compasses[player]
	return compass ~= nil and compass.Tool.Parent ~= nil
end

-- Puts a Burning Compass in the player's backpack. False when it could not be given.
function CompassService:Give(player: Player): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or CompassService:HasCompass(player) then
		return false
	end

	local template = findAsset(CompassConfig.ToolName, "Tool")
	local tool: Tool
	if template then
		tool = template:Clone() :: Tool
		for _, descendant in tool:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
	else
		-- Still playable: a bare tool the client can hold while it tracks the target.
		warnOnce(`tool template "{CompassConfig.ToolName}" not found under ReplicatedStorage.Assets.Models`)
		tool = Instance.new("Tool")
		tool.Name = CompassConfig.ToolName
		tool.RequiresHandle = false
	end

	local compass: Compass = { Tool = tool, Target = rollTarget() }
	tool:SetAttribute(CompassConfig.TargetAttribute, compass.Target)
	tool.CanBeDropped = false
	compasses[player] = compass
	-- The backpack is emptied on death: the compass goes with it, as in the legacy game.
	tool.Destroying:Once(function()
		if compasses[player] == compass then
			compasses[player] = nil
		end
	end)
	tool.Parent = backpack
	return true
end

-- True while the player has an island of their own (fight in progress or just won).
function CompassService:IsOnIsland(player: Player): boolean
	return sessions[player] ~= nil
end

function CompassService:KnitInit()
	CharacterService = Knit.GetService("CharacterService")
	DivineAxeService = Knit.GetService("DivineAxeService")
	EnemyService = Knit.GetService("EnemyService")
	NotifyService = Knit.GetService("NotifyService")
end

function CompassService:KnitStart()
	CompassService.Client.Arrive:Connect(onArrive)

	Players.PlayerRemoving:Connect(function(player: Player)
		arriveLimiter:Forget(player)
		compasses[player] = nil
		closeSession(player)
	end)
end

return CompassService
