--!strict
--[[
	Light fruit - Yata Mirror while charging: the mirror held in front of the chest and,
	for the owner only, a faint preview of the path the ray would take right now.

	Status value: "<ray length at full charge>|<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Light.Power3.LightMirrorPart, welded
	to the torso with the legacy offset and painted with the first fruit color.

	Preview (legacy FakeBeam): the same reflection walk as the server, from the mirror
	towards the mouse, as long as the charge reached so far (25 per second, 4 to 100,
	estimated from the moment the status appeared). It is only a guide: the server
	recomputes the real path on release. Unlike the legacy one it reuses its parts
	instead of creating up to 50 new ones every frame, and shows at most
	MAX_PREVIEW_SEGMENTS bounces. The segments are round, like the legacy cylinder mesh.

	Owner only as well: the charge animation (FruitAnims.MirrorHands), replicated by the
	Animator.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 0)
local MIRROR_OFFSET = Vector3.new(0, 0.25, -0.5)
local MIRROR_WELD = CFrame.new(MIRROR_OFFSET) * CFrame.Angles(0, math.rad(90), 0)
local CHARGE_RATE = 25
local MIN_CHARGE = 4
local MAX_CHARGE = 100
local MAX_PREVIEW_SEGMENTS = 12
local PREVIEW_TRANSPARENCY = 0.8
-- A cylinder lies along its X axis.
local ALONG_X = CFrame.Angles(0, math.rad(90), 0)

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local fullRange = tonumber(fields[1]) or 0
	local color = EffectAssets.Colors(fields[2], DEFAULT_COLOR, DEFAULT_COLOR)

	local track: AnimationTrack? = nil
	local animator = if isLocal then Animations.FindAnimator(character) else nil
	if animator then
		local loaded = Animations.Get(animator, AnimationConfig.FruitAnims.MirrorHands)
		loaded:Play()
		track = loaded
	end

	local mirror: BasePart? = nil
	local torso = character:FindFirstChild("Torso")
	local template = EffectAssets.FindFruit("Light", "Power3", "LightMirrorPart")
	if torso and torso:IsA("BasePart") and template and template:IsA("BasePart") then
		local part = template:Clone()
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		if fields[2] and fields[2] ~= "None" then
			part.Color = color
		end
		part.CFrame = torso.CFrame * MIRROR_WELD

		local weld = Instance.new("Weld")
		weld.Part0 = torso
		weld.Part1 = part
		weld.C0 = MIRROR_WELD
		weld.Parent = part

		part.Parent = torso
		mirror = part
	end

	local connection: RBXScriptConnection? = nil
	local segments: { BasePart } = {}
	if isLocal and fullRange > 0 then
		local started = os.clock()
		local inputController = Knit.GetController("InputController")
		local thickness = 1 + fullRange / 1000
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }

		connection = RunService.RenderStepped:Connect(function()
			local root = character:FindFirstChild("HumanoidRootPart")
			local used = 0
			if root and root:IsA("BasePart") then
				local aim: Vector3 = inputController:GetAimPosition()

				local charge = math.clamp(math.floor((os.clock() - started) * CHARGE_RATE), MIN_CHARGE, MAX_CHARGE)
				local remaining = fullRange * charge / 100
				local position = root.CFrame:PointToWorldSpace(MIRROR_OFFSET)
				local offset = aim - position
				local direction = if offset.Magnitude < 0.05 then root.CFrame.LookVector else offset.Unit

				while remaining > 0.01 and used < MAX_PREVIEW_SEGMENTS do
					local result = Workspace:Raycast(position, direction * remaining, params)
					local finish = if result then result.Position else position + direction * remaining
					local length = math.max((finish - position).Magnitude, 0.01)

					used += 1
					local segment = segments[used]
					if not segment then
						segment = Instance.new("Part")
						segment.Shape = Enum.PartType.Cylinder
						segment.Anchored = true
						segment.CanCollide = false
						segment.CanQuery = false
						segment.CanTouch = false
						segment.CastShadow = false
						segment.Material = Enum.Material.Neon
						segment.Transparency = PREVIEW_TRANSPARENCY
						segment.Color = color
						segment.Parent = World.Effects()
						segments[used] = segment
					end
					segment.Size = Vector3.new(length, thickness, thickness)
					segment.CFrame = CFrame.lookAt(position + direction * (length / 2), position + direction * length)
						* ALONG_X
					segment.Transparency = PREVIEW_TRANSPARENCY

					remaining -= length
					position = finish
					if not result then
						break
					end
					-- The real ray stops on the first character it meets.
					local model = result.Instance:FindFirstAncestorOfClass("Model")
					if model and model:FindFirstChildOfClass("Humanoid") then
						break
					end
					direction = (direction - 2 * direction:Dot(result.Normal) * result.Normal).Unit
				end
			end

			-- Segments not needed this frame are hidden, not destroyed.
			for index = used + 1, #segments do
				segments[index].Transparency = 1
			end
		end)
	end

	return function()
		if track then
			track:Stop()
		end
		if connection then
			connection:Disconnect()
		end
		for _, segment in segments do
			segment:Destroy()
		end
		if mirror then
			mirror:Destroy()
		end
	end
end
