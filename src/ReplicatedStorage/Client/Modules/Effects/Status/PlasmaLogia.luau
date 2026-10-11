--!strict
--[[
	Plasma fruit passive: a melee / sword hit just passed through the body.
	Status value: the fruit color string. Timed by the server (1 second).

	The six body parts turn to neon plasma (first fruit color, light purple by default)
	and glow, and 15 short sparks fly off the body; everything is removed when the
	status ends. Light template: ReplicatedStorage.Assets.Models.Fruits.Rumble.Logia.PointLight
	(the legacy Plasma effect borrowed the Rumble light too).

	Two logia effects can run on one body (a user of two logia fruits, or another fruit's
	pass-through one-shot): the neon is a BodyPaint layer, so the most recent effect
	shows and the parts get their own look back when the last one ends.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local drawBolt = require(script.Parent.Parent.OneShot.PlasmaBolt)

local BODY_PARTS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DEFAULT_COLOR = Color3.fromRGB(221, 117, 255)
local SPARKS = 15
local SPARK_LENGTH = 10
local SPARK_LIFE = 0.7

return function(character: Model, value: any, _isLocal: boolean): () -> ()
	local color = FruitColor.Parse(if type(value) == "string" then value else "") or DEFAULT_COLOR
	local template = EffectAssets.FindFruit("Rumble", "Logia", "PointLight")

	local parts = BodyPaint.Limbs(character, BODY_PARTS)
	local release = BodyPaint.Paint(parts, { Color = color, Material = Enum.Material.Neon })

	local created: { Instance } = {}
	if template and template:IsA("PointLight") then
		for _, part in parts do
			local light = template:Clone()
			light.Brightness = 1
			light.Color = color
			light.Parent = part
			table.insert(created, light)
		end
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local origin = root.Position
		for _ = 1, SPARKS do
			local direction = Vector3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
			if direction.Magnitude < 1 then
				direction = Vector3.yAxis
			end
			drawBolt(origin, {
				Target = origin + direction.Unit * SPARK_LENGTH,
				Color = color,
				Thickness = 0.5,
				Step = 2,
				Jitter = 1,
				Life = SPARK_LIFE,
				Shrink = SPARK_LIFE,
			})
		end
	end

	return function()
		for _, instance in created do
			instance:Destroy()
		end
		release()
	end
end
