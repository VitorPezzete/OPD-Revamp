--!strict
--[[
	Juicing bowls and what comes out of them.

	Clicking a bowl turns every plain fruit the player carries (Apple, Melon, ...) into
	its drink after the mix time. A bowl serves one player at a time. Drinking a fruit
	drink gives experience in the four combat skills; eating a Golden Apple gives Beri.

	The bowls are found once at start and tagged; while one mixes it carries an
	attribute and the clients spin its mixers. The legacy scripts rotated the parts on
	the server every frame.

	Using a drink needs no remote: Tool.Activated reaches the server. A tool is bound the
	first time a character equips it, whoever handed it out (bowl, barrel, cache).

	Fixed from the legacy scripts:
	- Only fruits in the backpack were counted, but the held one was destroyed too.
	- One bowl only reported players clicking from far away and served them anyway;
	  the other did not look at the distance at all.
	- A drink's "used" flag was set before checking who held it, so a tool could end
	  up spent without effect, and nothing checked the drinker was alive.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local World = require(ReplicatedStorage.Shared.Util.World)
local FruitOddsConfig = require(ServerStorage.Server.Configs.FruitOddsConfig)
local Proximity = require(ServerStorage.Server.Modules.Proximity)
local ToolTemplates = require(ServerStorage.Server.Modules.ToolTemplates)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

local JUICING = FruitEconomyConfig.Juicing
local DRINKS = FruitOddsConfig.Drinks
local GOLDEN_APPLE = FruitOddsConfig.GoldenApple
local BOWL_NAME = "JuicingBowl"
local BOWL_PARTS = { "Bowl", "Mixer1", "Mixer2" }
local ITEM_FOLDER = "Items"

local JuiceService = Knit.CreateService({
	Name = "JuiceService",
	Client = {},
})

-- (player, drinkName) after a fruit drink was drunk.
JuiceService.Drank = Signal.new() :: Signal.Signal<Player, string>
-- (player, { drinkName }) when a bowl hands out its drinks.
JuiceService.Mixed = Signal.new() :: Signal.Signal<Player, { string }>

local DataService
local CharacterService
local StatService
local WebhookService

local clickLimiter = RateLimiter.new(3, 1)
local busy: { [Instance]: boolean } = {}
local bound: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local random = Random.new()

local function getActiveEntity(player: Player): any
	local entity = CharacterService:GetPlayerEntity(player)
	return if entity and not entity.Dead and entity.Spawned then entity else nil
end

local function mix(player: Player, bowl: Instance, center: BasePart)
	if busy[bowl] or not clickLimiter:Consume(player) then
		return
	end
	local entity = getActiveEntity(player)
	if not entity or not Proximity.IsNear(player, center, JUICING.Range) then
		if entity then
			WebhookService:Flag(player, "JuicerFar")
		end
		return
	end

	local drinks: { string } = {}
	for _, tool in ToolTemplates.GetCarried(player) do
		local drink = JUICING.Recipes[tool.Name]
		if drink then
			table.insert(drinks, drink)
			tool:Destroy()
		end
	end
	if #drinks == 0 then
		return
	end

	busy[bowl] = true
	bowl:SetAttribute(JUICING.MixingAttribute, true)
	task.delay(JUICING.MixSeconds, function()
		busy[bowl] = nil
		bowl:SetAttribute(JUICING.MixingAttribute, false)
		-- Leaving during the mix loses the fruits, as before.
		if player.Parent ~= Players then
			return
		end
		for _, drink in drinks do
			ToolTemplates.Give(player, drink, ITEM_FOLDER)
		end
		JuiceService.Mixed:Fire(player, drinks)
	end)
end

local function bindBowl(bowl: Instance)
	local center = bowl:FindFirstChild("Mixer1")
	if not center or not center:IsA("BasePart") then
		return
	end

	for _, partName in BOWL_PARTS do
		local part = bowl:FindFirstChild(partName)
		if not part then
			continue
		end
		local detector: ClickDetector = part:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
		detector.Parent = part
		detector.MouseClick:Connect(function(player: Player)
			mix(player, bowl, center)
		end)
	end
	CollectionService:AddTag(bowl, JUICING.Tag)
end

-- The held tool's holder, if that is a living, spawned player character.
local function getDrinker(tool: Tool): (Player?, any)
	local character = tool.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	local entity = player and getActiveEntity(player)
	if not player or not entity or entity.Model ~= character then
		return nil, nil
	end
	return player, entity
end

local function drink(tool: Tool)
	local player = getDrinker(tool)
	if not player then
		return
	end

	local name = tool.Name
	-- Spent before the reward: a second Activated in the same frame finds no holder.
	tool:Destroy()
	for _, skill in DRINKS.Skills do
		StatService:AddExp(player, skill :: any, random:NextInteger(DRINKS.MinExp, DRINKS.MaxExp), true)
	end
	JuiceService.Drank:Fire(player, name)
end

local function eatGoldenApple(tool: Tool)
	local player = getDrinker(tool)
	local data = player and DataService:GetData(player)
	if not player or not data then
		return
	end

	tool:Destroy()
	data:Increment("Economy.Beri", random:NextInteger(GOLDEN_APPLE.MinBeri, GOLDEN_APPLE.MaxBeri))
end

local function bindTool(child: Instance)
	if not child:IsA("Tool") or bound[child] then
		return
	end

	local use = if child.Name == GOLDEN_APPLE.Name
		then eatGoldenApple
		elseif table.find(DRINKS.Names, child.Name) then drink
		else nil
	if use then
		bound[child] = true
		child.Activated:Connect(function()
			use(child)
		end)
	end
end

function JuiceService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	StatService = Knit.GetService("StatService")
	WebhookService = Knit.GetService("WebhookService")
end

function JuiceService:KnitStart()
	-- One pass over the map at start; the bowls are static.
	local found = 0
	local map = World.Map()
	for _, descendant in if map then map:GetDescendants() else {} do
		if descendant.Name == BOWL_NAME and descendant:FindFirstChild("Mixer1") then
			bindBowl(descendant)
			found += 1
		end
	end
	if found == 0 then
		warn("[JuiceService] no JuicingBowl found in Workspace.Map")
	end

	local function bindEntity(entity: any)
		if entity.Player then
			-- Dies with the character model.
			entity.Model.ChildAdded:Connect(bindTool)
		end
	end
	CharacterService.EntityAdded:Connect(bindEntity)
	for _, entity in CharacterService:GetEntities() do
		bindEntity(entity)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		clickLimiter:Forget(player)
	end)
end

return JuiceService
