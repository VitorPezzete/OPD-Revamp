--!strict
--[[
	Which devil fruits a player has. Server-only API: fruits are granted by gameplay
	systems (eating an item, shops, admin), never by a remote taking a fruit name.

	Fruit items are Tools cloned from Assets.Models.FruitItems. What an item really is
	(fruit, affinity scores, aura) is kept in a server-side table keyed by the Tool, so
	nothing a client can edit on the instance changes what eating it gives. The three
	client actions (eat, drop, give) always act on the fruit the character is holding.

	Rules kept from the legacy game:
	- First fruit goes to slot 1.
	- A second fruit needs Legendary Mode; without it, or with both slots full,
	  eating another fruit kills the character and the fruit is lost.
	- The item's four affinity scores (0-10) become 1.0-2.0 multipliers.
	- An item that rolled an aura saves the fruit's default colors.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

export type AffinityScores = { Defense: number, Melee: number, Sniper: number, Sword: number }
export type EatResult = "Slot1" | "Slot2" | "Rejected" | "Invalid"

export type FruitItem = { FruitName: string, Scores: AffinityScores, HasAura: boolean }

local SKILLS = { "Defense", "Melee", "Sniper", "Sword" }
local GIVE_RANGE = 10
local DROP_DISTANCE = 4
local MAX_SCORE = 10
-- Part of a fruit item the aura particle sits on.
local AURA_PART = "Main1"
-- A fruit is eaten, dropped or handed over in the world, not during a raid: the remotes
-- do not exist there (and nor does the prompt, UI.Screens.GiverGUI).
local HAS_ITEM_ACTIONS = PlaceConfig.Role ~= "Raid"

local FruitService = Knit.CreateService({
	Name = "FruitService",
	Client = if HAS_ITEM_ACTIONS
		then {
			-- All three act on the fruit tool the caller's character is holding.
			Eat = Knit.CreateSignal(),
			Drop = Knit.CreateSignal(),
			-- (targetPlayer)
			Give = Knit.CreateSignal(),
		}
		else {},
})

-- (player, item, action) for moderation logs: "Eaten" | "Dropped" | "Given".
FruitService.ItemUsed = Signal.new() :: Signal.Signal<Player, FruitItem, string>

-- (player, fruitSlot, fruitName) after a fruit is gained or removed ("None").
FruitService.FruitChanged = Signal.new() :: Signal.Signal<Player, number, string>

-- (player, fruitSlot, fruitName) after a fruit was eaten into a slot. Unlike FruitChanged it
-- stays silent for a bound fruit coming back, a slot swap or a fruit shifting to slot 1.
FruitService.FruitEaten = Signal.new() :: Signal.Signal<Player, number, string>

local DataService
local CharacterService

local templates: { [string]: Tool } = {}
-- Assets.Models.Items.AuraHolder.AuraAttachment (legacy ServerStorage.Backups.AuraHolder):
-- the particle a fruit item with an aura carries.
local auraTemplate: Attachment? = nil
local items: { [Tool]: FruitItem } = {}
local actionLimiter = RateLimiter.new(3, 1)
local random = Random.new()

local function getHeldItem(player: Player): (Tool?, FruitItem?)
	local entity = CharacterService:GetPlayerEntity(player)
	if not entity or entity.Dead or not actionLimiter:Consume(player) then
		return nil, nil
	end

	local tool = entity.Model:FindFirstChildOfClass("Tool")
	local item = tool and items[tool]
	if tool and item then
		return tool, item
	end
	return nil, nil
end

local function describe(scores: AffinityScores): string
	return string.format(
		"Defense: %g | Melee: %g | Sniper: %g | Sword: %g",
		FruitConfig.ScoreToMultiplier(scores.Defense),
		FruitConfig.ScoreToMultiplier(scores.Melee),
		FruitConfig.ScoreToMultiplier(scores.Sniper),
		FruitConfig.ScoreToMultiplier(scores.Sword)
	)
end

-- Random affinity scores for a freshly spawned item.
function FruitService:RollScores(maximum: number?): AffinityScores
	local cap = math.clamp(maximum or MAX_SCORE, 0, MAX_SCORE)
	return {
		Defense = random:NextInteger(0, cap),
		Melee = random:NextInteger(0, cap),
		Sniper = random:NextInteger(0, cap),
		Sword = random:NextInteger(0, cap),
	}
end

--[[
	What tells an aura fruit from a plain one in the hand or on the ground: the legacy
	particle, in the fruit's first default color, on the main mesh of the item. It is part
	of the item (like its meshes), so it is made here and replicates with the Tool.
]]
local function addAura(tool: Tool, fruitName: string)
	local template = auraTemplate
	local anchor = tool:FindFirstChild(AURA_PART) or tool:FindFirstChild("Handle")
	if not template or not anchor or not anchor:IsA("BasePart") then
		return
	end
	local aura = template:Clone()
	local color = FruitConfig.Fruits[fruitName].DefaultColors[1]
	for _, emitter in aura:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			emitter.Color = ColorSequence.new(color)
		end
	end
	aura.Parent = anchor
end

-- Builds a fruit Tool. Parent it to a Backpack or to the world; nil if the fruit has no model.
function FruitService:CreateItem(fruitName: string, scores: AffinityScores?, hasAura: boolean?): Tool?
	local template = templates[fruitName]
	if not template or not FruitConfig.Fruits[fruitName] then
		return nil
	end

	local item: FruitItem = {
		FruitName = fruitName,
		Scores = scores or FruitService:RollScores(),
		HasAura = hasAura == true,
	}
	local tool = template:Clone()
	tool.ToolTip = describe(item.Scores)
	if item.HasAura then
		addAura(tool, fruitName)
	end
	tool:SetAttribute("FruitItem", fruitName)
	items[tool] = item
	tool.Destroying:Once(function()
		items[tool] = nil
	end)
	return tool
end

function FruitService:GetItem(tool: Tool): FruitItem?
	return items[tool]
end

function FruitService:HasFruit(player: Player, fruitName: string): boolean
	local data = DataService:GetData(player)
	if not data then
		return false
	end
	local fruits = data.Data.DevilFruits
	return fruits.Slot1.Name == fruitName or fruits.Slot2.Name == fruitName
end

-- Applies the eating rules. "Rejected" means the character was killed for overeating.
function FruitService:EatFruit(player: Player, fruitName: string, scores: AffinityScores, hasAura: boolean): EatResult
	local data = DataService:GetData(player)
	if not data or not FruitConfig.Fruits[fruitName] then
		return "Invalid"
	end

	local fruits = data.Data.DevilFruits
	local slot: number
	if fruits.Slot1.Name == FruitConfig.EmptyName then
		slot = 1
	elseif fruits.Slot2.Name == FruitConfig.EmptyName and data.Data.Combat.LegendaryMode then
		slot = 2
	else
		local entity = CharacterService:GetPlayerEntity(player)
		if entity then
			entity:Kill()
		end
		return "Rejected"
	end

	local affinities = {}
	for _, skill in SKILLS do
		affinities[skill] = FruitConfig.ScoreToMultiplier((scores :: any)[skill])
	end

	data:Set(`Affinities.DF{slot}`, affinities)
	data:Set(`DevilFruits.Slot{slot}`, {
		Name = fruitName,
		Color = if hasAura then FruitColor.GetDefault(fruitName) or "None" else "None",
	})

	FruitService.FruitChanged:Fire(player, slot, fruitName)
	FruitService.FruitEaten:Fire(player, slot, fruitName)
	return if slot == 1 then "Slot1" else "Slot2"
end

function FruitService:RemoveFruit(player: Player, slot: number)
	local data = DataService:GetData(player)
	if not data or (slot ~= 1 and slot ~= 2) then
		return
	end

	data:Set(`Affinities.DF{slot}`, { Defense = 1, Melee = 1, Sniper = 1, Sword = 1 })
	data:Set(`DevilFruits.Slot{slot}`, { Name = FruitConfig.EmptyName, Color = "None" })
	FruitService.FruitChanged:Fire(player, slot, FruitConfig.EmptyName)
end

-- Puts a fruit in a slot with saved affinities (multipliers) and color: bound fruits, slot shifts.
function FruitService:SetFruit(player: Player, slot: number, fruitName: string, affinities: { [string]: number }, color: string)
	local data = DataService:GetData(player)
	if not data or (slot ~= 1 and slot ~= 2) or not FruitConfig.Fruits[fruitName] then
		return
	end

	data:Set(`Affinities.DF{slot}`, affinities)
	data:Set(`DevilFruits.Slot{slot}`, { Name = fruitName, Color = color })
	FruitService.FruitChanged:Fire(player, slot, fruitName)
end

function FruitService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")

	local models = ReplicatedStorage.Assets:FindFirstChild("Models")
	local itemModels = models and models:FindFirstChild("Items")
	local holder = itemModels and itemModels:FindFirstChild("AuraHolder")
	local attachment = holder and holder:FindFirstChild("AuraAttachment")
	if attachment and attachment:IsA("Attachment") then
		auraTemplate = attachment
	elseif HAS_ITEM_ACTIONS then
		-- The raid place keeps no item models (and hands out no fruit item).
		warn("[FruitService] Assets.Models.Items.AuraHolder.AuraAttachment not found: aura fruits will look plain")
	end
	local folder = models and models:FindFirstChild("FruitItems")
	if folder then
		for _, descendant in folder:GetDescendants() do
			-- Templates are named "<Fruit> Fruit".
			local fruitName = descendant:IsA("Tool") and string.match(descendant.Name, "^(%S+)")
			if fruitName and FruitConfig.Fruits[fruitName] and not templates[fruitName] then
				templates[fruitName] = descendant :: Tool
			end
		end
	end
end

function FruitService:KnitStart()
	if not HAS_ITEM_ACTIONS then
		return
	end

	local client = FruitService.Client :: any
	client.Eat:Connect(function(player: Player)
		local tool, item = getHeldItem(player)
		if not tool or not item then
			return
		end

		-- The item is consumed whatever the outcome, as in the original game.
		items[tool] = nil
		tool:Destroy()
		FruitService:EatFruit(player, item.FruitName, item.Scores, item.HasAura)
		FruitService.ItemUsed:Fire(player, item, "Eaten")
	end)

	client.Drop:Connect(function(player: Player)
		local tool, item = getHeldItem(player)
		local entity = CharacterService:GetPlayerEntity(player)
		if not tool or not item or not entity then
			return
		end

		-- Most fruit tools have no Handle, so the whole tool is placed, not just one part.
		tool.Parent = World.Drops()
		tool:PivotTo(entity.Root.CFrame * CFrame.new(0, 0, -DROP_DISTANCE))
		for _, part in tool:GetDescendants() do
			if part:IsA("BasePart") and not part.Anchored then
				part:SetNetworkOwner(nil)
			end
		end
		FruitService.ItemUsed:Fire(player, item, "Dropped")
	end)

	client.Give:Connect(function(player: Player, target: unknown)
		if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Player") or target == player then
			return
		end

		local tool, item = getHeldItem(player)
		local entity = CharacterService:GetPlayerEntity(player)
		local targetEntity = CharacterService:GetPlayerEntity(target :: Player)
		local backpack = (target :: Player):FindFirstChildOfClass("Backpack")
		if not tool or not item or not entity or not targetEntity or targetEntity.Dead or not backpack then
			return
		end
		if (targetEntity.Root.Position - entity.Root.Position).Magnitude > GIVE_RANGE then
			return
		end

		tool.Parent = backpack
		FruitService.ItemUsed:Fire(player, item, "Given")
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		actionLimiter:Forget(player)
	end)
end

return FruitService
