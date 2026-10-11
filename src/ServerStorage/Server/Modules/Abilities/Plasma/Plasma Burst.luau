--!strict
--[[
	Plasma fruit - Plasma Burst: an instant discharge around the user.

	Everyone inside a 60 x 60 x 60 box centered on (and turned with) the user takes
		1800 * defense affinity * (defense level / cap)   (Special, not dodgeable)
	doubled and "Haki" while armament haki is on. Cooldown 5 s.

	The legacy script also computed a distance to the center and a radius of 30 and then
	never used them: the damage does not fall off, and it does not here either.

	One hit per character NAME, as in the legacy game: its hit list was keyed by the
	model's name, so of several enemies with the same name (every NPC of a kind) only one
	is hurt by a burst, and nobody named like the caster is. The closest one is taken
	(legacy took whichever part the box query returned first).

	Legacy problems fixed here:
	- The three billboards and ~120 neon lightning parts were server instances.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local EFFECT = "PlasmaBurst"
local DAMAGE_TAG = "PlasmaBurst"

local BASE_DAMAGE = 1800
local HAKI_MULTIPLIER = 2
local BOX_SIZE = Vector3.new(60, 60, 60)

local PlasmaBurst = Ability.extend()

PlasmaBurst.Debounce = 5

function PlasmaBurst:OnBegin()
	local entity = self.Entity

	local damage = BASE_DAMAGE * self:GetAffinity("Defense") * self:GetLevelScale("Defense")
	local trait: CombatTypes.DamageTrait = "Special"
	local haki = self.Services.Haki:IsArmamentActive(entity)
	if haki then
		damage *= HAKI_MULTIPLIER
		trait = "Haki"
	end

	self:PlayEffect(EFFECT, entity.Root.Position, {
		Haki = haki,
		-- The legacy bolts were as thick as the sniper level allowed (0.25 to 1 stud).
		Thickness = math.clamp(self:GetLevelScale("Sniper"), 0.25, 1),
	})

	local center = entity.Root.Position
	local targets = Hitbox.Box(entity.Root.CFrame, BOX_SIZE, entity)
	table.sort(targets, function(a, b)
		return (a.Root.Position - center).Magnitude < (b.Root.Position - center).Magnitude
	end)

	-- Every character in the box. The legacy hit list was keyed by model name, which
	-- let only one of several same-named NPCs be hurt; the owner had that fixed.
	for _, target in targets do
		self:Damage(target, damage, trait, DAMAGE_TAG, false)
	end
end

return PlasmaBurst
