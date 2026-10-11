--!strict
--[[
	Boats: bought from a boat merchant (through ShopService), spawned at that merchant's
	Spawner, one per player, removed when the player leaves or buys another.

	As in the legacy game a boat is not kept: every purchase pays for a fresh one, and
	anyone may sit in it. Driving runs on the driver's client (see Classes/Boat and
	Client.Controllers.BoatController) instead of the legacy server script that every boat
	ran once per frame; the only loop here audits the speed of the boats being driven.

	Legacy bug fixed: the old boat was destroyed before the price check, so a purchase the
	player could not afford still deleted the boat they had.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local BoatConfig = require(ReplicatedStorage.Shared.Configs.BoatConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Configs.ShopConfig)
local World = require(ReplicatedStorage.Shared.Util.World)
local Boat = require(ServerStorage.Server.Classes.Boat)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)

type Boat = Boat.Boat
type PlayerData = PlayerData.PlayerData

local AUDIT_INTERVAL = 0.5

local BoatService = Knit.CreateService({
	Name = "BoatService",
	Client = {},
})

local NotifyService

local boats: { [Player]: Boat } = {}
local warnedMissing: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if not warnedMissing[key] then
		warnedMissing[key] = true
		warn(`[BoatService] {message}`)
	end
end

-- Workspace.Instances.Boats, created on first use.
local function getFolder(): Instance
	return World.RuntimeFolder(BoatConfig.FolderName) :: Instance
end

-- The templates were never moved in the dump this was written from: look in the new
-- asset tree first, then where the legacy place kept them.
local function findTemplate(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local world = models and models:FindFirstChild("World")
	local backups = ServerStorage:FindFirstChild("Backups")
	local candidates: { Instance? } = {
		models and models:FindFirstChild("Boats"),
		models and models:FindFirstChild("Items") and models.Items:FindFirstChild("Boats"),
		world and world:FindFirstChild("Boats"),
		backups and backups:FindFirstChild("Boats"),
	}
	for index = 1, 4 do
		local folder = candidates[index]
		local template = folder and folder:FindFirstChild(name)
		if template and template:IsA("Model") then
			return template
		end
	end

	warnOnce(name, `Missing boat template "{name}" (Assets.Models.Boats / Assets.Models.World.Boats)`)
	return nil
end

local function findSpawner(merchant: Model): BasePart?
	local spawner = merchant:FindFirstChild(BoatConfig.SpawnerName, true)
	if spawner and spawner:IsA("BasePart") then
		return spawner
	end
	warnOnce(merchant.Name, `{merchant.Name} has no "{BoatConfig.SpawnerName}" part`)
	return nil
end

function BoatService:GetBoat(player: Player): Boat?
	return boats[player]
end

function BoatService:Despawn(player: Player)
	local boat = boats[player]
	if boat then
		boats[player] = nil
		boat:Destroy()
	end
end

function BoatService:CanSpawn(boatName: string, merchant: Model): boolean
	local definition = BoatConfig.Boats[boatName]
	return definition ~= nil
		and BoatConfig.Merchants[merchant.Name] ~= nil
		and findTemplate(definition.Template) ~= nil
		and findSpawner(merchant) ~= nil
end

-- Replaces the player's boat with a new one at the merchant's dock.
function BoatService:Spawn(player: Player, boatName: string, merchant: Model): boolean
	local definition = BoatConfig.Boats[boatName]
	local dock = BoatConfig.Merchants[merchant.Name]
	local template = definition and findTemplate(definition.Template)
	local spawner = findSpawner(merchant)
	if not definition or not dock or not template or not spawner then
		return false
	end

	local model = template:Clone()
	local seat = model:FindFirstChild(BoatConfig.SeatName)
	if not seat or not seat:IsA("BasePart") then
		warnOnce(definition.Template .. "/seat", `{definition.Template} has no "{BoatConfig.SeatName}" seat`)
		model:Destroy()
		return false
	end

	BoatService:Despawn(player)

	local offset = (dock.Offsets and dock.Offsets[boatName]) or definition.Offset
	local origin = if dock.WorldAligned then CFrame.new(spawner.Position) else spawner.CFrame
	model.Name = player.Name .. "#"
	model:SetAttribute(BoatConfig.OwnerAttribute, player.UserId)
	model:PivotTo(origin * CFrame.new(offset))
	model.Parent = getFolder()

	local boat = Boat.new(player, model, seat)
	boat:Halt()
	boat:Face(dock.Yaw)
	boats[player] = boat
	return true
end

local function audit()
	local now = os.clock()
	for owner, boat in boats do
		-- Destroyed by something else (fell in the void, an ability, an admin).
		if not boat.Model:IsDescendantOf(Workspace) then
			boats[owner] = nil
			boat:Destroy()
			continue
		end

		local driver = boat.Driver
		if boat:Audit(now) and driver then
			NotifyService:Send(driver, "The boat went out of control", "Error")
		end
	end
end

function BoatService:KnitInit()
	NotifyService = Knit.GetService("NotifyService")

	Knit.GetService("ShopService"):RegisterGrant("Boat", {
		Check = function(_player: Player, _data: PlayerData, item: ShopConfig.Item, merchant: Model): (boolean, string?)
			if not BoatService:CanSpawn(item.Name, merchant) then
				return false, "This boat is unavailable"
			end
			return true, nil
		end,
		Give = function(player: Player, _data: PlayerData, item: ShopConfig.Item, merchant: Model): boolean
			return BoatService:Spawn(player, item.Name, merchant)
		end,
	})
end

function BoatService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		BoatService:Despawn(player)
	end)

	task.spawn(function()
		while true do
			task.wait(AUDIT_INTERVAL)
			audit()
		end
	end)
end

return BoatService
