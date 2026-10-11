--!strict
--[[
	Debug view of a sword / melee hitbox, sent only to the attacker when their "Hitbox"
	setting is on. Legacy: a red, 80% transparent box for a quarter of a second.
	params: { CFrame: CFrame, Size: Vector3 }
]]
local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

return function(_origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.CFrame) ~= "CFrame" or typeof(params.Size) ~= "Vector3" then
		return
	end
	WeaponFx.Part({
		Name = "Hitbox",
		Size = params.Size,
		CFrame = params.CFrame,
		Color = Color3.fromRGB(255, 0, 0),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.8,
	}, 0.25)
end
