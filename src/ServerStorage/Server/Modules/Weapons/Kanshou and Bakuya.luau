--!strict
--[[
	Kanshou and Bakuya - special: a dash along the aim. A quarter of a second after the
	press the user reappears at the first obstacle in that direction, at most 200 studs
	away, facing the way it was facing. It deals no damage (the legacy slash that
	followed was only a visual). Cooldown 3 s.

	Characters do not block the dash (legacy excluded every player and every enemy from
	the ray). The destination is found by a ray cast on the server from the real position
	of the character: the client only gives a direction.

	Legacy pivoted the character exactly onto the hit point, inside the wall; it now
	stops a few studs short of it.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)

local MAX_DISTANCE = 200
local DELAY = 0.25
local WALL_MARGIN = 3
local EFFECT = "WeaponTwinDash"

local TwinBlades: WeaponTypes.WeaponBehaviour = {}

function TwinBlades.Special(context: WeaponTypes.WeaponContext): boolean?
	local entity = context.Entity
	local services = context.Services
	local origin = entity.Root.Position
	local direction = (context.Aim - origin).Unit

	local ignored: { Instance } = {}
	for model in services.Character:GetEntities() do
		table.insert(ignored, model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored

	local result = Workspace:Raycast(origin, direction * MAX_DISTANCE, params)
	local distance = if result then math.max(0, result.Distance - WALL_MARGIN) else MAX_DISTANCE
	local destination = origin + direction * distance

	services.Effect:Play(EFFECT, origin, { Destination = destination, Delay = DELAY, Caster = entity.Model })

	task.delay(DELAY, function()
		if not context:IsHolding() or entity:HasStatus("Stunned") then
			return
		end
		services.Character:Teleport(entity, CFrame.new(destination, destination + entity.Root.CFrame.LookVector))
	end)
	return true
end

return TwinBlades
