--!strict
--[[
	Plasma fruit - Plasma Cannon while charging and firing: the plasma sphere held under
	the left hand. Status value: the fruit color string. The server keeps the status until
	the last ray of the volley has left.

	Template: ReplicatedStorage.Assets.Models.Fruits.Plasma.Power4.PlasmaArcSphere (same
	structure as the Plasma Coil sphere), welded 3 studs below the left arm. Dark with
	armament haki, first fruit color otherwise.

	Owner only: the character keeps facing the mouse while the status lasts, as the
	legacy script did, and plays the legacy clips: FruitAnims.ChargeLeft, then LoopLeft
	for as long as the key is held, and LongChargePunchLeft (speed 3) when the volley
	starts, which is when the server adds the "PlasmaCannonFiring" attribute. Purely
	visual: nothing waits for a clip.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_ATTRIBUTE = "Haki"
local FIRING_ATTRIBUTE = "PlasmaCannonFiring"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local RELEASE_FADE = 0.1
local RELEASE_SPEED = 3
local ARM_NAME = "Left Arm"
local HAND_OFFSET = CFrame.new(0, -3, 0)
local RENDER_STEP_NAME = "PlasmaCannonFacing"

-- Owner only: charge clips, then the release punch. Returns its cleanup.
local function animate(character: Model): (() -> ())?
	local found = Animations.FindAnimator(character)
	if not found then
		return nil
	end
	-- Typed copy: the closure below cannot rely on the narrowing above.
	local animator: Animator = found

	local anims = AnimationConfig.FruitAnims
	local windUp = Animations.Get(animator, anims.ChargeLeft)
	local held = Animations.Get(animator, anims.LoopLeft)
	local charging = true

	local stoppedConnection = windUp.Stopped:Connect(function()
		if charging then
			held:Play()
		end
	end)
	windUp:Play()

	local function release()
		if not charging or not character:GetAttribute(FIRING_ATTRIBUTE) then
			return
		end
		charging = false
		windUp:Stop()
		held:Stop()
		Animations.Play(animator, anims.LongChargePunchLeft, RELEASE_FADE, 1, RELEASE_SPEED)
	end
	local firingConnection = character:GetAttributeChangedSignal(FIRING_ATTRIBUTE):Connect(release)
	release()

	return function()
		charging = false
		stoppedConnection:Disconnect()
		firingConnection:Disconnect()
		windUp:Stop()
		held:Stop()
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local primary = FruitColor.Parse(if type(value) == "string" then value else "")
	local stopAnimating = if isLocal then animate(character) else nil

	local sphere: BasePart? = nil
	local hakiConnection: RBXScriptConnection? = nil

	local arm = character:FindFirstChild(ARM_NAME)
	local template = EffectAssets.FindFruit("Plasma", "Power4", "PlasmaArcSphere")
	if arm and arm:IsA("BasePart") and template and template:IsA("BasePart") then
		local clone = template:Clone()
		local shells: { [BasePart]: Color3 } = {}
		local emitters: { [ParticleEmitter]: ColorSequence } = {}
		clone.Anchored = false
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.Massless = true
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.Anchored = false
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.Massless = true
				shells[descendant] = descendant.Color
			elseif descendant:IsA("ParticleEmitter") then
				emitters[descendant] = descendant.Color
			end
		end

		local function paint()
			local color: Color3? = if character:GetAttribute(HAKI_ATTRIBUTE) then HAKI_COLOR else primary
			for shell, authored in shells do
				shell.Color = color or authored
			end
			for emitter, authored in emitters do
				emitter.Color = if color then ColorSequence.new(color) else authored
			end
		end

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = clone
		weld.C0 = HAND_OFFSET
		weld.Parent = clone

		paint()
		hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)
		clone.CFrame = arm.CFrame * HAND_OFFSET
		clone.Parent = arm
		sphere = clone
	end

	local facing = false
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if isLocal and foundHumanoid and foundRoot and foundRoot:IsA("BasePart") then
		-- Typed copies: the closure below cannot rely on the narrowing above.
		local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot
		local mouse = Players.LocalPlayer:GetMouse()
		facing = true
		RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value, function()
			if humanoid.Sit then
				return
			end
			local position = root.Position
			local target = mouse.Hit.Position
			local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
			if flat.Magnitude > 0.1 then
				root.CFrame = CFrame.lookAt(position, position + flat)
			end
		end)
	end

	return function()
		if stopAnimating then
			stopAnimating()
		end
		if facing then
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		end
		if hakiConnection then
			hakiConnection:Disconnect()
		end
		if sphere then
			sphere:Destroy()
		end
	end
end
