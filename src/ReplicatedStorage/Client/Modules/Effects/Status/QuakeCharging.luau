--!strict
--[[
	Quake fruit - any of the four abilities while it is being charged.
	Status value: "<Punch | Tsunami | Stomp | Seismic>|<R or L>|<bubble scale>|<colors>".

	Everyone: a quake bubble growing on the limb for three seconds - on both hands for
	Tsunami, on the charging hand for Seismic Wave, on the stomping foot for Quake Stomp,
	none for the punch. The bubble's two meshes grow to `bubble scale`.
	The stomp's bubble is not in the dumped legacy scripts (their stomp branch still
	picks the color and the limb and then creates nothing, and the client still sends the
	foot's position): it was restored at the owner's request, built like the other two.
	It stays through the kick (0.25 s after the release), until the shock ball leaves.
	Template: ReplicatedStorage.Assets.Models.Fruits.Quake.Power4.QuakeHand (a part with a
	Mesh and an "Inner" part with its own Mesh), welded one stud below the arm's centre.
	Both parts take the first fruit color, or go dark while armament haki is on (the
	legacy script inside the bubble followed the haki state the same way).

	Owner only:
	- the character keeps facing the mouse while charging (the legacy "Looker" render
	  step), except when seated;
	- the looped hold clip of the legacy client: both arms for Tsunami, the charged
	  punch of the charging hand for Seismic Wave, the punch hold for Quake Punch, none
	  for the stomp. The release swing is Effects.OneShot.QuakeSwing.

	The "Quake Charge" loop sound (commented out in the legacy script) is not played.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local GROW_INFO = TweenInfo.new(3, Enum.EasingStyle.Linear)
local HAND_OFFSET = CFrame.new(0, -1, 0)
-- The stomp's bubble outlives its charge by the kick (0.2 s right leg, 0.25 s left).
local STOMP_LINGER = 0.25
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

local function addBubble(arm: BasePart, template: BasePart, scale: number): BasePart
	local bubble = template:Clone()
	for _, descendant in bubble:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end

	local target = Vector3.new(scale, scale, scale)
	local pieces: { Instance } = bubble:GetDescendants()
	table.insert(pieces, bubble)
	for _, part in pieces do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		elseif part:IsA("DataModelMesh") and scale > 0 then
			TweenService:Create(part, GROW_INFO, { Scale = target }):Play()
		end
	end

	local weld = Instance.new("Weld")
	weld.Part0 = arm
	weld.Part1 = bubble
	weld.C0 = HAND_OFFSET
	weld.Parent = bubble
	bubble.CFrame = arm.CFrame * HAND_OFFSET
	bubble.Parent = arm
	return bubble
end

-- Hold clips of the legacy client for each ability.
local function holdClips(kind: string?, left: boolean): { string }
	local anims = AnimationConfig.FruitAnims
	if kind == "Tsunami" then
		return { anims.QuakeRightArmHold, anims.QuakeLeftArmHold }
	elseif kind == "Seismic" then
		return { if left then anims.Punch1LeftCharged else anims.Punch1RightCharged }
	elseif kind == "Punch" then
		return { if left then anims.LeftPunchHold else anims.RightPunchHold }
	end
	return {}
end

-- Turns the local character toward the mouse every frame. Returns its cleanup.
local function faceMouse(character: Model): (() -> ())?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end

	local mouse = Players.LocalPlayer:GetMouse()
	local previousAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false

	local connection = RunService.RenderStepped:Connect(function()
		if humanoid.Sit then
			return
		end
		local position = root.Position
		local aim = mouse.Hit.Position
		local flat = Vector3.new(aim.X, position.Y, aim.Z)
		if (flat - position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(position, flat)
		end
	end)

	return function()
		connection:Disconnect()
		humanoid.AutoRotate = previousAutoRotate
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local kind = fields[1]
	local left = fields[2] == "L"
	local scale = tonumber(fields[3]) or 0
	local primary = FruitColor.Parse(fields[4] or "")

	local arms: { string } = {}
	if kind == "Tsunami" then
		arms = { "Right Arm", "Left Arm" }
	elseif kind == "Seismic" then
		arms = { if left then "Left Arm" else "Right Arm" }
	elseif kind == "Stomp" then
		-- Same offset on a leg: one stud below its centre is the foot.
		arms = { if left then "Left Leg" else "Right Leg" }
	end

	local created: { Instance } = {}
	-- Authored colors, to come back to when haki is turned off without a custom color.
	local authored: { [BasePart]: Color3 } = {}
	local template = EffectAssets.FindFruit("Quake", "Power4", "QuakeHand")
	if template and template:IsA("BasePart") then
		for _, armName in arms do
			local arm = character:FindFirstChild(armName)
			if arm and arm:IsA("BasePart") then
				local bubble = addBubble(arm, template, scale)
				table.insert(created, bubble)
				authored[bubble] = bubble.Color
				for _, descendant in bubble:GetDescendants() do
					if descendant:IsA("BasePart") then
						authored[descendant] = descendant.Color
					end
				end
			end
		end
	end

	local function paint()
		local haki = character:GetAttribute(HAKI_ATTRIBUTE)
		for part, color in authored do
			part.Color = if haki then HAKI_COLOR elseif primary then primary else color
		end
	end
	local hakiConnection: RBXScriptConnection? = nil
	if next(authored) ~= nil then
		paint()
		hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)
	end

	local stopFacing = if isLocal then faceMouse(character) else nil

	local tracks: { AnimationTrack } = {}
	local animator = if isLocal then Animations.FindAnimator(character) else nil
	if animator then
		for _, animationId in holdClips(kind, left) do
			local track = Animations.Get(animator, animationId)
			track.Looped = true
			track:Play()
			table.insert(tracks, track)
		end
	end

	return function()
		if stopFacing then
			stopFacing()
		end
		if hakiConnection then
			hakiConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end
		for _, instance in created do
			if kind == "Stomp" and character.Parent then
				Debris:AddItem(instance, STOMP_LINGER)
			else
				instance:Destroy()
			end
		end
	end
end
