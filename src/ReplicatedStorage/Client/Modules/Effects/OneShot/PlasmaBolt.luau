--!strict
--[[
	Plasma fruit - one jagged bolt between two points: the legacy "Lightning" parts, neon
	cylinders chained every few studs, each joint thrown off by up to a stud or two.
	Every Plasma arc is drawn by this (Coil sparks and arcs, Burst, Cannon rays, the
	logia sparks): the other Plasma effects require the module and call it directly,
		local drawBolt = require(<Effects>.OneShot.PlasmaBolt)
		local last = drawBolt(from, { Target = to, Color = color, ... })
	which returns the frame of the last segment (its middle, looking at the end): where the
	legacy game put the flash / burst that ends an arc.

	params:
		Target: Vector3        end of the bolt (required)
		Color: Color3?         default light purple (221, 117, 255)
		Thickness: number?     studs, default 0.5
		Step: number?          length of a segment, default 5
		Jitter: number?        whole studs each joint may be off by on each axis, default 1
		Life: number?          seconds before the bolt is removed, default 0.7
		Shrink: number?        seconds of the tween that thins the bolt to 0.01 studs; it
		                       may be longer than Life (the Coil arcs are removed half-way).
		                       nil: the bolt stays whole (Cannon rays)
		Linear: boolean?       linear shrink (the legacy api2.tween calls) instead of the
		                       default Quad Out of a bare TweenInfo
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local DEFAULT_COLOR = Color3.fromRGB(221, 117, 255)
local MAX_SEGMENTS = 120
local MIN_LENGTH = 0.01
local THIN = 0.01
-- A cylinder's axis is its X axis.
local CYLINDER_TURN = CFrame.Angles(0, math.rad(90), 0)

return function(origin: Vector3, params: { [string]: any }?): CFrame?
	local target = params and params.Target
	if not params or typeof(target) ~= "Vector3" then
		return nil
	end

	local color: Color3 = if typeof(params.Color) == "Color3" then params.Color else DEFAULT_COLOR
	local thickness: number = if type(params.Thickness) == "number" then math.max(params.Thickness, 0.05) else 0.5
	local step: number = if type(params.Step) == "number" then math.max(params.Step, 0.5) else 5
	local jitter: number = if type(params.Jitter) == "number" then math.max(math.floor(params.Jitter), 0) else 1
	local life: number = if type(params.Life) == "number" then math.max(params.Life, 0.05) else 0.7
	local shrink: number? = if type(params.Shrink) == "number" and params.Shrink > 0 then params.Shrink else nil

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

	local tweenInfo: TweenInfo? = nil
	if shrink then
		tweenInfo = if params.Linear == true then TweenInfo.new(shrink, Enum.EasingStyle.Linear) else TweenInfo.new(shrink)
	end

	local folder = Instance.new("Folder")
	folder.Name = "PlasmaBolt"

	local last: CFrame? = nil
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		local length = (to - from).Magnitude
		if length < MIN_LENGTH then
			continue
		end

		local facing = CFrame.lookAt((from + to) / 2, to)
		last = facing

		local segment = Instance.new("Part")
		segment.Name = "Lightning"
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = color
		segment.Shape = Enum.PartType.Cylinder
		segment.Size = Vector3.new(length, thickness, thickness)
		segment.CFrame = facing * CYLINDER_TURN
		segment.Parent = folder

		if tweenInfo then
			TweenService:Create(segment, tweenInfo, { Size = Vector3.new(length, THIN, THIN) }):Play()
		end
	end

	folder.Parent = World.Effects()
	Debris:AddItem(folder, life)
	return last
end
