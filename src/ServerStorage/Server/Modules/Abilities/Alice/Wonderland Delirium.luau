--!strict
--[[
	Alice fruit - Wonderland Delirium: a burst of will around the caster.

	Cost:    100 haki, 10 s cooldown.
	Radius:  75 + haki level * 0.1 * defense affinity.
	Effect:  everyone inside is stunned for 1 s (crew mates too); 50 haki is stolen from
	         every player inside, once per body part of theirs inside the radius, while
	         they have any left. The legacy area query returned every limb and robbed
	         the victim once per limb (about 350 haki for a whole character); that is
	         the amount players knew, so it is kept.

	Instant, so there is nothing to undo. The expanding sphere is
	Effects.OneShot.AliceDelirium.

	Legacy problem fixed here: a victim without a data store `return`ed out of the whole
	loop.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local EFFECT = "AliceDelirium"

local HAKI_COST = 100
local BASE_RADIUS = 75
local RADIUS_PER_LEVEL = 0.1
local STUN = 1
local HAKI_STEAL = 50

local Delirium = Ability.extend()

-- Body parts of the character (direct children, as the legacy `part.Parent` test took
-- them) whose bounds reach into the sphere.
local function countPartsInside(model: Model, origin: Vector3, radius: number): number
	local count = 0
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and (child.Position - origin).Magnitude - child.Size.Magnitude / 2 <= radius then
			count += 1
		end
	end
	return math.max(count, 1)
end

Delirium.Debounce = 10

function Delirium:CanBegin(): boolean
	return Shared.GetHaki(self.Entity) >= HAKI_COST
end

function Delirium:OnBegin()
	local entity: CharacterEntity = self.Entity
	local services = self.Services
	Shared.AddHaki(services, entity, -HAKI_COST)

	local origin = entity.Root.Position
	local radius = BASE_RADIUS + self:GetLevel("Haki") * RADIUS_PER_LEVEL * self:GetAffinity("Defense")
	self:PlayEffect(EFFECT, origin, { Radius = radius })

	for _, target in Hitbox.Sphere(origin, radius, entity) do
		services.Status:ApplyStun(target, STUN)
		if target.Player then
			for _ = 1, countPartsInside(target.Model, origin, radius) do
				Shared.StealHaki(services, target, entity, HAKI_STEAL)
			end
		end
	end
end

return Delirium
