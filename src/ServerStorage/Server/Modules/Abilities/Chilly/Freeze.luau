--!strict
--[[
	Chilly fruit - shared freeze ("ChillyPunched" in the legacy game). Not an ability:
	Freezing Punch and Ice Wave both require this module.

	A frozen victim is stunned for `duration` seconds and takes `damagePerSecond` once a
	second, ceil(duration) times, the first one immediately (Special, not dodgeable).
	After being frozen a victim cannot be frozen again for 15 seconds, whoever tries.
	Quake and Luck users cannot be frozen at all.

	The replicated "ChillyPunched" status (value: the attacker's fruit color string)
	drives the ice shell on the victim (Effects.Status.ChillyPunched) and the HUD icon.

	Legacy problems fixed here:
	- Every character carried a control Script polling a BoolValue every frame.
	- NPC victims were stunned 1.1 s at a time inside the damage loop and their walk speed
	  was overwritten directly; players and NPCs now share one path.
	- The immunity test compared `df1.Value` of a string (always nil), so Quake / Luck
	  users were in fact frozen by the punch; the intended immunity is applied.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "ChillyPunched"
local STUN_NAME = "ChillyFrozen"
local DOT_NAME = "ChillyFreezeDot"
local COOLDOWN_STATUS = "ChillyFreezeCooldown"
local COOLDOWN_SECONDS = 15
local TICK_INTERVAL = 1
local IMMUNE_FRUITS = { "Quake", "Luck" }

local Freeze = {}

-- `ability` is the Ability object doing the freezing. Returns whether the target froze.
function Freeze.Apply(ability: any, target: CharacterEntity, damagePerSecond: number, duration: number): boolean
	if duration <= 0 or target.Dead or target == ability.Entity or target:HasStatus(COOLDOWN_STATUS) then
		return false
	end

	local player = target.Player
	if player then
		for _, fruitName in IMMUNE_FRUITS do
			if ability.Services.Fruit:HasFruit(player, fruitName) then
				return false
			end
		end
	end

	target:SetStatus(COOLDOWN_STATUS, true, COOLDOWN_SECONDS)
	ability.Services.Status:ApplyStun(target, duration, STUN_NAME)
	target:SetStatus(STATUS, ability:GetColorString(), duration, true)

	ability:Damage(target, damagePerSecond, "Special", STATUS, false)

	local remainingTicks = math.ceil(duration / TICK_INTERVAL) - 1
	if remainingTicks > 0 then
		ability.Services.Status:ApplyDot(target, DOT_NAME, {
			Source = ability.Entity,
			Damage = damagePerSecond,
			Interval = TICK_INTERVAL,
			Ticks = remainingTicks,
			Trait = "Special",
		})
	end
	return true
end

return Freeze
