--!strict
--[[
	Shirayuki special, around the user (legacy shapes, sizes and timings):
	- at once: a white disc 150 studs wide closing in on the feet over 1.2 s;
	- after Delay (1.75 s), the blast, all fading over 1 s: a ground shockwave to 150
	  studs, a pillar of light, a force-field dome to 180 studs with a white core to 150
	  (0.4 s), and a flat spinning wave to 160 studs.
	The ice on the victims is Effects.Status.WeaponShirayukiFrozen.
	params: { Caster: Model, Delay: number, Radius: number }
]]
local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

local WHITE = Color3.fromRGB(255, 255, 255)
local PALE = Color3.fromRGB(200, 230, 255)
local FLAT = CFrame.Angles(0, 0, math.rad(90))
local USE_SOUND = "rbxassetid://3744391247"

return function(origin: Vector3, params: { [string]: any }?)
	local delay: number = (params and params.Delay) or 1.75
	local feet = origin - Vector3.new(0, 1, 0)

	local anchor = WeaponFx.Part({ Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(origin) }, delay + 2)
	WeaponFx.Sound(USE_SOUND, anchor, 0.9)

	local ring = WeaponFx.Part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 150, 150),
		Material = Enum.Material.Neon,
		Color = WHITE,
		CFrame = CFrame.new(feet) * FLAT,
	}, 1.2)
	WeaponFx.Tween(ring, 1.2, { Size = Vector3.new(10, 0.2, 0.2), Transparency = 0.8 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

	task.wait(delay)

	local shockwave = WeaponFx.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 5, 5), Material = Enum.Material.Neon, Color = WHITE, CFrame = CFrame.new(feet) * FLAT }, 1)
	WeaponFx.Tween(shockwave, 1, { Size = Vector3.new(0.2, 150, 150), Transparency = 1 }, Enum.EasingStyle.Cubic)

	local pillar = WeaponFx.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 0.5, 0.5), Material = Enum.Material.Neon, Color = WHITE, CFrame = CFrame.new(origin) * FLAT }, 1)
	WeaponFx.Tween(pillar, 1, { Size = Vector3.new(300, 40, 40), Transparency = 1 }, Enum.EasingStyle.Cubic)

	local dome = WeaponFx.Part({ Shape = Enum.PartType.Ball, Size = Vector3.one, Material = Enum.Material.ForceField, Color = PALE, CFrame = CFrame.new(origin) }, 1)
	WeaponFx.Tween(dome, 1, { Size = Vector3.new(180, 180, 180), Transparency = 1 }, Enum.EasingStyle.Cubic)

	local core = WeaponFx.Part({ Shape = Enum.PartType.Ball, Size = Vector3.one, Material = Enum.Material.Neon, Color = WHITE, CFrame = CFrame.new(origin) }, 0.4)
	WeaponFx.Tween(core, 0.4, { Size = Vector3.new(150, 150, 150), Transparency = 1 })

	local wave = WeaponFx.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 1, 1), Material = Enum.Material.Neon, Color = WHITE, CFrame = CFrame.new(feet) * FLAT }, 1)
	WeaponFx.Tween(wave, 1, { Size = Vector3.new(2, 160, 160), Transparency = 1 }, Enum.EasingStyle.Cubic)
end
