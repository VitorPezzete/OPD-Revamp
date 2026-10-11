--!strict
--[[
	Dark fruit - state shared by its four abilities. Not an ability: the loader only
	looks modules up by ability name, so this one is never instantiated.

	The legacy script kept this in values under the fruit's scripts; sibling abilities
	share it through entity statuses instead:

		DarkCooldown      server      the cooldown Dark Vortex (8 s) and Black Hole (17 s)
		                              share; Dark Charge also waits for it
		DarkRecent        server      "RecentlyDarked": Dark Star cannot start charging;
		                              the value is the os.clock() it ends at
		DarkCharging      replicated  Dark Charge is absorbing (value: fruit colors)
		DarkChargeState   server      { Charge, Cap, Absorbed } filled by
		                              DamageModifiers.DarkCharge
		DarkChargeGuide   replicated  diameter of the disc the user sees under its feet
		                              while absorbing (it grows with the charge)
		DarkStarCharging  replicated  Dark Star is being charged: the legacy client refused
		                              the three other powers meanwhile (Shared.CanCast)
		DarkPulled        replicated  a victim dragged to a point
		                              ("x|y|z|forceX|forceY|forceZ|P|D": the point and the
		                              legacy BodyPosition that dragged it); the victim's
		                              client does the pulling (Effects.Status.DarkPulled)
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

export type ChargeState = {
	Charge: number,
	Cap: number,
	-- Called by the damage modifier after a hit was swallowed.
	Absorbed: (() -> ())?,
}

local Shared = {}

Shared.CooldownStatus = "DarkCooldown"
Shared.RecentStatus = "DarkRecent"
Shared.ChargingStatus = "DarkCharging"
Shared.ChargeStateStatus = "DarkChargeState"
Shared.ChargeGuideStatus = "DarkChargeGuide"
Shared.StarChargingStatus = "DarkStarCharging"
Shared.PulledStatus = "DarkPulled"
-- Set by StatusService while any stun is running.
Shared.StunStatus = "Stunned"

-- The BodyPosition of a legacy pull: the same mover is used, so the same numbers drag
-- a victim the same way.
export type Mover = {
	MaxForce: Vector3,
	P: number,
	D: number,
}

-- Hitbox queries reach this far past the radius they are given (a body's width); the
-- legacy checks measured root distances, so radii are passed less this.
Shared.BodyRadius = 2.5

-- NPCs are simulated by the server, which holds their mover itself.
local NPC_MOVER_NAME = "DarkPull"
local npcExpiry: { [Instance]: number } = setmetatable({} :: any, { __mode = "k" })

--[[
	Blocks Dark Star for `duration` seconds. The legacy flag was cleared by whichever
	delay ended first, so a short one (Vortex, 7 s) could cut a long one (Charge, 20 s)
	short; the longest one wins here.
]]
function Shared.MarkRecent(entity: CharacterEntity, duration: number)
	local endsAt = os.clock() + duration
	local current = entity:GetStatus(Shared.RecentStatus)
	if type(current) == "number" and current >= endsAt then
		return
	end
	entity:SetStatus(Shared.RecentStatus, endsAt, duration)
end

--[[
	Gate of Dark Charge, Dark Vortex and Black Hole: not while Dark Star is being charged,
	and not while stunned (they are KeepThroughStun, so AbilityService lets their presses
	through during a stun).
]]
function Shared.CanCast(entity: CharacterEntity): boolean
	return not entity:HasStatus(Shared.StunStatus) and not entity:HasStatus(Shared.StarChargingStatus)
end

--[[
	Drags a victim towards `point` for `duration` seconds with the given legacy mover
	(re-apply to keep it going or to move the point).
]]
function Shared.Pull(target: CharacterEntity, point: Vector3, duration: number, mover: Mover)
	if target.Dead then
		return
	end

	if target.Player then
		local force = mover.MaxForce
		target:SetStatus(
			Shared.PulledStatus,
			string.format("%.1f|%.1f|%.1f|%g|%g|%g|%g|%g", point.X, point.Y, point.Z, force.X, force.Y, force.Z, mover.P, mover.D),
			duration,
			true
		)
		return
	end

	local root = target.Root
	local found = root:FindFirstChild(NPC_MOVER_NAME)
	local body: BodyPosition
	if found and found:IsA("BodyPosition") then
		body = found
	else
		body = Instance.new("BodyPosition")
		body.Name = NPC_MOVER_NAME
	end
	body.MaxForce = mover.MaxForce
	body.P = mover.P
	body.D = mover.D
	body.Position = point
	body.Parent = root

	local endsAt = os.clock() + duration
	npcExpiry[body] = endsAt
	task.delay(duration, function()
		if npcExpiry[body] == endsAt then
			body:Destroy()
		end
	end)
end

-- Lets a victim go before its pull ran out.
function Shared.Release(target: CharacterEntity)
	target:ClearStatus(Shared.PulledStatus)
	if not target.Player then
		local body = target.Root:FindFirstChild(NPC_MOVER_NAME)
		if body then
			body:Destroy()
		end
	end
end

return Shared
