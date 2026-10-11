--!strict
--[[
	Sand fruit - Desert Spada: a line of ever larger sand blades erupts from the caster
	toward the aim point, cutting and bleeding whoever stands on the line.

	With a = sword affinity, s = sword level / cap and b = 10 * a * s:
	- 7 blades, the i-th one b * i studs long and tall and 0.2 thick, each centred half
	  its length past the centre of the previous one (the first starts on the caster):
	  the line reaches 17.5 * b studs (175 at level 500, affinity 1);
	- the blades grow in 0.25 s and are gone 2.25 s after the cast; everyone touching one
	  meanwhile takes 500 * a * s, Sword, once per cast, not dodgeable; armament haki at
	  cast time doubles it and makes it Haki;
	- each victim then bleeds: floor(10 * a) ticks of a random
	  floor(90 * a * s) .. floor(175 * a * s), Bleed, not dodgeable, the first one with the
	  cut and the next ones 0.2 to 1.1 s apart (each rolled); a second cast on the same
	  victim bleeds on top of the first;
	- 0.75 s between casts; casting grounds the Sand flight for 3 seconds.

	The legacy cast drew a second row of 7 blades of length (b - 5) * i in the same
	places. It never carried damage of its own that the first row did not already cover
	(same line, smaller blades, shared hit list), so it is only drawn by the clients.

	Bleed: the legacy loop ran inside the Touched handler with `wait(0.2 + random * 0.9)`
	between ticks and a new random amount per tick. It is the same chain here, bounded
	by its tick count; it stops when the victim dies and outlives a stun of the caster.

	Legacy problems fixed here:
	- 14 server parts with Touched connections that were never disconnected, sized by
	  server tweens. The hit is 7 box queries sampled every 0.1 s while the blades stand,
	  so nobody can walk through a blade between two samples.
	- The haki state was read again on every touch; it is fixed at cast time.
	- The sword affinity was a script-level variable shared by both fruit slots.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Shared = require(script.Parent._Shared)

local EFFECT = "SandSpada"
local DAMAGE_TAG = "SandSpada"

local BLADES = 7
local BASE_LENGTH = 10
local THICKNESS = 0.2
local DAMAGE = 500
local HAKI_MULTIPLIER = 2

local BLEED_TICKS = 10
local BLEED_MIN = 90
local BLEED_MAX = 175
local BLEED_WAIT_MIN = 0.2
local BLEED_WAIT_SPREAD = 0.9

-- Blades are fully grown at 0.25 s and destroyed at 2.25 s.
local GROW_TIME = 0.25
local SAMPLE_INTERVAL = 0.1
local SAMPLES = 21

type Cast = {
	Blades: { { CFrame: CFrame, Size: Vector3 } },
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	BleedMin: number,
	BleedMax: number,
	BleedTicks: number,
	Hit: { [any]: boolean },
}

local DesertSpada = Ability.extend()

DesertSpada.Debounce = 0.75

local function bleed(self: any, cast: Cast, target: any, left: number)
	if target.Dead or left <= 0 then
		return
	end
	local amount = math.random(cast.BleedMin, cast.BleedMax)
	if amount > 0 then
		self:Damage(target, amount, "Bleed", DAMAGE_TAG, false)
	end
	task.delay(BLEED_WAIT_MIN + math.random() * BLEED_WAIT_SPREAD, bleed, self, cast, target, left - 1)
end

local function strike(self: any, cast: Cast, target: any)
	self:Damage(target, cast.Damage, cast.Trait, DAMAGE_TAG, false)
	bleed(self, cast, target, cast.BleedTicks)
end

local function sample(self: any, cast: Cast, epoch: number, remaining: number)
	if (self.Epoch or 0) ~= epoch or self.Entity.Dead then
		return
	end

	for _, blade in cast.Blades do
		for _, target in Hitbox.Box(blade.CFrame, blade.Size, self.Entity) do
			if not cast.Hit[target] then
				cast.Hit[target] = true
				strike(self, cast, target)
			end
		end
	end

	if remaining > 1 then
		task.delay(SAMPLE_INTERVAL, sample, self, cast, epoch, remaining - 1)
	end
end

function DesertSpada:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity

	local affinity = self:GetAffinity("Sword")
	local scale = affinity * self:GetLevelScale("Sword")
	local base = BASE_LENGTH * scale
	if base <= 0 then
		return
	end
	local haki = self.Services.Haki:IsArmamentActive(entity)

	local origin = entity.Root.Position
	local direction = input.AimPosition - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	direction = direction.Unit

	local cast: Cast = {
		Blades = {},
		Damage = DAMAGE * scale * (if haki then HAKI_MULTIPLIER else 1),
		Trait = if haki then "Haki" else "Sword",
		BleedMin = math.floor(BLEED_MIN * scale),
		BleedMax = math.floor(BLEED_MAX * scale),
		BleedTicks = math.floor(BLEED_TICKS * affinity),
		Hit = {},
	}

	local center = origin
	for index = 1, BLADES do
		local length = base * index
		center += direction * (length / 2)
		table.insert(cast.Blades, {
			CFrame = CFrame.lookAt(center, center + direction),
			Size = Vector3.new(THICKNESS, length, length),
		})
	end

	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		Base = base,
		Haki = haki,
	})

	task.delay(GROW_TIME, sample, self, cast, self.Epoch or 0, SAMPLES)
end

function DesertSpada:OnInterrupt()
	-- Blades still standing stop cutting.
	self.Epoch = (self.Epoch or 0) + 1
end

return DesertSpada
