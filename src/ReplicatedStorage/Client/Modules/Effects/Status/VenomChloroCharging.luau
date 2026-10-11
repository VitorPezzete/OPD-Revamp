--!strict
--[[
	Venom fruit - Chloro Ball while charging: the ball of poison growing in the hand.

	Status value: "<full size>|<fruit colors>|<Right|Left>" (the hands alternate).
	Template: ReplicatedStorage.Assets.Models.Fruits.Venom.Power4.ChrolloBallHand (a part
	with a SpecialMesh named Mesh), welded 1 stud under the centre of that arm. Its mesh
	grows from 0.1 to the full size in 5 s, linearly, as in the legacy game. First fruit
	color.

	Owner only: the legacy charging pose of that hand, the wind-up clip
	(FruitAnims.Punch1RightCharge / Punch1LeftCharge, four times as fast) then the held
	one (Punch1...Charged). Nothing waits on them: the pose ends when the status goes,
	and the throw clip is played by the VenomChloro one-shot.
	Facing the aim is Effects.Status.VenomAiming.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local GROW_TIME = 5
local HAND_OFFSET = CFrame.new(0, -1, 0)
local WIND_UP_FADE = 0.1
local WIND_UP_SPEED = 4

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local size = tonumber(fields[1]) or 1
	local left = fields[3] == "Left"

	local ball: BasePart? = nil
	local arm = character:FindFirstChild(if left then "Left Arm" else "Right Arm")
	local template = EffectAssets.FindFruit("Venom", "Power4", "ChrolloBallHand")
	if arm and arm:IsA("BasePart") and template and template:IsA("BasePart") then
		local part = template:Clone()
		for _, descendant in part:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.Color = EffectAssets.Colors(fields[2], part.Color, part.Color)

		local mesh = part:FindFirstChild("Mesh")
		if mesh and mesh:IsA("SpecialMesh") then
			mesh.Scale = Vector3.new(0.1, 0.1, 0.1)
			TweenService:Create(mesh, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Linear), {
				Scale = Vector3.new(size, size, size),
			}):Play()
		end

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = part
		weld.C0 = HAND_OFFSET
		weld.Parent = part

		part.Parent = arm
		ball = part
	end

	local active = true
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil

	local animator = if isLocal then Animations.FindAnimator(character) else nil
	if animator then
		local anims = AnimationConfig.FruitAnims
		local windUpId = if left then anims.Punch1LeftCharge else anims.Punch1RightCharge
		local held = Animations.Get(animator, if left then anims.Punch1LeftCharged else anims.Punch1RightCharged)
		table.insert(tracks, held)
		if Animations.IsAvailable(windUpId) then
			local windUp = Animations.Get(animator, windUpId)
			table.insert(tracks, windUp)
			stoppedConnection = windUp.Stopped:Connect(function()
				if active then
					held:Play()
				end
			end)
			windUp:Play(WIND_UP_FADE, 1, WIND_UP_SPEED)
		else
			-- A clip that did not download never ends: go straight to the held pose.
			held:Play()
		end
	end

	return function()
		active = false
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end
		if ball then
			ball:Destroy()
		end
	end
end
