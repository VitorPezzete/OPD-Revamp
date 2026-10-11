--!strict
--[[
	Flare fruit - Fire Wave, the expanding ring of fire.
	params: { Radius: number, ExpandTime: number, Lifetime: number, Haki: boolean,
	          Colors: string, Caster: Model }
	Templates: every part named "FlareFirewave" in
	ReplicatedStorage.Assets.Models.Fruits.Flare.Power4 (16 invisible wall segments with
	a fire emitter; the Y orientation of each one is the direction it travels).

	Each segment starts at `origin` and slides `Radius` studs outwards with a sine
	ease-out, then stays until `Lifetime`, exactly as the legacy server tweened them.
	Both fruit colors on the particles; dark with armament haki.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local SEGMENT_NAME = "FlareFirewave"
local HAKI_PARTICLES = ColorSequence.new(Color3.new(0.051, 0, 0.133), Color3.new(0.098, 0.067, 0.098))

return function(origin: Vector3, params: { [string]: any }?)
	local folder = EffectAssets.FindFruit("Flare", "Power4")
	if not folder then
		return
	end
	local radius: number = if params and type(params.Radius) == "number" then params.Radius else 50
	local expandTime: number = if params and type(params.ExpandTime) == "number" then params.ExpandTime else 0.5
	local lifetime: number = if params and type(params.Lifetime) == "number" then params.Lifetime else 1.5

	local primary, secondary = FruitColor.Parse(if params and type(params.Colors) == "string" then params.Colors else "")
	local particles: ColorSequence? = if params and params.Haki
		then HAKI_PARTICLES
		elseif primary and secondary then FruitColor.ToSequence(primary, secondary)
		else nil

	local tweenInfo = TweenInfo.new(expandTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	for _, template in folder:GetChildren() do
		if not template:IsA("BasePart") or template.Name ~= SEGMENT_NAME then
			continue
		end

		local segment = template:Clone()
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false

		if particles then
			for _, descendant in segment:GetDescendants() do
				if descendant:IsA("ParticleEmitter") then
					descendant.Color = particles
				end
			end
		end

		local angle = math.rad(template.Orientation.Y)
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		segment.CFrame = CFrame.new(origin) * CFrame.Angles(0, angle, 0)
		segment.Parent = World.Effects()

		TweenService:Create(segment, tweenInfo, { Position = origin + direction * radius }):Play()
		Debris:AddItem(segment, lifetime)
	end
end
