--!strict
--[[
	Luck fruit - state and helpers shared by its five abilities. Not an ability: the
	loader only looks modules up by ability name, so this one is never instantiated.

	The legacy script kept everything in script-level variables; sibling abilities
	share it through entity statuses instead:

		LuckPercent     replicated  the luck gauge, 0-100 (Effects.Status.LuckPercent
		                            draws the bar)
		LuckJackpot     replicated  triple seven running: gauge pinned at 100
		LuckMoment      replicated  5 s of luck after Fortune's Purge broke a seal
		LuckCasino      replicated  Golden Casino running ("Lucky" in the legacy code);
		                            value packed by PackCasino for the client
		LuckCasinoArea  server      { Position, Radius, EndsAt } of that casino

	"Lucky" (casino), "LuckMoment" and "Jackpot" all improve the rolls.

	Running effects (a jackpot, a casino, a die or a coin in the air) outlive a stun of
	their caster, as they did in the legacy game, and the Luck powers can be used while
	stunned (the legacy scripts never looked at the "powers disabled" flag): the
	abilities set KeepThroughStun. Only Fortune's Purge reads Shared.IsStunned.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity

export type CasinoArea = {
	Position: Vector3,
	Radius: number,
	EndsAt: number,
}

local Shared = {}

Shared.PercentStatus = "LuckPercent"
Shared.JackpotStatus = "LuckJackpot"
Shared.MomentStatus = "LuckMoment"
Shared.CasinoStatus = "LuckCasino"
Shared.CasinoAreaStatus = "LuckCasinoArea"

Shared.MaxLuck = 100

-- Written by StatusService while any stun is on the character.
local STUN_STATUS = "Stunned"
-- A character this close to the aim point is the target, whatever the angle.
local AIM_RADIUS = 8
-- The legacy auto target (AimModule): within AIM_FOV / (distance + 10) degrees of the
-- aimed line, never more than AIM_MAX_ANGLE.
local AIM_FOV = 500
local AIM_MAX_ANGLE = 20

local random = Random.new()

function Shared.Get(entity: CharacterEntity): number
	local luck = entity:GetStatus(Shared.PercentStatus)
	return if type(luck) == "number" then luck else 0
end

function Shared.Set(entity: CharacterEntity, luck: number)
	entity:SetStatus(Shared.PercentStatus, math.clamp(luck, 0, Shared.MaxLuck), nil, true)
end

-- Gains and costs. During a jackpot the gauge is pinned at 100, as the legacy loop did.
function Shared.Add(entity: CharacterEntity, amount: number)
	if entity:HasStatus(Shared.JackpotStatus) then
		return
	end
	Shared.Set(entity, Shared.Get(entity) + amount)
end

function Shared.IsLucky(entity: CharacterEntity): boolean
	return entity:HasStatus(Shared.CasinoStatus)
		or entity:HasStatus(Shared.MomentStatus)
		or entity:HasStatus(Shared.JackpotStatus)
end

-- A six-sided die; never below 4 while lucky.
function Shared.RollDie(entity: CharacterEntity): number
	return random:NextInteger(if Shared.IsLucky(entity) then 4 else 1, 6)
end

function Shared.Random(): number
	return random:NextNumber()
end

function Shared.IsStunned(entity: CharacterEntity): boolean
	return entity:HasStatus(STUN_STATUS)
end

--[[
	The character a die or a coin is thrown at, within `range` studs of the caster.

	The legacy client locked on whoever stood closest to the line of the cursor, seen
	from the camera, inside a cone that narrows with distance. The server only knows the
	aim point, so the line runs from the caster to that point; the distance along it is
	capped at the aim point as the legacy one was capped at what the cursor touched,
	which keeps the cone wide for an aim at the ground in front of somebody.
]]
function Shared.AimTarget(entity: CharacterEntity, aim: Vector3, range: number): CharacterEntity?
	local origin = entity.Root.Position
	local direct = Hitbox.Closest(Hitbox.Sphere(aim, AIM_RADIUS, entity), aim)
	if direct and (direct.Root.Position - origin).Magnitude <= range then
		return direct
	end

	local line = aim - origin
	local length = line.Magnitude
	if length < 1 then
		return nil
	end
	local unit = line / length

	local best: CharacterEntity? = nil
	local bestAngle = AIM_MAX_ANGLE
	for _, candidate in Hitbox.Sphere(origin, range, entity) do
		local offset = candidate.Root.Position - origin
		local distance = offset.Magnitude
		if distance < 1 then
			continue
		end

		local cosine = math.clamp(unit:Dot(offset / distance), -1, 1)
		local angle = math.deg(math.acos(cosine))
		local along = math.clamp(distance * cosine, 0.5, length)
		if angle < bestAngle and angle <= AIM_FOV / (along + 10) then
			best, bestAngle = candidate, angle
		end
	end
	return best
end

-- "x,y,z|diameter|hidden|colors": what Effects.Status.LuckCasino needs to draw the skull.
function Shared.PackCasino(position: Vector3, diameter: number, hidden: boolean, colors: string): string
	return string.format(
		"%.2f,%.2f,%.2f|%.2f|%d|%s",
		position.X,
		position.Y,
		position.Z,
		diameter,
		if hidden then 1 else 0,
		colors
	)
end

--[[
	Jackpot haki refill. HakiService has no method to change a bar yet; this calls
	HakiService:AddBar(entity, amount) if it exists and does nothing otherwise.
]]
function Shared.AddHaki(services: any, entity: CharacterEntity, amount: number)
	local haki = services.Haki
	local addBar = haki and haki.AddBar
	if type(addBar) == "function" then
		addBar(haki, entity, amount)
	end
end

return Shared
