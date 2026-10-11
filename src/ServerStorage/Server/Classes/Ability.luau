--!strict
--[[
	Base class of every devil fruit ability. One instance exists per character per
	ability, created by AbilityService the first time the ability is used and destroyed
	with the character (or when the fruit is removed).

	The legacy game had one 600-1900 line LocalScript plus one server Script per fruit,
	each repeating ownership, level and cooldown checks. Those checks now live in
	AbilityService; a subclass only describes what the ability does:

		local Ability = require(ServerStorage.Server.Classes.Ability)

		local MyAbility = Ability.extend()

		function MyAbility:OnBegin(input) ... end      -- key pressed
		function MyAbility:OnEnd(input) ... end        -- key released (charged abilities)
		function MyAbility:OnInterrupt() ... end       -- death / sealed / fruit lost

	OnInterrupt must always leave the character in a neutral state: it is the single
	cleanup path, which is what most legacy "stuck state" bugs were missing.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)
local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)
local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

export type AbilityInput = {
	-- Validated point in the world the player is aiming at.
	AimPosition: Vector3,
}

export type AbilityContext = {
	Entity: CharacterEntity.CharacterEntity,
	Player: Player,
	Data: PlayerData.PlayerData,
	FruitName: string,
	-- Which of the player's two fruit slots holds this fruit.
	FruitSlot: number,
	Definition: FruitConfig.AbilityDefinition,
}

local Ability = {}
Ability.__index = Ability

-- Minimum seconds between two accepted Begin inputs. Subclasses may override.
Ability.Debounce = AbilityConfig.DefaultDebounce

-- Set to true on a subclass whose effect should keep running while its caster is stunned.
Ability.KeepThroughStun = false
-- The same for a seal (AbilitiesDisabled): what is already running keeps running. New
-- presses are still refused while sealed.
Ability.KeepThroughSeal = false
-- Set to true on a subclass the seal does not stop at all: its presses go through while
-- the character's powers are disabled (the legacy scripts of some fruits never checked).
Ability.IgnoreSeal = false
-- Style of the damage Ability.Damage deals. "Plain" on a subclass whose legacy script
-- dealt its damage without a style: the target's ResistAbilities perk does not apply.
Ability.DamageStyle = "Ability" :: CombatTypes.DamageStyle
-- Studs from the caster an aim point may be for this ability, when it needs more than
-- AbilityConfig.MaxAimDistance (never more than AbilityConfig.HardMaxAimDistance).
Ability.MaxAimDistance = nil :: number?
-- Set to true on a flight toggle the legacy "flight disabler" grounded (see
-- Server.Modules.FlightLock): AbilityService interrupts it when the character's flight
-- lock is raised, and its own presses never raise the lock. Such a class must refuse to
-- take off while IsFlightBlocked() and must land in OnInterrupt.
Ability.Flight = false

-- Knit services, filled in by AbilityService once Knit has started.
Ability.Services = {} :: {
	Combat: any,
	Character: any,
	Effect: any,
	Status: any,
	Stat: any,
	Ability: any,
	Fruit: any,
	Haki: any,
}

export type Ability = typeof(setmetatable(
	{} :: {
		Context: AbilityContext,
		Entity: CharacterEntity.CharacterEntity,
		Player: Player,
		-- Free for subclasses: true while a toggle / channel is running.
		Active: boolean,
		LastBegin: number,
		-- os.clock() of the press that started the current charge, if any.
		ChargeStart: number?,
		-- Set by StartCooldown; AbilityService reads it to know whether the press that
		-- just ran reported a cooldown of its own.
		CooldownReported: boolean,
	},
	Ability
))

function Ability.new(context: AbilityContext): Ability
	return setmetatable({
		Context = context,
		Entity = context.Entity,
		Player = context.Player,
		Active = false,
		LastBegin = 0,
		ChargeStart = nil,
		CooldownReported = false,
	}, Ability)
end

-- Creates a subclass table whose instances fall back to Ability.
function Ability.extend(): any
	local class = setmetatable({}, { __index = Ability })
	class.__index = class
	class.new = function(context: AbilityContext)
		return setmetatable(Ability.new(context) :: any, class)
	end
	return class
end

-- Extra, ability-specific gate checked before OnBegin (sitting, rooted, resources...).
function Ability.CanBegin(_self: Ability, _input: AbilityInput): boolean
	return true
end

function Ability.OnBegin(_self: Ability, _input: AbilityInput) end

function Ability.OnEnd(_self: Ability, _input: AbilityInput) end

-- Secondary input while self.Active is true (sent by the ability's own client effect
-- as phase 3 of AbilityService.Input). Not debounced: rate-limit it yourself.
function Ability.OnAction(_self: Ability, _input: AbilityInput) end

function Ability.OnInterrupt(_self: Ability) end

