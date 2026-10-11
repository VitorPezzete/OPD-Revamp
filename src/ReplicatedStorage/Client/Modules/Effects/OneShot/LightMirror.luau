--!strict
--[[
	Light fruit - Yata Mirror: the reflected ray of light the user travelled along.
	origin: the mirror on the chest (first point of the path).
	params: { Points: { Vector3 } (the corners, at most 24), Thickness: number,
	          Colors: string, Caster: Model }

	One round neon segment (the legacy cylinder mesh) between each pair of corners, shown
	for 0.65 s as in the legacy game (fading out instead of vanishing). Yellow or the
	first fruit color. The legacy ray was not darkened by haki, and neither is this one.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 0)
local DURATION = 0.65
local MAX_SEGMENTS = 50
-- A cylinder lies along its X axis.
local ALONG_X = CFrame.Angles(0, math.rad(90), 0)

return function(_origin: Vector3, params: { [string]: any }?)
	local points = params and params.Points
	if not params or type(points) ~= "table" then
		return
	end

	local color = EffectAssets.Colors(params.Colors, DEFAULT_COLOR, DEFAULT_COLOR)
	local thickness = if type(params.Thickness) == "number" then math.clamp(params.Thickness, 0.2, 10) else 1
	local fade = TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	for index = 1, math.min(#points - 1, MAX_SEGMENTS) do
		local from, to = points[index], points[index + 1]
		if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
			continue
		end
		local length = (to - from).Magnitude
		if length < 0.05 then
			continue
		end

		local segment = Instance.new("Part")
		segment.Shape = Enum.PartType.Cylinder
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = color
		segment.Size = Vector3.new(length, thickness, thickness)
		segment.CFrame = CFrame.lookAt((from + to) / 2, to) * ALONG_X
		segment.Parent = World.Effects()

		TweenService:Create(segment, fade, { Transparency = 1 }):Play()
		Debris:AddItem(segment, DURATION)
	end
end
