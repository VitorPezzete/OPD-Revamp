--!strict
--[[
	Spin fruit - Raging Top (toggle): spin on the spot, hitting everyone in arm's reach.

	Per hit:        melee level / 4 * melee affinity   (Melee; doubled and Haki with armament)
	Hit interval:   0.25 - 0.0625 * melee affinity seconds, per victim
	Spin speed:     1000 + 900 * melee affinity * melee level / 200 degrees per second

	The spin itself is local movement: the status carries "<degrees per second>|<colors>"
	and the owner's client rotates the character (Effects.Status.SpinRagingTop).

	Legacy problems fixed here:
	- Damage came from Touched connections on the arms plus a Heartbeat loop per user
	  rotating a BodyGyro on the server. It is now one short repeating delay that asks
	  the hitbox module who is in reach; its period is the legacy per-victim cooldown,
	  so the damage rate is the same.
	- The per-victim cooldown table was keyed by character model and never cleared.
	- Arm trails were server instances, left behind if the script died mid-spin.

	The tick is not capped in time (the legacy toggle was not either); it stops by itself
	the moment the ability is toggled off, interrupted, or the character sits.

	A stun does not stop the spin (KeepThroughStun): the legacy loop only ended on death,
	on sitting or with the toggle, and a stunned user could not press the key. Death, seal
	and fruit loss end it.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

local STATUS = "SpinRagingTop"
-- Armament haki status set by HakiService.
local HAKI_STATUS = "Haki"
local STUN_STATUS = "Stunned"

-- The legacy hit test was "an arm touched something". The arms hang at the sides, their
-- outer face 2 studs from the root, and the widest part of a victim is 2 studs from its
-- own root: contact needs the two roots within 4 studs. Hitbox adds the victim's body
-- radius (2.5) to this.
local HIT_RADIUS = 1.5
local MIN_INTERVAL = 0.1

local RagingTop = Ability.extend()

RagingTop.KeepThroughStun = true

function RagingTop:CanBegin(): boolean
	local entity = self.Entity
	if entity:HasStatus(STUN_STATUS) then
		return false
	end
	return self.Active or not (entity.Humanoid.Sit or entity:IsRooted())
end

function RagingTop:OnBegin()
	local entity = self.Entity

	-- Pressing the key grounds the flights for 3 s: AbilityService (Modules.FlightLock).

	if self.Active then
		self:OnInterrupt()
		return
	end

	local affinity = self:GetAffinity("Melee")
	local degreesPerSecond = math.round(1000 + 900 * affinity * self:GetLevel("Melee") / 200)
	local interval = math.max(MIN_INTERVAL, 0.25 - 0.0625 * affinity)

	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	entity:SetStatus(STATUS, `{degreesPerSecond}|{self:GetColorString()}`, nil, true)
	self.SeatConnection = entity.Humanoid.Seated:Connect(function(seated: boolean)
		if seated then
			self:OnInterrupt()
		end
	end)

	local function tick()
		if self.Run ~= run or not self.Active then
			return
		end

		local damage = self:GetLevel("Melee") / 4 * affinity
		local trait = "Melee"
		if entity:HasStatus(HAKI_STATUS) then
			damage *= 2
			trait = "Haki"
		end

		for _, target in Hitbox.Sphere(entity.Root.Position, HIT_RADIUS, entity) do
			self:Damage(target, damage, trait, nil, true)
		end
		task.delay(interval, tick)
	end
	task.delay(interval, tick)
end

function RagingTop:OnInterrupt()
	self.Active = false
	-- Invalidates the pending tick of the run that just ended.
	self.Run = (self.Run or 0) + 1
	if self.SeatConnection then
		self.SeatConnection:Disconnect()
		self.SeatConnection = nil
	end
	self.Entity:ClearStatus(STATUS)
end

return RagingTop
