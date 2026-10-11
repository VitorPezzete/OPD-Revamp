--!strict
--[[
	Quake fruit - Tsunami (charged): two walls of water rise out of the sea on either side
	of the caster, sweep toward each other, cross where the caster stood and sink again.

	Charge: 34 per second, 4 to 1000 (about 29 s for a full charge), timed on the
	server from the rounded start the legacy server used (see _Shared). The two-arm swing takes 0.5 s after the release and counts as charge, as in
	the legacy game (the client told the server once it was done). With a = defense
	affinity, L = defense level and s = L / cap:
	- size factor  k = (0.425 * charge / 100 + 2) * 0.004 * L * a, times 1.25 when the
	  caster owns the Bisento;
	- 0.25 s after the swing each wall (the Tsunami model scaled by k) starts 88 * k
	  studs to one side of where the caster then stands, just under sea level, and
	  travels 176 * k studs across it at 88 * s studs per second: it rises by its own
	  height on the way in and sinks twice as fast on the way out;
	- damage 7500 * charge / 1000 * a * s, Special, not dodgeable, once per wall per
	  target (someone caught by both walls is hit twice, as in the legacy game). The
	  caster is never hit;
	- cooldown 30 + 0.3 * L * (charge at the release / 1000) / a seconds from the release.

	Server simulation: no part, no Touched. Each wall is a box advanced by a chain of
	delayed queries (every TICK seconds, 2 * k / s seconds in total, so the chain always
	ends); each query covers everything the wall swept since the previous one, so a fast
	wall cannot step over a target. Clients draw the same path (Effects.OneShot.
	QuakeTsunami) from the parameters sent once at the release.

	Guessed / simplified - review:
	- SEA_LEVEL: the legacy walls were placed at the fixed height Y = 211 wherever the
	  caster stood. There is no shared map config yet, so the constant lives here.
	- The wall size is read from the Tsunami model (Assets.Models.Fruits._Shared, found
	  by _Shared.FindResource); FALLBACK_SIZE is that model's size, for a place without
	  it. The same size is sent to the clients, so the picture and the hitbox agree.
	- Chilly's ice spikes froze a legacy wall in place for 10 * a + charge / 25 seconds
	  and made it solid. Not ported (it needs a hook in the Chilly abilities and a
	  collidable wall, which the server no longer has).
	- CombatService ignores hits further than 3000 studs from the attacker: a caster who
	  travels far from a very large tsunami stops dealing its damage.

	Legacy problems fixed here:
	- Two server parts tweened by the server, with Touched connections that only saw
	  parts moving inside them and a `while` loop of GetPartsInPart every 1.5 s that
	  never ended once a wall was destroyed normally.
	- The client sent its own charge; the 0.25 s wait and the charge were script-level
	  variables shared by both fruit slots, so two casts overwrote each other.
	- The cooldown existed only on the client.

	KeepThroughStun: walls already released keep going when their caster is stunned, as
	in the legacy game. A release while stunned is dropped.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local EFFECT = "QuakeTsunami"
local DAMAGE_TAG = "QuakeTsunami"

-- Height of the sea surface in the legacy map (see the header).
local SEA_LEVEL = 211
local FALLBACK_SIZE = Vector3.new(72, 16, 24)
local BISENTO = "Bisento"
local BISENTO_MULTIPLIER = 1.25

local CHARGE_RATE = 34
local CHARGE_MIN = 4
local CHARGE_MAX = 1000
-- Seconds between the release and the end of the swing.
local SWING_SECONDS = 0.5

local SCALE_BASE = 2
local SCALE_PER_CHARGE = 0.425 / 100
local SCALE_PER_LEVEL = 0.004
-- Bubbles on the hands while charging grow to 20 * s * a (mesh scale).
local BUBBLE_SCALE = 20

local RELEASE_DELAY = 0.25
local TRAVEL = 88
local DAMAGE = 7500
local COOLDOWN_BASE = 30
local COOLDOWN_PER_LEVEL = 0.3

local TICK = 0.1
-- Extra distance at which clients still receive the effect, past the path of the walls.
local EFFECT_MARGIN = 400

type Wall = {
	Start: number,
	-- Centre of the wall on the ground plane when it starts, and its direction of travel.
	From: Vector3,
	Direction: Vector3,
	-- Seconds and studs of one half of the trip (out of the sea, then back into it).
	LegTime: number,
	LegDistance: number,
	Size: Vector3,
	Damage: number,
	Swept: number,
	Hit: { [any]: boolean },
}

local Tsunami = Ability.extend()

Tsunami.KeepThroughStun = true

-- One sweep query; reschedules itself until the wall has sunk on the far side.
local function advance(self: any, wall: Wall, epoch: number)
	local entity = self.Entity
	if (self.Epoch or 0) ~= epoch or entity.Dead then
		return
	end

	-- 0 at the start, 1 over the release point, 2 at the end.
	local alpha = math.clamp((os.clock() - wall.Start) / wall.LegTime, 0, 2)
	local distance = wall.LegDistance * alpha
	local height = wall.Size.Y
	-- The top of the wall is at sea level at the start and one height above it at 1.
	local centerY = if alpha <= 1
		then SEA_LEVEL - height / 2 + height * alpha
		else SEA_LEVEL + height / 2 - 2 * height * (alpha - 1)

	local swept = distance - wall.Swept
	local flat = wall.From + wall.Direction * ((distance + wall.Swept) / 2)
	local center = Vector3.new(flat.X, centerY, flat.Z)
	local size = Vector3.new(wall.Size.X, height, wall.Size.Z + swept)
	wall.Swept = distance

	for _, target in Hitbox.Box(CFrame.lookAt(center, center + wall.Direction), size, entity) do
		if not wall.Hit[target] then
			wall.Hit[target] = true
			self:Damage(target, wall.Damage, "Special", DAMAGE_TAG, false)
		end
	end

	if alpha < 2 then
		task.delay(TICK, advance, self, wall, epoch)
	end
end

function Tsunami:CanBegin(): boolean
	return Shared.CanCharge(self)
end

function Tsunami:OnBegin()
	local bubble = BUBBLE_SCALE * self:GetLevelScale("Defense") * self:GetAffinity("Defense")
	Shared.BeginCharge(self, "Tsunami", bubble, CHARGE_MAX / CHARGE_RATE)
end

-- The swing is over: the walls rise around where the caster stands now.
local function release(self: any, charge: number, epoch: number)
	local entity = self.Entity
	if (self.Epoch or 0) ~= epoch or entity.Dead then
		return
	end

	local affinity = self:GetAffinity("Defense")
	local level = self:GetLevel("Defense")
	local levelScale = self:GetLevelScale("Defense")
	if levelScale <= 0 or affinity <= 0 then
		return
	end

	local scale = (SCALE_PER_CHARGE * charge + SCALE_BASE) * SCALE_PER_LEVEL * level * affinity
	if self.Context.Data.Data.Items[BISENTO] == true then
		scale *= BISENTO_MULTIPLIER
	end

	local template = Shared.FindResource("Tsunami")
	local size = (if template then template.Size else FALLBACK_SIZE) * scale
	local legDistance = TRAVEL * scale
	local speed = TRAVEL * levelScale
	local legTime = legDistance / speed

	local position = entity.Root.Position
	local right = entity.Root.CFrame.RightVector * Vector3.new(1, 0, 1)
	right = if right.Magnitude > 0.05 then right.Unit else Vector3.xAxis

	local payload = {
		Right = right,
		Size = size,
		LegDistance = legDistance,
		LegTime = legTime,
		SeaLevel = SEA_LEVEL,
		Delay = RELEASE_DELAY,
		Scale = scale,
		Haki = self.Services.Haki:IsArmamentActive(entity),
		Colors = self:GetColorString(),
		Caster = entity.Model,
	}
	-- Not self:PlayEffect: the walls start far outside the default effect radius.
	self.Services.Effect:Play(EFFECT, position, payload, legDistance + EFFECT_MARGIN)

	local damage = DAMAGE * (charge / CHARGE_MAX) * affinity * levelScale
	local start = os.clock() + RELEASE_DELAY
	for _, side in { 1, -1 } do
		local wall: Wall = {
			Start = start,
			From = position + right * (legDistance * side),
			Direction = right * -side,
			LegTime = legTime,
			LegDistance = legDistance,
			Size = size,
			Damage = damage,
			Swept = 0,
			Hit = {},
		}
		task.delay(RELEASE_DELAY, advance, self, wall, epoch)
	end
end

function Tsunami:OnEnd()
	local entity = self.Entity
	local charge, released = Shared.EndCharge(self, CHARGE_RATE, CHARGE_MIN, CHARGE_MAX, SWING_SECONDS)
	if not charge or not released or entity:HasStatus(Shared.STUN_STATUS) then
		return
	end

	local affinity = self:GetAffinity("Defense")
	if affinity <= 0 then
		return
	end

	-- The legacy cooldown was the client's, computed on the charge it had at the release.
	local cooldown = COOLDOWN_BASE + COOLDOWN_PER_LEVEL * self:GetLevel("Defense") * (released / CHARGE_MAX) / affinity
	self.ReadyAt = os.clock() + cooldown
	self:StartCooldown(cooldown)

	Shared.Swing(self, "Tsunami")
	task.delay(SWING_SECONDS, release, self, charge, self.Epoch or 0)
end

function Tsunami:OnInterrupt()
	Shared.CancelCharge(self)
	-- Walls already released stop with their caster (legacy: destroyed with the character).
	self.Epoch = (self.Epoch or 0) + 1
end

return Tsunami
