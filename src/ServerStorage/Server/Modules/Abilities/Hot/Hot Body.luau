--!strict
--[[
	Hot fruit - Hot Body (toggle): the body glows hot and burns whoever touches it.

	Damage: 150 * (defense level / cap) * defense affinity (Special, not dodgeable) to
	each body part of a victim that touches the user's head, torso or limbs, at most
	once per second PER PART, exactly as the legacy cooldown worked: someone pressed
	against the body takes one hit per second for every part in contact (seven on a
	standard rig), someone brushed by an arm takes one. With armament haki each hit is
	doubled and Haki.

	Rumble and Plasma users do not burn: that exception lives in
	DamageModifiers.HotBurnImmunity, which recognises these hits by their "HotBody" tag.

	The glowing shell is a client effect driven by the replicated status, whose value is
	the fruit color string (Effects.Status.HotBody).

	Contact. The legacy game used Touched connections on the six body parts. Here every
	body that is on is checked ten times a second by one shared loop: the characters
	around it are compared part by part with its six limbs, and a part counts as
	touching when a limb's centre is within CONTACT_REACH studs of it (a limb is about a
	stud thick; the rest covers what moves between two checks).

	Legacy problems fixed here:
	- The cooldown table was keyed by the touching part and never cleared.
	- The shell parts were server instances recolored by a haki listener per user.

	The check is not capped in time (the legacy toggle was not either); it stops the
	moment the ability is toggled off or interrupted.
]]
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local BodyTouch = require(ServerStorage.Server.Modules.BodyTouch)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local STATUS = "HotBody"
local DAMAGE_TAG = "HotBody"
-- Armament haki status set by HakiService.
local HAKI_STATUS = "Haki"

local BASE_DAMAGE = 150
local HAKI_MULTIPLIER = 2
local PART_COOLDOWN = 1
local TICK = 0.1
local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
-- Characters whose root is further than this are not looked at part by part.
local SCAN_RADIUS = 10
local CONTACT_REACH = 1.5

local HotBody = Ability.extend()

-- Bodies that are on -> last hit of every part they burned (weak: parts that are gone
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

local function burn(self: any, lastHit: { [BasePart]: number }, now: number)
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

	local damage = BASE_DAMAGE * self:GetLevelScale("Defense") * self:GetAffinity("Defense")
	local trait: CombatTypes.DamageTrait = "Special"
	if entity:HasStatus(HAKI_STATUS) then
		damage *= HAKI_MULTIPLIER
		trait = "Haki"
	end

	for _, target in victims do
		for _, part in target.Model:GetChildren() do
			if part:IsA("BasePart") and now - (lastHit[part] or 0) >= PART_COOLDOWN and touches(part, limbs) then
				lastHit[part] = now
				self:Damage(target, damage, trait, DAMAGE_TAG, false)
			end
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
		burn(self, lastHit, now)
	end
end

local function setBurning(self: any, burning: boolean)
	bodies[self] = if burning then setmetatable({}, { __mode = "k" }) :: any else nil
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

function HotBody:OnBegin()
	local entity = self.Entity

	-- Pressing the key grounds the flights for 3 s: AbilityService (Modules.FlightLock).
	if self.Active then
		self:OnInterrupt()
		return
	end

	self.Active = true
	entity:SetStatus(STATUS, self:GetColorString(), nil, true)
	setBurning(self, true)

	-- Through a Gum punch of the same character (Modules.BodyTouch, DF Gum.server
	-- 101-104, 118-121, 167-168): one hit of the contact damage, dodgeable like the
	-- punch and without the "HotBody" tag: the legacy script had no Rumble / Plasma
	-- exception on this path.
	BodyTouch.Set(entity, "Hot", {
		OnHit = function(target, punch)
			local damage = BASE_DAMAGE * self:GetLevelScale("Defense") * self:GetAffinity("Defense")
			if punch.Haki then
				punch.Ability:Damage(target, damage * HAKI_MULTIPLIER, "Haki", nil, true)
			else
				punch.Ability:Damage(target, damage, "Special", nil, true)
			end
		end,
	})
end

function HotBody:OnInterrupt()
	self.Active = false
	BodyTouch.Set(self.Entity, "Hot", nil)
	setBurning(self, false)
	self.Entity:ClearStatus(STATUS)
end

return HotBody
