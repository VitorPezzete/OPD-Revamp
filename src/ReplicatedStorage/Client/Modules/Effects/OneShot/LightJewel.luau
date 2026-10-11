--!strict
--[[
	Light fruit - Sacred Jewels: one bolt of light.
	origin: the hand it leaves from.
	params: { Direction: Vector3, Speed: number, Range: number, Haki: boolean,
	          Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Light.Power5.LightP5Beam (a part
	with a SpecialMesh named Mesh).

	The bolt flies along the direction the server is casting, stops at the first wall
	(found with a local ray, like the server's) and bursts there: its mesh jumps to a
	scale of 22 for one second, as in the legacy game. First fruit color, dark with
	armament haki.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
-- Legacy orientation of the template along its flight.
local ROTATION = CFrame.Angles(0, math.rad(90), 0)
local BURST_SCALE = Vector3.new(22, 22, 22)
local BURST_TIME = 1

return function(origin: Vector3, params: { [string]: any }?)
	local direction = params and params.Direction
	if not params or typeof(direction) ~= "Vector3" or direction.Magnitude < 0.05 then
		return
	end
	local speed = if type(params.Speed) == "number" and params.Speed > 0 then params.Speed else 400
	local range = if type(params.Range) == "number" then params.Range else 1000

	local template = EffectAssets.FindFruit("Light", "Power5", "LightP5Beam")
	if not template or not template:IsA("BasePart") then
		return
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	if typeof(params.Caster) == "Instance" then
		rayParams.FilterDescendantsInstances = { params.Caster }
	end
	local unit = direction.Unit
	local result = Workspace:Raycast(origin, unit * range, rayParams)
	local distance = if result then (result.Position - origin).Magnitude else range
	local duration = distance / speed

	local bolt = template:Clone()
	for _, descendant in bolt:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanQuery = false
	bolt.CanTouch = false
	if params.Haki then
		bolt.Color = HAKI_COLOR
	else
		local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
		if primary then
			bolt.Color = primary
		end
	end

	local orientation = CFrame.lookAt(origin, origin + unit) * ROTATION
	bolt.CFrame = orientation
	bolt.Parent = World.Effects()

	TweenService:Create(bolt, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = orientation + unit * distance,
	}):Play()
	Debris:AddItem(bolt, duration + BURST_TIME)

	task.delay(duration, function()
		local mesh = bolt:FindFirstChild("Mesh")
		if bolt.Parent and mesh and mesh:IsA("SpecialMesh") then
			mesh.Scale = BURST_SCALE
		end
	end)
end
