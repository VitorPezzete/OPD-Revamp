--!strict
--[[
	Magma fruit - Magma Flow: blobs of magma rain in a widening cone towards the aim point.

	With f = sniper affinity * (sniper level / cap):
	- 15 rows, row r at r * 20 studs along the aim direction; each row drops a random
	  number of blobs between floor(1 + r / 3) and r, scattered up to 15 * r / 4 studs
	  (whole studs) on X and Z, a random whole number of hundredths of a second between
	  10 / r and 25 / r apart, never less than a server frame;
	- each blob falls on the ground under it (ray from 50 studs above to 50 below); with
	  no ground there it lands on the sea, where it deals no damage and cools into a
	  platform each client can stand on for 30 s (Effects.OneShot.MagmaFlow);
	- a blob is a box growing from (10, 3, 10) * f to (15, 4, 15) * f over 2.5 s; it
	  deals 400 * f to everyone inside every 0.25 s, 14 times, the first one 0.25 s
	  after it lands (the legacy loop ran 15 times but its first pass looked at the
	  blob before it had been moved to its landing point) (Special, not dodgeable;
	  armament haki at cast time doubles it and makes it Haki). Overlapping blobs stack,
	  as they did in the legacy game;
	- 8 s cooldown.

	Rumble owners take 1 Melee instead and Smelt / Hot / Plasma owners nothing
	(DamageModifiers.MagmaBurnImmunity, tag "MagmaHeat"). The flow leaves no burn.

	Server and clients build the same blob layout from a shared seed (the effect remote
	is unreliable and could not carry ~90 positions); keep `layout` identical to the one
	in Effects.OneShot.MagmaFlow.

	Blobs on the ground go on burning when the caster is stunned or sealed (the legacy
	ones were independent parts); they only stop if the caster dies.

	Legacy problems fixed here:
	- Every blob was a server MeshPart with its own tweens and a thread doing 15
	  GetPartBoundsInBox queries over the map. It is one bounded chain of ticks testing
	  the live blobs against the tracked characters now.
	- The handler had no level check, used the client CFrame unchecked and its direction
	  was NaN when aiming at one's own position.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local EFFECT = "MagmaFlow"
local DAMAGE_TAG = "MagmaHeat"

local DAMAGE = 400
local HAKI_MULTIPLIER = 2
local ROWS = 15
local ROW_SPACING = 20
local SPREAD_PER_ROW = 15 / 4
-- A wait shorter than a frame still took one on the legacy server.
local MIN_DELAY = 1 / 60
local FLOOR_PROBE = 50

local START_SIZE = Vector3.new(10, 3, 10)
local END_SIZE = Vector3.new(15, 4, 15)
local GROW_TIME = 2.5
local BLOB_LIFETIME = 3.75
local FIRST_HIT = 0.25
local TICK_INTERVAL = 0.25

type Blob = { Center: Vector3, Start: number }

local MagmaFlow = Ability.extend()

MagmaFlow.Debounce = 8

-- Flat landing targets and spawn delays of every blob. Mirrored on the client.
local function layout(seed: number, origin: Vector3, direction: Vector3): { { Point: Vector3, Delay: number } }
	local rng = Random.new(seed)
	local result = {}
	local delay = 0
	for row = 1, ROWS do
		local count = rng:NextInteger(math.floor(1 + row / 3), row)
		local spread = math.floor(SPREAD_PER_ROW * row)
		for _ = 1, count do
			local x = rng:NextInteger(-spread, spread)
			local z = rng:NextInteger(-spread, spread)
			table.insert(result, {
				Point = origin + direction * (row * ROW_SPACING) + Vector3.new(x, 0, z),
				Delay = delay,
			})
			delay += math.max(rng:NextInteger(10 // row, 25 // row) / 100, MIN_DELAY)
		end
	end
	return result
end

local function burn(self: any, blobs: { Blob }, size: number, damage: number, trait: CombatTypes.DamageTrait)
	if self.Entity.Dead or not self.Entity.Model.Parent then
		return
	end

	local now = os.clock()
	local pending = false
	for _, blob in blobs do
		local age = now - blob.Start
		if age < 0 then
			pending = true
		elseif age < FIRST_HIT then
			pending = true
		elseif age < BLOB_LIFETIME then
			pending = true
			-- Quint "out" easing of the legacy size tween.
			local alpha = 1 - (1 - math.min(age / GROW_TIME, 1)) ^ 5
			local box = START_SIZE:Lerp(END_SIZE, alpha) * size
			for _, target in Hitbox.Box(CFrame.new(blob.Center), box, self.Entity) do
				self:Damage(target, damage, trait, DAMAGE_TAG, false)
			end
		end
	end

	if pending then
		task.delay(TICK_INTERVAL, burn, self, blobs, size, damage, trait)
	end
end

function MagmaFlow:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local origin = entity.Root.Position
	local direction = input.AimPosition - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	direction = direction.Unit

	local factor = self:GetAffinity("Sniper") * self:GetLevelScale("Sniper")
	local haki = self.Services.Haki:IsArmamentActive(entity)
	local seed = math.random(1, 2 ^ 30)

	-- Blobs land on the map, never on characters.
	local ignored: { Instance } = {}
	for model in Knit.GetService("CharacterService"):GetEntities() do
		table.insert(ignored, model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored

	local now = os.clock()
	local blobs: { Blob } = {}
	for _, entry in layout(seed, origin, direction) do
		local result = Workspace:Raycast(
			entry.Point + Vector3.new(0, FLOOR_PROBE, 0),
			Vector3.new(0, -2 * FLOOR_PROBE, 0),
			params
		)
		if result then
			table.insert(blobs, { Center = result.Position, Start = now + entry.Delay })
		end
	end

	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		Seed = seed,
		Factor = factor,
		Haki = haki,
	})

	if #blobs > 0 then
		local damage = DAMAGE * factor * (if haki then HAKI_MULTIPLIER else 1)
		local trait: CombatTypes.DamageTrait = if haki then "Haki" else "Special"
		task.spawn(burn, self, blobs, factor, damage, trait)
	end
end

return MagmaFlow
