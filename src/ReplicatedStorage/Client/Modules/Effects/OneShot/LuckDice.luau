--!strict
--[[
	Luck fruit - Dice Roll: the thrown die and its blast.
	params: { Path: { Vector3 }, PathStep: number, Landing: Vector3, Target: Model?,
	          Face: number (1-6), Fuse: number, Size: number (blast diameter) }
	          (plus Caster, Colors)
	Template: ReplicatedStorage.Assets.Models.Fruits.Luck.Power3.Dice (MeshPart).

	The die follows the path the server worked out for it (one point every PathStep
	seconds: the throw, the fall, the bounces and the slide of the legacy physical die),
	held with the rolled face up as the legacy AlignOrientation held it. At the end of
	the path it stays there, or on Target's root if given (it stuck to that character),
	until the fuse runs out; then a neon ball swells to the blast size and fades. The
	server decides the blast on its own; this only has to end up in the same place at
	the same time.

	The caster additionally plays the throw animation and, when the die goes off, sees
	the face rolled in PlayerGui.DevilFruitIcons.Luck.IconExtra for a second.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

-- Rotation that puts each face up (legacy DiceSides table).
local FACE_ROTATIONS: { CFrame } = {
	CFrame.fromOrientation(math.rad(90), 0, 0),
	CFrame.fromOrientation(math.rad(180), 0, 0),
	CFrame.fromOrientation(0, 0, math.rad(90)),
	CFrame.fromOrientation(0, 0, math.rad(-90)),
	CFrame.fromOrientation(0, 0, 0),
	CFrame.fromOrientation(math.rad(-90), 0, 0),
}
local FACE_ICONS = {
	"rbxassetid://136531270453589",
	"rbxassetid://113124289578608",
	"rbxassetid://120232395010828",
	"rbxassetid://91954641190802",
	"rbxassetid://72824750457922",
	"rbxassetid://105881039709094",
}

local DEFAULT_PATH_STEP = 0.1
local BLAST_TIME = 1
local ICON_TIME = 1
local THROW_ANIMATION_SPEED = 2.5

local function showToCaster(caster: Instance, face: number, fuse: number)
	local humanoid = caster:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		Animations.Play(animator, AnimationConfig.FruitAnims.SunPos2, 0.1, 1, THROW_ANIMATION_SPEED)
	end

	-- The face is only revealed when the die goes off.
	task.wait(fuse)

	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local icons = playerGui and playerGui:FindFirstChild("DevilFruitIcons")
	local frame = icons and icons:FindFirstChild("Luck")
	local icon = frame and frame:FindFirstChild("IconExtra")
	if frame and frame:IsA("GuiObject") and icon and icon:IsA("ImageLabel") then
		local image: ImageLabel = icon
		frame.Visible = true
		image.Image = FACE_ICONS[face]
		image.Visible = true
		task.delay(ICON_TIME, function()
			image.Visible = false
		end)
	end
end

local function blast(position: Vector3, size: number, color: Color3)
	local ball = Instance.new("Part")
	ball.Name = "LuckDiceBlast"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Size = Vector3.new(0.1, 0.1, 0.1)
	ball.Position = position
	ball.Parent = World.Effects()
	Debris:AddItem(ball, BLAST_TIME)

	TweenService:Create(ball, TweenInfo.new(BLAST_TIME, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
		Size = Vector3.new(size, size, size),
		Transparency = 1,
	}):Play()
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end

	local landing = params.Landing
	local face = params.Face
	local fuse = params.Fuse
	local size = params.Size
	if typeof(landing) ~= "Vector3" or type(face) ~= "number" or type(fuse) ~= "number" or type(size) ~= "number" then
		return
	end
	face = math.clamp(math.floor(face), 1, 6)

	local caster = params.Caster
	if typeof(caster) == "Instance" and caster == Players.LocalPlayer.Character then
		task.spawn(showToCaster, caster, face, fuse)
	end

	local path: { Vector3 } = {}
	if type(params.Path) == "table" then
		for _, point in params.Path do
			if typeof(point) == "Vector3" then
				table.insert(path, point)
			end
		end
	end
	if #path < 2 then
		path = { origin, landing }
	end
	local pathStep: number = if type(params.PathStep) == "number" and params.PathStep > 0
		then params.PathStep
		else DEFAULT_PATH_STEP

	local target = if typeof(params.Target) == "Instance" then params.Target else nil
	local function goal(): Vector3
		local root = target and target:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root.Position else path[#path]
	end

	local fallbackColor = Color3.fromRGB(face * 40, face * 40, 0)
	local color = EffectAssets.Colors(params.Colors, fallbackColor, fallbackColor)

	local template = EffectAssets.FindFruit("Luck", "Power3", "Dice")
	if not template or not template:IsA("BasePart") then
		-- No die to show: the blast still tells everyone where it went off.
		task.delay(fuse, function()
			blast(goal(), size, color)
		end)
		return
	end

	local die = template:Clone()
	-- The template's AlignOrientation and friends are for the legacy physical die.
	for _, descendant in die:GetDescendants() do
		if descendant:IsA("Constraint") or descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	die.Anchored = true
	die.CanCollide = false
	die.CanQuery = false
	die.CanTouch = false
	die.CFrame = CFrame.new(origin) * FACE_ROTATIONS[face]
	die.Parent = World.Effects()

	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= fuse then
			connection:Disconnect()
			local position = goal()
			die:Destroy()
			blast(position, size, color)
			return
		end

		local progress = elapsed / pathStep
		local index = math.floor(progress) + 1
		local position = if index < #path
			then path[index]:Lerp(path[index + 1], progress - (index - 1))
			else goal()
		die.CFrame = CFrame.new(position) * FACE_ROTATIONS[face]
	end)
end
