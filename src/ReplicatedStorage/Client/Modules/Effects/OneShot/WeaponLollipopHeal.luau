--!strict
--[[
	Lollipop special: a pink disc at the user's feet growing from 5 to 20 studs while it
	fades, over 1 s (legacy: welded to the root, removed after 1.5 s).
	params: { Caster: Model }
]]
local RunService = game:GetService("RunService")

local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

local PINK = Color3.fromRGB(255, 105, 180)
local FLAT = CFrame.new(0, -2.5, 0) * CFrame.Angles(0, 0, math.rad(90))

return function(origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	local root = typeof(caster) == "Instance" and caster:FindFirstChild("HumanoidRootPart")

	local disc = WeaponFx.Part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 5, 5),
		Color = PINK,
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(origin) * FLAT,
	}, 1.1)
	WeaponFx.Tween(disc, 1, { Size = Vector3.new(0.2, 20, 20), Transparency = 1 }, Enum.EasingStyle.Cubic)

	if root and root:IsA("BasePart") then
		-- Follows the user without a weld (the disc is anchored and local).
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function()
			if disc.Parent == nil or root.Parent == nil then
				connection:Disconnect()
				return
			end
			disc.CFrame = CFrame.new(root.Position) * FLAT
		end)
	end
end
