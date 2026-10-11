--!strict
--[[
	Tools that are used rather than swung (UtilityConfig): Tea Cup, Tea Kettle, Zombie
	Head and the three grapples. Fishing rods belong to the fishing system.

	The client sends "use" and an aim point. What is held, its cooldown and what it
	reaches are resolved here.

	Tea Cup      6 s after the sip the drinker has one more tea (Economy.Tea); at 100
	             teas the Tea Kettle is theirs.
	Tea Kettle   pours for the closest player in the 4x3x3 box in front: a player who
	             has no Tea Cup is given one.
	Zombie Head  turns the closest character in that box zombie green until it respawns
	             (replicated "WeaponZombified" status; the legacy script recolored the
	             limbs on the server).
	Grapple      first use ties a rope from the tool to the surface or character under
	             the aim, at most 7 / 20 / 40 studs away (small / medium / large); the
	             rope is as long as that distance. Second use, putting the tool away or
	             dying removes it.

	The rope is the one thing created on the server: it is physics shared by two
	characters, not a visual (two Attachments and a RopeConstraint; the legacy anchor
	Part is an Attachment on Terrain).

	Legacy holes closed:
	- the grapple remote took the hit CFrame and the target Part from the client: a rope
	  could be anchored in mid-air or tied to any part of the map, and the distance
	  check used the client's point. The anchor is now found by a server ray along the
	  aim and a character is only roped when it is really there;
	- the Zombie Head remote took a target part (unused, but trusted nothing either);
	- the Tea Cup never re-armed when the character was missing (the debounce returned
	  before being reset), and its only cooldown was a script variable.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local UtilityConfig = require(ReplicatedStorage.Shared.Configs.UtilityConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity
type PlayerData = PlayerData.PlayerData

local SLOT_ATTRIBUTE = "WeaponSlot"
local ZOMBIE_STATUS = "WeaponZombified"
local TEA_CUP = "Tea Cup"
local TEA_KETTLE = "Tea Kettle"
-- A character counts as "under the aim" within this distance of the aim point.
local ROPE_TARGET_RADIUS = 1.5
local ROPE_RAY_MARGIN = 2

local UtilityService = Knit.CreateService({
	Name = "UtilityService",
	Client = {
		-- Client -> server: (aimPosition)
		Use = Knit.CreateSignal(),
	},
})

local DataService
local CharacterService

type Rope = { Instances: { Instance }, Connections: { RBXScriptConnection } }

local lastUse: { [Player]: { [string]: number } } = {}
local ropes: { [Player]: Rope } = {}
local useLimiter = RateLimiter.new(6, 3)

local function removeRope(player: Player)
	local rope = ropes[player]
	if not rope then
		return
	end
	ropes[player] = nil
	for _, connection in rope.Connections do
		connection:Disconnect()
	end
	for _, instance in rope.Instances do
		instance:Destroy()
	end
end

local function closestInFront(entity: CharacterEntity, playersOnly: boolean): CharacterEntity?
	local targets = Hitbox.InFront(entity, UtilityConfig.ReachSize, UtilityConfig.ReachDistance)
	if playersOnly then
		local players: { CharacterEntity } = {}
		for _, target in targets do
			if target.Player then
				table.insert(players, target)
			end
		end
		targets = players
	end
	return Hitbox.Closest(targets, entity.Root.Position)
end

local function drinkTea(_entity: CharacterEntity, data: PlayerData, definition: UtilityConfig.UtilityDefinition)
	task.delay(definition.Cooldown, function()
		if not data:IsActive() then
			return
		end
		local tea = data:Increment("Economy.Tea", 1)
		if tea >= UtilityConfig.TeaForKettle and data:Get(`Items.{TEA_KETTLE}`) ~= true then
			data:Set(`Items.{TEA_KETTLE}`, true)
		end
	end)
end

local function pourTea(entity: CharacterEntity)
	local target = closestInFront(entity, true)
	local targetData = if target and target.Player then DataService:GetData(target.Player) else nil
	if targetData and targetData:Get(`Items.{TEA_CUP}`) ~= true then
		targetData:Set(`Items.{TEA_CUP}`, true)
	end
end

local function zombify(entity: CharacterEntity)
	local target = closestInFront(entity, false)
	if target then
		target:SetStatus(ZOMBIE_STATUS, true, nil, true)
	end
end

local function throwRope(player: Player, entity: CharacterEntity, tool: Tool, definition: UtilityConfig.UtilityDefinition, aim: Vector3)
	if ropes[player] then
		removeRope(player)
		return
	end

	local root = entity.Root
	local maxDistance = definition.MaxDistance or 0
	local offset = aim - root.Position
	if offset.Magnitude < 1e-3 then
		return
	end

	local handle = tool:FindFirstChild("Handle")
	local holder: BasePart = if handle and handle:IsA("BasePart") then handle else root
	local instances: { Instance } = {}
	local far: Attachment

	local target = Hitbox.Closest(Hitbox.Sphere(aim, ROPE_TARGET_RADIUS, entity), aim)
	if target then
		if (target.Root.Position - root.Position).Magnitude > maxDistance then
			return
		end
		far = Instance.new("Attachment")
		far.Name = "RopeAttachment_Target"
		far.Parent = target.Root
	else
		local ignored: { Instance } = {}
		for model in CharacterService:GetEntities() do
			table.insert(ignored, model)
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignored

		-- The anchor must be a real surface along the aim, within reach of the rope.
		local reach = math.min(offset.Magnitude, maxDistance) + ROPE_RAY_MARGIN
		local result = Workspace:Raycast(root.Position, offset.Unit * reach, params)
		if not result or (result.Position - root.Position).Magnitude > maxDistance then
			return
		end
		far = Instance.new("Attachment")
		far.Name = "AnchorAttachment"
		far.Parent = Workspace.Terrain
		far.WorldPosition = result.Position
	end
	table.insert(instances, far)

	local near = Instance.new("Attachment")
	near.Name = "ArmAttachment"
	near.Parent = holder
	table.insert(instances, near)

	local rope = Instance.new("RopeConstraint")
	rope.Attachment0 = near
	rope.Attachment1 = far
	rope.Length = (far.WorldPosition - root.Position).Magnitude
	rope.Thickness = UtilityConfig.RopeThickness
	rope.Visible = true
	rope.Parent = holder
	table.insert(instances, rope)

	local connections: { RBXScriptConnection } = {}
	-- Put away, dropped or destroyed.
	table.insert(connections, tool.AncestryChanged:Connect(function()
		if tool.Parent ~= entity.Model then
			removeRope(player)
		end
	end))
	table.insert(connections, entity.Died:Connect(function()
		removeRope(player)
	end))
	-- The roped character died or left: its attachment went with it.
	table.insert(connections, far.AncestryChanged:Connect(function()
		if not far:IsDescendantOf(Workspace) then
			removeRope(player)
		end
	end))

	ropes[player] = { Instances = instances, Connections = connections }
end

local function isFiniteVector(value: Vector3): boolean
	return value.X == value.X and value.Y == value.Y and value.Z == value.Z and value.Magnitude < math.huge
end

local function onUse(player: Player, aim: unknown)
	if not useLimiter:Consume(player) then
		return
	end

	local entity = CharacterService:GetPlayerEntity(player)
	local data = DataService:GetData(player)
	if not entity or not data or entity.Dead or not entity.Spawned then
		return
	end

	local tool = entity.Model:FindFirstChildOfClass("Tool")
	local definition: UtilityConfig.UtilityDefinition? = if tool then UtilityConfig.Tools[tool.Name] else nil
	if not tool or not definition then
		return
	end
	-- Slot items are handed out by WeaponService (which checks ownership); grapples are
	-- plain items of the world and carry no slot.
	if definition.Kind ~= "Grapple" and tool:GetAttribute(SLOT_ATTRIBUTE) ~= "Utility" then
		return
	end

	local now = os.clock()
	local history = lastUse[player]
	if not history then
		history = {}
		lastUse[player] = history
	end
	if now - (history[tool.Name] or 0) < definition.Cooldown then
		return
	end

	if definition.Kind == "Grapple" then
		if typeof(aim) ~= "Vector3" or not isFiniteVector(aim :: Vector3) then
			return
		end
		if ((aim :: Vector3) - entity.Root.Position).Magnitude > AbilityConfig.HardMaxAimDistance then
			return
		end
		history[tool.Name] = now
		throwRope(player, entity, tool, definition, aim :: Vector3)
		return
	end

	history[tool.Name] = now
	if definition.Kind == "TeaCup" then
		drinkTea(entity, data, definition)
	elseif definition.Kind == "TeaKettle" then
		pourTea(entity)
	elseif definition.Kind == "ZombieHead" then
		zombify(entity)
	end
end

function UtilityService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
end

function UtilityService:KnitStart()
	UtilityService.Client.Use:Connect(onUse)

	Players.PlayerRemoving:Connect(function(player: Player)
		removeRope(player)
		lastUse[player] = nil
		useLimiter:Forget(player)
	end)
end

return UtilityService