--[[
	For the CanBegin of a flight: true while the character may not take off, because its
	flight lock is up (a power was used in the last seconds) or it carries a NoMovement
	status (Slash Frenzy). Pass `ignoreNoMovement` for the flights whose legacy server
	script did not check the NoMovement flag (Gravity Flying, Smoke's Fly).
]]
function Ability.IsFlightBlocked(self: Ability, ignoreNoMovement: boolean?): boolean
	local entity = self.Entity
	if entity:HasStatus(AbilityConfig.Status.FlightLock) then
		return true
	end
	if not ignoreNoMovement then
		for _, status in MovementConfig.NoMovementStatuses do
			if entity:HasStatus(status) then
				return true
			end
		end
	end
	return false
end

-- Multiplier (1.0-2.0) the eaten fruit item rolled for a skill.
function Ability.GetAffinity(self: Ability, skill: "Melee" | "Defense" | "Sniper" | "Sword"): number
	local affinities = self.Context.Data.Data.Affinities
	local slot = if self.Context.FruitSlot == 1 then affinities.DF1 else affinities.DF2
	return slot[skill]
end

function Ability.GetLevel(self: Ability, skill: DataTypes.SkillName): number
	return self.Context.Data.Data.Skills[skill].Level
end

-- Level as a 0-1 fraction of the skill cap: the scaling term of most legacy formulas.
function Ability.GetLevelScale(self: Ability, skill: DataTypes.SkillName): number
	return self:GetLevel(skill) / StatConfig.Caps[skill]
end

-- Saved effect colors of the fruit ("r,g,b,r,g,b"), or "None".
function Ability.GetColorString(self: Ability): string
	local fruits = self.Context.Data.Data.DevilFruits
	return if self.Context.FruitSlot == 1 then fruits.Slot1.Color else fruits.Slot2.Color
end

-- Deals ability damage from this character through the combat pipeline.
function Ability.Damage(
	self: Ability,
	target: CharacterEntity.CharacterEntity,
	amount: number,
	trait: CombatTypes.DamageTrait?,
	tag: string?,
	dodgeable: boolean?
): number
	return self.Services.Combat:Damage({
		Target = target,
		Attacker = self.Entity,
		Amount = amount,
		Trait = trait or "Special",
		Style = self.DamageStyle,
		Dodgeable = dodgeable ~= false,
		Tag = tag,
	})
end

-- One-shot visual for nearby clients. The fruit's color string is added as params.Colors.
-- `radius` widens who receives it (default AbilityConfig.EffectRadius) for map-scale effects.
function Ability.PlayEffect(self: Ability, effectName: string, origin: Vector3, params: { [string]: any }?, radius: number?)
	local payload = params or {}
	payload.Colors = self:GetColorString()
	payload.Caster = self.Entity.Model
	self.Services.Effect:Play(effectName, origin, payload, radius)
end

-- Knockback: launches a target with the given velocity (studs per second).
function Ability.Impulse(
	self: Ability,
	target: CharacterEntity.CharacterEntity,
	velocity: Vector3,
	duration: number?,
	maxForce: Vector3?,
	power: number?
)
	self.Services.Character:ApplyImpulse(target, velocity, duration, maxForce, power)
end

--[[
	Tells the caster's HUD that the ability cannot be used again for `seconds` from now.
	Call it where the cooldown really starts (often not the press: a cast that lands, a
	charge released). Display only: the gate is still the ability's own check. An ability
	that never calls it shows its Debounce, when that is longer than the default.
]]
function Ability.StartCooldown(self: Ability, seconds: number)
	self.CooldownReported = true
	self.Services.Ability:Report(self, "Cooldown", seconds)
end

--[[
	Charged abilities: call BeginCharge in OnBegin and EndCharge in OnEnd.
	`fullSeconds` is how long the hold takes to reach the maximum charge (maximum / rate
	of the EndCharge call); the caster's HUD fills its charge bar over it.
]]
function Ability.BeginCharge(self: Ability, fullSeconds: number?)
	self.ChargeStart = os.clock()
	self.Services.Ability:Report(self, "Charge", fullSeconds or 0)
end

--[[
	Returns the charge reached (seconds held * rate, clamped), or nil when no charge was
	running. Time is measured on the server, so the client cannot claim a longer hold.
]]
function Ability.EndCharge(self: Ability, rate: number, minimum: number, maximum: number): number?
	local start = self.ChargeStart
	if not start then
		return nil
	end
	self.ChargeStart = nil
	self.Services.Ability:Report(self, "ChargeEnd", 0)
	return math.floor(math.clamp((os.clock() - start) * rate, minimum, maximum))
end

function Ability.Destroy(self: Ability)
	if self.ChargeStart then
		self.Services.Ability:Report(self, "ChargeEnd", 0)
	end
	self.ChargeStart = nil
	self:OnInterrupt()
	self.Active = false
end

return Ability
