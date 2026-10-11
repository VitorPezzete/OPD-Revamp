--!strict
--[[
	Smelt fruit - Silver Body (toggle): the body is coated in molten silver.

	While active:
	- Incoming damage is reduced by 0.125 * defense affinity * (defense level / cap)
	  (DamageModifiers/SmeltBody, gated on the SmeltBodyGuard status set here).
	- Anyone touching the user burns for 150 * defense affinity * (defense level / cap),
	  once per second for each of the victim's body parts in contact: a victim pressed
	  against the user takes several hits a second, as in the legacy game. "Special"
	  damage; armament haki doubles it and makes it "Haki". Without haki the owners of a
	  heat-proof fruit are spared: a Rumble owner takes 1 "Melee" per hit instead, Hot
	  and Plasma owners nothing.

	Legacy problems fixed here:
	- Contact came from Touched connections on every limb. It is now one check, four
	  times a second, of which body parts of the characters standing close reach the
	  user's body, with the same one second cooldown per touched part.
	- The connections lived in script-level variables overwritten on every activation,
	  so toggling quickly leaked Touched handlers that kept dealing damage.
	- The shell parts were server instances that stayed on the corpse; the look is a
	  client effect driven by the replicated status and removed in OnInterrupt.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Ability = require(ServerStorage.Server.Classes.Ability)
local BodyTouch = require(ServerStorage.Server.Modules.BodyTouch)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

-- Replicated: value is the fruit color string the client paints the shell with.
local STATUS = "SmeltBody"
-- Server only: value is the damage reduction fraction read by the damage modifier.
local GUARD_STATUS = "SmeltBodyGuard"
local HAKI_STATUS = "Haki"
local DAMAGE_TAG = "SmeltBody"

local REDUCTION = 0.125
local CONTACT_DAMAGE = 150
local HAKI_MULTIPLIER = 2
local CONTACT_INTERVAL = 0.25
-- Per touched body part, as the legacy Touched handler counted it.
local PART_COOLDOWN = 1
-- Characters whose root is further than this are not looked at.
local SEARCH_RADIUS = 12
-- The user's body around its root (an R6 character is 4 x 5 x 1, its root 0.5 above
-- the middle), with some room for limbs that are moving.
local BODY_OFFSET = CFrame.new(0, -0.5, 0)
local BODY_HALF_SIZE = Vector3.new(2.5, 3.25, 1.75)
local REDUCED_DAMAGE = 1
local REDUCED_FRUIT = "Rumble"
local SPARED_FRUITS = { "Hot", "Plasma" }

local SilverBody = Ability.extend()

-- How a victim's own fruit answers the heat: "Burn", "Graze" (Rumble) or "Spare".
local function heatAnswer(target: any): string
	local player = target.Player
	if not player then
		return "Burn"
	end

	local fruitService = Knit.GetService("FruitService")
	if fruitService:HasFruit(player, REDUCED_FRUIT) then
		return "Graze"
	end
	for _, fruitName in SPARED_FRUITS do
		if fruitService:HasFruit(player, fruitName) then
			return "Spare"
		end
	end
	return "Burn"
end

-- Counts the body parts of `model` that reach the box `body` and are off cooldown,
-- and starts their cooldown.
local function touch(body: CFrame, model: Model, burned: { [BasePart]: number }, now: number): number
	local count = 0
	for _, child in model:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end
		local part: BasePart = child
		if now - (burned[part] or 0) < PART_COOLDOWN then
			continue
		end

		-- The point of the part closest to the middle of the body.
		local half = part.Size / 2
		local center = part.CFrame:PointToObjectSpace(body.Position)
		local closest = part.CFrame
			* Vector3.new(
				math.clamp(center.X, -half.X, half.X),
				math.clamp(center.Y, -half.Y, half.Y),
				math.clamp(center.Z, -half.Z, half.Z)
			)
		local offset = body:PointToObjectSpace(closest)
		if
			math.abs(offset.X) <= BODY_HALF_SIZE.X
			and math.abs(offset.Y) <= BODY_HALF_SIZE.Y
			and math.abs(offset.Z) <= BODY_HALF_SIZE.Z
		then
			burned[part] = now
			count += 1
		end
	end
	return count
end

-- One contact check; reschedules itself until the toggle that started it ends.
local function burn(self: any, epoch: number)
	if not self.Active or self.Epoch ~= epoch then
		return
	end

	local entity = self.Entity
	local now = os.clock()
	local body = entity.Root.CFrame * BODY_OFFSET
	local burned = self.Burned

	for _, target in Hitbox.Sphere(body.Position, SEARCH_RADIUS, entity) do
		local hits = touch(body, target.Model, burned, now)
		if hits == 0 then
			continue
		end

		local damage = CONTACT_DAMAGE * self:GetAffinity("Defense") * self:GetLevelScale("Defense")
		local haki = entity:HasStatus(HAKI_STATUS)
		local answer = if haki then "Burn" else heatAnswer(target)
		if answer == "Spare" then
			continue
		end

		for _ = 1, hits do
			if haki then
				self:Damage(target, damage * HAKI_MULTIPLIER, "Haki", DAMAGE_TAG, false)
			elseif answer == "Graze" then
				self:Damage(target, REDUCED_DAMAGE, "Melee", DAMAGE_TAG, false)
			else
				self:Damage(target, damage, "Special", DAMAGE_TAG, false)
			end
		end
	end

	task.delay(CONTACT_INTERVAL, burn, self, epoch)
end

function SilverBody:OnBegin()
	self.Active = not self.Active
	if not self.Active then
		self:OnInterrupt()
		return
	end

	local reduction = REDUCTION * self:GetAffinity("Defense") * self:GetLevelScale("Defense")
	self.Entity:SetStatus(GUARD_STATUS, reduction)
	self.Entity:SetStatus(STATUS, self:GetColorString(), nil, true)

	-- Cooldowns survive re-toggling, so spamming the key cannot burn faster.
	if not self.Burned then
		self.Burned = setmetatable({}, { __mode = "k" })
	end
	self.Epoch = (self.Epoch or 0) + 1
	burn(self, self.Epoch)

	-- Through a Gum punch of the same character (Modules.BodyTouch, DF Gum.server 97-100,
	-- 118-121, 165-166): one hit of the contact damage, dodgeable like the punch, with
	-- none of the heat-proof exceptions of the contact code (the legacy script had none).
	BodyTouch.Set(self.Entity, "Smelt", {
		OnHit = function(target, punch)
			local damage = CONTACT_DAMAGE * self:GetAffinity("Defense") * self:GetLevelScale("Defense")
			if punch.Haki then
				punch.Ability:Damage(target, damage * HAKI_MULTIPLIER, "Haki", nil, true)
			else
				punch.Ability:Damage(target, damage, "Special", nil, true)
			end
		end,
	})
end

function SilverBody:OnInterrupt()
	self.Active = false
	BodyTouch.Set(self.Entity, "Smelt", nil)
	-- Invalidates the pending contact check.
	self.Epoch = (self.Epoch or 0) + 1
	self.Entity:ClearStatus(GUARD_STATUS)
	self.Entity:ClearStatus(STATUS)
end

return SilverBody
