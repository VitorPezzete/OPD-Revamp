--!strict
--[[
	The altar: the structure needed to perform the ritual and become Legendary. A devil
	fruit is offered on it before entering Legendary Mode.

	The model is not part of the map any more: it is stored in
	ReplicatedStorage.Assets.Models.World.Altar and this service owns its copy in the
	world. The legacy game had the altar standing in the Workspace at all times, usable
	by anyone, so it is built once when the server starts (Workspace.Instances.Altar, at the
	pivot the stored model carries) and stays. Everybody else reaches it through
	AltarService:GetModel / :GetReceptacle / :GetOffering, never by path.

	This service only owns the altar and the offering itself; the rebirth (requirements,
	what is reset, consuming the fruit) is StatResetService, which takes the Tool from
	GetOffering exactly where this service put it.

	Interaction is by walking up, as in the legacy game (no prompt, nothing the client
	sends):
	- empty altar: a fruit held within PlaceRange of the receptacle is laid on it;
	- occupied: the fruit goes back into the backpack of whoever laid it once they are
	  LeaveRange away, or when they leave the game.
	Laying a fruit with enough total level fires Client.Offer, which shows the Legendary
	prompt to that player.

	Legacy problems fixed
	- AltarMain looped over every player on every Heartbeat measuring distances, and
	  re-anchored the fruit each frame. Players are looked at every ScanSeconds and the
	  fruit is anchored once.
	- The fruit on the altar could be touched by anyone, who then walked off with it (and
	  a touch by its owner laid it straight back, so it could not be taken back at all).
	  It cannot be touched now and only ever returns to its owner.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local World = require(ReplicatedStorage.Shared.Util.World)

local WorldObjectConfig = require(ServerStorage.Server.Configs.WorldObjectConfig)
local WorldAssets = require(ServerStorage.Server.Modules.WorldAssets)

local CONFIG = WorldObjectConfig.Altar

local AltarService = Knit.CreateService({
	Name = "AltarService",
	Client = {
		-- () to the player who placed a fruit and may enter Legendary Mode.
		Offer = Knit.CreateSignal(),
	},
})

local DataService
local CharacterService
local FruitService

local model: Model? = nil
local receptacle: BasePart
local pedestal: BasePart
local offering: Tool? = nil
local owner: Player? = nil

-- Collision of the offered fruit's parts before it was placed, to give it back unchanged.
local savedCollision: { [BasePart]: boolean } = {}

local function setPhysics(tool: Tool, placed: boolean)
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			if placed then
				savedCollision[part] = part.CanCollide
				part.CanCollide = false
			else
				part.CanCollide = savedCollision[part] == true
			end
			part.Anchored = placed
			-- An anchored Handle in the world would still be picked up by touching it.
			part.CanTouch = not placed
		end
	end
	if not placed then
		table.clear(savedCollision)
	end
end

local function clearOffering()
	offering = nil
	owner = nil
end

local function release()
	table.clear(savedCollision)
	clearOffering()
end

local function place(player: Player, tool: Tool)
	tool.Parent = receptacle
	setPhysics(tool, true)
	tool:PivotTo(pedestal.CFrame * CONFIG.FruitOffset)
	offering = tool
	owner = player

	-- Consumed by the rebirth, or destroyed by anything else: the altar is free again.
	tool.AncestryChanged:Connect(function()
		if offering == tool and tool.Parent ~= receptacle then
			release()
		end
	end)

	local data = DataService:GetData(player)
	if data and not data.Data.Combat.LegendaryMode then
		local total = 0
		for _, skill in CONFIG.OfferSkills do
			total += data.Data.Skills[skill].Level
		end
		if total >= CONFIG.OfferTotalLevel then
			AltarService.Client.Offer:Fire(player)
		end
	end
end

-- The fruit goes back to the player who laid it. False while they have no backpack.
local function giveBack(player: Player): boolean
	local tool = offering
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not tool or not backpack then
		return false
	end
	clearOffering()
	setPhysics(tool, false)
	tool.Parent = backpack
	return true
end

-- Distance from the receptacle of a living character, nil for anyone else.
local function distanceOf(player: Player): number?
	local entity = CharacterService:GetPlayerEntity(player)
	if not entity or entity.Dead then
		return nil
	end
	return (entity.Root.Position - receptacle.Position).Magnitude
end

local function scan()
	if offering then
		-- Dead or between characters: the fruit waits, a backpack about to be thrown away
		-- is no place for it.
		local player = owner
		local distance = player and distanceOf(player)
		if player and distance and distance >= CONFIG.LeaveRange then
			giveBack(player)
		end
		return
	end

	for _, player in Players:GetPlayers() do
		local distance = distanceOf(player)
		if distance and distance < CONFIG.PlaceRange then
			local entity = CharacterService:GetPlayerEntity(player)
			local tool = entity and entity.Model:FindFirstChildOfClass("Tool")
			if tool and FruitService:GetItem(tool) then
				place(player, tool)
				return
			end
		end
	end
end

-- The fruit tool lying on the altar, if any.
function AltarService:GetOffering(): Tool?
	return offering
end

function AltarService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	FruitService = Knit.GetService("FruitService")
end

-- The altar standing in the world (Workspace.Instances.Altar), nil when it could not be built.
function AltarService:GetModel(): Model?
	return model
end

-- The part an offered fruit is parented to; what "near the altar" is measured from.
function AltarService:GetReceptacle(): BasePart?
	return if model then receptacle else nil
end

--[[
	Clones the stored altar into the world. The template keeps its world pivot
	(2054, 489.5, -606), so the clone needs no placing: it appears where it always stood.
]]
local function build(): Model?
	local template = WorldAssets.Find(CONFIG.Model, "Model")
	if not template then
		return nil
	end

	local altar = template:Clone() :: Model
	for _, descendant in altar:GetDescendants() do
		-- The legacy AltarMain script, should a copy of the model still carry it.
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	altar.Name = CONFIG.Model
	altar:PivotTo(template:GetPivot())
	altar.Parent = World.RuntimeParent()
	return altar
end

function AltarService:KnitStart()
	local altar = build()
	local foundReceptacle = altar and altar:FindFirstChild(CONFIG.Receptacle)
	local foundPedestal = altar and altar:FindFirstChild(CONFIG.Pedestal)
	if
		not altar
		or not foundReceptacle
		or not foundReceptacle:IsA("BasePart")
		or not foundPedestal
		or not foundPedestal:IsA("BasePart")
	then
		warn(`[AltarService] Assets.Models.World.{CONFIG.Model} with {CONFIG.Receptacle} and {CONFIG.Pedestal} not found: no altar, Legendary Mode is unavailable`)
		if altar then
			altar:Destroy()
		end
		return
	end
	model = altar
	receptacle = foundReceptacle
	pedestal = foundPedestal

	-- A prompt an older copy of the stored model may still carry.
	for _, descendant in altar:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= CONFIG.ScanSeconds then
			elapsed = 0
			scan()
		end
	end)

	-- Leaving with a fruit on the altar: it leaves with its owner, or it is gone (nobody
	-- else may have it).
	Players.PlayerRemoving:Connect(function(player: Player)
		if owner == player and not giveBack(player) then
			local tool = offering
			clearOffering()
			if tool then
				tool:Destroy()
			end
		end
	end)
end

return AltarService
