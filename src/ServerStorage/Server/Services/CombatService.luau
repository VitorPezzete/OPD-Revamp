--!strict
--[[
	The only place health is taken away. Damage is always computed on the server from
	server state: clients never send an amount, a target's health, or a hit result.

	Mitigation is a list of modifiers sorted by priority. Systems (fruits, haki, crews)
	register their own modifier instead of adding a branch here, which is what turned
	the legacy Damage module into a 400-line chain of per-fruit conditions.

	Server API
		CombatService:Damage(request) -> damage dealt
		CombatService:RegisterModifier(modifier)
		CombatService.Damaged (context, dealt, amount) / Blocked (context) / Killed (target, attacker?)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Allies = require(ServerStorage.Server.Modules.Allies)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity
type DamageContext = CombatTypes.DamageContext

-- Hits from further than this are discarded as impossible.
local MAX_PLAYER_RANGE = 3000
local MAX_NPC_RANGE = 200
local DEFENSE_EXP_PER_HIT = 1

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		-- (amount, position, trait) to the attacker and the victim, for damage numbers.
		DamageDealt = Knit.CreateUnreliableSignal(),
	},
})

CombatService.Damaged = Signal.new() :: Signal.Signal<DamageContext, number>
CombatService.Blocked = Signal.new() :: Signal.Signal<DamageContext>
CombatService.Killed = Signal.new() :: Signal.Signal<CharacterEntity, CharacterEntity?>

local DataService
local StatService

local modifiers: { CombatTypes.DamageModifier } = {}

local function isValid(request: CombatTypes.DamageRequest): boolean
	local target, attacker = request.Target, request.Attacker
	local amount = request.Amount

	if amount ~= amount or math.abs(amount) == math.huge then
		return false
	end
	if target.Dead or not target.Spawned then
		return false
	end

	if attacker then
		if attacker == target or attacker.Dead or not attacker.Spawned then
			return false
		end
		-- Team mates, and with them every player of a raid (Allies).
		if Allies.SameSide(attacker, target) then
			return false
		end

		local range = if attacker.Player then MAX_PLAYER_RANGE else MAX_NPC_RANGE
		if (attacker.Root.Position - target.Root.Position).Magnitude > range then
			return false
		end
	end
	return true
end

function CombatService:RegisterModifier(modifier: CombatTypes.DamageModifier)
	table.insert(modifiers, modifier)
	table.sort(modifiers, function(a, b)
		return a.Priority < b.Priority
	end)
end

function CombatService:Damage(request: CombatTypes.DamageRequest): number
	if not isValid(request) then
		return 0
	end

	local target, attacker = request.Target, request.Attacker
	local context: DamageContext = {
		Target = target,
		Attacker = attacker,
		TargetData = if target.Player then DataService:GetData(target.Player) else nil,
		AttackerData = if attacker and attacker.Player then DataService:GetData(attacker.Player) else nil,
		Amount = math.max(0, request.Amount),
		TrueAmount = 0,
		Trait = request.Trait,
		Style = request.Style,
		Dodgeable = request.Dodgeable == true,
		Tag = request.Tag,
		Cancelled = false,
		CancelReason = nil,
	}

	for _, modifier in modifiers do
		modifier.Apply(context)
		if context.Cancelled then
			break
		end
	end

	-- Being hit trains defense, even when the hit is negated.
	if target.Player then
		StatService:AddExp(target.Player, "Defense", DEFENSE_EXP_PER_HIT, true)
	end

	if context.Cancelled then
		CombatService.Blocked:Fire(context)
		return 0
	end

	-- `amount` is what the attack does after every modifier; `dealt` is the health it
	-- actually took, which stops at whatever the target had left. Players are shown the
	-- first: a killing blow reads as the blow it was.
	local amount = math.max(0, context.Amount) + context.TrueAmount
	local dealt = target:TakeDamage(amount)
	CombatService.Damaged:Fire(context, dealt, amount)

	if dealt > 0 then
		local position = target.Root.Position
		if target.Player then
			CombatService.Client.DamageDealt:Fire(target.Player, amount, position, context.Trait)
		end
		if attacker and attacker.Player then
			CombatService.Client.DamageDealt:Fire(attacker.Player, amount, position, context.Trait)
		end
	end

	if target.Dead then
		CombatService.Killed:Fire(target, attacker)
	end
	return dealt
end

function CombatService:KnitInit()
	DataService = Knit.GetService("DataService")
	StatService = Knit.GetService("StatService")

	for _, module in ServerStorage.Server.Modules.DamageModifiers:GetChildren() do
		if module:IsA("ModuleScript") then
			CombatService:RegisterModifier((require :: any)(module))
		end
	end
end

return CombatService
