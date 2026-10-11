--!strict
--[[
	Magma fruit - Magma Body (toggle): the body turns to magma and burns whoever touches it.

	With d = defense affinity and s = defense level / cap:
	- each body part of a victim that touches the user's head, torso or limbs takes
	  100 * s * d (Special, not dodgeable), at most once per second PER PART, exactly as
	  the legacy cooldown worked: someone pressed against the body takes one hit per
	  second for every part in contact (seven on a standard rig), someone brushed by an
	  arm takes one. With armament haki each hit is doubled and Haki;
	- a contact also leaves, or renews, "MagmaBurn": 100 * d * s every 0.5 s for 20 s.

	Rumble owners take 1 Melee per hit instead and Smelt / Hot / Plasma owners nothing
	(DamageModifiers.MagmaBurnImmunity, tag "MagmaHeat"); the burn is applied anyway,
	as in the legacy game.

	The flames and the body tint are a client effect driven by the replicated status,
	whose value is the fruit color string (Effects.Status.MagmaBody).

	Contact. The legacy game used Touched connections on the six body parts. Here every
	body that is on is checked ten times a second by one shared loop: the characters
	around it are compared part by part with its six limbs, and a part counts as
	touching when a limb's centre is within CONTACT_REACH studs of it (a limb is about a
	stud thick; the rest covers what moves between two checks).

	Legacy problems fixed here:
	- The cooldown table was keyed by the touching part and never cleared.
	- The connection table was cleaned with the wrong key, and the fire, the body colors
	  and the haki listener were only undone by the toggle, never on death.
]]
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local BodyTouch = require(ServerStorage.Server.Modules.BodyTouch)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local STATUS = "MagmaBody"
local DAMAGE_TAG = "MagmaHeat"
local BURN = "MagmaBurn"

local BASE_DAMAGE = 100
local HAKI_MULTIPLIER = 2
local BURN_INTERVAL = 0.5
local BURN_TICKS = 40
local PART_COOLDOWN = 1
local TICK = 0.1
local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
-- Characters whose root is further than this are not looked at part by part.
local SCAN_RADIUS = 10
local CONTACT_REACH = 1.5

local MagmaBody = Ability.extend()

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

	local base = BASE_DAMAGE * self:GetLevelScale("Defense") * self:GetAffinity("Defense")
	local damage = base
	local trait: CombatTypes.DamageTrait = "Special"
	if self.Services.Haki:IsArmamentActive(entity) then
		damage *= HAKI_MULTIPLIER
		trait = "Haki"
	end

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
				self:Damage(target, damage, trait, DAMAGE_TAG, false)
			end
			self.Services.Status:ApplyDot(target, BURN, {
				Source = entity,
				Damage = base,
				Interval = BURN_INTERVAL,
				Ticks = BURN_TICKS,
				Trait = "Special",
			})
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

function MagmaBody:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	self.Active = true
	self.Entity:SetStatus(STATUS, self:GetColorString(), nil, true)
	setBurning(self, true)

	-- Through a Gum punch of the same character (Modules.BodyTouch, DF Gum.server 85-88
	-- and 150-154): the punch is multiplied by the defense affinity and becomes Special,
	-- and whoever it hits burns for 20 s at 100 * affinity per tick - no level term in
	-- this one, unlike the burn of a body contact.
	BodyTouch.Set(self.Entity, "Magma", {
		ModifyDamage = function(damage: number): (number, CombatTypes.DamageTrait)
			return damage * self:GetAffinity("Defense"), "Special"
		end,
		OnHit = function(target)
			if target.Dead then
				return
			end
			self.Services.Status:ApplyDot(target, BURN, {
				Source = self.Entity,
				Damage = BASE_DAMAGE * self:GetAffinity("Defense"),
				Interval = BURN_INTERVAL,
				Ticks = BURN_TICKS,
				Trait = "Special",
			})
		end,
	})
end

function MagmaBody:OnInterrupt()
	self.Active = false
	BodyTouch.Set(self.Entity, "Magma", nil)
	setBurning(self, false)
	self.Entity:ClearStatus(STATUS)
end

return MagmaBody
