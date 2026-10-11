--!strict
--[[
	Alice fruit - Wonderland Delirium: the burst of will.
	params: { Radius: number }   (plus Caster, Colors)
	Template: ReplicatedStorage.Assets.Models.Fruits.Alice.Power3.Will (a sphere part
	with an inner part "Inside").

	Same two beats as the legacy tweens: for 1.5 s the shell collapses to nothing while
	the inside swells to the full radius; then, for 1 s, the shell bursts back out and
	the inside shrinks, both fading.
]]
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Util.World)
local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local COLLAPSE_TIME = 1.5
local BURST_TIME = 1
local SMALL = Vector3.new(1, 1, 1)

local function prepare(part: BasePart, position: Vector3)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = position
end

return function(origin: Vector3, params: { [string]: any }?)
	local radius = params and params.Radius
	if type(radius) ~= "number" or radius <= 0 then
		return
	end

	local template = EffectAssets.FindFruit("Alice", "Power3", "Will")
	if not template or not template:IsA("BasePart") then
		return
	end

	local will = template:Clone()
	prepare(will, origin)
	local foundInside = will:FindFirstChild("Inside")
	local inside: BasePart? = if foundInside and foundInside:IsA("BasePart") then foundInside else nil
	if inside then
		prepare(inside, origin)
	end
	will.Parent = World.Effects()
	Debris:AddItem(will, COLLAPSE_TIME + BURST_TIME)

	local full = Vector3.new(radius * 2, radius * 2, radius * 2)
	local collapse = TweenInfo.new(COLLAPSE_TIME)
	local burst = TweenInfo.new(BURST_TIME)

	TweenService:Create(will, collapse, { Size = SMALL }):Play()
	if inside then
		TweenService:Create(inside, collapse, { Size = full }):Play()
	end

	task.delay(COLLAPSE_TIME, function()
		if will.Parent == nil then
			return
		end
		TweenService:Create(will, burst, { Size = full, Transparency = 1 }):Play()
		if inside then
			TweenService:Create(inside, burst, { Size = SMALL, Transparency = 1 }):Play()
		end
	end)
end
