--!strict
--[[
	Bisento special: the quake bubble flying from the blade, a 2.5-stud force-field ball
	(white, dark with armament haki) with eight cracks fading around its starting point.
	It stops at the first wall on this client; the burst is WeaponBisentoBurst.
	params: { Direction: Vector3, Speed: number, Distance: number, Haki: boolean }
]]
local Workspace = game:GetService("Workspace")

local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

local CRACKS = 8

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Direction) ~= "Vector3" then
		return
	end
	local direction: Vector3 = params.Direction.Unit
	local speed: number = params.Speed or 125
	local distance: number = params.Distance or 100
	local color = if params.Haki then WeaponFx.HakiColor else Color3.fromRGB(255, 255, 255)

	local result = Workspace:Raycast(origin, direction * distance)
	if result then
		distance = result.Distance
	end
	local facing = CFrame.lookAt(origin, origin + direction)

	for index = 1, CRACKS do
		local crack = WeaponFx.Part({
			Size = Vector3.new(0.05, 1.5, 0.05),
			CFrame = facing * CFrame.Angles(0, 0, math.rad(360 / CRACKS * index)) * CFrame.new(0, 1.5, 0),
			Color = color,
			Material = Enum.Material.Neon,
		}, 0.4)
		WeaponFx.Tween(crack, 0.4, { Transparency = 1 })
	end

	local duration = distance / speed
	local bubble = WeaponFx.Part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.5, 2.5, 2.5),
		Transparency = 0.2,
		Color = color,
		Material = Enum.Material.ForceField,
		CFrame = facing,
	}, duration + 0.05)
	WeaponFx.Tween(bubble, duration, { CFrame = facing + direction * distance }, Enum.EasingStyle.Linear)
end
