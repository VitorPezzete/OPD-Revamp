--!strict
--[[
	Dark fruit - Dark Charge (hold): the user stands still and swallows every hit, then
	gives it all back in one burst when the key is released (or after 10 s).

	With d = defense affinity and s = defense level / cap:
	- while held the user is rooted, cannot use any other power (sealed, as the legacy
	  DF_Disabled flag did) and takes no damage: each hit adds twice its amount to the
	  charge instead (DamageModifiers.DarkCharge), from 100 up to 5000 * d * s;
	- release: everyone within 57.5 * d + charge / 50 studs is stunned for 1 s and takes
	  the charge as Special damage, not dodgeable;
	- 20 s cooldown from the release, and it also waits for the cooldown Dark Vortex and
	  Black Hole share. Dark Star is blocked for those 20 s as well, and the charge cannot
	  be started while Dark Star is being charged.
	- only the user sees a dark disc under its feet while absorbing, as wide as
	  defense level / 10 + charge / 100 studs (at most defense level / 2): the replicated
	  DarkChargeGuide status, drawn by Effects.Status.DarkCharging.

	The charge is kept through stuns (KeepThroughStun): being stunned did not release or
	cancel it in the legacy game, but it could not be started while stunned. Death, an
	outside seal or losing the fruit drop the charge without a burst.

	Legacy problems fixed here:
	- The 10 s timeout was never cancelled: after an early release it fired on the next
	  charge started within those 10 s and cut it short.
	- The burst walked every descendant of the workspace to find characters.
	- The charge parts were created and welded by the server.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local EFFECT = "DarkChargeBurst"
local DAMAGE_TAG = "DarkCharge"
local ROOT = "DarkCharge"
local SEAL_SOURCE = "DarkCharge"
local STUN = "DarkChargeBurst"

local START_CHARGE = 100
local CHARGE_CAP = 5000
local MAX_HOLD = 10
local COOLDOWN = 20
local BASE_RADIUS = 57.5
local CHARGE_PER_STUD = 50
local STUN_TIME = 1
-- The disc under the user: studs of diameter per defense level and per point of charge.
local GUIDE_PER_LEVEL = 1 / 10
local GUIDE_PER_CHARGE = 1 / 100
local GUIDE_MAX_PER_LEVEL = 1 / 2

local DarkCharge = Ability.extend()

DarkCharge.KeepThroughStun = true

function DarkCharge:CanBegin(): boolean
	local entity = self.Entity
	return not self.Active
		and os.clock() >= (self.ReadyAt or 0)
		and not entity:HasStatus(Shared.CooldownStatus)
		and Shared.CanCast(entity)
end

function DarkCharge:OnBegin()
	local entity = self.Entity

	-- Sealing interrupts every ability of the character, this one included: the flag
	-- makes our own OnInterrupt ignore that call, and the state is set up after it.
	self.Sealing = true
	self.Services.Ability:SetSealed(entity, true, nil, SEAL_SOURCE)
	self.Sealing = false

	local state: Shared.ChargeState = {
		Charge = START_CHARGE,
		Cap = CHARGE_CAP * self:GetAffinity("Defense") * self:GetLevelScale("Defense"),
	}
	self.State = state
	self.Active = true
	self.Epoch = (self.Epoch or 0) + 1
	self.ReadyAt = os.clock() + COOLDOWN

	local level = self:GetLevel("Defense")
	local function showGuide()
		local diameter = level * GUIDE_PER_LEVEL + state.Charge * GUIDE_PER_CHARGE
		diameter = math.min(diameter, level * GUIDE_MAX_PER_LEVEL)
		entity:SetStatus(Shared.ChargeGuideStatus, math.floor(diameter * 10 + 0.5) / 10, nil, true)
	end
	state.Absorbed = showGuide
	showGuide()

	entity:SetStatus(Shared.ChargeStateStatus, state)
	entity:SetStatus(Shared.ChargingStatus, self:GetColorString(), nil, true)
	entity:SetRooted(ROOT, true)
	Shared.MarkRecent(entity, COOLDOWN)

	local epoch = self.Epoch
	task.delay(MAX_HOLD, function()
		if self.Epoch == epoch and self.State == state then
			self:Release()
		end
	end)
end

-- Ends the absorbing state. Returns the state that was running, if any.
function DarkCharge:Stop(): Shared.ChargeState?
	local state: Shared.ChargeState? = self.State
	if not state then
		return nil
	end

	local entity = self.Entity
	self.State = nil
	self.Active = false
	self.Epoch = (self.Epoch or 0) + 1

	state.Absorbed = nil
	entity:ClearStatus(Shared.ChargeStateStatus)
	entity:ClearStatus(Shared.ChargingStatus)
	entity:ClearStatus(Shared.ChargeGuideStatus)
	entity:SetRooted(ROOT, false)
	self.Services.Ability:SetSealed(entity, false, nil, SEAL_SOURCE)
	return state
end

function DarkCharge:Release()
	local state: Shared.ChargeState? = self:Stop()
	if not state then
		return
	end

	local entity = self.Entity
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)
	Shared.MarkRecent(entity, COOLDOWN)

	local charge = state.Charge
	local origin = entity.Root.Position
	local radius = BASE_RADIUS * self:GetAffinity("Defense") + charge / CHARGE_PER_STUD

	local models: { Model } = {}
	for _, target in Hitbox.Sphere(origin, radius - Shared.BodyRadius, entity) do
		self.Services.Status:ApplyStun(target, STUN_TIME, STUN)
		self:Damage(target, charge, "Special", DAMAGE_TAG, false)
		table.insert(models, target.Model)
	end

	self:PlayEffect(EFFECT, origin, { Targets = models, Duration = STUN_TIME })
end

function DarkCharge:OnEnd()
	if self.State then
		self:Release()
	end
end

function DarkCharge:OnInterrupt()
	if self.Sealing then
		return
	end
	self:Stop()
end

return DarkCharge
