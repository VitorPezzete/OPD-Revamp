--!strict
--[[
	Venom fruit - Venom Hydra (charged key, but the charge changes nothing): a hydra
	head rises behind the user, arcs over and bites the aim point.

	On release, with a = sniper affinity:
	- the target is the aim point, pulled back to 75 * a studs from the user
	  (150 * a with Venom Demon);
	- the head bites 0.75 s later (0.45 s with Venom Demon): three neck segments of
	  0.2 s (0.1 s) and a lunge of 0.15 s. The neck of the lunge takes 0.35 s (0.2 s) to
	  finish growing, but the legacy script never waited for it;
	- everyone in a 50 stud cube around the target takes 500 * a (1000 * a with Venom
	  Demon), "Sword" trait, not dodgeable, and is poisoned: 375 * f per hit (750 with
	  Venom Demon), floor(5 * f) hits, Slow, with f = a * (sniper level / cap);
	- at most 3 heads per window of 15 - level * 0.01 * a seconds (the legacy `Heads`
	  counter), and 0.1 s between two heads.

	Kept as in the legacy game although odd: the bite is "Sword" damage (logia users are
	immune to it, the poison still lands) and does not scale with the level; the charge
	bar fills but is never read.

	Legacy problems fixed here:
	- The server checked level 200 while the fruit requires 400, and the 3 heads limit
	  only existed in the LocalScript.
	- "StopCharging" did not need a "StartCharging": the remote could be fired in a loop.
	- A target exactly on the user gave a NaN direction.
	- The head, its 5 joints and 4 necks were server parts moved by server tweens with
	  `task.wait` between them inside the remote handler; the bite is one delayed box
	  query now.

	A head already rising still bites when its user is stunned or sealed meanwhile, as in
	the legacy game (every client is drawing it); only the user's death stops it.

	The replicated VenomHydraCharging status is the owner's charging pose
	(Effects.Status.VenomHydraCharging); facing the aim is Shared.AIM_STATUS. The release
	clip is played by the VenomHydra one-shot.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local AIM_STATUS = Shared.AIM_STATUS
local CHARGE_STATUS = "VenomHydraCharging"
local EFFECT = "VenomHydra"

local RANGE = 75
local DEMON_RANGE = 150
-- Three neck segments and the wait of the final lunge: 3 * 0.2 + 0.15, or 3 * 0.1 + 0.15.
local TRAVEL_TIME = 0.75
local DEMON_TRAVEL_TIME = 0.45
local BITE_SIZE = Vector3.new(50, 50, 50)
local BITE_DAMAGE = 500
local DEMON_BITE_DAMAGE = 1000
local POISON_DAMAGE = 375
local DEMON_POISON_DAMAGE = 750
local POISON_HITS = 5
local MAX_HEADS = 3
local HEAD_WINDOW = 15
local HEAD_WINDOW_PER_LEVEL = 0.01
local COOLDOWN = 0.1

local VenomHydra = Ability.extend()

local function liveHeads(self: any, now: number): number
	local heads: { number } = self.Heads or {}
	for index = #heads, 1, -1 do
		if now >= heads[index] then
			table.remove(heads, index)
		end
	end
	self.Heads = heads
	return #heads
end

function VenomHydra:CanBegin(): boolean
	local now = os.clock()
	return now >= (self.ReadyAt or 0) and liveHeads(self, now) < MAX_HEADS
end

function VenomHydra:OnBegin()
	self:BeginCharge()
	self.Charging = true
	self.Entity:SetStatus(AIM_STATUS, true, nil, true)
	self.Entity:SetStatus(CHARGE_STATUS, true, nil, true)
end

function VenomHydra:OnEnd(input: Ability.AbilityInput)
	if not self:EndCharge(1, 0, 1) then
		return
	end
	local entity = self.Entity
	entity:ClearStatus(AIM_STATUS)
	entity:ClearStatus(CHARGE_STATUS)
	self.Charging = false

	local now = os.clock()
	local affinity = self:GetAffinity("Sniper")
	self.ReadyAt = now + COOLDOWN
	liveHeads(self, now)
	table.insert(self.Heads, now + HEAD_WINDOW - self:GetLevel("Sniper") * HEAD_WINDOW_PER_LEVEL * affinity)

	local demon = Shared.IsDemon(entity)
	local range = (if demon then DEMON_RANGE else RANGE) * affinity
	local origin = entity.Root.Position
	local target = input.AimPosition
	local offset = target - origin
	if offset.Magnitude > range then
		target = origin + offset.Unit * range
	end

	local travel = if demon then DEMON_TRAVEL_TIME else TRAVEL_TIME
	self:PlayEffect(EFFECT, origin, {
		Base = entity.Root.CFrame,
		Target = target,
		Demon = demon,
	})

	task.delay(travel, function()
		if entity.Dead then
			return
		end
		local bite = (if demon then DEMON_BITE_DAMAGE else BITE_DAMAGE) * affinity
		for _, victim in Hitbox.Box(CFrame.new(target), BITE_SIZE, entity) do
			Shared.Poison(self, victim, if demon then DEMON_POISON_DAMAGE else POISON_DAMAGE, POISON_HITS, "Sniper", "Slow")
			self:Damage(victim, bite, "Sword", nil, false)
		end
	end)
end

function VenomHydra:OnInterrupt()
	self.ChargeStart = nil
	-- Only when this ability is the one aiming: OnInterrupt also runs for idle siblings.
	if self.Charging then
		self.Charging = false
		self.Entity:ClearStatus(AIM_STATUS)
	end
	self.Entity:ClearStatus(CHARGE_STATUS)
end

return VenomHydra
