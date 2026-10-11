--!strict
--[[
	Barrels and crates of the map (Workspace.Map.Barrels): click one to loot a random food
	item; it then stays closed for everybody for a minute.

	No remote: the parts already carry a ClickDetector and the server listens to it.
	Each click is validated (spawned, alive, within reach, plausible travel, not a flood),
	because exploits can fire a ClickDetector from across the map.

	Legacy problems fixed
	- Three overlapping "anti-cheat" paths (BarrelsScript, BarrelModule, the SpecialBarrel
	  scripts) banned automatically and posted to Discord webhooks stored in the scripts.
	  Now an impossible click is refused and reported through BarrelService.Flagged;
	  punishing is a moderation decision, not a side effect of looting.
	- BarrelModule connected a second MouseClick to every barrel just to keep statistics.
	- A per-player cooldown table was kept next to a per-barrel one that already covered it.

	Special barrels are traps, not loot: see WorldObjectConfig.Barrels.Honeypots.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local World = require(ReplicatedStorage.Shared.Util.World)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local TravelGuard = require(ServerStorage.Server.Classes.TravelGuard)
local WorldObjectConfig = require(ServerStorage.Server.Configs.WorldObjectConfig)
local WorldAssets = require(ServerStorage.Server.Modules.WorldAssets)

local CONFIG = WorldObjectConfig.Barrels

local BarrelService = Knit.CreateService({
	Name = "BarrelService",
	Client = {},
})

-- (player, items) after a barrel was looted; for quests and challenges.
BarrelService.Looted = Signal.new() :: Signal.Signal<Player, { string }>
-- (player, reason): "BarrelTravel" | "BarrelFlood" | "BarrelHoneypot"; for moderation.
BarrelService.Flagged = Signal.new() :: Signal.Signal<Player, string>

local CharacterService
local FruitService
local WebhookService

local closedUntil: { [BasePart]: number } = {}
local floodLimiter = RateLimiter.new(CONFIG.FloodBurst, CONFIG.FloodRefill)
local travelGuard = TravelGuard.new(CONFIG.MinTravelDistance)
local random = Random.new()

local function isInReach(player: Player, part: BasePart): boolean
	local entity = CharacterService:GetPlayerEntity(player)
	if not entity or entity.Dead or not entity.Spawned then
		return false
	end
	return (entity.Root.Position - part.Position).Magnitude <= CONFIG.ClickRange
end

local function giveLoot(player: Player)
	local rolls = 1
	if FruitService:HasFruit(player, CONFIG.LuckFruit) then
		rolls += random:NextInteger(CONFIG.LuckExtraMin, CONFIG.LuckExtraMax)
	end

	local items: { string } = {}
	for _ = 1, rolls do
		local item = CONFIG.Loot[random:NextInteger(1, #CONFIG.Loot)]
		if WorldAssets.GiveItem(player, item) > 0 then
			table.insert(items, item)
		end
	end
	BarrelService.Looted:Fire(player, items)
end

local function onClicked(player: Player, barrel: BasePart, detector: ClickDetector)
	local now = os.clock()
	if now < (closedUntil[barrel] or 0) or not isInReach(player, barrel) then
		return
	end
	if not floodLimiter:Consume(player) then
		BarrelService.Flagged:Fire(player, "BarrelFlood")
		return
	end
	if not travelGuard:Visit(player, barrel.Position, CONFIG.MaxTravelSpeed) then
		BarrelService.Flagged:Fire(player, "BarrelTravel")
		return
	end

	closedUntil[barrel] = now + CONFIG.CooldownSeconds
	-- Hides the click cursor while the barrel is empty.
	detector.MaxActivationDistance = 0
	task.delay(CONFIG.CooldownSeconds, function()
		closedUntil[barrel] = nil
		detector.MaxActivationDistance = CONFIG.ClickRange
	end)

	giveLoot(player)
end

local function bindBarrels(folder: Instance)
	for _, descendant in folder:GetDescendants() do
		if not descendant:IsA("BasePart") or not CONFIG.Names[descendant.Name] then
			continue
		end
		local detector = descendant:FindFirstChildOfClass("ClickDetector")
		if detector then
			detector.MaxActivationDistance = CONFIG.ClickRange
			detector.MouseClick:Connect(function(player: Player)
				onClicked(player, descendant, detector)
			end)
		end
	end
end

--[[
	A trap barrel appears for a while at random intervals. Timers are chained, so a
	hidden trap costs nothing. It keeps the template's own position.
]]
local function runHoneypot(honeypot: WorldObjectConfig.Honeypot, parent: Instance)
	local template = WorldAssets.Find(honeypot.Template, "PVInstance")
	if not template then
		return
	end

	local trap = template:Clone()
	for _, descendant in trap:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end

	local detector = trap:FindFirstChildWhichIsA("ClickDetector", true)
	if not detector then
		detector = Instance.new("ClickDetector")
		detector.MaxActivationDistance = CONFIG.ClickRange
		detector.Parent = trap
	end
	(detector :: ClickDetector).MouseClick:Connect(function(player: Player)
		BarrelService.Flagged:Fire(player, "BarrelHoneypot")
	end)

	local function cycle()
		task.delay(random:NextInteger(honeypot.MinWait, honeypot.MaxWait), function()
			trap.Parent = parent
			task.delay(honeypot.Visible, function()
				trap.Parent = nil
				cycle()
			end)
		end)
	end
	cycle()
end

-- Call after the game itself teleports a player (events, raids), so the jump is not held against them.
function BarrelService:ResetTravel(player: Player)
	travelGuard:Reset(player)
end

function BarrelService:KnitInit()
	CharacterService = Knit.GetService("CharacterService")
	FruitService = Knit.GetService("FruitService")
	WebhookService = Knit.GetService("WebhookService")
end

function BarrelService:KnitStart()
	-- The legacy barrel scripts posted their bans to Discord; the flags are reported instead.
	BarrelService.Flagged:Connect(function(player: Player, reason: string)
		WebhookService:Flag(player, reason)
	end)

	local folder = World.Find(CONFIG.Container)
	if not folder then
		warn(`[BarrelService] Workspace.Map.{CONFIG.Container} not found: no barrels`)
		return
	end

	bindBarrels(folder)

	-- On purpose inside the map folder and not Workspace.Instances: a trap has to sit among
	-- the real barrels to be picked up by whatever is scanning for them.
	local honeypotParent = folder:FindFirstChild(CONFIG.HoneypotFolder) or folder
	for _, honeypot in CONFIG.Honeypots do
		runHoneypot(honeypot, honeypotParent)
	end

	CharacterService.EntityAdded:Connect(function(entity)
		if entity.Player then
			travelGuard:Reset(entity.Player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		travelGuard:Reset(player)
		floodLimiter:Forget(player)
	end)
end

return BarrelService
