--!strict
--[[
	Light fruit - Light Beam: one still frame of the laser.
	UNUSED: the ability no longer sends it. The beam is drawn every frame by
	Effects.Status.LightBeam; this module can be removed.
	origin: the hand the beam leaves from at that moment.
	params: { To: Vector3, Radius: number, Haki: boolean, Colors: string, Caster: Model }

	A 0.5 stud neon beam and the spark at its end (legacy: sphere of the damage
	diameter, shown 0.25 s). Each frame lives a little longer than the gap to the next
	one, so the beam looks continuous and disappears by itself when the frames stop.
	Yellow, the first fruit color, or dark with armament haki.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 0)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local BEAM_THICKNESS = 0.5
local DURATION = 0.22
local MIN_SPARK = 1

local function neon(color: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

return function(origin: Vector3, params: { [string]: any }?)
	local target = params and params.To
	if not params or typeof(target) ~= "Vector3" then
		return
	end

	local primary = EffectAssets.Colors(params.Colors, DEFAULT_COLOR, DEFAULT_COLOR)
	local color = if params.Haki then HAKI_COLOR else primary

	local length = (target - origin).Magnitude
	if length > 0.05 then
		local beam = neon(color)
		beam.Size = Vector3.new(BEAM_THICKNESS, BEAM_THICKNESS, length)
		beam.CFrame = CFrame.lookAt(origin, target) * CFrame.new(0, 0, -length / 2)
		beam.Parent = World.Effects()
		Debris:AddItem(beam, DURATION)
	end

	local radius = if type(params.Radius) == "number" then params.Radius else 0
	local size = math.max(radius * 2, MIN_SPARK)
	local spark = neon(color)
	spark.Shape = Enum.PartType.Ball
	spark.Size = Vector3.new(size, size, size)
	spark.CFrame = CFrame.new(target)
	spark.Parent = World.Effects()
	Debris:AddItem(spark, DURATION)
end
