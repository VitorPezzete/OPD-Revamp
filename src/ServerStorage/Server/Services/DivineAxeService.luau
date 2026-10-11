--!strict
--[[
	The Divine Axe on the fire island: after the Burning Compass boss falls, the player
	it was summoned for may try to lift the axe. The axe judges:

		required = 10 * floor(clamp(10 - (clock - 12)^2, 1, 10))   -- sun: 100 at noon
		         + 2 * expertise level
		         + 100 for a Flare user
		roll     = 1..10000 with expertise level 60 or more, 5000..10000 below it
		accepted when roll <= required

	So below expertise 60 it is never accepted, and at 60+ the chance is required /
	10000 (5.2% at best: noon, expertise 100, Flare). Accepted: the axe is owned
	(Items["Divine Axe"]). Denied: the character is burnt to pieces on the spot.

	Who may try is decided here, never by the prompt alone:
	- DivineAxeService:Offer(player, axe) - called by whatever spawns the island when its
	  boss dies (the legacy Killed event set PlayerId and enabled the prompt);
	- as a fallback for an island built the legacy way, an axe carrying a PlayerId
	  IntValue (or attribute) equal to the player's user id is honoured too.
	The player must be alive and standing next to the axe, and gets one try per axe.

	Legacy problems fixed: a denied player could trigger the prompt again while falling
	apart; the roll ran (and could kill) even for someone who already owned the axe -
	an owner is now simply told so.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local World = require(ReplicatedStorage.Shared.Util.World)

local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local Proximity = require(ServerStorage.Server.Modules.Proximity)

local ITEM = "Divine Axe"
local ISLAND_NAME = "FireIsland"
local FRUIT = "Flare"
local DENIED_EFFECT = "WeaponDivineAxeDenied"
local DENIED_TEXT = "The Divine Axe denies you."

local SUN_STEP = 10
local EXPERTISE_STEP = 2
local FLARE_BONUS = 100
local ROLL_MAX = 10000
local LOW_ROLL_MIN = 5000
local FULL_ROLL_EXPERTISE = 60
local RANGE_MARGIN = 10

local DivineAxeService = Knit.CreateService({
	Name = "DivineAxeService",
	Client = {},
})

local DataService
local CharacterService
local EffectService
local NotifyService

-- Weak keys: an island that is destroyed takes its entries with it.
local offers: { [Instance]: Player } = setmetatable({} :: any, { __mode = "k" })
local tried: { [Instance]: { [Player]: boolean } } = setmetatable({} :: any, { __mode = "k" })
local bound: { [Instance]: boolean } = setmetatable({} :: any, { __mode = "k" })
local limiter = RateLimiter.new(3, 0.5)

local function isOfferedTo(axe: Instance, player: Player): boolean
	if offers[axe] == player then
		return true
	end
	local value = axe:FindFirstChild("PlayerId")
	if value and value:IsA("IntValue") and value.Value == player.UserId then
		return true
	end
	return axe:GetAttribute("PlayerId") == player.UserId
end

local function attempt(player: Player, axe: Instance, prompt: ProximityPrompt)
	if not limiter:Consume(player) or not prompt.Enabled then
		return
	end

	local entity = CharacterService:GetPlayerEntity(player)
	local data = DataService:GetData(player)
	if not entity or not data or entity.Dead or not entity.Spawned then
		return
	end
	if not isOfferedTo(axe, player) then
		return
	end
	if not Proximity.IsNear(player, axe, prompt.MaxActivationDistance + RANGE_MARGIN) then
		return
	end

	if data:Get(`Items.{ITEM}`) == true then
		NotifyService:Send(player, "The Divine Axe is already yours.", "Info")
		return
	end

	local attempts = tried[axe]
	if not attempts then
		attempts = {}
		tried[axe] = attempts
	end
	if attempts[player] then
		return
	end
	attempts[player] = true

	local expertise = data.Data.Skills.Expertise.Level
	local fruits = data.Data.DevilFruits
	local sun = math.floor(math.clamp(10 - (Lighting.ClockTime - 12) ^ 2, 1, 10))
	local required = SUN_STEP * sun + EXPERTISE_STEP * expertise
	if fruits.Slot1.Name == FRUIT or fruits.Slot2.Name == FRUIT then
		required += FLARE_BONUS
	end
	local roll = math.random(if expertise >= FULL_ROLL_EXPERTISE then 1 else LOW_ROLL_MIN, ROLL_MAX)

	if roll <= required then
		-- The unlock alert is the client's NewUnlock screen, which watches Items.
		data:Set(`Items.{ITEM}`, true)
		return
	end

	EffectService:Play(DENIED_EFFECT, entity.Root.Position, { Caster = entity.Model })
	NotifyService:Send(player, DENIED_TEXT, "Error", 3.5)
	entity:Kill()
end

local function bind(axe: Instance)
	if bound[axe] then
		return
	end
	local prompt = axe:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		warn(`[DivineAxeService] {axe:GetFullName()} has no ProximityPrompt`)
		return
	end
	bound[axe] = true
	prompt.Triggered:Connect(function(player: Player)
		attempt(player, axe, prompt)
	end)
end

-- Lets `player` try to lift this axe (a "Divine Axe" instance holding a ProximityPrompt).
function DivineAxeService:Offer(player: Player, axe: Instance)
	offers[axe] = player
	bind(axe)
end

local function bindIsland(island: Instance)
	if island.Name ~= ISLAND_NAME then
		return
	end
	-- Deferred: whoever spawned the island may still be filling it in this frame.
	task.defer(function()
		local axe = island:FindFirstChild(ITEM)
		if axe then
			bind(axe)
		end
	end)
end

function DivineAxeService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	EffectService = Knit.GetService("EffectService")
	NotifyService = Knit.GetService("NotifyService")
end

function DivineAxeService:KnitStart()
	-- CompassService builds its islands in Workspace.Instances.
	local runtime = World.RuntimeParent()
	runtime.ChildAdded:Connect(bindIsland)
	for _, child in runtime:GetChildren() do
		bindIsland(child)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		limiter:Forget(player)
	end)
end

return DivineAxeService
