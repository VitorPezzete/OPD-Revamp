--!strict
--[[
	Gates of the Yamato sword: a black disc opens above the user and another at the
	destination; the user and everyone within 15 studs sink into the first and come out
	of the second two seconds later.

	Two ways to open one, both only for the user ids in YamatoConfig and only while the
	sword is in hand:
	- the sword's special attack: to the aim point (Modules.Weapons.Yamato);
	- typing a destination name in the Yamato box: Client:Travel(name). The client sends
	  a name, never a position.

	Not ported from the legacy tool, on purpose:
	- the "lgbt" and "fps" words, which sent every player around the user to another
	  Roblox place through TeleportService;
	- dragging loose Tools lying nearby through the gate;
	- travellers were flagged as not spawned (untouchable) until 3 s after arriving.
	  They are only held in place while they sink.

	Legacy problems fixed: the destination list was also read from chat by a Chatted
	connection per equip; passengers were found by walking every descendant of
	Workspace; each traveller was anchored part by part and faded by a Heartbeat
	connection on the server.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local World = require(ReplicatedStorage.Shared.Util.World)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local YamatoConfig = require(ServerStorage.Server.Configs.YamatoConfig)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity

local WEAPON = "Yamato"
local SLOT_ATTRIBUTE = "WeaponSlot"
local STATUS = "WeaponYamatoGate"
local ROOT = "WeaponYamatoGate"
local EFFECT = "WeaponYamatoGate"
-- Hitbox.Sphere already adds the body radius of a character (2.5).
local BODY_RADIUS = 2.5
local EXIT_HEIGHT = 3

local YamatoService = Knit.CreateService({
	Name = "YamatoService",
	Client = {},
})

local CharacterService
local EffectService
local NotifyService

local travelling: { [CharacterEntity]: boolean } = {}
local lastTravel: { [Player]: number } = {}
local travelLimiter = RateLimiter.new(4, 0.5)
local warnedIsland: { [string]: boolean } = {}

function YamatoService:IsAllowed(player: Player): boolean
	return YamatoConfig.AllowedUserIds[player.UserId] == true
end

--[[
	Sends `entity` and everyone around it to `destination` (the point above which the
	exit gate opens). Returns false when the character is already inside a gate.
]]
function YamatoService:OpenGate(entity: CharacterEntity, destination: Vector3): boolean
	if travelling[entity] or entity.Dead then
		return false
	end

	local start = entity.Root.Position
	local passengers = Hitbox.Sphere(start, YamatoConfig.PassengerRadius - BODY_RADIUS, entity)
	table.insert(passengers, entity)

	local entrance = start + Vector3.new(0, 5, 0)
	local seconds = YamatoConfig.TravelSeconds
	EffectService:Play(EFFECT, entrance, { Seconds = seconds })
	EffectService:Play(EFFECT, destination, { Seconds = seconds })

	local moving: { CharacterEntity } = {}
	for _, passenger in passengers do
		if not travelling[passenger] then
			travelling[passenger] = true
			passenger:SetRooted(ROOT, true)
			-- Value: height of the gate, which the client uses to hide what has gone through.
			passenger:SetStatus(STATUS, entrance.Y, seconds, true)
			table.insert(moving, passenger)
		end
	end

	task.delay(seconds, function()
		for _, passenger in moving do
			travelling[passenger] = nil
			passenger:SetRooted(ROOT, false)
			if not passenger.Dead and passenger.Model.Parent ~= nil then
				local _, yaw = passenger.Root.CFrame:ToOrientation()
				local exit = destination + Vector3.new(0, EXIT_HEIGHT, 0)
				CharacterService:Teleport(passenger, CFrame.new(exit) * CFrame.Angles(0, yaw, 0))
			end
		end
	end)
	return true
end

-- Some destinations are map pieces kept in storage until someone travels there.
local function ensureIsland(location: string): boolean
	local islandName = YamatoConfig.Islands[location]
	-- Already there: part of the static map, or cloned for an earlier traveller.
	if not islandName or World.Island(islandName) or World.RuntimeParent():FindFirstChild(islandName) then
		return true
	end

	local template = ServerStorage:FindFirstChild(islandName)
	if not template then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local models = assets and assets:FindFirstChild("Models")
		template = models and models:FindFirstChild(islandName, true)
	end
	if not template then
		if not warnedIsland[islandName] then
			warnedIsland[islandName] = true
			warn(`[YamatoService] Missing island "{islandName}" for destination "{location}"`)
		end
		return false
	end

	local island = template:Clone()
	island.Parent = World.RuntimeParent()
	Debris:AddItem(island, YamatoConfig.IslandLifetime)
	return true
end

function YamatoService.Client:Travel(player: Player, name: unknown): boolean
	if not travelLimiter:Consume(player) then
		return false
	end
	if type(name) ~= "string" or #name > YamatoConfig.MaxNameLength then
		return false
	end
	if not YamatoService:IsAllowed(player) then
		return false
	end

	local entity = CharacterService:GetPlayerEntity(player)
	if not entity or entity.Dead or not entity.Spawned then
		return false
	end
	local tool = entity.Model:FindFirstChildOfClass("Tool")
	if not tool or tool.Name ~= WEAPON or tool:GetAttribute(SLOT_ATTRIBUTE) == nil then
		return false
	end

	local location = string.lower(name)
	local destination = YamatoConfig.Locations[location]
	if not destination then
		return false
	end

	local now = os.clock()
	if now - (lastTravel[player] or 0) < YamatoConfig.Cooldown then
		return false
	end
	if not ensureIsland(location) then
		NotifyService:Send(player, "That place cannot be reached right now.", "Error")
		return false
	end

	if not YamatoService:OpenGate(entity, destination) then
		return false
	end
	lastTravel[player] = now
	return true
end

function YamatoService:KnitInit()
	CharacterService = Knit.GetService("CharacterService")
	EffectService = Knit.GetService("EffectService")
	NotifyService = Knit.GetService("NotifyService")
end

function YamatoService:KnitStart()
	CharacterService.EntityRemoving:Connect(function(entity: CharacterEntity)
		travelling[entity] = nil
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastTravel[player] = nil
		travelLimiter:Forget(player)
	end)
end

return YamatoService
