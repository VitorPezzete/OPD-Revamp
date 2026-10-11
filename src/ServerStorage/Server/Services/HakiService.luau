--!strict
--[[
	Haki: a per-character energy bar spent by two toggles.

	Armament    - doubles weapon damage and turns it into "Haki" damage; drains 1 point
	              per second and trains the Haki skill for every point spent.
	Observation - dodges any dodgeable hit for 1 point, unless the attacker is also
	              using observation.

	The bar refills 1 point per second while neither is active. Its maximum is the Haki
	level (doubled by the Alice fruit).

	Legacy problems fixed: the bar lived in a ValueObject driven by three separate
	scripts per player that waited on PlayerGui objects, the toggle debounce was shared
	by every player through one module-level flag, and running out of haki indexed limbs
	that could already be gone.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

type HakiState = {
	Bar: number,
	Max: number,
	Armament: boolean,
	Observation: boolean,
	LastToggle: number,
}

local TOGGLE_DEBOUNCE = 1.5
local TICK = 1
local ARMAMENT_STATUS = "Haki"
local OBSERVATION_STATUS = "UsingObs"
local DOUBLE_BAR_FRUIT = "Alice"

local HakiService = Knit.CreateService({
	Name = "HakiService",
	Client = {
		ToggleArmament = Knit.CreateSignal(),
		ToggleObservation = Knit.CreateSignal(),
		-- Fired to a player whose observation just dodged a hit.
		Dodged = Knit.CreateUnreliableSignal(),
	},
})

local DataService
local CharacterService
local CombatService
local StatService
local FruitService
local WebhookService

local states: { [CharacterEntity]: HakiState } = {}
local toggleLimiter = RateLimiter.new(3, 1)

local function replicate(entity: CharacterEntity, state: HakiState)
	entity.Model:SetAttribute("HakiBar", state.Bar)
	entity.Model:SetAttribute("HakiMax", state.Max)
end

local function getMax(player: Player): number
	local level = StatService:GetLevel(player, "Haki")
	return if FruitService:HasFruit(player, DOUBLE_BAR_FRUIT) then level * 2 else level
end

local function setArmament(entity: CharacterEntity, state: HakiState, active: boolean)
	state.Armament = active
	entity:SetStatus(ARMAMENT_STATUS, active, nil, true)
end

local function setObservation(entity: CharacterEntity, state: HakiState, active: boolean)
	state.Observation = active
	entity:SetStatus(OBSERVATION_STATUS, active, nil, true)
end

local function spend(entity: CharacterEntity, state: HakiState, amount: number)
	state.Bar = math.max(0, state.Bar - amount)
	if entity.Player then
		StatService:AddExp(entity.Player, "Haki", amount, true)
	end
	if state.Bar <= 0 then
		setArmament(entity, state, false)
		setObservation(entity, state, false)
	end
	replicate(entity, state)
end

local function canToggle(player: Player, requirement: number): (CharacterEntity?, HakiState?)
	if not toggleLimiter:Consume(player) then
		-- The legacy remote banned (and posted) whoever fired it 25 times in 5 seconds.
		WebhookService:Flag(player, "HakiToggleSpam")
		return nil, nil
	end

	local entity = CharacterService:GetPlayerEntity(player)
	local state = entity and states[entity]
	if not entity or not state or entity.Dead or not entity.Spawned then
		return nil, nil
	end
	if entity:HasStatus(AbilityConfig.Status.AbilitiesDisabled) then
		return nil, nil
	end
	if StatService:GetLevel(player, "Haki") < requirement then
		return nil, nil
	end

	local now = os.clock()
	if now - state.LastToggle < TOGGLE_DEBOUNCE then
		return nil, nil
	end
	state.LastToggle = now
	return entity, state
end

local function tick()
	for entity, state in states do
		if entity.Dead then
			continue
		end

		local player = entity.Player
		if player then
			state.Max = getMax(player)
		end

		if state.Armament then
			spend(entity, state, 1)
		elseif not state.Observation and state.Bar < state.Max then
			state.Bar = math.min(state.Max, state.Bar + 1)
			replicate(entity, state)
		elseif state.Bar > state.Max then
			state.Bar = state.Max
			replicate(entity, state)
		end
	end
end

-- Observation dodge. Runs right after immunities so a dodged hit costs nothing else.
local observationModifier: CombatTypes.DamageModifier = {
	Name = "ObservationDodge",
	Priority = 60,
	Apply = function(context: CombatTypes.DamageContext)
		local target = context.Target
		local state = states[target]
		if not context.Dodgeable or not state or not state.Observation then
			return
		end
		if target:HasStatus(AbilityConfig.Status.AbilitiesDisabled) then
			return
		end

		local attacker = context.Attacker
		local attackerState = attacker and states[attacker]
		if attackerState and attackerState.Observation then
			return
		end

		context.Cancelled = true
		context.CancelReason = "Dodged"
		spend(target, state, 1)
		if target.Player then
			HakiService.Client.Dodged:Fire(target.Player)
		end
	end,
}

function HakiService:GetBar(entity: CharacterEntity): (number, number)
	local state = states[entity]
	if state then
		return state.Bar, state.Max
	end
	return 0, 0
end

--[[
	Adds haki to a character's bar (negative spends it), clamped to [0, max].
	Returns false, changing nothing, when a spend is larger than what is left.
	Spending through here gives no Haki exp and running dry turns both toggles off.
]]
function HakiService:AddBar(entity: CharacterEntity, amount: number): boolean
	local state = states[entity]
	if not state or amount ~= amount then
		return false
	end
	if amount < 0 and state.Bar < -amount then
		return false
	end

	state.Bar = math.clamp(state.Bar + amount, 0, state.Max)
	if state.Bar <= 0 then
		setArmament(entity, state, false)
		setObservation(entity, state, false)
	end
	replicate(entity, state)
	return true
end

function HakiService:IsArmamentActive(entity: CharacterEntity): boolean
	local state = states[entity]
	return state ~= nil and state.Armament
end

function HakiService:IsObservationActive(entity: CharacterEntity): boolean
	local state = states[entity]
	return state ~= nil and state.Observation
end

function HakiService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	CombatService = Knit.GetService("CombatService")
	StatService = Knit.GetService("StatService")
	FruitService = Knit.GetService("FruitService")
	WebhookService = Knit.GetService("WebhookService")
end

function HakiService:KnitStart()
	CombatService:RegisterModifier(observationModifier)

	CharacterService.EntityAdded:Connect(function(entity: CharacterEntity)
		local player = entity.Player
		if not player or not DataService:GetData(player) then
			return
		end

		local max = getMax(player)
		local state: HakiState = { Bar = max, Max = max, Armament = false, Observation = false, LastToggle = 0 }
		states[entity] = state
		replicate(entity, state)
	end)
	CharacterService.EntityRemoving:Connect(function(entity: CharacterEntity)
		states[entity] = nil
	end)

	HakiService.Client.ToggleArmament:Connect(function(player: Player)
		local entity, state = canToggle(player, StatConfig.HakiRequirement)
		if entity and state and (state.Armament or state.Bar > 1) then
			setArmament(entity, state, not state.Armament)
		end
	end)
	HakiService.Client.ToggleObservation:Connect(function(player: Player)
		local entity, state = canToggle(player, StatConfig.ObservationRequirement)
		if entity and state and (state.Observation or state.Bar > 1) then
			setObservation(entity, state, not state.Observation)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		toggleLimiter:Forget(player)
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			tick()
		end
	end)
end

return HakiService
