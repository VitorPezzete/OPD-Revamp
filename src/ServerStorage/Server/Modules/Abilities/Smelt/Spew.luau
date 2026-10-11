--!strict
--[[
	Smelt fruit - Spew: a pool of molten metal that spreads along the ground towards
	the aim point, burning everything standing in it.

	With s = defense affinity * (defense level / cap):
	- The pool starts under the caster, grows linearly for 5s up to a radius of 60 * s
	  while sliding 60 * s studs towards the aim (flat direction), then stays 3s.
	- Every 0.2s everyone inside (flat distance <= current radius, within 8 studs
	  vertically) takes 150 * s, rounded to a whole number (the legacy pool kept it in
	  an IntValue). "Special" damage; armament haki at cast time doubles it and makes it
	  "Haki" for players (NPCs always took it as "Special", doubled all the same); owners
	  of a heat-proof fruit take a pool without haki as "Melee" instead.
	- 3s cooldown, so up to three pools can overlap, as in the legacy game.
	- A pool does not care what happens to its caster afterwards (stun, seal); it only
	  goes out when the caster dies, like the legacy pool that lived in the character.

	Legacy problems fixed here:
	- Each pool carried a Script running a Heartbeat loop over every player and every
	  enemy, spawning one coroutine per victim; that connection was never disconnected.
	  It is now one bounded chain of 40 delayed box queries per pool.
	- The direction came from a client CFrame and was NaN when aiming at one's own feet.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local EFFECT = "SmeltSpew"
local HAKI_STATUS = "Haki"

local DAMAGE = 150
local HAKI_MULTIPLIER = 2
-- Full diameter of the pool and distance it slides, per unit of s.
local LENGTH = 120
local TRAVEL = 60
local GROW_TIME = 5
local LINGER_TIME = 3
local TICK_INTERVAL = 0.2
-- The pool sits at the caster's feet and reaches this far above and below.
local GROUND_OFFSET = 3
local POOL_HEIGHT = 16
local HEAT_PROOF_FRUITS = { "Rumble", "Hot", "Plasma" }

type Pool = {
	Start: number,
	Origin: Vector3,
	Direction: Vector3,
	Travel: number,
	Length: number,
	Damage: number,
	Haki: boolean,
}

local Spew = Ability.extend()

Spew.Debounce = 3

local function isHeatProof(target: any): boolean
	local player = target.Player
	if not player then
		return false
	end

	local fruitService = Knit.GetService("FruitService")
	for _, fruitName in HEAT_PROOF_FRUITS do
		if fruitService:HasFruit(player, fruitName) then
			return true
		end
	end
	return false
end

-- One damage tick of one pool; reschedules itself until the pool expires.
local function burn(self: any, pool: Pool)
	local entity = self.Entity
	if entity.Dead or entity.Model.Parent == nil then
		return
	end

	local elapsed = os.clock() - pool.Start
	if elapsed >= GROW_TIME + LINGER_TIME then
		return
	end

	local alpha = math.min(elapsed / GROW_TIME, 1)
	local radius = pool.Length * alpha / 2
	if radius > 0 then
		local center = pool.Origin + pool.Direction * (pool.Travel * alpha)
		local size = Vector3.new(radius * 2, POOL_HEIGHT, radius * 2)
		for _, target in Hitbox.Box(CFrame.new(center), size, entity) do
			local offset = target.Root.Position - center
			local flatDistance = Vector2.new(offset.X, offset.Z).Magnitude
			if flatDistance <= radius and math.abs(offset.Y) <= POOL_HEIGHT / 2 then
				local trait: CombatTypes.DamageTrait = if not target.Player
					then "Special"
					elseif pool.Haki then "Haki"
					elseif isHeatProof(target) then "Melee"
					else "Special"
				self:Damage(target, pool.Damage, trait, EFFECT, false)
			end
		end
	end

	task.delay(TICK_INTERVAL, burn, self, pool)
end

function Spew:OnBegin(input: Ability.AbilityInput)
	local root = self.Entity.Root
	local origin = root.Position - Vector3.new(0, GROUND_OFFSET, 0)

	local flat = Vector3.new(input.AimPosition.X - origin.X, 0, input.AimPosition.Z - origin.Z)
	if flat.Magnitude < 0.05 then
		-- Aiming at one's own feet: spew forward.
		local look = root.CFrame.LookVector
		flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.05 then
			flat = Vector3.new(0, 0, -1)
		end
	end
	local direction = flat.Unit

	local scale = self:GetAffinity("Defense") * self:GetLevelScale("Defense")
	local haki = self.Entity:HasStatus(HAKI_STATUS)
	local pool: Pool = {
		Start = os.clock(),
		Origin = origin,
		Direction = direction,
		Travel = TRAVEL * scale,
		Length = LENGTH * scale,
		Damage = math.round(DAMAGE * scale * (if haki then HAKI_MULTIPLIER else 1)),
		Haki = haki,
	}

	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		Travel = pool.Travel,
		Length = pool.Length,
		GrowTime = GROW_TIME,
		LingerTime = LINGER_TIME,
		Haki = haki,
	})

	task.delay(TICK_INTERVAL, burn, self, pool)
end

return Spew
