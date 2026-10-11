--!strict
--[[
	Gravity fruit - Gravity Repel, while the owner holds the key: gravity particles swirl
	around the character the release would fling away. Owner only, as in the legacy game
	(the marker lived in the LocalScript).

	Status value: "<range in studs>|<fruit color string>".
	Template: ReplicatedStorage.Assets.Models.Fruits._Shared.GravitySelectionPart (an
	invisible part whose Attachment, 5 studs off centre, holds a ParticleEmitter). It is
	put on the target with a new random rotation every frame, so the particles come from
	all around it; the emitter takes the first fruit color.

	The target is chosen exactly like the server will (Abilities/Gravity/Gravity Repel):
	the character in range closest in angle to the aim line, inside the legacy cone, the
	camera being taken CAMERA_DISTANCE studs behind the user on that line.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local AIM_FOV = 1000
local AIM_FOV_PADDING = 10
local AIM_MAX_ANGLE = 20
local AIM_MIN_DEPTH = 0.5
local CAMERA_DISTANCE = 12

local random = Random.new()

local function noop() end

local function findTarget(character: Model, rootPosition: Vector3, aim: Vector3, range: number): BasePart?
	local toAim = aim - rootPosition
	if toAim.Magnitude < 1e-3 then
		return nil
	end
	local direction = toAim.Unit
	local eye = rootPosition - direction * CAMERA_DISTANCE
	local aimDepth = toAim.Magnitude + CAMERA_DISTANCE

	local best: BasePart? = nil
	local bestAngle = AIM_MAX_ANGLE
	for _, kind in World.AliveKinds do
		local folder = World.Alive(kind)
		if not folder then
			continue
		end
		for _, model in folder:GetChildren() do
			if model == character or model:GetAttribute("Spawned") == false then
				continue
			end
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
				continue
			end
			local position = root.Position
			if (position - rootPosition).Magnitude > range then
				continue
			end

			local offset = position - eye
			local cosine = math.clamp(direction:Dot(offset) / offset.Magnitude, -1, 1)
			local angle = math.deg(math.acos(cosine))
			local depth = math.clamp(offset.Magnitude * cosine, AIM_MIN_DEPTH, aimDepth)
			if angle <= AIM_FOV / (depth + AIM_FOV_PADDING) and angle < bestAngle then
				best, bestAngle = root, angle
			end
		end
	end
	return best
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local fields = EffectAssets.Unpack(value)
	local range = tonumber(fields[1])
	local template = EffectAssets.FindFruit("_Shared", "GravitySelectionPart")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not range or not template or not template:IsA("BasePart") then
		return noop
	end
	if not foundRoot or not foundRoot:IsA("BasePart") then
		return noop
	end
	local root: BasePart = foundRoot
	local reach: number = range

	local marker = template:Clone()
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	local primary = FruitColor.Parse(fields[2] or "")
	for _, descendant in marker:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") then
			if primary then
				descendant.Color = ColorSequence.new(primary)
			end
			descendant.Enabled = true
		end
	end

	local inputController = Knit.GetController("InputController")
	local connection = RunService.RenderStepped:Connect(function()
		local target = findTarget(character, root.Position, inputController:GetAimPosition(), reach)
		if not target then
			marker.Parent = nil
			return
		end
		marker.CFrame = CFrame.new(target.Position)
			* CFrame.Angles(
				random:NextNumber(0, math.pi * 2),
				random:NextNumber(0, math.pi * 2),
				random:NextNumber(0, math.pi * 2)
			)
		marker.Parent = World.Effects()
	end)

	return function()
		connection:Disconnect()
		marker:Destroy()
	end
end
