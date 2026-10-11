--!strict
--[[
	Client half of the aim assistance for gamepads and touch screens (the server half,
	leading moving targets, is Projectile.Lead).

	Without a cursor the player aims with the camera: the point is the centre of the
	screen (or where a tap landed). FindTarget picks the living character nearest to that
	point on screen, inside a circle around it, in range and in sight, so the aim lands on
	it instead of on whatever is behind.

		AimAssist.FindTarget(camera, viewportPoint, ownCharacter) -> BasePart?   its root
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

-- Radius of the circle around the aim point, as a share of the screen height.
local SCREEN_RADIUS = 0.18
-- Characters further than this (studs) are never taken.
local RANGE = 300
-- Studs of distance worth one pixel of distance from the aim point: near targets win ties.
local DISTANCE_WEIGHT = 0.6
-- Candidates checked for line of sight, best first.
local SIGHT_CHECKS = 3

local AimAssist = {}

type Candidate = { Part: BasePart, Score: number }

local function rootOf(model: Instance): BasePart?
	if not model:IsA("Model") then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function inSight(camera: Camera, part: BasePart, ownCharacter: Model?): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	if ownCharacter then
		table.insert(ignore, ownCharacter)
	end
	local target = part.Parent
	if target then
		table.insert(ignore, target)
	end
	-- What this client draws never hides a target: a thrown sword slash answers queries
	-- (Effects.OneShot.WeaponSlash) and would otherwise stand between the two.
	local effects = World.Effects()
	if effects ~= Workspace then
		table.insert(ignore, effects)
	end
	params.FilterDescendantsInstances = ignore
	local origin = camera.CFrame.Position
	return Workspace:Raycast(origin, part.Position - origin, params) == nil
end

function AimAssist.FindTarget(camera: Camera, viewportPoint: Vector2, ownCharacter: Model?): BasePart?
	local ownRoot = ownCharacter and ownCharacter.PrimaryPart
	local from = if ownRoot then ownRoot.Position else camera.CFrame.Position
	local radius = camera.ViewportSize.Y * SCREEN_RADIUS

	local candidates: { Candidate } = {}
	for _, kind in World.AliveKinds do
		local folder = World.Alive(kind)
		if not folder then
			continue
		end
		for _, model in folder:GetChildren() do
			if model == ownCharacter then
				continue
			end
			local root = rootOf(model)
			if not root then
				continue
			end
			local distance = (root.Position - from).Magnitude
			if distance > RANGE then
				continue
			end
			local point, onScreen = camera:WorldToViewportPoint(root.Position)
			if not onScreen or point.Z <= 0 then
				continue
			end
			local away = (Vector2.new(point.X, point.Y) - viewportPoint).Magnitude
			if away <= radius then
				table.insert(candidates, { Part = root, Score = away + distance * DISTANCE_WEIGHT })
			end
		end
	end

	table.sort(candidates, function(a: Candidate, b: Candidate): boolean
		return a.Score < b.Score
	end)
	for index = 1, math.min(#candidates, SIGHT_CHECKS) do
		local part = candidates[index].Part
		if inSight(camera, part, ownCharacter) then
			return part
		end
	end
	return nil
end

return AimAssist
