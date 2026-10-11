--!strict
--[[
	Yamato: one gate. A black neon disc opening to 7.5 studs in 0.4 s at `origin`, held
	while the travellers go through, then closing over 0.5 s. The server plays it once
	for the entrance and once for the exit. Legacy teleport sound on open and on close.
	params: { Seconds: number }  -- travel time; the gate closes half a second after it
]]
local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

local SOUND = "rbxassetid://8772726906"

return function(origin: Vector3, params: { [string]: any }?)
	local seconds: number = (params and params.Seconds) or 2
	local open = seconds + 0.5

	local gate = WeaponFx.Part({
		Name = "Gate",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.zero,
		Color = Color3.fromRGB(0, 0, 0),
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90)),
	}, open + 1)

	WeaponFx.Sound(SOUND, gate, 3.45)
	WeaponFx.Tween(gate, 0.4, { Size = Vector3.new(0.23, 7.5, 7.5) }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)

	task.wait(open)
	if gate.Parent then
		WeaponFx.Sound(SOUND, gate, 1)
		WeaponFx.Tween(gate, 0.5, { Size = Vector3.zero }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
	end
end
