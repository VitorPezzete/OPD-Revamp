--!strict
--[[
	Fruits lying in the world: how they get there and how they are picked up.

	The legacy game never spawned fruits on a timer. A fruit reaches the ground when its
	holder drops it (FruitService), when its holder dies, or when a server system places
	one with SpawnFruit. This service owns the ground side of that:

	- Pickup. Any fruit Tool that lands on the ground (Workspace.Instances.Drops, or the
	  Workspace itself when the engine dropped it) gets one ClickDetector
	  (on the Tool, so it covers every part). A click from a living character within
	  range moves the Tool to that backpack. The legacy script scanned Workspace twice a
	  second to add a detector to every part of every fruit.
	- Death. A character that dies scatters every fruit it carried (held or in the
	  backpack) around the body. The legacy script only dropped tools that had a Handle
	  and silently destroyed the rest.
	- Dropping other tools (compasses, boxes, drinks) from the drop button: always the
	  held tool. The legacy remote took the tool name as an argument.

	Fruits on the ground never despawn, as before.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local World = require(ReplicatedStorage.Shared.Util.World)
local Proximity = require(ServerStorage.Server.Modules.Proximity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

local PICKUP = FruitEconomyConfig.Pickup
local DROP = FruitEconomyConfig.Drop
-- Where a dropped tool appears in front of the character, and how it is tossed.
local TOOL_DROP_OFFSET = CFrame.new(0, 1.5, -3)
local TOOL_DROP_SPEED = 8
local TOOL_DROP_LIFT = 4

local FruitSpawnService = Knit.CreateService({
	Name = "FruitSpawnService",
	Client = {
		-- Drops the held tool, if it is one the drop button accepts. No arguments.
		DropTool = Knit.CreateSignal(),
	},
})

local CharacterService
local FruitService
local FruitLogService
local NotifyService

local pickupLimiter = RateLimiter.new(3, 2)
local dropLimiter = RateLimiter.new(1, 1 / DROP.CooldownSeconds)
local detectors: { [Tool]: ClickDetector } = {}
local random = Random.new()

local function releaseParts(tool: Tool)
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			part:SetNetworkOwner(nil)
		end
	end
end

local function pickUp(player: Player, tool: Tool)
	local entity = CharacterService:GetPlayerEntity(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not entity or entity.Dead or not backpack or not pickupLimiter:Consume(player) then
		return
	end
	-- The first valid click wins: the Tool has left the ground for everyone after it.
	if not World.IsOnGround(tool) or not FruitService:GetItem(tool) then
		return
	end
	if not Proximity.IsNear(player, tool, PICKUP.Range) then
		return
	end

	tool.Parent = backpack
	FruitLogService:RecordTool(player, "PickedUp", tool)
end

local function watch(child: Instance)
	if not child:IsA("Tool") or detectors[child] or not FruitService:GetItem(child) then
		return
	end

	local tool = child
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = PICKUP.Range
	detector.MouseClick:Connect(function(player: Player)
		pickUp(player, tool)
	end)
	detector.Parent = tool
	detectors[tool] = detector
end

local function unwatch(child: Instance)
	local detector = detectors[child :: Tool]
	if detector then
		detectors[child :: Tool] = nil
		detector:Destroy()
	end
end

-- Puts a fruit Tool on the ground at a position.
function FruitSpawnService:Place(tool: Tool, cframe: CFrame)
	tool.Parent = World.Drops()
	tool:PivotTo(cframe)
	releaseParts(tool)
end

--[[
	Creates a fruit on the ground for server systems (events, admin tools). Nothing in
	the legacy game called for this; `announcement` is sent to everyone when given.
]]
function FruitSpawnService:SpawnFruit(fruitName: string, cframe: CFrame, announcement: string?): Tool?
	local tool = FruitService:CreateItem(fruitName)
	if not tool then
		return nil
	end

	FruitSpawnService:Place(tool, cframe)
	FruitLogService:Record(nil, "WorldSpawn", fruitName, nil, false)
	if announcement then
		NotifyService:Broadcast(announcement, "Announcement")
	end
	return tool
end

local function dropFruitsOf(entity: any)
	local player: Player = entity.Player
	local origin = entity.Root.Position
	local carried = entity.Model:GetChildren()
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local stowed = backpack:GetChildren()
		table.move(stowed, 1, #stowed, #carried + 1, carried)
	end

	for _, child in carried do
		if child:IsA("Tool") and FruitService:GetItem(child) then
			local offset = Vector3.new(
				random:NextInteger(-PICKUP.DeathScatter, PICKUP.DeathScatter),
				PICKUP.DeathHeight,
				random:NextInteger(-PICKUP.DeathScatter, PICKUP.DeathScatter)
			)
			FruitLogService:RecordTool(player, "DiedWith", child)
			FruitSpawnService:Place(child, CFrame.new(origin + offset))
		end
	end
end

local function bindEntity(entity: any)
	if entity.Player then
		-- The signal belongs to the entity and goes away with it.
		entity.Died:Connect(function()
			dropFruitsOf(entity)
		end)
	end
end

local function dropHeldTool(player: Player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not entity or entity.Dead or not dropLimiter:Consume(player) then
		return
	end

	local tool = entity.Model:FindFirstChildOfClass("Tool")
	-- Fruits have their own drop request, with its own log entry.
	if not tool or FruitService:GetItem(tool) or not FruitEconomyConfig.IsDroppable(tool.Name) then
		return
	end

	local root: BasePart = entity.Root
	tool.Parent = World.Drops()
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.CFrame = root.CFrame * TOOL_DROP_OFFSET
		handle.AssemblyLinearVelocity = root.CFrame.LookVector * TOOL_DROP_SPEED + Vector3.new(0, TOOL_DROP_LIFT, 0)
	else
		tool:PivotTo(root.CFrame * TOOL_DROP_OFFSET)
	end
end

function FruitSpawnService:KnitInit()
	CharacterService = Knit.GetService("CharacterService")
	FruitService = Knit.GetService("FruitService")
	FruitLogService = Knit.GetService("FruitLogService")
	NotifyService = Knit.GetService("NotifyService")
end

function FruitSpawnService:KnitStart()
	-- Workspace.Instances.Drops is where this game puts Tools; the Workspace itself is where
	-- the engine puts a Tool it drops on its own.
	for _, ground in { World.Drops(), Workspace } :: { Instance } do
		ground.ChildAdded:Connect(watch)
		ground.ChildRemoved:Connect(function(child: Instance)
			-- Moving between the two grounds is not a pickup.
			if not World.IsOnGround(child) then
				unwatch(child)
			end
		end)
		for _, child in ground:GetChildren() do
			watch(child)
		end
	end

	CharacterService.EntityAdded:Connect(bindEntity)
	for _, entity in CharacterService:GetEntities() do
		bindEntity(entity)
	end

	FruitSpawnService.Client.DropTool:Connect(dropHeldTool)

	Players.PlayerRemoving:Connect(function(player: Player)
		pickupLimiter:Forget(player)
		dropLimiter:Forget(player)
	end)
end

return FruitSpawnService
