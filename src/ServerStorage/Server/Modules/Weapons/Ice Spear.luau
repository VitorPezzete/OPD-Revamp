--!strict
--[[
	Ice Spear - special: a rain of 23 ice spears on the aim point (brought back to 150
	studs from the user when further). A spear starts every 0.08 to 0.15 s, 45 studs
	above a random spot within 12 studs of the centre on each axis, lands 0.45 s later
	and hits everyone within 8 studs of where it lands for 7 + 0.55 * sword level (x2
	and Haki with armament haki, then the BuffWeapons perk). Hits cannot be dodged and
	every spear hits on its own. The rain stops if the user dies. Cooldown 8.5 s.

	The ground height is found by one ray cast on the server (from 50 studs above the
	centre, 100 studs down); the centre itself is clamped here, not trusted.

	The whole rain is laid out when the key is pressed and sent once: clients draw the
	spears (Effects.OneShot.WeaponIceSpear), the server only schedules the 23 landings.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)

type WeaponContext = WeaponTypes.WeaponContext

local MAX_DISTANCE = 150
local SPEARS = 23
local SPREAD = 12
local FALL_HEIGHT = 45
local FALL_SECONDS = 0.45
local HIT_RADIUS = 8
local BASE_DAMAGE = 7
local LEVEL_DAMAGE = 0.55
local EFFECT = "WeaponIceSpear"

local IceSpear: WeaponTypes.WeaponBehaviour = {}

function IceSpear.Special(context: WeaponContext): boolean?
	local entity = context.Entity
	local origin = entity.Root.Position
	local offset = context.Aim - origin
	local center = if offset.Magnitude > MAX_DISTANCE then origin + offset.Unit * MAX_DISTANCE else context.Aim

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	local ground = Workspace:Raycast(center + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), params)
	local groundY = if ground then ground.Position.Y else center.Y

	local damage = (BASE_DAMAGE + LEVEL_DAMAGE * context.Level) * context.HakiMultiplier * context.PerkMultiplier
	local trait = if context.Haki then "Haki" else "Sword"

	local landings: { Vector3 } = {}
	local starts: { number } = {}
	local elapsed = 0
	for index = 1, SPEARS do
		landings[index] = Vector3.new(center.X + math.random(-SPREAD, SPREAD), groundY, center.Z + math.random(-SPREAD, SPREAD))
		starts[index] = elapsed
		elapsed += math.random(8, 15) / 100
	end

	context.Services.Effect:Play(EFFECT, Vector3.new(center.X, groundY, center.Z), {
		Landings = landings,
		Starts = starts,
		Height = FALL_HEIGHT,
		Fall = FALL_SECONDS,
		Haki = context.Haki,
	})

	for index = 1, SPEARS do
		task.delay(starts[index] + FALL_SECONDS, function()
			if entity.Dead then
				return
			end
			for _, target in Hitbox.Sphere(landings[index], HIT_RADIUS, entity) do
				context.Services.Combat:Damage({
					Target = target,
					Attacker = entity,
					Amount = damage,
					Trait = trait,
					Style = "Weapon",
					Dodgeable = false,
				})
			end
		end)
	end
	return true
end

return IceSpear
