--!strict
--[[
	Light fruit - Light Blast while charging: a four-pointed star of light spinning in
	the hand that will fire.

	Status value: "<star length>|<fruit colors>|<Right|Left>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Light.Power2.ExplosionBall (a part
	with a SpecialMesh named Mesh), used twice at right angles. Each mesh grows in 3 s
	from nothing to (star length, 5, 5), welded 1 stud under the centre of the arm and
	spun around the arm at 3 rad/s, as in the legacy game. First fruit color; dark with
	armament haki.

	Owner only: the charge animation of that hand (the wind-up clip, then the held
	clip). It replicates through the Animator.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local GROW_TIME = 3
local SPIN_SPEED = -3
local HAND_OFFSET = CFrame.new(0, -1, 0)

local function noop() end

-- The charge clips of the owner; returns what stops them.
local function playCharge(character: Model, left: boolean): () -> ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return noop
	end

	local anims = AnimationConfig.FruitAnims
	local windUp = Animations.Get(animator, if left then anims.BeamChargeLeft else anims.BeamChargeRight)
	local held = Animations.Get(animator, if left then anims.BeamChargedLeft else anims.BeamChargedRight)
	local active = true
	local stopped = windUp.Stopped:Connect(function()
		if active then
			held:Play()
		end
	end)
	windUp:Play()

	return function()
		active = false
		stopped:Disconnect()
		windUp:Stop()
		held:Stop()
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local length = tonumber(fields[1]) or 0
	local left = fields[3] == "Left"
	local stopCharge = if isLocal then playCharge(character, left) else noop
	local arm = character:FindFirstChild(if left then "Left Arm" else "Right Arm")
	local template = EffectAssets.FindFruit("Light", "Power2", "ExplosionBall")
	if not arm or not arm:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return stopCharge
	end

	local primary = EffectAssets.Colors(fields[2], template.Color, template.Color)
	local color = if character:GetAttribute(HAKI_ATTRIBUTE) then HAKI_COLOR else primary

	local stars: { BasePart } = {}
	local welds: { Weld } = {}
	for _ = 1, 2 do
		local star = template:Clone()
		for _, descendant in star:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		star.Anchored = false
		star.CanCollide = false
		star.CanQuery = false
		star.CanTouch = false
		star.Massless = true
		star.Color = color

		local mesh = star:FindFirstChild("Mesh")
		if mesh and mesh:IsA("SpecialMesh") then
			mesh.Scale = Vector3.new(0.001, 0.001, 0.001)
			TweenService:Create(mesh, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Linear), {
				Scale = Vector3.new(length, 5, 5),
			}):Play()
		end

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = star
		weld.C0 = HAND_OFFSET
		weld.Parent = star

		star.Parent = arm
		table.insert(stars, star)
		table.insert(welds, weld)
	end

	local angle = 0
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		angle += SPIN_SPEED * deltaTime
		welds[1].C1 = CFrame.Angles(0, angle, 0)
		welds[2].C1 = CFrame.Angles(0, angle + math.rad(90), 0)
	end)

	return function()
		stopCharge()
		connection:Disconnect()
		for _, star in stars do
			star:Destroy()
		end
	end
end
