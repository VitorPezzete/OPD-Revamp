--!strict
--[[
	String fruit - God Thread (charged): sixteen threads gather behind the user and are
	driven through everything in a line.

	- Charge: 25 per second held, 4 to 500 (20 s for a full charge).
	- On release everyone whose root is inside a 20 x 20 x 200 stud box from the user
	  towards the aim point is hit once, instantly (the legacy test was the root
	  position alone, with no body width added).
	- Damage: 3750 * sniper affinity * (sniper level / cap) * charge / 500, "Sword", not
	  dodgeable. Armament haki at the start of the charge doubles it and makes it "Haki".
	- 3 s after a release before the next charge can start (the legacy client lock).
	- Hands alternate, right first (owner's animation).

	Visuals: the "StringGodThread" status while charging (Effects.Status.StringGodThread)
	and the one-shot "StringGodThread" when it fires.

	Legacy problems fixed here:
	- The hit test created two anchored parts and a tween for every player and every
	  NPC on the map, each time (they were only destroyed two seconds later).
	- The box was asked to be 400 studs long but the function ignored that argument and
	  used 200; 200 is kept, since that is what the power really did.
	- The 16 threads were server parts with AlignPosition constraints.
	- A release without a press hit for the minimum charge; it does nothing now.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

local STATUS = "StringGodThread"
local EFFECT = "StringGodThread"
local DAMAGE_TAG = "GodThread"
local HAKI_STATUS = "Haki"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 500
local BASE_DAMAGE = 3750
local HAKI_MULTIPLIER = 2
local BOX_WIDTH = 20
local BOX_LENGTH = 200
local COOLDOWN = 3

local GodThread = Ability.extend()

function GodThread:CanBegin(): boolean
	return not self.ChargeStart and os.clock() >= (self.ReadyAt or 0)
end

function GodThread:OnBegin()
	local entity = self.Entity
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	self.ChargeHaki = entity:HasStatus(HAKI_STATUS)
	-- "<haki 0/1>|<colors>|<hand>"
	local hand = if self.UseLeft then "Left" else "Right"
	entity:SetStatus(STATUS, `{if self.ChargeHaki then 1 else 0}|{self:GetColorString()}|{hand}`, nil, true)
end

function GodThread:OnEnd(input)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end

	local entity = self.Entity
	entity:ClearStatus(STATUS)
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)
	local hand = if self.UseLeft then "Left" else "Right"
	self.UseLeft = not self.UseLeft

	local origin = entity.Root.Position
	local direction = input.AimPosition - origin
	direction = if direction.Magnitude > 0.05 then direction.Unit else entity.Root.CFrame.LookVector

	local haki: boolean = self.ChargeHaki == true
	local damage = BASE_DAMAGE * self:GetAffinity("Sniper") * self:GetLevelScale("Sniper") * charge / CHARGE_MAX
	if haki then
		damage *= HAKI_MULTIPLIER
	end

	local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local middle = origin + direction * (BOX_LENGTH / 2)
	local box = CFrame.lookAt(middle, middle + direction, up)
	for _, target in Hitbox.Box(box, Vector3.new(BOX_WIDTH, BOX_WIDTH, BOX_LENGTH), entity) do
		-- Hitbox.Box pads the box by a body radius; the legacy test was the root alone.
		local offset = box:PointToObjectSpace(target.Root.Position)
		if
			math.abs(offset.X) <= BOX_WIDTH / 2
			and math.abs(offset.Y) <= BOX_WIDTH / 2
			and math.abs(offset.Z) <= BOX_LENGTH / 2
		then
			self:Damage(target, damage, if haki then "Haki" else "Sword", DAMAGE_TAG, false)
		end
	end

	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		Range = BOX_LENGTH,
		Haki = haki,
		Held = charge / CHARGE_RATE,
		Hand = hand,
	})
end

function GodThread:OnInterrupt()
	self.ChargeStart = nil
	self.Entity:ClearStatus(STATUS)
end

return GodThread
