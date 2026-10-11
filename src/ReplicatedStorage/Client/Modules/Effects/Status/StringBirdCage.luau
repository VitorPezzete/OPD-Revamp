--!strict
--[[
	String fruit - Bird Cage: the cage itself, drawn from the status of the String user
	who owns it for as long as it stands (it does not follow the user).

	Status value: "<x>|<y>|<z>|<radius>|<shrink start (server time, 0 = still)>|<shrink rate>|<haki 0/1>|<fruit colors>|<Right|Left>|<pole length>|<pole thickness>|<pole width>".

	18 meridians, 10 degrees apart, each a StringCageBeam (a part with Attachment1 /
	Attachment2 at the poles and Beam1 / Beam2 bulging to either side), as in the legacy
	cage. Template: ReplicatedStorage.Assets.Models.Fruits.String.Power5.Cage.StringCageBeam.
	Without it a translucent sphere is shown. While the cage shrinks the radius is
	recomputed from the server clock ten times a second.

	The axis: the pole woven during the charge (a copy of
	Assets.Models.Fruits.String.Power5.StringCageSpot, at the size it had reached), which
	shrinks to (2, 0.5, 2) along with the cage.

	Owner only: each time the status is written (the cage appears, it starts shrinking)
	the character turns to the aim point and snaps a wave of the given hand, at 32 times
	the clip's speed as in the legacy game.

	The legacy beam curve was 675 studs for a 512 stud radius; the same ratio is kept.
	The poles were placed at charge * affinity studs, which only matched the barrier at
	maximum level: they are placed on the sphere here.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local MERIDIANS = 18
local MERIDIAN_STEP = math.rad(10)
local CURVE_RATIO = 675 / 512
local MIN_RADIUS = 1
local UPDATE_INTERVAL = 0.1
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local FALLBACK_COLOR = Color3.fromRGB(255, 255, 255)
local POLE_END_SIZE = Vector3.new(2, 0.5, 2)
local WAVE_FADE = 0.1
local WAVE_SPEED = 32

local function wave(character: Model, left: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") and not humanoid.Sit then
		local aim: Vector3 = Knit.GetController("InputController"):GetAimPosition()
		local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
		if flat.Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end

	local animator = Animations.FindAnimator(character)
	if animator then
		local anims = AnimationConfig.FruitAnims
		Animations.Play(animator, if left then anims.WaveLeft else anims.WaveRight, WAVE_FADE, 1, WAVE_SPEED)
	end
end

type Meridian = { Beam1: Beam, Beam2: Beam, Pole1: Attachment, Pole2: Attachment }

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local x, y, z = tonumber(fields[1]), tonumber(fields[2]), tonumber(fields[3])
	local startRadius = tonumber(fields[4])
	local shrinkStart = tonumber(fields[5]) or 0
	local shrinkRate = tonumber(fields[6]) or 0
	if not x or not y or not z or not startRadius then
		return noop
	end
	local center = Vector3.new(x, y, z)

	local color: Color3? = FruitColor.Parse(fields[8] or "")
	if fields[7] == "1" then
		color = HAKI_COLOR
	end

	if isLocal then
		wave(character, fields[9] == "Left")
	end

	local created: { Instance } = {}
	local meridians: { Meridian } = {}
	local sphere: BasePart? = nil

	local pole: BasePart? = nil
	local poleSize = Vector3.new(tonumber(fields[10]) or 0, tonumber(fields[11]) or 0, tonumber(fields[12]) or 0)
	local poleTemplate = EffectAssets.FindFruit("String", "Power5", "StringCageSpot")
	if poleSize.X > 0 and poleTemplate and poleTemplate:IsA("BasePart") then
		local spot = poleTemplate:Clone()
		for _, descendant in spot:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		spot.Anchored = true
		-- The legacy pole (Power5.StringCageSpot) is anchored and solid.
		spot.CanCollide = true
		spot.CanQuery = false
		spot.CanTouch = false
		spot.Size = poleSize
		spot.CFrame = spot.CFrame.Rotation + center
		if color then
			spot.Color = color
		end
		spot.Parent = World.Effects()
		table.insert(created, spot)
		pole = spot
	end

	local template = EffectAssets.FindFruit("String", "Power5", "Cage", "StringCageBeam")
	if template and template:IsA("BasePart") then
		for index = 1, MERIDIANS do
			local part = template:Clone()
			local beam1 = part:FindFirstChild("Beam1")
			local beam2 = part:FindFirstChild("Beam2")
			local pole1 = part:FindFirstChild("Attachment1")
			local pole2 = part:FindFirstChild("Attachment2")
			if
				not (beam1 and beam1:IsA("Beam"))
				or not (beam2 and beam2:IsA("Beam"))
				or not (pole1 and pole1:IsA("Attachment"))
				or not (pole2 and pole2:IsA("Attachment"))
			then
				part:Destroy()
				break
			end

			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CFrame = CFrame.new(center) * CFrame.Angles(math.rad(90), 0, MERIDIAN_STEP * index)
			if color then
				beam1.Color = ColorSequence.new(color)
				beam2.Color = ColorSequence.new(color)
			end
			part.Parent = World.Effects()

			table.insert(created, part)
			table.insert(meridians, { Beam1 = beam1, Beam2 = beam2, Pole1 = pole1, Pole2 = pole2 })
		end
	end

	if #meridians == 0 then
		local ball = Instance.new("Part")
		ball.Name = "StringCage"
		ball.Shape = Enum.PartType.Ball
		ball.Material = Enum.Material.ForceField
		ball.Color = color or FALLBACK_COLOR
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.CastShadow = false
		ball.Position = center
		ball.Parent = World.Effects()
		table.insert(created, ball)
		sphere = ball
	end

	local function apply(radius: number)
		local curve = radius * CURVE_RATIO
		for _, meridian in meridians do
			meridian.Beam1.CurveSize0 = -curve
			meridian.Beam1.CurveSize1 = curve
			meridian.Beam2.CurveSize0 = curve
			meridian.Beam2.CurveSize1 = -curve
			meridian.Pole1.CFrame = CFrame.new(0, 0, radius)
			meridian.Pole2.CFrame = CFrame.new(0, 0, -radius)
		end
		if sphere then
			sphere.Size = Vector3.one * (radius * 2)
		end
		if pole and startRadius > MIN_RADIUS then
			local shrunk = math.clamp((startRadius - radius) / (startRadius - MIN_RADIUS), 0, 1)
			pole.Size = poleSize:Lerp(POLE_END_SIZE, shrunk)
		end
	end
	apply(startRadius)

	local connection: RBXScriptConnection? = nil
	if shrinkStart > 0 then
		local sinceUpdate = UPDATE_INTERVAL
		connection = RunService.Heartbeat:Connect(function(deltaTime: number)
			sinceUpdate += deltaTime
			if sinceUpdate < UPDATE_INTERVAL then
				return
			end
			sinceUpdate = 0
			apply(math.max(MIN_RADIUS, startRadius - shrinkRate * (Workspace:GetServerTimeNow() - shrinkStart)))
		end)
	end

	return function()
		if connection then
			connection:Disconnect()
		end
		for _, instance in created do
			instance:Destroy()
		end
	end
end
