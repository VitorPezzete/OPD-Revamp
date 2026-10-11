--!strict
--[[
	Dark fruit - Dark Star while charging: the star held under the charging hand.
	Status value: "<preview scale>|<fruit colors>|<Right or Left>" (the hand alternates
	from one charge to the next, as the legacy client did).
	Template: ReplicatedStorage.Assets.Models.Fruits.Dark.Power4.DarkStarBit (a part with
	an "Effect" emitter and an "OffPoint" child).

	Owner only, as the legacy LocalScript did:
	- the character keeps facing the mouse;
	- the sphere the star will grab from is shown around it: two copies of
	  Assets.Models.Fruits._Shared.Room (the legacy Resources.Room), their mesh scaled by
	  the preview scale, the second one turned inside out so it also shows from within;
	- the beam charge animation (wind-up clip, then the held clip). Those assets do not
	  all load in this copy of the game: a missing one is skipped.
	The release animation is played by the DarkStar one-shot effect.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAND_OFFSET = CFrame.new(0, -2.5, 0)
local RENDER_STEP_NAME = "DarkStarCharging"
local STUN_ATTRIBUTE = "Stunned"

local function noop() end

-- The two shells of the range sphere, parented to the star (and removed with it).
local function buildPreview(star: BasePart, scale: number): { BasePart }
	local shells: { BasePart } = {}
	local template = EffectAssets.FindFruit("_Shared", "Room")
	if scale <= 0 or not template or not template:IsA("BasePart") then
		return shells
	end

	for _, sign in { 1, -1 } do
		local shell = template:Clone()
		local mesh = shell:FindFirstChildOfClass("SpecialMesh")
		if not mesh then
			shell:Destroy()
			continue
		end
		mesh.Scale *= scale * sign
		shell.Anchored = true
		shell.CanCollide = false
		shell.CanQuery = false
		shell.CanTouch = false
		shell.CFrame = CFrame.new(star.Position)
		shell.Parent = star
		table.insert(shells, shell)
	end
	return shells
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local hand = if fields[3] == "Left" then "Left" else "Right"
	local arm = character:FindFirstChild(hand .. " Arm")
	local template = EffectAssets.FindFruit("Dark", "Power4", "DarkStarBit")
	if not arm or not arm:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return noop
	end

	local previewScale = tonumber(fields[1]) or 0
	local primary, secondary = FruitColor.Parse(fields[2] or "")

	local star = template:Clone()
	for _, descendant in star:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- Only the star itself is shown in the hand.
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") and primary and secondary then
			descendant.Color = FruitColor.ToSequence(primary, secondary)
		end
	end

	star.Anchored = false
	star.CanCollide = false
	star.CanQuery = false
	star.CanTouch = false
	star.Massless = true
	star.CFrame = arm.CFrame * HAND_OFFSET

	local weld = Instance.new("Weld")
	weld.Part0 = arm
	weld.Part1 = star
	weld.C0 = HAND_OFFSET
	weld.Parent = star

	star.Parent = arm

	local active = true
	local bound = false
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil

	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if isLocal and foundHumanoid and foundRoot and foundRoot:IsA("BasePart") then
		-- Typed copies: the closure below cannot rely on the narrowing above.
		local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot
		local shells = buildPreview(star, previewScale)
		local mouse = Players.LocalPlayer:GetMouse()

		bound = true
		RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value, function()
			local center = CFrame.new(star.Position)
			for _, shell in shells do
				shell.CFrame = center
			end

			if humanoid.Sit or character:GetAttribute(STUN_ATTRIBUTE) then
				return
			end
			local position = root.Position
			local target = mouse.Hit.Position
			local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
			if flat.Magnitude > 0.1 then
				root.CFrame = CFrame.lookAt(position, position + flat)
			end
		end)

		local anims = AnimationConfig.FruitAnims
		local animator = humanoid:FindFirstChildOfClass("Animator")
		local windUpId = if hand == "Left" then anims.BeamChargeLeft else anims.BeamChargeRight
		local heldId = if hand == "Left" then anims.BeamChargedLeft else anims.BeamChargedRight
		if animator and Animations.IsAvailable(windUpId) and Animations.IsAvailable(heldId) then
			local windUp = Animations.Get(animator, windUpId)
			local held = Animations.Get(animator, heldId)
			table.insert(tracks, windUp)
			table.insert(tracks, held)
			stoppedConnection = windUp.Stopped:Connect(function()
				if active then
					held:Play()
				end
			end)
			windUp:Play()
		end
	end

	return function()
		active = false
		if bound then
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		end
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end
		star:Destroy()
	end
end
