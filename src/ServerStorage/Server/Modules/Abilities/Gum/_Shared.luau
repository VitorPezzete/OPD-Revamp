--!strict
--[[
	Gum fruit - state and helpers shared by its five abilities. Not an ability: the loader
	only looks modules up by ability name, so this one is never instantiated.

	Entity statuses:
		Gum2nd        replicated  2nd Gear is on (value: fruit color string). The legacy
		                          UsingGum2nd flag; other systems may read it.
		GumArmsBusy   timed       the arms are out: Pistol / Bazooka cooldown, which also
		                          holds back the other two punches (legacy db / db2).
		GumArmsOut    timed       a Pistol / Bazooka arm has not come back yet: no Gatling
		                          until it has, and a running Gatling stops (the legacy
		                          CanUseGatling flag, and the client ending its Gatling
		                          loop when another punch was pressed).
	The rubber body (melee immunity) is the fruit's passive: Passives/Gum.

	Gears. The legacy client kept the gear in a local variable and sent it with every
	request ("0" or "2"); the server believed it. The gear is the Gum2nd status now. In
	2nd Gear each move becomes its Jet version, which has its own melee level gate
	(Pistol 125, Bazooka 150, Gatling 175): below it the move does nothing while the gear
	is on, as in the legacy game. Gum Rocket has none (see there).

	Stretch punch (Pistol, each arm of Bazooka, each punch of Gatling). With L = melee
	level and m = melee affinity:
	- reach  = L * m studs from the hand towards the aim point, stopped by the first
	  wall or character;
	- damage = L / 4 + L / 4 * m, Melee, dodgeable. Doubled and Haki with armament haki;
	  Special for a Dark fruit owner, and Special against a Rumble owner (whose logia body
	  would otherwise ignore a Melee hit).
	The legacy arm was an anchored server part tweened to the first ray hit (wall or
	character, looked up at the press) in a fixed "punch time", whatever the distance;
	when it got there, whoever had a part inside a 2x2x2 box at that tip was hit. It is
	the same here: one server raycast at the press finds the tip, and one box query at
	the tip, a punch time later, finds the victims. Nothing along the arm is hit, and a
	target that left the tip in the meantime is missed, as before. The arm itself is the
	client one-shot GumPunch, given the same distance and time.

	The user was pinned in place by a BodyPosition (and turned, pitch included, by a
	BodyGyro in the head) until the arm was back. The owner's client puts those same two
	movers in its own character (Effects.OneShot.GumPunch with Face,
	Effects.Status.GumGatling); the named root on the entity only keeps the server's view
	of "cannot walk" in step.

	GumMoved (timed status): a Pistol, Bazooka or Gatling was started in the last 1.75 s;
	the gear cannot be switched meanwhile (the legacy client's MoveCounter).

	Body of the other fruit (Modules.BodyTouch): when a body ability of the character's
	OTHER fruit is on at the press (Magma, Candy, Snow, Smelt, Hot bodies, Venom Demon,
	Poison Coat, Vampire Transform), every character the punch hits also receives that
	body's effect, after the punch damage and the Bazooka push; a Magma body also
	multiplies the punch and makes it Special. Each body registers its own effect; the
	legacy list, order and numbers are in Modules/BodyTouch.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Allies = require(ServerStorage.Server.Modules.Allies)
local BodyTouch = require(ServerStorage.Server.Modules.BodyTouch)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

export type PunchOptions = {
	-- "Left" or "Right".
	Hand: string,
	-- Seconds the arm takes to reach its tip (the first thing in its way, or its full reach).
	Time: number,
	-- Seconds the arm stays out before coming back (visual only).
	Hold: number,
	-- Knockback speed applied to whoever is hit (Bazooka), if any.
	Push: number?,
	-- The owner's client turns the user towards the punch (not for Gatling, which keeps
	-- facing the cursor by itself).
	Face: boolean?,
}

local Shared = {}

Shared.GearStatus = "Gum2nd"
Shared.BusyStatus = "GumArmsBusy"
Shared.ArmsOutStatus = "GumArmsOut"
Shared.PunchEffect = "GumPunch"
Shared.DamageTag = "GumPunch"

Shared.MovedStatus = "GumMoved"

local HAKI_MULTIPLIER = 2
local MIN_REACH = 4
local MIN_DISTANCE = 1
-- The legacy box at the tip of the arm.
local TIP_BOX = Vector3.new(2, 2, 2)
-- Studs a character the fist was aimed at may have moved, while the arm travelled, and
-- still be hit: a sprint's worth over the longest punch, not a teleport.
local FOLLOW_DISTANCE = 8
-- Seconds after starting a punch during which the gear cannot be switched.
local MOVE_LOCK = 1.75
-- Vertical part of the Bazooka knockback direction before normalising.
local PUSH_LIFT = 0.25
-- The legacy knockback mover: lifetime, MaxForce per unit of the victim's mass, P.
local PUSH_TIME = 0.18
local PUSH_FORCE_PER_MASS = 1e5
local PUSH_POWER = 1250

function Shared.IsSecondGear(entity: CharacterEntity): boolean
	return entity:HasStatus(Shared.GearStatus)
end

-- False while 2nd Gear is on and the Jet version of the move is not unlocked yet.
function Shared.MeetsGearLevel(ability: any, jetLevel: number): boolean
	return not Shared.IsSecondGear(ability.Entity) or ability:GetLevel("Melee") >= jetLevel
end

function Shared.IsBusy(entity: CharacterEntity): boolean
	return entity:HasStatus(Shared.BusyStatus)
end

function Shared.SetBusy(entity: CharacterEntity, seconds: number)
	entity:SetStatus(Shared.BusyStatus, true, seconds)
end

function Shared.AreArmsOut(entity: CharacterEntity): boolean
	return entity:HasStatus(Shared.ArmsOutStatus)
end

function Shared.SetArmsOut(entity: CharacterEntity, seconds: number)
	entity:SetStatus(Shared.ArmsOutStatus, true, seconds)
end

--[[
	Pins the caster for `seconds` under the ability's own root name. A newer hold of the
	same ability replaces the older one; Release (from OnInterrupt) ends it at once.
]]
function Shared.Hold(ability: any, rootName: string, seconds: number)
	ability.HoldToken = (ability.HoldToken or 0) + 1
	local token = ability.HoldToken
	local entity: CharacterEntity = ability.Entity
	entity:SetRooted(rootName, true)
	task.delay(seconds, function()
		if ability.HoldToken == token then
			entity:SetRooted(rootName, false)
		end
	end)
end

function Shared.Release(ability: any, rootName: string)
	ability.HoldToken = (ability.HoldToken or 0) + 1
	ability.Entity:SetRooted(rootName, false)
end

-- `body`: the body effect of the other fruit this punch carries (BodyTouch.Get), if any.
function Shared.GetPunchDamage(ability: any, body: BodyTouch.Body?): (number, CombatTypes.DamageTrait, boolean)
	local level = ability:GetLevel("Melee")
	local damage = level / 4 + level / 4 * ability:GetAffinity("Melee")
	local trait: CombatTypes.DamageTrait = "Melee"
	if ability.Services.Fruit:HasFruit(ability.Player, "Dark") then
		trait = "Special"
	end
	-- Legacy order: the body's change first (Magma), then haki on top of it.
	if body and body.ModifyDamage then
		damage, trait = body.ModifyDamage(damage, trait)
	end

	local haki = ability.Services.Haki:IsArmamentActive(ability.Entity)
	if haki then
		damage *= HAKI_MULTIPLIER
		trait = "Haki"
	end
	return damage, trait, haki
end

-- A Pistol, Bazooka or Gatling was just started: no gear switch for a moment.
function Shared.MarkMove(entity: CharacterEntity)
	entity:SetStatus(Shared.MovedStatus, true, MOVE_LOCK)
end

function Shared.Punch(ability: any, aim: Vector3, options: PunchOptions)
	local entity: CharacterEntity = ability.Entity
	local arm = entity.Model:FindFirstChild(options.Hand .. " Arm")
	local origin = if arm and arm:IsA("BasePart") then arm.Position else entity.Root.Position

	local direction = aim - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	direction = direction.Unit

	local reach = math.max(ability:GetLevel("Melee") * ability:GetAffinity("Melee"), MIN_REACH)
	direction = Projectile.Lead(entity, origin, direction, reach / options.Time, reach)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	local met = Workspace:Raycast(origin, direction * reach, params)
	local distance = if met then math.max((met.Position - origin).Magnitude, MIN_DISTANCE) else reach
	local tip = origin + direction * distance
	-- The character the fist was thrown straight at, if any. The legacy fist was a part
	-- that flew there and touched whatever it met; here the hit is decided one punch time
	-- later at a fixed point, and a target that kept walking for that long (plus the age
	-- of the aim, which a stream of punches only refreshes a few times a second) had left
	-- the 2-stud box by then: aiming right at an enemy missed more often than aiming at
	-- the ground it was about to step on. The fist stays on whoever it was aimed at, as
	-- long as that character is still about where it was.
	local aimed: CharacterEntity? = if met then ability.Services.Character:GetEntityFromPart(met.Instance) else nil
	-- The fist finds its targets by itself, not through Hitbox: the ally rule is asked
	-- here and at the tip below.
	if aimed and Allies.Spares(entity, aimed) then
		aimed = nil
	end
	local aimedOffset = if aimed then aimed.Root.Position - tip else Vector3.zero

	-- Read at the press, like the legacy flags: a body turned on or off while the arm is
	-- on its way changes nothing for this punch.
	local body = BodyTouch.Get(entity)
	local damage, trait, haki = Shared.GetPunchDamage(ability, body)
	local punch: BodyTouch.Punch = { Ability = ability, Damage = damage, Haki = haki }
	local push = options.Push

	ability:PlayEffect(Shared.PunchEffect, origin, {
		Direction = direction,
		Distance = distance,
		Time = options.Time,
		Hold = options.Hold,
		Hand = options.Hand,
		Haki = haki,
		Face = options.Face == true,
	})

	local function strike(target: CharacterEntity)
		local hitTrait = trait
		local targetPlayer = target.Player
		if hitTrait == "Melee" and targetPlayer and ability.Services.Fruit:HasFruit(targetPlayer, "Rumble") then
			hitTrait = "Special"
		end
		ability:Damage(target, damage, hitTrait, Shared.DamageTag, true)

		if push and push > 0 and not target.Dead then
			-- As the legacy script: the X and Z of the full direction from the user, not
			-- of the flat one, so a target above or below is pushed less sideways.
			local away = target.Root.Position - entity.Root.Position
			local unit = if away.Magnitude > 0 then away.Unit else Vector3.zero
			local force = PUSH_FORCE_PER_MASS * target.Root.AssemblyMass
			ability:Impulse(
				target,
				Vector3.new(unit.X, PUSH_LIFT, unit.Z).Unit * push,
				PUSH_TIME,
				Vector3.new(force, force, force),
				PUSH_POWER
			)
		end

		-- Whether or not the punch itself was dodged or negated, as in the legacy script.
		if body and body.OnHit then
			body.OnHit(target, punch)
		end
	end

	task.delay(options.Time, function()
		if entity.Dead then
			return
		end
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = { entity.Model }

		local characterService = ability.Services.Character
		local struck: { [CharacterEntity]: boolean } = {}
		if aimed and aimed ~= entity and not aimed.Dead and aimed.Spawned then
			local moved = (aimed.Root.Position - tip - aimedOffset).Magnitude
			if moved <= FOLLOW_DISTANCE then
				struck[aimed] = true
				strike(aimed)
			end
		end
		for _, part in Workspace:GetPartBoundsInBox(CFrame.new(tip), TIP_BOX, overlap) do
			local target: CharacterEntity? = characterService:GetEntityFromPart(part)
			if
				target
				and target ~= entity
				and not struck[target]
				and not target.Dead
				and target.Spawned
				and not Allies.Spares(entity, target)
			then
				struck[target] = true
				strike(target)
			end
		end
	end)
end

return Shared
