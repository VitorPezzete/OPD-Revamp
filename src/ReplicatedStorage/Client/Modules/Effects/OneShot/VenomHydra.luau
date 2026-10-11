--!strict
--[[
	Venom fruit - Venom Hydra: the hydra head that rises behind the user and bites.
	origin: the user's root position when the key was released.
	params: { Base: CFrame (the user's root CFrame then), Target: Vector3 (bite point),
	          Demon: boolean, Colors: string, Caster: Model }
	Templates, under ReplicatedStorage.Assets.Models.Fruits.Venom.Power3: Connect (a
	joint ball), Line (a neck segment: a part whose SpecialMesh "Mesh" is stretched
	along X) and HydraHead (a model: Head, its PrimaryPart, carries the eyes and, through
	the "HeadWeld" joint and the invisible "Joint" part, the jaw).

	The legacy choreography, with the legacy offsets and timings: five joints - one
	5 studs behind the user, three in an arc above and behind it, the last on the target.
	The neck grows from joint to joint, 0.2 s each (0.1 s with Venom Demon), while the
	head hops above each joint looking at the target. For the lunge the head drops over
	the target and its jaw swings on HeadWeld in 0.15 s, then the head snaps so that its
	jaw joint sits on the target: that is the bite, and the moment the server strikes
	(0.75 s after the release, 0.45 s with Venom Demon). The last neck segment is slower
	(0.35 s, 0.2 s with Venom Demon) and finishes growing after the bite; the joint on
	the target stays invisible. Everything is removed 3 s after the bite.
	Joints are 5 studs wide (6 with Venom Demon). Colors: first fruit color; with Venom
	Demon the second one, or a dull red. The eyes are painted too when there is a color.

	The thrower's own client also plays the release clip (replicated by the Animator).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEMON_COLOR = Color3.fromRGB(163, 75, 75)
-- Joints after the first, relative to it (legacy).
local ARC = { CFrame.new(0, 20, 40), CFrame.new(0, 35, 55), CFrame.new(0, 90, 35) }
local BEHIND = CFrame.new(0, 0, 5)
local HEAD_TILT = CFrame.Angles(math.rad(75), 0, 0)
local HEAD_HOP = Vector3.new(0, 7, -2)
local HEAD_STRIKE = Vector3.new(0, 7, 0)
local HEAD_TIME = 0.15
local LUNGE_WAIT = 0.15
local JAW_JOINT = "HeadWeld"
local JAW_PIVOT = "Joint"
local JAW_C0 = CFrame.new(0, -4.965, 4.235)
local JAW_TIME = 0.1
local LINE_ROTATION = CFrame.Angles(0, math.rad(90), 0)
local LINGER = 3
local RELEASE_FADE = 0.1
local RELEASE_SPEED = 10

return function(_origin: Vector3, params: { [string]: any }?)
	local base = params and params.Base
	local target = params and params.Target
	if not params or typeof(base) ~= "CFrame" or typeof(target) ~= "Vector3" then
		return
	end

	local localPlayer = Players.LocalPlayer
	local caster = params.Caster
	if typeof(caster) == "Instance" and localPlayer and caster == localPlayer.Character then
		local animator = Animations.FindAnimator(caster)
		if animator then
			Animations.Play(animator, AnimationConfig.FruitAnims.VenomHydra, RELEASE_FADE, 1, RELEASE_SPEED)
		end
	end

	local connectTemplate = EffectAssets.FindFruit("Venom", "Power3", "Connect")
	local lineTemplate = EffectAssets.FindFruit("Venom", "Power3", "Line")
	local headTemplate = EffectAssets.FindFruit("Venom", "Power3", "HydraHead")
	if not connectTemplate or not connectTemplate:IsA("BasePart") then
		return
	end

	local demon = params.Demon == true
	local size = if demon then 6 else 5
	local stepTime = if demon then 0.1 else 0.2
	local lungeTime = if demon then 0.2 else 0.35

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local color: Color3? = nil
	if demon then
		color = secondary or DEMON_COLOR
	elseif primary then
		color = primary
	end

	local created: { Instance } = {}
	local function setup(part: BasePart)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		if color then
			part.Color = color
		end
	end

	-- The five joints; the middle ones appear when the neck reaches them.
	local first = base * BEHIND
	local positions = { first.Position }
	for _, offset in ARC do
		table.insert(positions, (first * offset).Position)
	end
	table.insert(positions, target)

	local joints: { BasePart } = {}
	for index, position in positions do
		local joint = connectTemplate:Clone()
		setup(joint)
		joint.Size = Vector3.new(size, size, size)
		joint.CFrame = CFrame.new(position)
		joint.Transparency = if index == 1 then joint.Transparency else 1
		joint.Parent = World.Effects()
		table.insert(joints, joint)
		table.insert(created, joint)
	end
	local jointTransparency = joints[1].Transparency

	-- The head: only its PrimaryPart is anchored, the rest hangs on the model's welds, so
	-- moving that part moves the head and turning HeadWeld moves the jaw.
	local head: BasePart? = nil
	local jawJoint: JointInstance? = nil
	local jawPivot: BasePart? = nil
	if headTemplate and headTemplate:IsA("Model") then
		local model = headTemplate:Clone()
		local root = model.PrimaryPart
		if root then
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					setup(descendant)
					descendant.Anchored = descendant == root
					descendant.Massless = true
				elseif descendant:IsA("LuaSourceContainer") then
					descendant:Destroy()
				end
			end
			root.CFrame = first * HEAD_TILT
			model.Parent = World.Effects()
			head = root
			table.insert(created, model)

			local foundJoint = model:FindFirstChild(JAW_JOINT)
			local foundPivot = model:FindFirstChild(JAW_PIVOT)
			jawJoint = if foundJoint and foundJoint:IsA("JointInstance") then foundJoint else nil
			jawPivot = if foundPivot and foundPivot:IsA("BasePart") then foundPivot else nil
		else
			model:Destroy()
		end
	end

	local headTween: Tween? = nil
	local function moveHead(goal: CFrame)
		if head then
			local tween = TweenService:Create(head, TweenInfo.new(HEAD_TIME), { CFrame = goal })
			headTween = tween
			tween:Play()
		end
	end

	local last = #positions - 1
	for index = 1, last do
		local from, to = positions[index], positions[index + 1]
		local distance = (to - from).Magnitude
		local lunge = index == last

		if distance > 0.05 and lineTemplate and lineTemplate:IsA("BasePart") then
			local line = lineTemplate:Clone()
			setup(line)
			line.Size = Vector3.new(1, size, size)
			line.CFrame = CFrame.lookAt(from, to) * LINE_ROTATION
			line.Parent = World.Effects()
			table.insert(created, line)

			local info = TweenInfo.new(if lunge then lungeTime else stepTime)
			local mesh = line:FindFirstChild("Mesh")
			if mesh and mesh:IsA("SpecialMesh") then
				mesh.Scale = Vector3.new(1, 1, 1)
				TweenService:Create(mesh, info, { Scale = Vector3.new(distance, 1, 1) }):Play()
			else
				TweenService:Create(line, info, { Size = Vector3.new(distance, size, size) }):Play()
			end
			TweenService:Create(line, info, {
				CFrame = CFrame.lookAt((from + to) / 2, to) * LINE_ROTATION,
			}):Play()
		end

		if not lunge then
			local above = to + HEAD_HOP
			if (target - to).Magnitude > 0.001 and (target - above).Magnitude > 0.05 then
				moveHead(CFrame.lookAt(above, target))
			end
			task.wait(stepTime)
			joints[index + 1].Transparency = jointTransparency
		else
			if head then
				moveHead(CFrame.new(to + HEAD_STRIKE) * head.CFrame.Rotation)
			end
			if jawJoint then
				TweenService:Create(jawJoint, TweenInfo.new(JAW_TIME), { C0 = JAW_C0 }):Play()
			end
			task.wait(LUNGE_WAIT)

			-- The bite: the jaw joint lands on the target.
			if headTween then
				headTween:Cancel()
			end
			if head and jawPivot then
				head.CFrame += to - jawPivot.Position
			end
		end
	end

	task.wait(LINGER)
	for _, instance in created do
		instance:Destroy()
	end
end
