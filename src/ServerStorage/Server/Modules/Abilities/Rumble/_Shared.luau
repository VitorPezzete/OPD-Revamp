--!strict
--[[
	Rumble fruit - rules shared by its abilities (not an ability: AbilityService only
	loads modules named after an ability of FruitConfig).

	Rubber. Every legacy Rumble hit on a Gum user was dealt as "Melee" damage instead of
	"Special", which the Gum user's own melee immunity then negates.

	Electrocution ("RumbleStun"). El Thor stuns the players it hits for 1.25 s, and the
	same player cannot be stunned again for 6 s. Legacy details kept:
	- only players: enemies never had the RumbleStun value, so the stun did nothing to them;
	- the 6 s window is per victim, whoever the Rumble user is.
	Legacy detail changed: the control script exempted a victim only when BOTH fruit slots
	held Gum (`table.find(immune, df1) and table.find(immune, df2)`), which can never be
	true. It is read as the obviously intended "a Gum user is not electrocuted".

	The replicated, timed "RumbleStun" status drives the electrocution animation on the
	clients (Effects.Status.RumbleStun); the root and the ability interruption come from
	StatusService:ApplyStun.

	Hands. El Thor and Lightning Blitz are cast from the right hand, then the left, and
	so on: each release of either one passes the turn (the legacy client kept a single
	"ChargeMode" for both). The turn is an entity status because sibling abilities do not
	see each other's objects.

	Charge clock. For El Thor and Lightning Blitz the legacy server stored the moment the
	charge began in an IntValue (`PowerN.Charge.Value = time()`), which rounds to the
	nearest whole second, and measured the charge from that rounded moment: a release
	counted up to half a second (12.5 charge) more or less than what was really held,
	while the client's charge bar showed the real hold. BeginCharge / EndCharge reproduce
	it (it decides, among other things, whether a short El Thor comes out as the beam or
	as the cloud).
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

local RUBBER_FRUIT = "Gum"
local STUN_STATUS = "RumbleStun"
local STUN_COOLDOWN_STATUS = "RumbleStunCooldown"
local STUN_SECONDS = 1.25
local STUN_COOLDOWN = 6
local LEFT_HAND_STATUS = "RumbleLeftHand"

local Shared = {}

-- Set (replicated, they drive the charge visuals) by El Thor and Lightning Blitz while
-- they charge: the legacy game refused to start charging one while the other was charging.
Shared.ThorChargeStatus = "RumbleThorCharging"
Shared.BlitzChargeStatus = "RumbleBlitzCharging"

function Shared.BeginCharge(ability: any, fullSeconds: number)
	ability:BeginCharge(fullSeconds)
	ability.ChargeBegan = time()
end

-- The charge the legacy server would have computed, or nil when nothing was charging.
function Shared.EndCharge(ability: any, rate: number, minimum: number, maximum: number): number?
	local held = ability:EndCharge(rate, minimum, maximum)
	local began: number? = ability.ChargeBegan
	ability.ChargeBegan = nil
	if not held or not began then
		return nil
	end
	return math.floor(math.clamp((time() - math.round(began)) * rate, minimum, maximum))
end

-- "Right" or "Left": the hand the next El Thor / Lightning Blitz is cast from.
function Shared.GetHand(entity: CharacterEntity): string
	return if entity:HasStatus(LEFT_HAND_STATUS) then "Left" else "Right"
end

function Shared.SwapHand(entity: CharacterEntity)
	entity:SetStatus(LEFT_HAND_STATUS, not entity:HasStatus(LEFT_HAND_STATUS))
end

function Shared.GetHandPosition(entity: CharacterEntity, hand: string): Vector3
	local arm = entity.Model:FindFirstChild(hand .. " Arm")
	return if arm and arm:IsA("BasePart") then arm.Position else entity.Root.Position
end

function Shared.IsRubber(services: any, target: CharacterEntity): boolean
	local player = target.Player
	return player ~= nil and services.Fruit:HasFruit(player, RUBBER_FRUIT) == true
end

-- Trait of a lightning hit on this target.
function Shared.TraitFor(services: any, target: CharacterEntity): CombatTypes.DamageTrait
	return if Shared.IsRubber(services, target) then "Melee" else "Special"
end

function Shared.Electrocute(services: any, target: CharacterEntity)
	if not target.Player or target.Dead or target:HasStatus(STUN_COOLDOWN_STATUS) then
		return
	end
	if Shared.IsRubber(services, target) then
		return
	end

	target:SetStatus(STUN_COOLDOWN_STATUS, true, STUN_COOLDOWN)
	target:SetStatus(STUN_STATUS, true, STUN_SECONDS, true)
	services.Status:ApplyStun(target, STUN_SECONDS, STUN_STATUS)
end

return Shared
