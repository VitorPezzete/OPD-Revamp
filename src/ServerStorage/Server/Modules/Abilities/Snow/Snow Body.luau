--!strict
--[[
	Snow fruit - Snow Body (toggle): the body turns to snow and whoever touches it is
	hurt and slowed.

	Each body part of a victim that touches the user's head, torso or limbs takes 100
	damage (flat, Special, not dodgeable), at most once per second PER PART, exactly as
	the legacy cooldown worked: someone pressed against the body takes one hit per second
	for every part in contact (seven on a standard rig), someone brushed by an arm takes
	one. A contact also leaves, or renews, SnowTouched: 200 * defense affinity *
	(defense level / cap) every 0.5 s, floor(10 * defense affinity) times, at 10% walk
	speed (SnowShared.Touch). Crew-war teammates are slowed too; only the damage is
	cancelled for them (by the combat pipeline), as in the legacy game.

	Stuns do not end it (KeepThroughStun): the legacy body only went away on the toggle,
	on a sealed fruit and on death.

	The snow body is a client effect driven by the replicated status, whose value is the
	fruit color string (Effects.Status.SnowBody). While it is on, the logia "hit passes
	through" visual is skipped (Passives.Snow), as in the legacy game.

	Contact. The legacy game used Touched connections on the body parts. Here every body
	that is on is checked ten times a second by one shared loop: the characters around
	it are compared part by part with its six limbs, and a part counts as touching when
	a limb's centre is within CONTACT_REACH studs of it (a limb is about a stud thick;
	the rest covers what moves between two checks).

	Legacy problems fixed here:
	- The cooldown table was keyed by the touching part and never cleared.
	- The touch connections lived in a script-level table and were not removed on death.

	Not reproduced: head and torso were moved to a "Snow" collision group that did not
	collide with itself (snowed map parts of the globe, a Snow Ring). The root part
	stayed in the default group and has the torso's size, so the body was stopped by
	them anyway.

	The check is not capped in time (the legacy toggle was not either); it stops as soon
	as the ability is toggled off or interrupted.
]]
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local BodyTouch = require(ServerStorage.Server.Modules.BodyTouch)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local SnowShared = require(script.Parent.SnowShared)

local STATUS = "SnowBody"
local DAMAGE_TAG = "SnowBody"

local CONTACT_DAMAGE = 100
local DOT_DAMAGE = 200
local DOT_HITS = 10
local PART_COOLDOWN = 1
local TICK = 0.1
local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
-- Characters whose root is further than this are not looked at part by part.
local SCAN_RADIUS = 10
local CONTACT_REACH = 1.5

local SnowBody = Ability.extend()

SnowBody.KeepThroughStun = true

-- Bodies that are on -> last hit of every part they touched (weak: parts that are gone
-- are forgotten).
local bodies: { [any]: { [BasePart]: number } } = {}
local connection: RBXScriptConnection? = nil
local elapsed = 0

local function touches(part: BasePart, limbs: { Vector3 }): boolean
	local half = part.Size / 2
	local cframe = part.CFrame
	for _, limb in limbs do
		local offset = cframe:PointToObjectSpace(limb)
		local gap = Vector3.new(
			math.max(math.abs(offset.X) - half.X, 0),
			math.max(math.abs(offset.Y) - half.Y, 0),
			math.max(math.abs(offset.Z) - half.Z, 0)
		)
		if gap.Magnitude <= CONTACT_REACH then
			return true
		end
	end
	return false
end

local function chill(self: any, lastHit: { [BasePart]: number }, now: number)
	local entity = self.Entity
	local victims = Hitbox.Sphere(entity.Root.Position, SCAN_RADIUS, entity)
	if #victims == 0 then
		return
	end

	local limbs: { Vector3 } = {}
	for _, name in LIMBS do
		local limb = entity.Model:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			table.insert(limbs, limb.Position)
		end
	end

	local affinity = self:GetAffinity("Defense")
	for _, target in victims do
		local hits = 0
		for _, part in target.Model:GetChildren() do
			if part:IsA("BasePart") and now - (lastHit[part] or 0) >= PART_COOLDOWN and touches(part, limbs) then
				lastHit[part] = now
				hits += 1
			end
		end
		if hits > 0 then
			for _ = 1, hits do
				self:Damage(target, CONTACT_DAMAGE, "Special", DAMAGE_TAG, false)
			end
			SnowShared.Touch(self, target, DOT_DAMAGE * affinity * self:GetLevelScale("Defense"), DOT_HITS * affinity)
		end
	end
end

local function step(deltaTime: number)
	elapsed += deltaTime
	if elapsed < TICK then
		return
	end
	elapsed = 0

	local now = os.clock()
	for self, lastHit in bodies do
		chill(self, lastHit, now)
	end
end

local function setChilling(self: any, chilling: boolean)
	bodies[self] = if chilling then setmetatable({}, { __mode = "k" }) :: any else nil
	if next(bodies) == nil then
		if connection then
			connection:Disconnect()
			connection = nil
		end
	elseif not connection then
		elapsed = 0
		connection = RunService.Heartbeat:Connect(step)
	end
end

function SnowBody:OnBegin()
	local entity = self.Entity

	if self.Active then
		self:OnInterrupt()
		return
	end

	self.Active = true
	entity:SetStatus(STATUS, self:GetColorString(), nil, true)
	setChilling(self, true)

	-- Through a Gum punch of the same character (Modules.BodyTouch, DF Gum.server 93-96,
	-- 160-164): the same SnowTouched as a contact, without the 100 contact damage (the
	-- legacy script computed an extra damage for Snow and never dealt it).
	BodyTouch.Set(entity, "Snow", {
		OnHit = function(target)
			local affinity = self:GetAffinity("Defense")
			SnowShared.Touch(
				self,
				target,
				DOT_DAMAGE * affinity * self:GetLevelScale("Defense"),
				math.floor(DOT_HITS * affinity)
			)
		end,
	})
end

function SnowBody:OnInterrupt()
	self.Active = false
	BodyTouch.Set(self.Entity, "Snow", nil)
	setChilling(self, false)
	self.Entity:ClearStatus(STATUS)
end

return SnowBody
