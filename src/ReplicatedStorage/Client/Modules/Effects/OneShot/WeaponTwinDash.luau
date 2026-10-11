--!strict
--[[
	Kanshou and Bakuya special: the cut left behind by the dash. After the dash delay a
	slash flies from 10 to 100 studs along the path while spinning, for 1 s (legacy
	KanshouBakuyaSlash tweened the same way); without the template, a white streak
	between the two ends of the dash.
	From the press until the dash, the trails of the two blades are lit, as the legacy
	script did (Trail / Trail2 of each held model, 0.25 s).
	params: { Destination: Vector3, Delay: number, Caster: Model }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

-- The Tool in the caster's hands; the two blade models are its children.
local TWIN_BLADES = "Kanshou and Bakuya"
local DEFAULT_DELAY = 0.25

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Destination) ~= "Vector3" then
		return
	end
	local destination: Vector3 = params.Destination
	local length = (destination - origin).Magnitude
	if length < 1 then
		return
	end

	local delay: number = if type(params.Delay) == "number" then params.Delay else DEFAULT_DELAY
	local caster = params.Caster
	local blades = if typeof(caster) == "Instance" then caster:FindFirstChild(TWIN_BLADES) else nil
	if blades then
		WeaponFx.LightTrails(blades, delay)
	end

	task.wait(delay)
	local path = CFrame.lookAt(origin, destination)

	local template = WeaponFx.FindAsset("KanshouBakuyaSlash")
	if template and template:IsA("BasePart") then
		local slash = template:Clone()
		WeaponFx.Neutralize(slash)
		slash.CFrame = path * CFrame.new(0, 0, -10) * CFrame.Angles(0, math.rad(90), 0)
		slash.Parent = World.Effects()
		WeaponFx.Tween(slash, 1, { CFrame = path * CFrame.new(0, 0, -100) * CFrame.Angles(0, math.rad(90) + math.pi * 4, 0) })
		Debris:AddItem(slash, 1)
	end

	local streak = WeaponFx.Part({
		Size = Vector3.new(0.4, 0.4, length),
		CFrame = path * CFrame.new(0, 0, -length / 2),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.2,
	}, 0.4)
	WeaponFx.Tween(streak, 0.35, { Size = Vector3.new(0.02, 0.02, length), Transparency = 1 })
end
