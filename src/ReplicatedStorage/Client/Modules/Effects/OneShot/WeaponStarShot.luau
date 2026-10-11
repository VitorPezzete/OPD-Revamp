--!strict
--[[
	Visual of a throwing star (weapon "Stars"): the star itself, spinning, flying along the
	line the server is casting. The star is the Handle of the tool
	(ReplicatedStorage.Assets.Models.Weapons.Sniper.Stars): what leaves the hand is what
	was in it. Purely cosmetic, so it never collides and removes itself.
	params: { Direction: Vector3, Speed: number, Range: number, Caster: Model? }
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

local TOOL_NAME = "Stars"
-- Turns per second around the axis the star lies flat on.
local SPIN = 6
-- The star flies flat, like a thrown disc.
local FLAT = CFrame.Angles(math.rad(90), 0, 0)

local function makeStar(): BasePart
	local tool = WeaponFx.FindAsset(TOOL_NAME)
	local handle = tool and tool:FindFirstChild("Handle")
	local star: BasePart
	if handle and handle:IsA("BasePart") then
		star = handle:Clone()
		for _, descendant in star:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("JointInstance") or descendant:IsA("Sound") then
				descendant:Destroy()
			end
		end
	else
		-- The asset is missing: a small dark disc rather than nothing.
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.1, 0.8, 0.8)
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(60, 60, 66)
		star = part
	end
	star.Name = "StarShot"
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CanTouch = false
	star.CastShadow = false
	return star
end

return function(origin: Vector3, params: { [string]: any }?)
	local direction: Vector3? = params and params.Direction
	local speed: number = (params and params.Speed) or 300
	local range: number = (params and params.Range) or 300
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-4 or speed <= 0 then
		return
	end
	local unit = direction.Unit

	-- Stops at the first thing in the way, as the server's cast does; the thrower is not in the way.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local caster = params and params.Caster
	rayParams.FilterDescendantsInstances = if typeof(caster) == "Instance" then { caster } else {}
	local result = Workspace:Raycast(origin, unit * range, rayParams)
	local distance = if result then (result.Position - origin).Magnitude else range
	local duration = distance / speed

	local star = makeStar()
	local facing = CFrame.lookAt(origin, origin + unit)
	star.CFrame = facing * FLAT
	star.Parent = World.Effects()

	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= duration or not star.Parent then
			connection:Disconnect()
			star:Destroy()
			return
		end
		star.CFrame = (facing + unit * (speed * elapsed)) * FLAT * CFrame.Angles(0, elapsed * SPIN * math.pi * 2, 0)
	end)
	Debris:AddItem(star, duration + 1)
end
