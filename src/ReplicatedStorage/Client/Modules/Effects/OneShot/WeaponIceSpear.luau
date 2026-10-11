--!strict
--[[
	Ice Spear special: the rain of spears. Each spear appears Height studs above its
	landing point at its start time, falls in Fall seconds (cubic, accelerating), sends
	an ice ring from 2 to 16 studs across the ground when it lands, stays planted 1.5 s
	and fades over 0.5 s.

	The landing points and start times come from the server, which hits at the same
	moments. params: { Landings: { Vector3 }, Starts: { number }, Height: number,
	                   Fall: number, Haki: boolean }
	Template: "IceSpear12" (legacy SwordModels); an ice bar without it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

local ICE = Color3.fromRGB(128, 187, 219)
local POINT_DOWN = CFrame.Angles(math.rad(-90), 0, 0)

local function drop(landing: Vector3, height: number, fall: number, color: Color3)
	local top = landing + Vector3.new(0, height, 0)
	local template = WeaponFx.FindAsset("IceSpear12")
	local spear: BasePart
	if template and template:IsA("BasePart") then
		spear = template:Clone() :: BasePart
		WeaponFx.Neutralize(spear)
		spear.Parent = World.Effects()
	else
		spear = WeaponFx.Part({ Size = Vector3.new(0.6, 9, 0.6) })
	end
	spear.Color = color
	spear.Material = Enum.Material.Ice

	-- lookAt straight down needs another up axis.
	local orientation = CFrame.lookAt(top, landing, Vector3.xAxis) * POINT_DOWN
	spear.CFrame = orientation
	WeaponFx.Tween(spear, fall, { CFrame = orientation.Rotation + landing }, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
	Debris:AddItem(spear, fall + 2.1)

	task.delay(fall, function()
		local ring = WeaponFx.Part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 2, 2),
			Color = color,
			Material = Enum.Material.Ice,
			CFrame = CFrame.new(landing) * CFrame.Angles(0, 0, math.rad(90)),
		}, 0.4)
		WeaponFx.Tween(ring, 0.3, { Size = Vector3.new(0.2, 16, 16), Transparency = 1 })
	end)
	task.delay(fall + 1.5, function()
		if spear.Parent then
			WeaponFx.Tween(spear, 0.5, { Transparency = 1 })
		end
	end)
end

return function(_origin: Vector3, params: { [string]: any }?)
	if not params or type(params.Landings) ~= "table" or type(params.Starts) ~= "table" then
		return
	end
	local color = if params.Haki then WeaponFx.HakiColor else ICE
	local height: number = params.Height or 45
	local fall: number = params.Fall or 0.45

	for index, landing in params.Landings do
		if typeof(landing) == "Vector3" then
			task.delay(tonumber(params.Starts[index]) or 0, drop, landing, height, fall, color)
		end
	end
end
