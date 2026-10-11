--!strict
--[[
	Diamond fruit - Diamond Cluster: the cluster erupting around the caster, standing
	for a while and shrinking away. Damage was already dealt by the server.

	params: { CFrame: CFrame, Size: Vector3, StandTime: number, ShrinkTime: number,
	          Haki: boolean, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Diamond.Power3.DiamondCluster (MeshPart).

	The cluster keeps the template's collision, so on each client it is the same
	obstacle it was in the legacy game (players simulate their own character). It never
	collides with its caster, who is standing inside it.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local GROW_TIME = 0.15
local START_SIZE = Vector3.new(0.1, 0.1, 0.1)
local END_SIZE = Vector3.new(0.1, 0.05, 0.1)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local RELEASE_SPEED = 10
local RELEASE_FADE = 0.1

local function playRelease(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	Animations.Play(animator, AnimationConfig.FruitAnims.VenomHydra, RELEASE_FADE, 1, RELEASE_SPEED)
end

return function(_origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end

	local caster = params.Caster
	if typeof(caster) == "Instance" and caster:IsA("Model") and caster == Players.LocalPlayer.Character then
		playRelease(caster)
	end

	local cframe = params.CFrame
	local size = params.Size
	if typeof(cframe) ~= "CFrame" or typeof(size) ~= "Vector3" then
		return
	end
	local standTime: number = if type(params.StandTime) == "number" then params.StandTime else 10
	local shrinkTime: number = if type(params.ShrinkTime) == "number" then params.ShrinkTime else 5

	local models = ReplicatedStorage.Assets:FindFirstChild("Models")
	local fruits = models and models:FindFirstChild("Fruits")
	local fruit = fruits and fruits:FindFirstChild("Diamond")
	local folder = fruit and fruit:FindFirstChild("Power3")
	local template = folder and folder:FindFirstChild("DiamondCluster")
	if not template or not template:IsA("BasePart") then
		return
	end

	local cluster = template:Clone()
	cluster.Anchored = true
	cluster.CanTouch = false
	cluster.Size = START_SIZE
	cluster.CFrame = cframe

	if params.Haki then
		cluster.Color = HAKI_COLOR
	else
		local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
		if primary then
			cluster.Color = primary
		end
	end

	if typeof(caster) == "Instance" then
		for _, descendant in caster:GetDescendants() do
			if descendant:IsA("BasePart") then
				local constraint = Instance.new("NoCollisionConstraint")
				constraint.Part0 = cluster
				constraint.Part1 = descendant
				constraint.Parent = cluster
			end
		end
	end

	cluster.Parent = World.Effects()
	TweenService:Create(cluster, TweenInfo.new(GROW_TIME), { Size = size }):Play()

	task.delay(standTime, function()
		if cluster.Parent then
			TweenService:Create(cluster, TweenInfo.new(shrinkTime), { Size = END_SIZE }):Play()
		end
	end)
	Debris:AddItem(cluster, standTime + shrinkTime)
end
