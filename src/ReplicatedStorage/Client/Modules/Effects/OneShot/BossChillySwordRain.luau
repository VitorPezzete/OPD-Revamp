--!strict
--[[
	Chilly boss - Sword Rain: one ice blade falling from the sky. The server sends one
	message per blade (each aims at where the target stands at that moment) and hurts
	whoever is within Radius of the landing point when the fall ends.

	origin: where the blade appears (45 studs above its landing point).
	params: { Landing: Vector3, FallTime: number, Radius: number, Haki: boolean, Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Chilly.Power1.ChillySword.

	As in the legacy script: the blade points down, falls with a cubic "in" easing and
	leaves a short trail; where it lands a flat ring spreads to twice Radius in 0.3 s;
	the blade stays planted 1.5 s, then fades in 0.5 s.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(128, 187, 219)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local TRAIL_LIFETIME = 0.2
local TRAIL_TRANSPARENCY = NumberSequence.new(0.3, 1)
local RING_START = Vector3.new(0.2, 2, 2)
local RING_THICKNESS = 0.2
local RING_TIME = 0.3
local RING_LIFETIME = 0.4
local STAY_TIME = 1.5
local FADE_TIME = 0.5

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Landing) ~= "Vector3" then
		return
	end
	local landing: Vector3 = params.Landing
	local fallTime: number = if type(params.FallTime) == "number" then math.max(params.FallTime, 0.03) else 0.45
	local radius: number = if type(params.Radius) == "number" then params.Radius else 8

	local template = EffectAssets.FindFruit("Chilly", "Power1", "ChillySword")
	if not template or not template:IsA("BasePart") or (landing - origin).Magnitude < 0.05 then
		return
	end

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local color = if params.Haki then HAKI_COLOR else primary or DEFAULT_COLOR

	local blade = template:Clone()
	for _, descendant in blade:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Trail") then
			descendant:Destroy()
		end
	end
	blade.Color = color
	blade.Material = Enum.Material.Ice
	blade.Anchored = true
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false
	blade.CFrame = CFrame.lookAt(origin, landing) * CFrame.Angles(math.rad(-180), 0, 0)

	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, blade.Size.Y / 2, 0)
	top.Parent = blade
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -blade.Size.Y / 2, 0)
	bottom.Parent = blade

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(color)
	trail.Transparency = TRAIL_TRANSPARENCY
	trail.Lifetime = TRAIL_LIFETIME
	trail.Parent = blade

	blade.Parent = World.Effects()
	Debris:AddItem(blade, fallTime + STAY_TIME + FADE_TIME + 0.5)

	TweenService:Create(blade, TweenInfo.new(fallTime, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
		CFrame = blade.CFrame.Rotation + landing,
	}):Play()
	task.wait(fallTime)
	if not blade.Parent then
		return
	end
	trail.Enabled = false

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = RING_START
	ring.Color = color
	ring.Material = Enum.Material.Ice
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.CFrame = CFrame.new(landing) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = World.Effects()
	TweenService:Create(ring, TweenInfo.new(RING_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(RING_THICKNESS, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, RING_LIFETIME)

	task.wait(STAY_TIME)
	if blade.Parent then
		TweenService:Create(blade, TweenInfo.new(FADE_TIME), { Transparency = 1 }):Play()
	end
end
