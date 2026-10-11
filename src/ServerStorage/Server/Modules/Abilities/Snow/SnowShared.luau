--!strict
--[[
	Snow fruit - helpers shared by its abilities. Not an ability.

	Touch: the "SnowTouched" debuff, with the timing of the legacy control script that
	every character carried. A touch writes the damage and the number of hits, and (once
	per frame: the legacy trigger was a value holding time()) starts a run:

		0.25 s later   the victim is slowed to 10% walk speed ("SnowTouched" status) and
		               takes the first hit
		every 0.5 s    one more hit, `hits` in total, always of the damage written last
		0.25 s after   the last wait the slow ends

	A run stops quietly after its current 0.5 s wait when a newer touch has started its
	own run. So every touch lands a hit 0.25 s later, and two touches less than 0.25 s
	apart leave two runs ticking side by side, exactly as the legacy script did (it is
	what made a boulder or a snow body rubbing against someone hurt so much). The run
	that finishes first lifts the slow, even while another one is still ticking.

	Hits are Special, not dodgeable, tagged "SnowTouched". Players holding the Chilly,
	Snow or Luck fruit are neither slowed nor hurt. The slow is also lifted when the
	attacker of the current run dies (the legacy script did that; the hits go on).

	The legacy "flight disabler" (another power ends Snow Angel and locks it for 3 s) is
	character-wide and lives in Server.Modules.FlightLock / AbilityService.

	GetGlobe: center and radius of the caster's Snow Globe, read from its status (sibling
	abilities share state through statuses).

	Other systems that looked at SnowTouched in the legacy game (Shave refused to start,
	Dash was 10 times shorter) read the "SnowTouched" entity status.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

local TOUCH_STATUS = "SnowTouched"
local SLOW_NAME = "SnowTouchedSlow"
local SLOW_SCALE = 0.1
local HIT_INTERVAL = 0.5
-- Legacy: 0.25 s before the first hit and 0.25 s after the last wait.
local RUN_DELAY = 0.25
local END_DELAY = 0.25
local IMMUNE_FRUITS = { "Chilly", "Snow", "Luck" }

local GLOBE_STATUS = "SnowGlobe"
local FLIGHT_STATUS = "SnowFlying"

-- The legacy SnowTouched value object of one character.
type Touched = {
	-- time() of the last touch that counted (the legacy "Time" value).
	Time: number,
	-- The touch the newest run belongs to (the legacy script's `lasttime`).
	Current: number,
	Hits: number,
	Damage: number,
	-- Ability object of whoever touched last.
	Source: any,
	DiedConnection: any,
}

local touched: { [CharacterEntity]: Touched } = setmetatable({}, { __mode = "k" }) :: any

local SnowShared = {}

SnowShared.GlobeStatus = GLOBE_STATUS
SnowShared.FlightStatus = FLIGHT_STATUS

local function isImmune(source: any, target: CharacterEntity): boolean
	local player = target.Player
	if player then
		for _, fruitName in IMMUNE_FRUITS do
			if source.Services.Fruit:HasFruit(player, fruitName) then
				return true
			end
		end
	end
	return false
end

local function setSlowed(target: CharacterEntity, state: Touched, slowed: boolean)
	if state.DiedConnection then
		state.DiedConnection:Disconnect()
		state.DiedConnection = nil
	end
	if target.Dead then
		return
	end
	if slowed then
		target:SetStatus(TOUCH_STATUS, true, nil, true)
		target:SetSpeedScale(SLOW_NAME, SLOW_SCALE)
	else
		target:ClearStatus(TOUCH_STATUS)
		target:SetSpeedScale(SLOW_NAME, nil)
	end
end

local function hit(target: CharacterEntity, state: Touched, source: any, timing: number, remaining: number)
	if target.Dead then
		return
	end
	if remaining <= 0 then
		task.delay(END_DELAY, function()
			-- NPCs kept the slow when a newer touch had refilled the hits meanwhile.
			if target.Player or state.Hits <= 0 then
				state.Hits = 0
				setSlowed(target, state, false)
			end
		end)
		return
	end

	if not isImmune(source, target) then
		source:Damage(target, state.Damage, "Special", TOUCH_STATUS, false)
	end
	task.delay(HIT_INTERVAL, function()
		state.Hits -= 1
		if state.Current ~= timing then
			return
		end
		hit(target, state, source, timing, remaining - 1)
	end)
end

local function run(target: CharacterEntity, state: Touched)
	if target.Dead then
		return
	end

	local source = state.Source
	local timing = state.Time
	state.Current = timing
	-- The player version of the legacy script did nothing at all for an immune victim.
	if isImmune(source, target) then
		return
	end

	setSlowed(target, state, true)
	local attacker: CharacterEntity = source.Entity
	if not attacker.Dead then
		state.DiedConnection = attacker.Died:Connect(function()
			setSlowed(target, state, false)
		end)
	end
	hit(target, state, source, timing, state.Hits)
end

-- `ability` is the Ability object applying the debuff. Returns whether it was applied.
function SnowShared.Touch(ability: any, target: CharacterEntity, damage: number, hits: number): boolean
	if target.Dead or target == ability.Entity then
		return false
	end

	local state = touched[target]
	if not state then
		state = { Time = -1, Current = -1, Hits = 0, Damage = 0, Source = ability, DiedConnection = nil }
		touched[target] = state
	end
	state.Hits = math.floor(hits)
	state.Damage = damage
	state.Source = ability

	-- Touches of one frame are one touch: the legacy trigger only fired when time() changed.
	local now = time()
	if state.Time ~= now then
		state.Time = now
		task.delay(RUN_DELAY, run, target, state)
	end
	return true
end

-- Status value written by Snow Globe: "<x>,<y>,<z>|<radius>|<colors>".
function SnowShared.GetGlobe(entity: CharacterEntity): (Vector3?, number?)
	local value = entity:GetStatus(GLOBE_STATUS)
	if type(value) ~= "string" then
		return nil, nil
	end

	local fields = string.split(value, "|")
	local coordinates = string.split(fields[1] or "", ",")
	local x, y, z = tonumber(coordinates[1]), tonumber(coordinates[2]), tonumber(coordinates[3])
	local radius = tonumber(fields[2])
	if not x or not y or not z or not radius then
		return nil, nil
	end
	return Vector3.new(x, y, z), radius
end

return SnowShared
