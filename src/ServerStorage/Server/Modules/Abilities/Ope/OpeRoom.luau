--!strict
--[[
	Ope fruit - shared Room state. NOT an ability: AbilityService only requires modules
	named after an ability in FruitConfig, so this one is just a library for Room,
	Scalpel, Shambles, Severance and the Ope passive.

	Sibling abilities do not see each other's objects, so the state is one table kept in
	a non-replicated entity status ("OpeState") and shared by reference.

	Room:     a sphere fixed where it was created. Its diameter grows from 0 to
	          defense level * defense affinity at
	          (level / timeToOpen) * (level / 500) * affinity studs per second, with
	          timeToOpen = 7.5 - 1.5 * affinity ^ affinity.
	          The current radius is computed from the opening time: nothing ticks.
	Stamina:  max = defense level * defense affinity (full the first time a Room opens).
	          It only refills while the Room is CLOSED, at
	          25 * (level / 500) * affinity ^ affinity per second (credited when the next
	          Room opens, exactly as the legacy did), and by kills (see Passives/Ope).

	"OpeStamina" ("<current>|<max>") is replicated on the caster for a future HUD bar.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

export type State = {
	Stamina: number,
	Max: number,
	Open: boolean,
	Center: Vector3,
	FinalRadius: number,
	-- Radius gained per second.
	GrowRate: number,
	OpenedAt: number,
	ClosedAt: number,
}

local STATE_STATUS = "OpeState"
local STAMINA_STATUS = "OpeStamina"
local LEVEL_SCALE = 500
local REGEN_RATE = 25
local MIN_TIME_TO_OPEN = 0.5

local OpeRoom = {}

-- Set by Hollow's Projection: the legacy client refused every Ope power while projecting.
OpeRoom.ProjectingStatus = "HollowProjecting"

local function replicate(entity: CharacterEntity, state: State)
	entity:SetStatus(STAMINA_STATUS, `{math.floor(state.Stamina)}|{math.floor(state.Max)}`, nil, true)
end

function OpeRoom.Get(entity: CharacterEntity): State
	local state = entity:GetStatus(STATE_STATUS) :: State?
	if not state then
		local created: State = {
			Stamina = 0,
			Max = 0,
			Open = false,
			Center = Vector3.zero,
			FinalRadius = 0,
			GrowRate = 0,
			OpenedAt = 0,
			ClosedAt = 0,
		}
		entity:SetStatus(STATE_STATUS, created)
		return created
	end
	return state
end

function OpeRoom.IsOpen(entity: CharacterEntity): boolean
	return OpeRoom.Get(entity).Open
end

function OpeRoom.GetRadius(state: State): number
	if not state.Open then
		return 0
	end
	return math.min(state.FinalRadius, (os.clock() - state.OpenedAt) * state.GrowRate)
end

-- Whether a point is inside the caster's open Room.
function OpeRoom.Contains(entity: CharacterEntity, position: Vector3): boolean
	local state = OpeRoom.Get(entity)
	return state.Open and (position - state.Center).Magnitude <= OpeRoom.GetRadius(state)
end

-- Opens the Room at `center`. Returns the state so the caller can describe it to clients.
function OpeRoom.Open(entity: CharacterEntity, center: Vector3, level: number, affinity: number): State
	local state = OpeRoom.Get(entity)
	local now = os.clock()
	local maximum = level * affinity

	if state.Max <= 0 then
		state.Stamina = maximum
	else
		local regen = (now - state.ClosedAt) * REGEN_RATE * (level / LEVEL_SCALE) * affinity ^ affinity
		state.Stamina = math.clamp(state.Stamina + regen, 1, maximum)
	end
	state.Max = maximum

	local timeToOpen = math.max(MIN_TIME_TO_OPEN, 7.5 - 1.5 * affinity ^ affinity)
	state.Open = true
	state.Center = center
	state.FinalRadius = maximum / 2
	state.GrowRate = (level / timeToOpen) * (level / LEVEL_SCALE) * affinity / 2
	state.OpenedAt = now

	replicate(entity, state)
	return state
end

function OpeRoom.Close(entity: CharacterEntity)
	local state = OpeRoom.Get(entity)
	if state.Open then
		state.Open = false
		state.ClosedAt = os.clock()
	end
end

function OpeRoom.GetStamina(entity: CharacterEntity): number
	return OpeRoom.Get(entity).Stamina
end

-- Takes `cost` stamina; false (and nothing taken) when there is not enough.
function OpeRoom.Spend(entity: CharacterEntity, cost: number): boolean
	local state = OpeRoom.Get(entity)
	if state.Stamina < cost then
		return false
	end
	state.Stamina -= cost
	replicate(entity, state)
	return true
end

function OpeRoom.AddStamina(entity: CharacterEntity, amount: number)
	local state = OpeRoom.Get(entity)
	if state.Max <= 0 then
		-- No Room was ever opened: the first one starts full anyway.
		return
	end
	state.Stamina = math.clamp(state.Stamina + amount, 0, state.Max)
	replicate(entity, state)
end

return OpeRoom
