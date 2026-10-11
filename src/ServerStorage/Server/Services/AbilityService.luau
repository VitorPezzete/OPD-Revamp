--!strict
--[[
	Single entry point for devil fruit abilities.

	The client sends only: which fruit slot, which ability slot, pressed or released,
	and where it is aiming. Everything else is resolved here from server state:
	which fruit that is, whether the ability exists, the level requirement, cooldown,
	whether the character is alive / spawned / sealed, and whether the aim point is sane.
	Ability code therefore never sees unvalidated client data.

	Ability classes live in Server.Modules.Abilities.<FruitName>.<Ability Name>.

	Passives (always on while the fruit is owned: logia immunities, day/night bonuses...)
	live in Server.Modules.Passives.<FruitName> and return
		function(entity, player, data, fruitSlot) -> cleanup
	They start when the character is created or the fruit is gained, and their cleanup
	runs when the character or the fruit goes away.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local FlightLock = require(ServerStorage.Server.Modules.FlightLock)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

type CharacterEntity = CharacterEntity.CharacterEntity
type Ability = Ability.Ability

local PHASE_BEGIN = 1
local PHASE_END = 2
-- Secondary input while an ability is active (e.g. a click that swings a summoned blade).
local PHASE_ACTION = 3

local AbilityService = Knit.CreateService({
	Name = "AbilityService",
	Client = {
		-- Client -> server: (fruitSlot, abilitySlot, phase, aimPosition)
		Input = Knit.CreateSignal(),
		-- Server -> owner: (fruitSlot, abilitySlot, kind, seconds), for the ability bar.
		-- kind: "Cooldown" (unusable for seconds), "Charge" (full in seconds, 0 = unknown),
		-- "ChargeEnd".
		State = Knit.CreateSignal(),
	},
})

-- (entity, fruitName, abilityName) after an ability accepts a press. Lets abilities react to
-- each other (e.g. flight that stops when another power is used) without knowing them.
AbilityService.Used = Signal.new() :: Signal.Signal<CharacterEntity, string, string>

local DataService
local CharacterService

local abilityFolder: Instance
local seals: { [CharacterEntity]: { [string]: any } } = {}
local passiveFolder: Instance?
local passives: { [CharacterEntity]: { () -> () } } = {}

local function stopPassives(entity: CharacterEntity)
	local running = passives[entity]
	if running then
		passives[entity] = nil
		for _, cleanup in running do
			task.spawn(cleanup)
		end
	end
end

local function startPassives(entity: CharacterEntity)
	stopPassives(entity)

	local player = entity.Player
	local data = player and DataService:GetData(player)
	if not player or not data or not passiveFolder or entity.Dead then
		return
	end

	local running: { () -> () } = {}
	local fruits = data.Data.DevilFruits
	for fruitSlot, fruitName in { fruits.Slot1.Name, fruits.Slot2.Name } do
		local module = passiveFolder:FindFirstChild(fruitName)
		if module and module:IsA("ModuleScript") then
			local cleanup = (require :: any)(module)(entity, player, data, fruitSlot)
			if type(cleanup) == "function" then
				table.insert(running, cleanup)
			end
		end
	end
	passives[entity] = running
end
local classCache: { [string]: any } = {}
local instances: { [CharacterEntity]: { [number]: Ability } } = {}
local inputLimiter = RateLimiter.new(AbilityConfig.InputBudget[1], AbilityConfig.InputBudget[2])
local releaseLimiter = RateLimiter.new(AbilityConfig.InputBudget[1], AbilityConfig.InputBudget[2])

-- false is cached too, so a missing module is looked up (and warned about) once.
local function getClass(fruitName: string, abilityName: string): any
	local key = `{fruitName}/{abilityName}`
	local class = classCache[key]
	if class == nil then
		local folder = abilityFolder:FindFirstChild(fruitName)
		local module = folder and folder:FindFirstChild(abilityName)
		if module and module:IsA("ModuleScript") then
			class = (require :: any)(module)
		else
			class = false
		end
		classCache[key] = class
	end
	return class or nil
end

-- Requires every ability of a fruit ahead of its first press, so that press does not
-- pay for loading the module. Once per fruit per server.
local preloaded: { [string]: boolean } = {}
local function preloadFruit(fruitName: string)
	if preloaded[fruitName] then
		return
	end
	preloaded[fruitName] = true
	local fruit = FruitConfig.Fruits[fruitName]
	if not fruit then
		return
	end
	task.spawn(function()
		for _, definition in fruit.Abilities do
			getClass(fruitName, definition.Name)
			task.wait()
		end
	end)
end

local function isFiniteVector(value: Vector3): boolean
	return value.X == value.X and value.Y == value.Y and value.Z == value.Z and value.Magnitude < math.huge
end

-- Returns every ability of the character to neutral. The objects are kept (so their
-- cooldowns survive a stun) unless `drop` is set, which is for a lost fruit or character.
local function interruptAll(entity: CharacterEntity, drop: boolean?, fromStun: boolean?, fromSeal: boolean?)
	local owned = instances[entity]
	if not owned then
		return
	end
	if drop then
		instances[entity] = nil
	end
	for _, ability in owned do
		-- Abilities flagged KeepThroughStun (rooms, projections) outlive a plain stun;
		-- KeepThroughSeal / IgnoreSeal ones outlive a seal.
		local class = ability :: any
		local kept = (fromStun and class.KeepThroughStun) or (fromSeal and (class.KeepThroughSeal or class.IgnoreSeal))
		if not kept then
			ability:Destroy()
		end
	end
end

local function dropAll(entity: CharacterEntity)
	interruptAll(entity, true)
end

local function getOrCreate(
	entity: CharacterEntity,
	player: Player,
	data: PlayerData.PlayerData,
	fruitName: string,
	fruitSlot: number,
	definition: FruitConfig.AbilityDefinition
): Ability?
	local owned = instances[entity]
	if not owned then
		owned = {}
		instances[entity] = owned
	end

	local key = fruitSlot * 10 + definition.Slot
	local ability = owned[key]
	if not ability then
		local class = getClass(fruitName, definition.Name)
		if not class then
			return nil
		end

		ability = class.new({
			Entity = entity,
			Player = player,
			Data = data,
			FruitName = fruitName,
			FruitSlot = fruitSlot,
			Definition = definition,
		})
		owned[key] = ability
	end
	return ability
end

local function onInput(player: Player, fruitSlot: unknown, abilitySlot: unknown, phase: unknown, aim: unknown)
	-- A release is never dropped for lack of budget (a charge would stay stuck): it has a
	-- budget of its own, only there to stop a flood.
	if phase == PHASE_END then
		if not releaseLimiter:Consume(player) then
			return
		end
	elseif not inputLimiter:Consume(player) then
		return
	end
	if fruitSlot ~= 1 and fruitSlot ~= 2 then
		return
	end
	if type(abilitySlot) ~= "number" or abilitySlot % 1 ~= 0 or abilitySlot < 1 or abilitySlot > 6 then
		return
	end
	if phase ~= PHASE_BEGIN and phase ~= PHASE_END and phase ~= PHASE_ACTION then
		return
	end
	if typeof(aim) ~= "Vector3" or not isFiniteVector(aim :: Vector3) then
		return
	end

	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not data or not entity or entity.Dead or not entity.Spawned then
		return
	end

	local fruits = data.Data.DevilFruits
	local fruitName = if fruitSlot == 1 then fruits.Slot1.Name else fruits.Slot2.Name
	-- nil as well for an ability that is switched off (AbilityDefinition.Disabled).
	local definition = FruitConfig.GetAbility(fruitName, abilitySlot)
	if not definition then
		return
	end
	if data.Data.Skills[definition.Skill].Level < definition.Requirement then
		return
	end

	local aimPosition = aim :: Vector3
	local aimOffset = aimPosition - entity.Root.Position
	if aimOffset.Magnitude > AbilityConfig.HardMaxAimDistance then
		return
	end

	local ability = getOrCreate(entity, player, data, fruitName, fruitSlot :: number, definition)
	if not ability then
		return
	end

	-- Further than this ability reaches: the same direction, at its reach.
	local reach = math.clamp(
		(ability :: any).MaxAimDistance or AbilityConfig.MaxAimDistance,
		AbilityConfig.MaxAimDistance,
		AbilityConfig.HardMaxAimDistance
	)
	if aimOffset.Magnitude > reach then
		aimPosition = entity.Root.Position + aimOffset.Unit * reach
	end

	local input: Ability.AbilityInput = { AimPosition = aimPosition }
	local sealed = entity:HasStatus(AbilityConfig.Status.AbilitiesDisabled) and not (ability :: any).IgnoreSeal
	-- When this ability's key grounds the character's flights (never a flight's own key).
	local lockMode: FlightLock.Mode = if (ability :: any).Flight
		then "None"
		else FlightLock.GetMode(fruitName, definition.Name)

	if phase == PHASE_END then
		if not sealed and (lockMode == "Release" or lockMode == "Both") then
			AbilityService:RaiseFlightLock(entity)
		end
		-- Releases are always delivered so a charge can never get stuck.
		ability:OnEnd(input)
		return
	end

	if sealed then
		return
	end
	-- A stun interrupts once when it lands; this keeps powers off for its whole length.
	if entity:HasStatus("Stunned") and not ability.KeepThroughStun then
		return
	end

	if phase == PHASE_ACTION then
		if ability.Active then
			ability:OnAction(input)
		end
		return
	end

	-- Before the ability's own gates: the legacy client raised the counter and only then
	-- asked the server, so a press refused for its cooldown grounded the flights too.
	if lockMode == "Press" or lockMode == "Both" then
		AbilityService:RaiseFlightLock(entity)
	end

	local now = os.clock()
	if now - ability.LastBegin < ability.Debounce or not ability:CanBegin(input) then
		return
	end
	ability.LastBegin = now
	ability.CooldownReported = false
	ability:OnBegin(input)
	-- Abilities without a cooldown of their own show their debounce.
	if not ability.CooldownReported and ability.Debounce > AbilityConfig.DefaultDebounce then
		AbilityService:Report(ability, "Cooldown", ability.Debounce)
	end
	AbilityService.Used:Fire(entity, fruitName, definition.Name)
end

-- Sends an ability's cooldown / charge to its caster's HUD. NPC casters have no HUD.
function AbilityService:Report(ability: Ability, kind: string, seconds: number)
	local player = ability.Player
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
		return
	end
	local context = ability.Context
	AbilityService.Client.State:Fire(player, context.FruitSlot, context.Definition.Slot, kind, seconds)
end

--[[
	The legacy "flight disabler" (Server.Modules.FlightLock): lands every flight of the
	character and refuses their take-off for `seconds` (default
	AbilityConfig.FlightLockSeconds) from now. Called here for the key events of the
	abilities that raised the legacy counter; abilities whose legacy server script raised
	it by itself (Slash Frenzy each round, Bomb Full Body while charging) call it too.
]]
-- When the flight lock of each character runs out (os.clock).
local flightLockEnds: { [CharacterEntity]: number } = setmetatable({} :: any, { __mode = "k" })

function AbilityService:RaiseFlightLock(entity: CharacterEntity, seconds: number?)
	-- Never shortens a lock already running: an ability that holds it for its whole length
	-- (Torque Mochi) is not cut back to the default by the next key press.
	local length = seconds or AbilityConfig.FlightLockSeconds
	local now = os.clock()
	local endsAt = math.max(now + length, flightLockEnds[entity] or 0)
	flightLockEnds[entity] = endsAt
	entity:SetStatus(AbilityConfig.Status.FlightLock, true, endsAt - now)

	local owned = instances[entity]
	if not owned then
		return
	end
	for _, ability in owned do
		-- Not gated on ability.Active: most flights keep their state in an entity status.
		-- Their OnInterrupt is the landing and does nothing on the ground.
		if (ability :: any).Flight then
			ability:Destroy()
		end
	end
end

-- Runs an input through the same validation as a client request (NPC casters, tests).
function AbilityService:HandleInput(player: Player, fruitSlot: number, abilitySlot: number, phase: number, aim: Vector3)
	onInput(player, fruitSlot, abilitySlot, phase, aim)
end

--[[
	Seals or unseals a character's fruit powers. Sealing interrupts everything running.
	Seals are counted per `source` (default "Default"), so one system lifting its seal
	never lifts another's: the powers come back only when every source has released.
]]
function AbilityService:SetSealed(entity: CharacterEntity, sealed: boolean, duration: number?, source: string?)
	local key = source or "Default"
	local sources = seals[entity]
	if not sources then
		sources = {}
		seals[entity] = sources
	end

	if sealed then
		local token = {}
		sources[key] = token
		entity:SetStatus(AbilityConfig.Status.AbilitiesDisabled, true, nil, true)
		interruptAll(entity, false, false, true)
		if duration then
			task.delay(duration, function()
				if seals[entity] == sources and sources[key] == token then
					AbilityService:SetSealed(entity, false, nil, key)
				end
			end)
		end
		return
	end

	sources[key] = nil
	if next(sources) == nil then
		seals[entity] = nil
		entity:ClearStatus(AbilityConfig.Status.AbilitiesDisabled)
	end
end

-- Stops every running ability of a character (death, fruit removed, stun effects).
function AbilityService:Interrupt(entity: CharacterEntity)
	interruptAll(entity)
end

-- Same, for stuns: abilities whose class sets `KeepThroughStun = true` keep running.
function AbilityService:InterruptForStun(entity: CharacterEntity)
	interruptAll(entity, false, true)
end

function AbilityService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	abilityFolder = ServerStorage.Server.Modules.Abilities
	passiveFolder = ServerStorage.Server.Modules:FindFirstChild("Passives")
end

function AbilityService:KnitStart()
	Ability.Services.Combat = Knit.GetService("CombatService")
	Ability.Services.Character = CharacterService
	Ability.Services.Effect = Knit.GetService("EffectService")
	Ability.Services.Status = Knit.GetService("StatusService")
	Ability.Services.Stat = Knit.GetService("StatService")
	Ability.Services.Ability = AbilityService
	Ability.Services.Fruit = Knit.GetService("FruitService")
	Ability.Services.Haki = Knit.GetService("HakiService")

	AbilityService.Client.Input:Connect(onInput)

	CharacterService.EntityAdded:Connect(function(entity: CharacterEntity)
		entity.Died:Connect(function()
			interruptAll(entity)
			stopPassives(entity)
		end)
		startPassives(entity)
	end)
	CharacterService.EntityRemoving:Connect(function(entity: CharacterEntity)
		dropAll(entity)
		seals[entity] = nil
		stopPassives(entity)
	end)

	-- Losing or swapping a fruit drops every ability object built for the old one.
	DataService:ObserveData(function(player: Player, data: PlayerData.PlayerData)
		preloadFruit(data.Data.DevilFruits.Slot1.Name)
		preloadFruit(data.Data.DevilFruits.Slot2.Name)
		data:Observe("DevilFruits", function()
			local fruits = data.Data.DevilFruits
			preloadFruit(fruits.Slot1.Name)
			preloadFruit(fruits.Slot2.Name)
			local entity = CharacterService:GetPlayerEntity(player)
			if entity then
				dropAll(entity)
				startPassives(entity)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		inputLimiter:Forget(player)
		releaseLimiter:Forget(player)
	end)
end

return AbilityService
