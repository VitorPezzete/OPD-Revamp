--!strict
--[[
	Paw fruit - Ursus Shock (held): while the key is down every hit the user would take is
	swallowed into a giant paw floating above its head; on release the paw is thrown.

	With b = (defense level / cap) * defense affinity / 2:
	- while held, a hit that got through everything else (dodge, immunities, shield,
	  resistances) deals nothing and its final amount is added to the damage taken
	  (DamageModifiers.PawUrsusShock);
	- absorbed = clamp(damage taken, 100 b, 15000 b) and f = b * absorbed / (15000 b): the
	  paw is 75 f x 75 f x 50 f studs, centred 7.5 + 37.5 f studs above the root;
	- on release it flies towards the aim point at 100 studs/s for clamp(5 f, 1, 5) seconds
	  at most, stops at the first thing it touches and bursts there (a sphere 250 f studs
	  wide and a ring, Effects.OneShot.PawUrsusShock);
	- 10 s cooldown after the release. Nothing else of the fruit can be used while held.

	WHAT THE SOURCE REALLY DID, and what was decided here:
	- The burst deals NO damage in the source. The server script only raised the absorbing
	  flag and lowered it; the damage taken is read by the client effect alone, to size the
	  paw. Nothing, on the server or through a remote, ever hurt anyone (POWER4_MAX_DAMAGE
	  is declared and never used). That is reproduced: RELEASE_DEALS_DAMAGE is false. Set it
	  to true for the obvious intent: everyone within the burst sphere (125 f studs) takes
	  `absorbed` as "Special" damage, not dodgeable, decided here on the server.
	- The server never reset its cooldown flag: the power worked once per life, while the
	  client showed 10 s. The 10 s of the client (POWER4_COOLDOWN) is used.
	- Nothing limited the hold: the charge bar filled in 10 s (POWER4_MAX_CHARGE) and the
	  user stayed untouchable for as long as the key was down. The hold ends by itself at
	  10 s here: the owner's client releases with its aim when the bar is full, and the
	  server does it on its own shortly after (thrown where the character faces) if that
	  never comes.
	- The paw's flight and where it burst were decided by each client separately. The
	  server simulates it once (Projectile) and tells the clients where it ended.
	- The sea. The source's water damage took health directly, so a held paw neither
	  stopped it nor grew from it. Here the sea is a hit like any other and the paw
	  swallowed it: a user could stand in the water unharmed while the paw filled up. Now
	  the sea is never swallowed (DamageModifiers.PawUrsusShock) and the first sea hit
	  while the paw is held throws it, exactly as the hold running out does: where the
	  character faces, same paw, same 10 s cooldown. That hit and the following ones hurt.
	  Raised while already in the water, the paw is thrown at the next sea hit (0.23 s at
	  most) at its smallest size.

	Statuses on the user while held:
	- "PawUrsusShock" replicated: "<b>|<colors>|<fruit slot>|<ability slot>".
	- "PawUrsusTaken" replicated number: the damage taken so far (the client effect sizes
	  the paw with it and plays the "taken" sound when it changes).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local Paw = require(script.Parent._Shared)

local NAME = "Ursus Shock"
local SKILL = "Defense"
-- Shared with DamageModifiers.PawUrsusShock and Effects.Status.PawUrsusShock.
local STATUS = "PawUrsusShock"
local TAKEN_STATUS = "PawUrsusTaken"
local EFFECT = "PawUrsusShock"

-- See the header: the source burst hurt nobody.
local RELEASE_DEALS_DAMAGE = false

local MAX_HOLD = 10
-- How long past MAX_HOLD the server waits for the owner's client to release with its aim.
local RELEASE_GRACE = 0.5
local COOLDOWN = 10
local MIN_ABSORBED = 100
local MAX_ABSORBED = 15000
local MAX_SPEED = 100
local FLIGHT_SECONDS = 5
local MIN_FLIGHT_SECONDS = 1
-- Per unit of factor: half the width of the paw, which is also how far its centre rises.
local PAW_HALF_WIDTH = 37.5
local BASE_HEIGHT = 7.5
-- Radius of the burst sphere per unit of factor (it grows to 250 f studs wide).
local BURST_RADIUS = 125

local UrsusShock = Ability.extend()
-- The source named no style for this fruit's damage: ResistAbilities does not apply.
UrsusShock.DamageStyle = "Plain"

local function release(self: any, aim: Vector3?)
	local entity = self.Entity
	local base: number = self.Base or 0
	local taken = entity:GetStatus(TAKEN_STATUS)

	self.Active = false
	self.Run = (self.Run or 0) + 1
	self:EndCharge(1, 0, MAX_HOLD)
	entity:ClearStatus(STATUS)
	entity:ClearStatus(TAKEN_STATUS)
	Paw.ClearBusy(entity, NAME)
	Paw.OnWater(entity, nil)
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)
	if base <= 0 then
		return
	end

	local absorbed = math.clamp(if type(taken) == "number" then taken else 0, MIN_ABSORBED * base, MAX_ABSORBED * base)
	local factor = base * absorbed / (MAX_ABSORBED * base)

	local root = entity.Root
	local origin = (root.CFrame * CFrame.new(0, BASE_HEIGHT + PAW_HALF_WIDTH * factor, 0)).Position
	local speed = MAX_SPEED
	local range = speed * math.clamp(FLIGHT_SECONDS * factor, MIN_FLIGHT_SECONDS, FLIGHT_SECONDS)
	local direction = if aim then Paw.Direction(entity, origin, aim) else root.CFrame.LookVector
	direction = Projectile.Lead(entity, origin, direction, speed, range)

	local id = Paw.NextId()
	self:PlayEffect(EFFECT, origin, {
		Phase = "Fly",
		Id = id,
		Direction = direction,
		Speed = speed,
		Range = range,
		Factor = factor,
	}, Paw.EFFECT_RADIUS + range)

	Projectile.Fire({
		Origin = origin,
		Direction = direction,
		Speed = speed,
		MaxDistance = range,
		Radius = PAW_HALF_WIDTH * factor,
		Owner = entity,
		HitOverlapping = true,
		OnHit = function() end,
		OnEnd = function(stopped: Vector3)
			-- The burst is around the middle of the paw, not where its edge touched.
			local position = Paw.Centre(origin, direction, range, PAW_HALF_WIDTH * factor, stopped)
			self:PlayEffect(EFFECT, position, {
				Phase = "Burst",
				Id = id,
				Direction = direction,
				Factor = factor,
				-- Wide enough to reach whoever was sent the paw from where it started.
			}, Paw.EFFECT_RADIUS + math.max((position - origin).Magnitude, BURST_RADIUS * factor))

			if RELEASE_DEALS_DAMAGE and not entity.Dead then
				for _, target in Hitbox.Sphere(position, BURST_RADIUS * factor, entity) do
					self:Damage(target, absorbed, "Special", nil, false)
				end
			end
		end,
	})
end

function UrsusShock:CanBegin(): boolean
	return not self.Active and os.clock() >= (self.ReadyAt or 0) and not Paw.IsBusy(self.Entity)
end

function UrsusShock:OnBegin()
	local entity = self.Entity
	local context = self.Context
	local base = Paw.Factor(self, SKILL)

	self.Active = true
	self.Base = base
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	self:BeginCharge(MAX_HOLD)
	Paw.SetBusy(entity, NAME)
	entity:SetStatus(TAKEN_STATUS, 0, nil, true)
	entity:SetStatus(
		STATUS,
		string.format("%.4f|%s|%d|%d", base, self:GetColorString(), context.FruitSlot, context.Definition.Slot),
		nil,
		true
	)

	-- Both automatic releases go through the one the key uses, and only for the hold they
	-- were set up for: `release` ends the hold (Active, Run), so neither can throw a second
	-- paw nor one after an interrupt, and both start the cooldown.
	local function releaseUnaimed()
		if self.Run == run and self.Active then
			release(self, nil)
		end
	end
	Paw.OnWater(entity, releaseUnaimed)
	task.delay(MAX_HOLD + RELEASE_GRACE, releaseUnaimed)
end

function UrsusShock:OnEnd(input: Ability.AbilityInput)
	if self.Active then
		release(self, input.AimPosition)
	end
end

-- Death, seal, stun, fruit lost: the paw and what it swallowed are simply dropped. A paw
-- dropped that way costs its cooldown all the same, or a stunned user could raise it again
-- the moment the stun ends.
function UrsusShock:OnInterrupt()
	self.ChargeStart = nil
	self.Run = (self.Run or 0) + 1
	if self.Active then
		self.Active = false
		self.Entity:ClearStatus(STATUS)
		self.Entity:ClearStatus(TAKEN_STATUS)
		self.ReadyAt = os.clock() + COOLDOWN
		if not self.Entity.Dead then
			self:StartCooldown(COOLDOWN)
		end
	end
	Paw.ClearBusy(self.Entity, NAME)
	Paw.OnWater(self.Entity, nil)
end

return UrsusShock
