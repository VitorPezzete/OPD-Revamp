--!strict
--[[
	Blood fruit - Blood Surge (hold): the user melts into blood, reappears further along
	the aim line and keeps streaming forward for as long as the key is held.

	Cost:      5% of max health (doubled by Concentrate)
	Blink:     50 * defense affinity studs towards the aim point (doubled by
	           Concentrate), or to the very point where the first thing in the way is
	           met. The user arrives facing the aim direction, pitch included, and is
	           held still for 0.3 s (the legacy zero BodyVelocity, MaxForce 100000: while
	           the key is held it fights the flight, which starts at half speed).
	Untouchable for 0.5 s after the blink (1 s with Concentrate)
	Flight:    while held, defense level / 15 * defense affinity + 15 studs per second
	           in the direction the camera looks (flown by the owner's client)
	Cooldown   1.75 s: the lock of the legacy client. The legacy server's own 1.5 s was
	           shorter, so it never was what limited the ability.

	The server owns the blink, the guard and the "is streaming" status
	("<speed>|<fruit colors>"); Effects.Status.BloodSurge draws the pool and the body
	particles for everyone and flies the owner.

	Legacy problems fixed here:
	- Being untouchable was done by clearing the character's Spawned flag, which also
	  made the user unable to hit anything and hid it from every other system. It is
	  now a short status read by the BloodSurge damage modifier.
	- The path was found with up to 50 two-stud raycasts; it is one raycast.
	- Nothing ended the stream on death or seal; the particles were only removed by the
	  release message, so a dropped remote left them on the body forever.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local BloodShared = require(script.Parent.BloodShared)

local STATUS = "BloodSurge"
-- Read by DamageModifiers/BloodSurge.
local GUARD_STATUS = "BloodSurgeGuard"

local COOLDOWN = 1.75
local HEALTH_COST = 5
local BASE_DISTANCE = 50
local GUARD_TIME = 0.5
-- The legacy BodyVelocity that pinned the user after the blink.
local HOLD_TIME = 0.3
local HOLD_FORCE = Vector3.new(100000, 100000, 100000)
local BASE_SPEED = 15
local LEVELS_PER_SPEED = 15

local Surge = Ability.extend()

function Surge:CanBegin(): boolean
	return not self.Entity.Humanoid.Sit and os.clock() - (self.LastCast or 0) >= COOLDOWN
end

function Surge:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	-- A release that never arrived must not leave a second seat connection behind.
	self:Land()
	self.LastCast = os.clock()
	self:StartCooldown(COOLDOWN)
	BloodShared.PayHealth(entity, HEALTH_COST)
	if entity.Dead then
		return
	end

	local affinity = self:GetAffinity("Defense")
	local scale = BloodShared.GetScale(entity)

	local origin = entity.Root.Position
	local offset = input.AimPosition - origin
	local direction = if offset.Magnitude > 1e-3 then offset.Unit else entity.Root.CFrame.LookVector
	local maxDistance = BASE_DISTANCE * affinity * scale

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	local result = Workspace:Raycast(origin, direction * maxDistance, params)
	local destination = if result then result.Position else origin + direction * maxDistance

	local rotation = if math.abs(direction.Y) < 0.999
		then CFrame.lookAt(Vector3.zero, direction).Rotation
		else CFrame.lookAt(Vector3.zero, direction, Vector3.xAxis).Rotation
	self.Services.Character:Teleport(entity, CFrame.new(destination) * rotation)
	self:Impulse(entity, Vector3.zero, HOLD_TIME, HOLD_FORCE)

	entity:SetStatus(GUARD_STATUS, true, GUARD_TIME * scale)

	local speed = self:GetLevel("Defense") / LEVELS_PER_SPEED * affinity + BASE_SPEED
	self.Active = true
	entity:SetStatus(STATUS, string.format("%.3f|%s", speed, self:GetColorString()), nil, true)
	self.SeatConnection = entity.Humanoid.Seated:Connect(function(seated: boolean)
		if seated then
			self:Land()
		end
	end)
end

function Surge:OnEnd()
	if self.Active then
		self:Land()
	end
end

-- Ends the stream. The guard is left to run out, as it did when the key was released.
function Surge:Land()
	self.Active = false
	if self.SeatConnection then
		self.SeatConnection:Disconnect()
		self.SeatConnection = nil
	end
	self.Entity:ClearStatus(STATUS)
end

function Surge:OnInterrupt()
	self:Land()
	self.Entity:ClearStatus(GUARD_STATUS)
end

return Surge
