--!strict
--[[
	Rumble fruit - Overload: the user discharges, electrocuting everyone around for 2.5 s.

	With a = defense affinity and s = defense level / cap:
	- area: a cube of 40 * s * a studs centered on (and turned with) the user, measured
	  when the key is pressed;
	- everyone inside takes 10 hits, one every 0.25 s starting immediately, of
	      clamp(500 * a * s * falloff, 10, 1000)      ("Special"; "Melee" on Gum users)
	  where falloff = 1 within 4 studs of the user, else
	      clamp(1 - (distance / (side / 2)) * 0.9, 0.1, 1)
	  using the distance at the moment of the discharge. Leaving the area afterwards does
	  not stop the hits (it did not in the legacy game).
	Cooldown 6 s: the legacy client waited 6 s between two presses (its server only asked
	for 5.5). FruitConfig marks this ability as chargeable, but the legacy one never
	charged: it fires on press and ignores the release.

	Each victim gets its own bounded chain of ten hits, as the legacy thread per victim:
	a second discharge on the same victim adds its own ten, a stun of the user does not
	stop them, the user's death does. Nothing is shown on the victims (nothing was).

	One victim per character NAME, as in the legacy game: its hit list was keyed by the
	model's name, so of several enemies with the same name (every NPC of a kind) only one
	is electrocuted by a discharge, and nobody named like the user is. The closest one is
	taken (legacy took whichever part the box query returned first).

	Legacy problems fixed here:
	- One thread per victim ran the ten hits; the lightning was built on the server by a
	  `while over` loop every 0.01 s, driven by GLOBAL variables shared by every user.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local EFFECT = "RumbleOverloadBurst"
local DAMAGE_TAG = "RumbleOverload"

local BASE_SIZE = 40
local BASE_DAMAGE = 500
local DAMAGE_MIN = 10
local DAMAGE_MAX = 1000
local FULL_DAMAGE_DISTANCE = 4
local FALLOFF = 0.9
local FALLOFF_MIN = 0.1
local HITS = 10
local HIT_INTERVAL = 0.25

local Overload = Ability.extend()

local function shock(self: any, target: any, damage: number, left: number)
	if target.Dead or self.Entity.Dead then
		return
	end
	self:Damage(target, damage, Shared.TraitFor(self.Services, target), DAMAGE_TAG, false)
	if left > 1 then
		task.delay(HIT_INTERVAL, shock, self, target, damage, left - 1)
	end
end

Overload.Debounce = 6

function Overload:OnBegin()
	local entity = self.Entity
	local affinity = self:GetAffinity("Defense")
	local scale = self:GetLevelScale("Defense")
	local side = BASE_SIZE * scale * affinity
	local center = entity.Root.Position

	self:PlayEffect(EFFECT, center, { Size = side, Thickness = 0.5 * scale })

	local targets = Hitbox.Box(entity.Root.CFrame, Vector3.new(side, side, side), entity)
	table.sort(targets, function(a, b)
		return (a.Root.Position - center).Magnitude < (b.Root.Position - center).Magnitude
	end)

	-- Every character in the box. The legacy hit list was keyed by model name, which
	-- let only one of several same-named NPCs be shocked; the owner had that fixed.
	for _, target in targets do
		local distance = (target.Root.Position - center).Magnitude
		local falloff = if distance <= FULL_DAMAGE_DISTANCE
			then 1
			else math.clamp(1 - (distance / (side / 2)) * FALLOFF, FALLOFF_MIN, 1)
		local damage = math.clamp(BASE_DAMAGE * affinity * scale * falloff, DAMAGE_MIN, DAMAGE_MAX)
		shock(self, target, damage, HITS)
	end
end

return Overload
