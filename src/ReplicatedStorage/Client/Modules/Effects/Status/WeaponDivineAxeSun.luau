--!strict
--[[
	Divine Axe special: the sun burning at the axe hand while the status lasts (3 s).
	Status value: diameter of the burning area in studs (100, or 200 for a Flare user).

	Legacy blew the axe's own ParticleEmitter up to that size. The weapon model is not
	something this module can rely on, so the sun is a glowing ball on the right arm
	(a tenth of the area across) with a light reaching the whole area.
]]
local RunService = game:GetService("RunService")

local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

local SUN_COLOR = Color3.fromRGB(255, 190, 60)

local function noop() end

return function(character: Model, value: any, _isLocal: boolean): () -> ()
	local arm = character:FindFirstChild("Right Arm") or character:FindFirstChild("HumanoidRootPart")
	if not arm or not arm:IsA("BasePart") then
		return noop
	end
	local diameter = if type(value) == "number" then value else 100

	local sun = WeaponFx.Part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one,
		Material = Enum.Material.Neon,
		Color = SUN_COLOR,
		Transparency = 0.25,
		CFrame = arm.CFrame,
	})
	local light = Instance.new("PointLight")
	light.Color = SUN_COLOR
	light.Brightness = 4
	light.Range = math.min(60, diameter / 2)
	light.Parent = sun
	WeaponFx.Tween(sun, 0.4, { Size = Vector3.one * diameter / 10 })

	local connection = RunService.Heartbeat:Connect(function()
		sun.CFrame = CFrame.new(arm.Position + Vector3.new(0, diameter / 20 + 3, 0))
	end)

	return function()
		connection:Disconnect()
		sun:Destroy()
	end
end
