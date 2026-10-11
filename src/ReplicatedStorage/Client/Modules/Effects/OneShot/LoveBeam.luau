--!strict
--[[
	Love fruit - Beam: one heart of the salvo. Cosmetic copy of a server-simulated
	projectile: it flies straight and stops at the first wall or at its range.

	params: { Direction: Vector3, Speed: number, Range: number, Size: number (width in
	          studs), Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Love.Power4.LoveHeartTrim (a MeshPart
	with a LoveHeartTrimFill child). Without it a plain neon disc is used.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(255, 105, 180)
-- The legacy heart was 20 x 20 x 2.719 and its inner fill 19 x 19 x 2.7, times the scale.
local DEPTH_RATIO = 2.719 / 20
local FILL_RATIO = Vector3.new(19 / 20, 19 / 20, 2.7 / 2.719)
local FILL_NAME = "LoveHeartTrimFill"
-- The mesh faces backwards along its own Z axis.
local FACING = CFrame.Angles(0, math.rad(180), 0)
local FADE_TIME = 0.3

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end

	local direction = params.Direction
	local speed = params.Speed
	local range = params.Range
	if typeof(direction) ~= "Vector3" or type(speed) ~= "number" or type(range) ~= "number" then
		return
	end
	if direction.Magnitude < 1e-3 or speed <= 0 or range <= 0 then
		return
	end
	local width: number = if type(params.Size) == "number" then math.max(params.Size, 0.2) else 4
	local size = Vector3.new(width, width, width * DEPTH_RATIO)
	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")

	local heart: BasePart
	local fill: BasePart? = nil
	local template = EffectAssets.FindFruit("Love", "Power4", "LoveHeartTrim")
	if template and template:IsA("BasePart") then
		heart = template:Clone()
		local child = heart:FindFirstChild(FILL_NAME)
		if child and child:IsA("BasePart") then
			fill = child
		end
	else
		local plain = Instance.new("Part")
		plain.Shape = Enum.PartType.Cylinder
		plain.Material = Enum.Material.Neon
		plain.Color = DEFAULT_COLOR
		plain.Transparency = 0.4
		heart = plain
	end

	local parts: { BasePart } = { heart }
	if fill then
		table.insert(parts, fill)
	end
	for _, part in parts do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		if primary then
			part.Color = primary
		end
	end
	heart.Size = size
	if fill then
		fill.Size = size * FILL_RATIO
	end

	local caster = params.Caster
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	if typeof(caster) == "Instance" then
		raycastParams.FilterDescendantsInstances = { caster }
	end
	local unit = direction.Unit
	local result = Workspace:Raycast(origin, unit * range, raycastParams)
	local distance = if result then (result.Position - origin).Magnitude else range
	local duration = distance / speed

	local up = if math.abs(unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local startCFrame = CFrame.lookAt(origin, origin + unit, up) * FACING
	local goalCFrame = startCFrame + unit * distance
	heart.CFrame = startCFrame
	if fill then
		fill.CFrame = startCFrame
	end
	heart.Parent = World.Effects()

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	for _, part in parts do
		TweenService:Create(part, tweenInfo, { CFrame = goalCFrame }):Play()
	end
	task.delay(duration, function()
		for _, part in parts do
			TweenService:Create(part, TweenInfo.new(FADE_TIME), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(heart, duration + FADE_TIME)
end
