--!strict
--[[
	Vampire fruit - state shared by its abilities and its passive (not an ability: no
	FruitConfig entry has this name, so AbilityService never loads it as one).

	Four things the legacy game spread over the fruit script, RewardModule, HealthV2, a
	Souls script and one script cloned into every character:

	Day / night   TimeService decides: night is 18:00 to 06:00 inclusive, like the legacy
	              DayNight script. DayChanged fires (isDay) when it flips.

	Bats          Up to 6 per vampire. A bat is only a number (the max health of the
	              character it was made from); the orbiting models are the VampireBats
	              client effect, fed by the replicated status "<count>|<fruit colors>".
	              Gained by killing a player, or by Necromancy on a soul. Spent by
	              Bat Swarm. Lost with the character.

	Souls         Every kill made by a player leaves a soul at that spot for 20 s,
	              holding the victim's max health - except a vampire killing a player,
	              which raises a bat directly (or nothing when it already has 6). NPC
	              victims count, whoever killed them: that is how a vampire fills up
	              while fighting enemies. Only vampires see souls (VampireSoul client
	              effect, sent to them alone), and none is kept while the server has no
	              vampire.

	Bite marks    Sanguine Vampiris marks players. A marked player:
	              - has 80% max health by day and 120% by night (legacy numbers; yes,
	                the curse helps its victim at night);
	              - burns while standing in direct sunlight by day: 2.2% of max health
	                the moment the sun touches it and every 0.65 s after that, taken
	                straight from health like the legacy script did (no mitigation,
	                no defense experience, nobody gets the kill);
	              - can be hypnotised by the vampire that bit it.
	              A mark ends only with the victim's death, as in legacy: it outlives
	              the vampire's character. After the vampire respawned (or lost the
	              fruit) its old victims stay cursed but can neither be hypnotised nor
	              marked again, and the vampire no longer sees their marker (it was a
	              child of the dead character's fruit script).

	The sunlight check is one loop for every marked character, alive only while marks
	exist, ten times a second (the legacy game ran a raycast per marked character per
	frame). It uses the legacy sun, which is not the one in the sky: always 45 degrees
	up, turning once around the horizon per day. The clock comes from TimeService; the
	server's Lighting only moves at dawn and dusk.

	Not reproduced: stepping out of the sun and back in within 0.65 s started a second
	legacy burn loop next to the first (the burn then ticked twice as fast for good).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

type Roost = { Colors: string, Bats: { number } }
type Mark = { Biter: CharacterEntity, Value: string, InSun: boolean, NextBurn: number, Died: any, Orphan: boolean? }
export type Soul = { Id: number, Position: Vector3, Health: number, ExpiresAt: number }

local FRUIT_NAME = "Vampire"
local SOUL_EFFECT = "VampireSoul"

local MAX_BATS = 6
local SOUL_LIFETIME = 20

local BITTEN_MODIFIER = "VampireBitten"
local BITTEN_DAY_HEALTH = 0.8
local BITTEN_NIGHT_HEALTH = 1.2
local SUN_INTERVAL = 0.65
local SUN_CHECK_INTERVAL = 0.1
local SUN_DAMAGE_FRACTION = 0.022
local SUN_RAY_LENGTH = 500

local VampireShared = {}

VampireShared.MaxBats = MAX_BATS
VampireShared.Status = table.freeze({
	-- On every vampire while the passive runs: lets the client show vampire-only things.
	Passive = "VampirePassive",
	-- "<count>|<fruit colors>" while the vampire has bats.
	Bats = "VampireBats",
	-- Necromancy's attack mode: the next Bat Swarm carries a bat.
	BatAttack = "VampireBatAttack",
	-- On a bitten player: "<biter user id>|<1 while burning in the sun, else 0>|<marker range>".
	Bitten = "VampireBitten",
})

VampireShared.DayChanged = Signal.new() :: Signal.Signal<boolean>

function VampireShared.IsDay(): boolean
	return Knit.GetService("TimeService"):IsDay()
end

local roosts: { [CharacterEntity]: Roost } = {}
local marks: { [CharacterEntity]: Mark } = {}
local souls: { Soul } = {}
local nextSoulId = 0
local sunLoopRunning = false
local started = false

-- Bats ---------------------------------------------------------------------------------

local function publishBats(entity: CharacterEntity, roost: Roost)
	if #roost.Bats > 0 then
		entity:SetStatus(VampireShared.Status.Bats, `{#roost.Bats}|{roost.Colors}`, nil, true)
	else
		entity:ClearStatus(VampireShared.Status.Bats)
	end
end

function VampireShared.GetBatCount(entity: CharacterEntity): number
	local roost = roosts[entity]
	return if roost then #roost.Bats else 0
end

-- Adds a bat holding `health`. False when the vampire is full (or is not one).
function VampireShared.AddBat(entity: CharacterEntity, health: number): boolean
	local roost = roosts[entity]
	if not roost or entity.Dead or #roost.Bats >= MAX_BATS then
		return false
	end
	table.insert(roost.Bats, health)
	publishBats(entity, roost)
	return true
end

-- Removes the oldest bat and returns the health it held, or nil without bats.
function VampireShared.TakeBat(entity: CharacterEntity): number?
	local roost = roosts[entity]
	if not roost or #roost.Bats == 0 then
		return nil
	end
	local health = table.remove(roost.Bats, 1)
	publishBats(entity, roost)
	return health
end

-- Souls --------------------------------------------------------------------------------

local function pruneSouls()
	local now = os.clock()
	for index = #souls, 1, -1 do
		if now >= souls[index].ExpiresAt then
			table.remove(souls, index)
		end
	end
end

-- Souls are drawn for vampires only, wherever they are (EffectService:Play would send
-- every kill of the server to everybody near it).
local function showSoul(position: Vector3, params: { [string]: any })
	local play = Knit.GetService("EffectService").Client.Play
	for entity in roosts do
		if entity.Player then
			play:Fire(entity.Player, SOUL_EFFECT, position, params)
		end
	end
end

local function addSoul(position: Vector3, health: number)
	if next(roosts) == nil then
		return
	end
	pruneSouls()
	nextSoulId += 1
	table.insert(souls, {
		Id = nextSoulId,
		Position = position,
		Health = health,
		ExpiresAt = os.clock() + SOUL_LIFETIME,
	})
	showSoul(position, { Id = nextSoulId, Duration = SOUL_LIFETIME })
end

-- Removes and returns the live soul closest to `position` within `radius`, if any.
function VampireShared.TakeSoulNear(position: Vector3, radius: number): Soul?
	pruneSouls()
	local closestIndex: number? = nil
	local closestDistance = radius
	for index, soul in souls do
		local distance = (soul.Position - position).Magnitude
		if distance <= closestDistance then
			closestIndex, closestDistance = index, distance
		end
	end
	if not closestIndex then
		return nil
	end

	local soul = table.remove(souls, closestIndex) :: Soul
	showSoul(soul.Position, { Id = soul.Id, Remove = true })
	return soul
end

-- Bite marks ---------------------------------------------------------------------------

local function unmark(victim: CharacterEntity)
	local mark = marks[victim]
	if not mark then
		return
	end
	marks[victim] = nil
	mark.Died:Disconnect()
	victim:SetMaxHealthModifier(BITTEN_MODIFIER, nil)
	victim:ClearStatus(VampireShared.Status.Bitten)
end

local function publishMark(victim: CharacterEntity, mark: Mark)
	victim:SetStatus(VampireShared.Status.Bitten, string.format(mark.Value, if mark.InSun then 1 else 0), nil, true)
end

-- Towards the legacy sun (see the header).
local function getSunDirection(): Vector3
	local angle = Knit.GetService("TimeService"):GetClockTime() / 24 * math.pi * 2
	return Vector3.new(math.sin(angle), 1, -math.cos(angle)).Unit
end

local function isInSunlight(victim: CharacterEntity, sunDirection: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { victim.Model }
	return Workspace:Raycast(victim.Root.Position, sunDirection * SUN_RAY_LENGTH, params) == nil
end

local function sunStep()
	local isDay = VampireShared.IsDay()
	local sunDirection = getSunDirection()
	local now = os.clock()
	for victim, mark in marks do
		if victim.Dead or victim.Model.Parent == nil then
			unmark(victim)
			continue
		end

		-- The vampire's character is gone: the mark stays but belongs to nobody (a
		-- respawned vampire is another entity for GetBitten) and shows no marker.
		local orphaned = not mark.Orphan and (mark.Biter.Dead or mark.Biter.Model.Parent == nil)
		if orphaned then
			mark.Orphan = true
			mark.Value = "0" .. string.sub(mark.Value, (string.find(mark.Value, "|", 1, true) or 1))
		end

		local inSun = isDay and victim.Spawned and isInSunlight(victim, sunDirection)
		if inSun ~= mark.InSun or orphaned then
			mark.InSun = inSun
			publishMark(victim, mark)
		end
		if inSun and now >= mark.NextBurn then
			mark.NextBurn = now + SUN_INTERVAL
			-- May kill the victim, which unmarks it through its Died signal.
			victim:TakeDamage(victim.MaxHealth * SUN_DAMAGE_FRACTION)
		end
	end

	if next(marks) ~= nil then
		task.delay(SUN_CHECK_INTERVAL, sunStep)
	else
		sunLoopRunning = false
	end
end

--[[
	Marks `victim` as bitten by `biter`. False when it already carries a mark.
	`markerRange` is how far away the vampire's client still shows the marker.
]]
function VampireShared.Bite(victim: CharacterEntity, biter: CharacterEntity, markerRange: number): boolean
	if marks[victim] or victim.Dead or victim == biter then
		return false
	end

	local biterId = if biter.Player then biter.Player.UserId else 0
	local mark: Mark = {
		Biter = biter,
		-- %d is the "in sunlight" flag, filled in by publishMark.
		Value = `{biterId}|%d|{math.floor(markerRange)}`,
		InSun = false,
		NextBurn = 0,
		Died = victim.Died:Connect(function()
			unmark(victim)
		end),
	}
	marks[victim] = mark

	victim:SetMaxHealthModifier(BITTEN_MODIFIER, if VampireShared.IsDay() then BITTEN_DAY_HEALTH else BITTEN_NIGHT_HEALTH)
	publishMark(victim, mark)

	if not sunLoopRunning then
		sunLoopRunning = true
		task.delay(SUN_CHECK_INTERVAL, sunStep)
	end
	return true
end

-- Every living character currently marked by `biter`.
function VampireShared.GetBitten(biter: CharacterEntity): { CharacterEntity }
	local result: { CharacterEntity } = {}
	for victim, mark in marks do
		if mark.Biter == biter and not mark.Orphan and not victim.Dead then
			table.insert(result, victim)
		end
	end
	return result
end

-- Lifetime -----------------------------------------------------------------------------

-- Called by the passive when a vampire's character (or fruit) appears.
function VampireShared.Register(entity: CharacterEntity, colors: string)
	roosts[entity] = { Colors = colors, Bats = {} }
end

-- Called by the passive's cleanup: the bats go away. The marks this vampire left stay
-- on their victims (see the header); the sunlight loop notices when their vampire's
-- character is gone.
function VampireShared.Unregister(entity: CharacterEntity)
	roosts[entity] = nil
	entity:ClearStatus(VampireShared.Status.Bats)
	entity:ClearStatus(VampireShared.Status.BatAttack)
end

--[[
	Hooks the two world events the fruit needs, once for the whole server:
	- a kill on a player gives the killer a bat when the killer is a vampire; every other
	  rewarded kill, NPC victims included, leaves a soul (as in the legacy RewardModule,
	  so not on private servers, where RewardService pays nothing);
	- day / night flips re-scale the max health of every marked player.
]]
function VampireShared.Start()
	if started then
		return
	end
	started = true

	local characterService = Knit.GetService("CharacterService")
	local fruitService = Knit.GetService("FruitService")

	Knit.GetService("RewardService").KillRewarded:Connect(function(killer: Player, victim: CharacterEntity)
		if victim.Player and fruitService:HasFruit(killer, FRUIT_NAME) then
			local killerEntity = characterService:GetPlayerEntity(killer)
			if killerEntity then
				VampireShared.AddBat(killerEntity, victim.MaxHealth)
			end
			return
		end
		addSoul(victim.Root.Position, victim.MaxHealth)
	end)

	Knit.GetService("TimeService").PhaseChanged:Connect(function(isNight: boolean)
		local isDay = not isNight
		for victim in marks do
			victim:SetMaxHealthModifier(BITTEN_MODIFIER, if isDay then BITTEN_DAY_HEALTH else BITTEN_NIGHT_HEALTH)
		end
		VampireShared.DayChanged:Fire(isDay)
	end)
end

return VampireShared
