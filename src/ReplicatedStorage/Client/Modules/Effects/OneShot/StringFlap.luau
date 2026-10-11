--!strict
--[[
	String fruit - Flapping Thread: one spike. Cosmetic copy of a server-simulated
	projectile: it flies straight for its range, trailing a curved string back to the
	caster's torso.

	params: { Direction: Vector3, Speed: number, Range: number, Right: boolean (which
	          shoulder it left from), Haki: boolean, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.String.Power3.StringCone (a MeshPart
	with a Beam). Without it a thin neon spike is used.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
-- The cone mesh points along its Y axis.
local CONE_ROTATION = CFrame.Angles(math.rad(-90), 0, 0)
local STRING_CURVE = 10
local LINGER = 0.05

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

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local haki = params.Haki == true

	local spike: BasePart
	local template = EffectAssets.FindFruit("String", "Power3", "StringCone")
	if template and template:IsA("BasePart") then
		spike = template:Clone()
		for _, descendant in spike:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("BodyMover") then
				descendant:Destroy()
			end
		end
	else
		local plain = Instance.new("Part")
		plain.Material = Enum.Material.Neon
		plain.Size = Vector3.new(0.6, 4, 0.6)
		spike = plain
	end
	spike.Anchored = true
	spike.CanCollide = false
	spike.CanQuery = false
	spike.CanTouch = false
	spike.Color = if haki then HAKI_COLOR else (primary or DEFAULT_COLOR)

	local unit = direction.Unit
	local duration = range / speed
	local up = if math.abs(unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local startCFrame = CFrame.lookAt(origin, origin + unit, up) * CONE_ROTATION
	spike.CFrame = startCFrame

	-- The string back to the caster.
	local beam = spike:FindFirstChildOfClass("Beam")
	local caster = params.Caster
	local torso = if typeof(caster) == "Instance" then caster:FindFirstChild("Torso") else nil
	if beam and torso and torso:IsA("BasePart") then
		local anchor = Instance.new("Attachment")
		anchor.Name = "StringFlapAnchor"
		anchor.Parent = torso
		Debris:AddItem(anchor, duration + LINGER)

		beam.Attachment1 = anchor
		beam.CurveSize1 = if params.Right == true then -STRING_CURVE else STRING_CURVE
		if primary then
			beam.Color = ColorSequence.new(primary)
		end
	elseif beam then
		beam.Enabled = false
	end

	spike.Parent = World.Effects()
	TweenService:Create(spike, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = startCFrame + unit * range,
	}):Play()
	Debris:AddItem(spike, duration + LINGER)
end
