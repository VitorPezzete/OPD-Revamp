--!strict
--[[
	Fishing with a rod: cast -> wait -> bite -> reel (minigame) -> fish.

	The server owns the whole line. The client sends four intents and nothing else:
		Cast(aim)      throw the bobber towards a point (clamped to the rod's reach, must land on the sea)
		Reel(gamepad)  pull the line: retracts it, or starts the minigame if a fish is biting
		Hit(index)     "I hit target #index" during the minigame
		Miss()         "I clicked the water"
	The bite delay, the difficulty, the minigame timeline, the hit count, the fish and the
	cache roll are all decided here. A hit only counts while its target is up according to
	the server clock (FishingConfig.GetSchedule), once per target.

	The bobber is not an instance: its position is a replicated status of the character
	("FishingBobber") that clients draw themselves.

	Also here, because they act on the fish this service hands out: cooking the catch at a
	fire (using a fish next to one, or clicking a kitchen stove, cooks every raw fish
	carried) and selling it to the chef.

	Server API
		FishingService.FishCaught (player, fishName, difficulty, hits)

	Legacy exploits closed:
	  - the minigame score was the client's: "Finish" carried the hit count and the server
	    only compared it with a counter the same client incremented by firing "Running"
	    as fast as it wanted, so ten events and a "Finish, 10" gave a perfect fish at once;
	  - "Start" was accepted without a bite, and the rod (which sets the odds) was a
	    StringValue inside PlayerGui the client could rewrite;
	  - the cast position was trusted and nothing checked the rod was still held;
	  - the chef sold by tool name and trusted a NumberValue inside the tool for the price.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local FishingConfig = require(ReplicatedStorage.Shared.Configs.FishingConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local World = require(ReplicatedStorage.Shared.Util.World)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local Proximity = require(ServerStorage.Server.Modules.Proximity)
local ToolTemplates = require(ServerStorage.Server.Modules.ToolTemplates)

type CharacterEntity = CharacterEntity.CharacterEntity
type PlayerData = PlayerData.PlayerData

type Session = {
	Entity: CharacterEntity,
	Rod: Tool,
	Phase: "Waiting" | "Bite" | "Playing",
	Bobber: Vector3,
	Difficulty: string,
	Schedule: FishingConfig.Schedule?,
	StartedAt: number,
	Hit: { [number]: boolean },
	Hits: number,
	Misses: number,
	Connections: { RBXScriptConnection },
}

type Fish = { Size: string, Quality: number, Cooked: boolean }

local BOBBER_STATUS = "FishingBobber"
local BITE_STATUS = "FishingBite"
local SLOT_ATTRIBUTE = "WeaponSlot"
local FISH_FOLDER = "Fish"
local CAST_HEIGHT = 6

local FishingService = Knit.CreateService({
	Name = "FishingService",
	Client = {
		Cast = Knit.CreateSignal(),
		Reel = Knit.CreateSignal(),
		Hit = Knit.CreateSignal(),
		Miss = Knit.CreateSignal(),
		-- (difficulty, variant): the reeling minigame starts now.
		MinigameStarted = Knit.CreateSignal(),
		-- (hits, fishName?): the minigame is over; fishName is nil when the fish got away
		-- and hits is -1 when it was interrupted.
		MinigameEnded = Knit.CreateSignal(),
	},
})

FishingService.FishCaught = Signal.new() :: Signal.Signal<Player, string, string, number>

-- Private servers keep the gameplay but pay nothing.
FishingService.RewardsEnabled = game.PrivateServerOwnerId == 0

local DataService
local CharacterService
local NotifyService
local QuestService
local CacheService
local WeaponUnlockService
local WebhookService

local random = Random.new()
local sessions: { [Player]: Session } = {}
local fishes: { [Tool]: Fish } = {}

local castLimiter = RateLimiter.new(3, 0.5)
local reelLimiter = RateLimiter.new(4, 1)
local hitLimiter = RateLimiter.new(20, 10)
local sellLimiter = RateLimiter.new(2, 0.5)
local cookLimiter = RateLimiter.new(3, 1)
-- Studs added to a stove detector's own reach: that one is measured by the client, from
-- the camera's side of the stove, and this check from the root to the middle of it.
local STOVE_SLACK = 8

local function isFinite(vector: Vector3): boolean
	return vector == vector and math.abs(vector.X) < 1e6 and math.abs(vector.Y) < 1e6 and math.abs(vector.Z) < 1e6
end

-- The rod in the character's hands, when it is the one saved as equipped.
local function getHeldRod(player: Player, data: PlayerData): (Tool?, FishingConfig.RodDefinition?)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute(SLOT_ATTRIBUTE) ~= FishingConfig.RodSlot then
		return nil, nil
	end
	if data.Data.Weapons[FishingConfig.RodSlot] ~= tool.Name then
		return nil, nil
	end

	local definition = FishingConfig.Rods[tool.Name]
	return if definition then tool else nil, definition
end

local function endSession(player: Player, interrupted: boolean?)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil

	for _, connection in session.Connections do
		connection:Disconnect()
	end
	session.Entity:ClearStatus(BOBBER_STATUS)
	session.Entity:ClearStatus(BITE_STATUS)

	if interrupted and session.Phase == "Playing" then
		FishingService.Client.MinigameEnded:Fire(player, -1, nil)
	end
end

-- Where a cast towards `aim` comes down, or nil when that is not open sea.
local function findWaterPoint(entity: CharacterEntity, aim: Vector3): Vector3?
	local origin = entity.Root.Position
	local offset = Vector3.new(aim.X - origin.X, 0, aim.Z - origin.Z)
	if offset.Magnitude < 0.5 then
		local look = entity.Root.CFrame.LookVector
		offset = Vector3.new(look.X, 0, look.Z) * FishingConfig.MaxCastDistance
	end
	if offset.Magnitude > FishingConfig.MaxCastDistance then
		offset = offset.Unit * FishingConfig.MaxCastDistance
	end

	local seaLevel = WorldConfig.SeaLevel
	local top = math.max(origin.Y, seaLevel) + CAST_HEIGHT
	local start = Vector3.new(origin.X + offset.X, top, origin.Z + offset.Z)

	local ignored: { Instance } = { entity.Model }
	-- The sea parts must not count as land (Workspace.Map.Sea).
	local sea = World.Find("Sea")
	if sea then
		table.insert(ignored, sea)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored
	params.IgnoreWater = true

	local landLevel = seaLevel + FishingConfig.WaterTolerance
	local result = Workspace:Raycast(start, Vector3.new(0, landLevel - top, 0), params)
	if result then
		return nil
	end
	return Vector3.new(start.X, seaLevel, start.Z)
end

local function rollDifficulty(data: PlayerData, rod: FishingConfig.RodDefinition): string
	local bonus = 1 + data.Data.Expertise.Perks.BuffFishing.Value * FishingConfig.PerkDifficultyBonus
	local roll = random:NextInteger(1, 100)
	if roll <= rod.Thresholds.Impossible * bonus then
		return "Impossible"
	elseif roll <= rod.Thresholds.Hard * bonus then
		return "Hard"
	elseif roll <= rod.Thresholds.Medium * bonus then
		return "Medium"
	end
	return "Easy"
end

-- A cache (or the Aqua Staff) on top of the fish; rarer rewards get likelier with better
-- rods, harder fish and the BuffFishing perk.
local function rollCache(player: Player, data: PlayerData, rodName: string, difficulty: FishingConfig.DifficultyDefinition)
	if random:NextInteger(1, difficulty.CacheRoll) > FishingConfig.CacheThreshold then
		return
	end

	local rod = FishingConfig.Rods[rodName]
	local perk = 1 + data.Data.Expertise.Perks.BuffFishing.Value * FishingConfig.PerkCacheBonus
	local entries = table.clone(FishingConfig.CacheWeights)

	local staff = FishingConfig.AquaStaff
	if
		rodName == staff.Rod
		and data.Data.Fishing.ChefGift >= staff.ChefGiftRequirement
		and not data.Data.Items[staff.Item]
	then
		table.insert(entries, { Item = staff.Item, Weight = staff.Weight })
	end

	local weights: { number } = {}
	local total = 0
	for index, entry in entries do
		local weight = entry.Weight * (rod.CacheWeights[entry.Item] or 1) * (difficulty.CacheWeights[entry.Item] or 1)
		if FishingConfig.PerkBoostedRewards[entry.Item] then
			weight *= perk
		end
		weights[index] = weight
		total += weight
	end

	local roll = random:NextNumber() * total
	for index, entry in entries do
		roll -= weights[index]
		if roll <= 0 then
			if entry.Item == staff.Item then
				WeaponUnlockService:Unlock(player, staff.Item)
			else
				CacheService:Give(player, entry.Item)
			end
			return
		end
	end
end

-- Cooks every raw fish the player carries, in hand or not. Returns how many there were.
local function cookCarried(player: Player): number
	local cooked = 0
	for _, tool in ToolTemplates.GetCarried(player) do
		local info = fishes[tool]
		if info and not info.Cooked then
			info.Cooked = true
			tool.Name = "Cooked " .. tool.Name
			local handle = tool:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.BrickColor = FishingConfig.CookedColor
			end
			cooked += 1
		end
	end
	if cooked > 0 then
		NotifyService:Send(player, `Cooked {cooked} fish.`, "Success")
	end
	return cooked
end

-- A fish used next to a fire: the whole catch is cooked, not only the fish in hand.
local function cook(player: Player, tool: Tool)
	local entity = CharacterService:GetPlayerEntity(player)
	if not fishes[tool] or not entity or entity.Dead then
		return
	end

	local position = entity.Root.Position
	for _, spot in FishingConfig.CookSpots do
		if (position - spot).Magnitude <= FishingConfig.CookRange then
			cookCarried(player)
			return
		end
	end
end

-- A click on a kitchen stove: the same, from as far as its ClickDetector can be clicked.
local function onStoveClicked(player: Player, stove: BasePart, range: number)
	local entity = CharacterService:GetPlayerEntity(player)
	if not entity or entity.Dead or not cookLimiter:Consume(player) then
		return
	end
	if not Proximity.IsNear(player, stove, range) then
		return
	end
	if cookCarried(player) == 0 then
		NotifyService:Send(player, "You have no raw fish to cook.", "Error")
	end
end

local function giveFish(player: Player, difficultyName: string, hits: number): string?
	local difficulty = FishingConfig.Difficulties[difficultyName]
	local species = FishingConfig.FishNames[random:NextInteger(1, #FishingConfig.FishNames)]
	local tool = ToolTemplates.Give(player, species, FISH_FOLDER)
	if not tool then
		return nil
	end

	local targets = FishingConfig.Minigame.Targets
	tool.Name = `{difficulty.Prefix} {species}`
	tool.ToolTip = `{hits}/{targets} ({FishingConfig.QualityLabels[hits] or "Bad"})`

	local handle = tool:FindFirstChild("Handle")
	local mesh = handle and handle:FindFirstChildWhichIsA("DataModelMesh")
	if mesh then
		mesh.Scale *= difficulty.MeshScale
	elseif handle and handle:IsA("BasePart") then
		handle.Size *= difficulty.MeshScale
	end

	fishes[tool] = { Size = difficulty.Prefix, Quality = hits / targets, Cooked = false }
	tool.Destroying:Once(function()
		fishes[tool] = nil
	end)
	-- Using the fish next to a fire cooks the catch. The connection dies with the tool.
	tool.Activated:Connect(function()
		local holder = Players:GetPlayerFromCharacter(tool.Parent)
		if holder then
			cook(holder, tool)
		end
	end)
	return tool.Name
end

local function award(player: Player, session: Session)
	local data = DataService:GetData(player)
	local difficulty = FishingConfig.Difficulties[session.Difficulty]
	local hits = session.Hits
	if not data or hits < FishingConfig.Minigame.MinimumHits then
		FishingService.Client.MinigameEnded:Fire(player, hits, nil)
		return
	end

	local rodName = session.Rod.Name
	local fishName = giveFish(player, session.Difficulty, hits)
	FishingService.Client.MinigameEnded:Fire(player, hits, fishName)
	if not fishName then
		return
	end

	-- The lifetime count is what WeaponUnlockService watches for the Sturdy Rod and the Golden Fish.
	data:Increment("Economy.Fish", 1)

	QuestService:ReduceSamTimer(player, math.floor(difficulty.SamSeconds * hits / FishingConfig.Minigame.Targets))
	rollCache(player, data, rodName, difficulty)
	FishingService.FishCaught:Fire(player, fishName, session.Difficulty, hits)
end

local function settle(player: Player, session: Session)
	if sessions[player] ~= session then
		return
	end

	-- The rod has to be in hand until the end; unequipping ends the session before this.
	endSession(player)
	award(player, session)
end

local function onCast(player: Player, aim: unknown)
	if not castLimiter:Consume(player) or typeof(aim) ~= "Vector3" or not isFinite(aim) then
		return
	end
	if sessions[player] then
		return
	end

	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not data or not entity or entity.Dead or not entity.Spawned then
		return
	end

	local rod, definition = getHeldRod(player, data)
	if not rod or not definition then
		return
	end

	local bobber = findWaterPoint(entity, aim)
	if not bobber then
		NotifyService:Send(player, "Cast your line into the sea.", "Error", 2)
		return
	end

	local session: Session = {
		Entity = entity,
		Rod = rod,
		Phase = "Waiting",
		Bobber = bobber,
		Difficulty = "Easy",
		Schedule = nil,
		StartedAt = 0,
		Hit = {},
		Hits = 0,
		Misses = 0,
		Connections = {},
	}
	sessions[player] = session
	entity:SetStatus(BOBBER_STATUS, bobber, nil, true)

	-- Putting the rod away or dying drops the line, whatever the phase.
	table.insert(session.Connections, rod.AncestryChanged:Connect(function()
		local held = rod.Parent == entity.Model and rod:IsDescendantOf(Workspace)
		if not held and sessions[player] == session then
			endSession(player, true)
		end
	end))
	table.insert(session.Connections, entity.Died:Connect(function()
		if sessions[player] == session then
			endSession(player, true)
		end
	end))

	local biteDelay = random:NextInteger(definition.BiteTime.Min, definition.BiteTime.Max)
	task.delay(biteDelay, function()
		if sessions[player] == session and session.Phase == "Waiting" then
			session.Phase = "Bite"
			entity:SetStatus(BITE_STATUS, true, nil, true)
		end
	end)
end

local function onReel(player: Player, gamepad: unknown)
	local session = sessions[player]
	if not session or not reelLimiter:Consume(player) then
		return
	end

	if session.Phase == "Waiting" then
		endSession(player)
		return
	elseif session.Phase ~= "Bite" then
		return
	end

	local data = DataService:GetData(player)
	local entity = session.Entity
	local rod: Tool?, definition: FishingConfig.RodDefinition? = nil, nil
	if data then
		rod, definition = getHeldRod(player, data)
	end
	if
		not data
		or rod ~= session.Rod
		or not definition
		or entity.Dead
		or (entity.Root.Position - session.Bobber).Magnitude > FishingConfig.MaxLineDistance
	then
		endSession(player)
		return
	end

	local difficulty = rollDifficulty(data, definition)
	local variants = FishingConfig.Minigame.Variants
	local variant: string = "Scatter"
	if gamepad == true then
		variant = "Arrows"
	elseif difficulty ~= "Easy" then
		variant = variants[random:NextInteger(1, #variants)]
	end

	local schedule = FishingConfig.GetSchedule(difficulty, variant)
	if not schedule then
		endSession(player)
		return
	end

	session.Phase = "Playing"
	session.Difficulty = difficulty
	session.Schedule = schedule
	session.StartedAt = os.clock() + FishingConfig.Minigame.Intro
	entity:ClearStatus(BITE_STATUS)
	FishingService.Client.MinigameStarted:Fire(player, difficulty, variant)

	task.delay(FishingConfig.Minigame.Intro + schedule.Duration + FishingConfig.Minigame.SettleGrace, settle, player, session)
end

local function onHit(player: Player, index: unknown)
	local session = sessions[player]
	local schedule = session and session.Schedule
	if not session or not schedule or session.Phase ~= "Playing" or not hitLimiter:Consume(player) then
		return
	end
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > FishingConfig.Minigame.Targets then
		WebhookService:Flag(player, "FishingBadHit")
		return
	end
	if session.Hit[index] then
		return
	end

	local minigame = FishingConfig.Minigame
	local elapsed = os.clock() - session.StartedAt
	if elapsed < schedule.Opens[index] - minigame.EarlyTolerance or elapsed > schedule.Closes[index] + minigame.LateTolerance then
		return
	end

	session.Hit[index] = true
	session.Hits += 1
end

local function onMiss(player: Player)
	local session = sessions[player]
	if not session or session.Phase ~= "Playing" or not hitLimiter:Consume(player) then
		return
	end

	session.Misses += 1
	if session.Misses >= FishingConfig.Minigame.MissesPerPenalty then
		session.Misses = 0
		session.Hits = math.max(0, session.Hits - 1)
	end
end

-- Sells every fish the player carries to the chef. Returns the Beri paid.
function FishingService.Client:SellFish(player: Player): number
	if not sellLimiter:Consume(player) then
		return 0
	end

	local data = DataService:GetData(player)
	if not data or not Proximity.GetMerchant(player, FishingConfig.ChefMerchant) then
		return 0
	end
	if not FishingService.RewardsEnabled then
		NotifyService:Send(player, "The chef does not buy fish in private servers.", "Error")
		return 0
	end

	local total = 0
	local sold = 0
	for _, tool in ToolTemplates.GetCarried(player) do
		local info = fishes[tool]
		if info then
			local price = (FishingConfig.SizePrices[info.Size] or 0) * info.Quality
			if info.Cooked then
				price *= FishingConfig.CookedMultiplier
			end
			total += price
			sold += 1
			fishes[tool] = nil
			tool:Destroy()
		end
	end

	total = math.floor(total)
	if sold == 0 then
		NotifyService:Send(player, "You have no fish to sell.", "Error")
		return 0
	end

	data:Increment("Economy.Beri", total)
	data:Increment("Fishing.ChefGift", total)
	NotifyService:Send(player, `Sold {sold} fish for {total} Beri.`, "Success")
	return total
end

function FishingService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	NotifyService = Knit.GetService("NotifyService")
	QuestService = Knit.GetService("QuestService")
	CacheService = Knit.GetService("CacheService")
	WeaponUnlockService = Knit.GetService("WeaponUnlockService")
	WebhookService = Knit.GetService("WebhookService")
end

function FishingService:KnitStart()
	FishingService.Client.Cast:Connect(onCast)
	FishingService.Client.Reel:Connect(onReel)
	FishingService.Client.Hit:Connect(onHit)
	FishingService.Client.Miss:Connect(onMiss)

	-- The kitchen stoves are static: one look at start. A place without a kitchen still
	-- cooks at its fires (FishingConfig.CookSpots).
	local kitchen = World.Resolve(FishingConfig.StovePath)
	for _, child in if kitchen then kitchen:GetChildren() else {} do
		local detector = if child.Name == FishingConfig.StovePart and child:IsA("BasePart")
			then child:FindFirstChildOfClass("ClickDetector")
			else nil
		if detector then
			detector.MouseClick:Connect(function(player: Player)
				onStoveClicked(player, child :: BasePart, detector.MaxActivationDistance + STOVE_SLACK)
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		endSession(player)
		cookLimiter:Forget(player)
		castLimiter:Forget(player)
		reelLimiter:Forget(player)
		hitLimiter:Forget(player)
		sellLimiter:Forget(player)
	end)
end

return FishingService
