--!strict
--[[
	A jagged lightning bolt between two points, made of thin neon segments that vanish
	after a moment. This is the one drawing routine behind every Rumble and Plasma arc.

	It is a regular one-shot effect (origin = start of the bolt), and because effect
	modules return plain functions the other Rumble / Plasma effects also require it and
	call it directly:
		local drawBolt = require(<Effects>.OneShot.RumbleBolt)
		local last = drawBolt(from, { Target = to, Color = color, ... })
	which returns the frame of the last segment (its middle, looking at the end): where
	the legacy game put the ball that ends a Lightning Blitz.

	params:
		Target: Vector3        end of the bolt (required)
		Color: Color3?         defaults to the first color of Colors, then to Rumble blue
		Colors: string?        fruit color string
		Thickness: number?     studs, default 0.5
		Step: number?          length of a segment, default 5
		Jitter: number?        each segment end is moved by up to this many whole studs
		                       on each axis, default 1 (keep it below Step / 2)
		Life: number?          seconds before the bolt is removed, default 0.5
		Shrink: boolean?       thin out over Life instead of staying whole
		Fade: number?          transparency reached at the end of Life (default 0: opaque)
		Cylinder: boolean?     round segments (Plasma, Lightning Blitz) instead of the
		                       square ones of the sparks

	The legacy game built these on the server, part by part, and recycled them through a
	per-player folder in ReplicatedStorage.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

-- BrickColor "Toothpaste", the legacy default of every Rumble bolt.
local DEFAULT_COLOR = Color3.fromRGB(0, 255, 255)
local MAX_SEGMENTS = 260
local MIN_LENGTH = 0.01
local THIN = 0.01

return function(origin: Vector3, params: { [string]: any }?): CFrame?
	local target = params and params.Target
	if not params or typeof(target) ~= "Vector3" then
		return nil
	end

	local color: Color3 = DEFAULT_COLOR
	if typeof(params.Color) == "Color3" then
		color = params.Color
	elseif type(params.Colors) == "string" then
		color = FruitColor.Parse(params.Colors) or DEFAULT_COLOR
	end
	local thickness: number = if type(params.Thickness) == "number" then math.max(params.Thickness, 0.05) else 0.5
	local step: number = if type(params.Step) == "number" then math.max(params.Step, 0.5) else 5
	local jitter: number = if type(params.Jitter) == "number" then math.max(math.floor(params.Jitter), 0) else 1
	local life: number = if type(params.Life) == "number" then math.max(params.Life, 0.05) else 0.5
	local shrink = params.Shrink == true
	local fade: number = if type(params.Fade) == "number" then math.clamp(params.Fade, 0, 1) else 0
	local cylinder = params.Cylinder == true

	local points: { Vector3 } = { origin }
	local current = origin
	while (target - current).Magnitude > step and #points < MAX_SEGMENTS do
		local offset = Vector3.new(
			math.random(-jitter, jitter),
			math.random(-jitter, jitter),
			math.random(-jitter, jitter)
		)
		current += (target - current).Unit * step + offset
		table.insert(points, current)
	end
	table.insert(points, target)

	local folder = Instance.new("Folder")
	folder.Name = "LightningBolt"
	local last: CFrame? = nil

	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		local length = (to - from).Magnitude
		if length < MIN_LENGTH then
			continue
		end

		local segment = Instance.new("Part")
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = color

		local facing = CFrame.lookAt((from + to) / 2, to)
		last = facing
		local thin: Vector3
		if cylinder then
			-- A cylinder's axis is its X axis.
			segment.Shape = Enum.PartType.Cylinder
			segment.Size = Vector3.new(length, thickness, thickness)
			segment.CFrame = facing * CFrame.Angles(0, math.rad(90), 0)
			thin = Vector3.new(length, THIN, THIN)
		else
			segment.Size = Vector3.new(thickness, thickness, length)
			segment.CFrame = facing
			thin = Vector3.new(THIN, THIN, length)
		end
		segment.Parent = folder

		if shrink or fade > 0 then
			local goal: { [string]: any } = { Transparency = fade }
			if shrink then
				goal.Size = thin
			end
			TweenService:Create(segment, TweenInfo.new(life, Enum.EasingStyle.Linear), goal):Play()
		end
	end

	folder.Parent = World.Effects()
	Debris:AddItem(folder, life)
	return last
end
