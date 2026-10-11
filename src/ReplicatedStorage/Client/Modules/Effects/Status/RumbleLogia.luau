--!strict
--[[
	Rumble fruit passive: a melee / sword hit just passed through the body.
	Status value: the fruit color string. Timed by the server (1 second).

	The six body parts turn to neon lightning and glow, 20 sparks crackle around the body
	and the "Electricity" sound plays; everything is removed when the status ends.
	Light template: ReplicatedStorage.Assets.Models.Fruits.Rumble.Logia.PointLight.

	Colors, as the legacy LogiaModule set them. With a fruit color: body, light and
	sparks all take the first one. Without: the body is electric blue (4, 175, 236), the
	light keeps the template's own blue and the sparks the "Toothpaste" cyan of every
	Rumble bolt.

	Two logia effects can run on one body (a user of two logia fruits, or another fruit's
	pass-through one-shot): the neon is a BodyPaint layer, so the most recent effect
	shows and the parts get their own look back when the last one ends.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local startSparks = require(script.Parent.Parent.OneShot.RumbleSparks)

local BODY_PARTS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DEFAULT_BODY_COLOR = Color3.fromRGB(4, 175, 236)

return function(character: Model, value: any, _isLocal: boolean): () -> ()
	local fruitColor = FruitColor.Parse(if type(value) == "string" then value else "")
	local template = EffectAssets.FindFruit("Rumble", "Logia", "PointLight")

	local parts = BodyPaint.Limbs(character, BODY_PARTS)
	local release = BodyPaint.Paint(parts, { Color = fruitColor or DEFAULT_BODY_COLOR, Material = Enum.Material.Neon })

	local created: { Instance } = {}
	if template and template:IsA("PointLight") then
		for _, part in parts do
			local light = template:Clone()
			light.Brightness = 1
			if fruitColor then
				light.Color = fruitColor
			end
			light.Parent = part
			table.insert(created, light)
		end
	end

	local stopSparks: (() -> ())? = nil
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		-- Legacy: 20 sparks, one every 0.027 s, up to 5 studs out (2.5 below, 5 above).
		stopSparks = startSparks(root.Position, {
			Part = root,
			Range = 5,
			Floor = -0.5,
			Count = 20,
			Interval = 0.027,
			Thickness = 0.2,
			Life = 0.5,
			Color = fruitColor,
		})

		local sfx = (SoundConfig :: any).SFX
		local group = sfx and sfx.Elemental and sfx.Elemental.Rumble
		local definition = group and group.Electricity
		if definition then
			local sound = Instance.new("Sound")
			sound.SoundId = definition.Id
			sound.Volume = definition.Volume or 0.25
			sound.PlaybackSpeed = definition.Speed or 1
			sound.Parent = root
			sound:Play()
			table.insert(created, sound)
		end
	end

	return function()
		if stopSparks then
			stopSparks()
		end
		for _, instance in created do
			instance:Destroy()
		end
		release()
	end
end
