--!strict
--[[
	Bomb fruit - one explosion (Bomb Punch, Bomb Boost, each blast of Bomb Wave, Full Body).
	params: { Radius: number (the server's hit radius), Scale: number, PartSize: number,
	          Haki: boolean,
	          Blend: number (0 = first fruit color, 1 = second),
	          Template: "Power5" | "Power6", Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Bomb.<Template>.ExplosionBall (a part
	with a mesh).

	The ball bursts in 0.2 s (0.1 s for Full Body) and is removed after a second without
	fading, as in the legacy game.

	Size. Exactly the legacy ball: a part of PartSize studs (0.5 for Punch, Boost and Full
	Body, 0.1 * i for blast i of a Wave) whose MESH scale is tweened from 0.1 to Scale
	(the blast length the server computed). What is drawn therefore is not the hit
	sphere: with the template's sphere mesh a Punch ball is half as wide as its reach.
	A template without a mesh is sized PartSize * Scale, which is what a sphere mesh
	would have shown.

	Release. A blast carrying Release ("Punch" | "Wave"), Hand and Aim is the release of
	a charge: the caster's own client turns the character towards the aim point and plays
	the release clip (Punch1*Punch / Wave*, at the legacy speed of 32), which replicates
	through the Animator.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local START_SCALE = Vector3.new(0.1, 0.1, 0.1)
local LEGACY_PART_SIZE = 0.5
local LIFETIME = 1
local RELEASE_SPEED = 32

local function playRelease(character: Model, params: { [string]: any })
	local root = character:FindFirstChild("HumanoidRootPart")
	local aim = params.Aim
	if root and root:IsA("BasePart") and typeof(aim) == "Vector3" then
		local flat = Vector3.new(aim.X, root.Position.Y, aim.Z)
		if (flat - root.Position).Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, flat)
		end
	end

	local animator = Animations.FindAnimator(character)
	if not animator then
		return
	end
	local anims = AnimationConfig.FruitAnims
	local left = params.Hand == "Left"
	if params.Release == "Punch" then
		Animations.Play(animator, if left then anims.Punch1LeftPunch else anims.Punch1RightPunch, 0.01, 1, RELEASE_SPEED)
	elseif params.Release == "Wave" then
		Animations.Play(animator, if left then anims.WaveLeft else anims.WaveRight, 0.1, 1, RELEASE_SPEED)
	end
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local releasing = params.Caster
	if
		params.Release
		and typeof(releasing) == "Instance"
		and releasing:IsA("Model")
		and releasing == Players.LocalPlayer.Character
	then
		playRelease(releasing, params)
	end
	if type(params.Radius) ~= "number" or params.Radius <= 0 then
		return
	end
	local scale: number = if type(params.Scale) == "number" then params.Scale else params.Radius * 2
	local partSize: number = if type(params.PartSize) == "number" then params.PartSize else LEGACY_PART_SIZE
	local isFull = params.Template == "Power6"

	local template = EffectAssets.FindFruit("Bomb", if isFull then "Power6" else "Power5", "ExplosionBall")
	if not template or not template:IsA("BasePart") then
		return
	end

	local ball = template:Clone()
	for _, descendant in ball:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false

	if params.Haki then
		ball.Color = HAKI_COLOR
	else
		local primary, secondary = EffectAssets.Colors(params.Colors, template.Color, template.Color)
		local blend = if type(params.Blend) == "number" then math.clamp(params.Blend, 0, 1) else 0
		ball.Color = primary:Lerp(secondary, blend)
	end

	local caster = params.Caster
	local facing = CFrame.new(origin)
	if typeof(caster) == "Instance" and caster:IsA("Model") and caster.PrimaryPart then
		facing = caster.PrimaryPart.CFrame.Rotation + origin
	end

	local info = TweenInfo.new(if isFull then 0.1 else 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local full = Vector3.new(scale, scale, scale)
	local mesh = ball:FindFirstChildWhichIsA("DataModelMesh")

	if mesh then
		ball.Size = Vector3.new(partSize, partSize, partSize)
		mesh.Scale = START_SCALE
		TweenService:Create(mesh, info, { Scale = full }):Play()
	else
		ball.Size = START_SCALE * partSize
		TweenService:Create(ball, info, { Size = full * partSize }):Play()
	end

	ball.CFrame = facing
	ball.Parent = World.Effects()

	Debris:AddItem(ball, LIFETIME)
end
