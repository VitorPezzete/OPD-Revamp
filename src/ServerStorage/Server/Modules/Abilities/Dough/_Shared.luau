--!strict
--[[
	Dough fruit - state and helpers shared by its six abilities. Not an ability: the loader
	only looks modules up by ability name, so this one is never instantiated.

	Source: the place dumped under .sync/place2 (DF Dough server script, Dough LocalScript,
	ClientEffects/Dough). Every number below and in the six abilities is the source's.

	Power factor. Every source formula starts from
		f = ((level / 500) / 2) * affinity
	with the level and affinity of the ability's own skill (FruitConfig): Shared.Factor.
	The charged abilities then multiply it by `held seconds / full charge`.

	One power at a time. The source server kept one `using` variable for Burning Mochi,
	Dough Bazooka, Mochi Gatling and Torque Mochi: while one of them was charging / held,
	the presses of the other three were refused. Mochi Wasteland never set it (it only
	asked that nothing else was in use when pressed) and Donut Roll was driven by the client,
	which did not look at it at all. That variable is the non-replicated entity status
	DoughUsing (value: the ability's name) here, since sibling abilities do not see each
	other's objects.

	Haki. The source read `UsingHaki`; armament haki doubles (or, for the two mochi punches,
	turns from "Melee" halved into "Haki" full) the damage as written in each ability.

	Entity statuses of the fruit (all start with "Dough"):
		DoughUsing          server      see above
		DoughCharging       replicated  Burning Mochi / Dough Bazooka being charged
		DoughGatling        replicated  Mochi Gatling held
		DoughRoll           replicated  Donut Roll on
		DoughMochiCovered   replicated  standing in someone's Mochi Wasteland (the DoT)
		DoughTorqueMochi    replicated  Torque Mochi spinning (caster)
		DoughTorqueRelease  replicated  ... and its last 1.1 s (value: seconds charged)
		DoughTorqueCaught   replicated  stuck on someone's Torque Mochi (victim)
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

local Shared = {}

Shared.UsingStatus = "DoughUsing"
Shared.ChargingStatus = "DoughCharging"
Shared.CoveredStatus = "DoughMochiCovered"
Shared.TorqueStatus = "DoughTorqueMochi"
Shared.TorqueReleaseStatus = "DoughTorqueRelease"
Shared.CaughtStatus = "DoughTorqueCaught"

-- The source's `((statLevel / 500) / 2) * affinity`.
function Shared.Factor(ability: any, skill: string): number
	return ability:GetLevelScale(skill) / 2 * ability:GetAffinity(skill)
end

function Shared.Haki(ability: any): boolean
	return ability.Services.Haki:IsArmamentActive(ability.Entity) == true
end

function Shared.IsUsing(entity: CharacterEntity): boolean
	return entity:HasStatus(Shared.UsingStatus)
end

function Shared.SetUsing(entity: CharacterEntity, abilityName: string)
	entity:SetStatus(Shared.UsingStatus, abilityName)
end

-- Only the ability that holds the flag lowers it.
function Shared.ClearUsing(entity: CharacterEntity, abilityName: string)
	if entity:GetStatus(Shared.UsingStatus) == abilityName then
		entity:ClearStatus(Shared.UsingStatus)
	end
end

-- Seconds held, measured on the server, clamped like the source's `math.clamp(os.clock() - charge, ...)`.
function Shared.HeldSeconds(ability: any, minimum: number, maximum: number): number?
	-- EndCharge floors its result: hundredths of a second keep the source's resolution.
	local hundredths = ability:EndCharge(100, minimum * 100, maximum * 100)
	return if hundredths then hundredths / 100 else nil
end

-- Position of the centre of a character's torso (the source pushed and aimed at Torso).
function Shared.TorsoPosition(entity: CharacterEntity): Vector3
	local torso = entity.Model:FindFirstChild("Torso")
	return if torso and torso:IsA("BasePart") then torso.Position else entity.Root.Position
end

return Shared
