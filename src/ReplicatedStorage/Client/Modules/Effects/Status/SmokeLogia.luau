--!strict
--[[
	Smoke fruit passive: a melee / sword hit just passed through the body.
	Status value: the fruit color string. Timed by the server (1 second).

	The six body parts take the smoke color (white unless the fruit has custom colors)
	and leak smoke, with the leak sound; everything is put back when the status ends.
	Template: ReplicatedStorage.Assets.Models.Fruits.Smoke.Logia.SmokeLogia (ParticleEmitter).

	The legacy LogiaModule recolored the body on the server and then rebuilt the skin
	from the saved skin color / dye; here the tint is a BodyPaint layer, so the parts get
	their own look back whatever else painted them meanwhile.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local BODY_PARTS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)
local LEAK_SECONDS = 1.5

return function(character: Model, value: any, _isLocal: boolean): () -> ()
	local primary = FruitColor.Parse(if type(value) == "string" then value else "")
	local template = EffectAssets.FindFruit("Smoke", "Logia", "SmokeLogia")

	local parts = BodyPaint.Limbs(character, BODY_PARTS)
	local release = BodyPaint.Paint(parts, { Color = primary or DEFAULT_COLOR, Material = Enum.Material.Plastic })

	local emitters: { Instance } = {}
	if template and template:IsA("ParticleEmitter") then
		for _, part in parts do
			local emitter = template:Clone()
			if primary then
				emitter.Color = ColorSequence.new(primary)
			end
			emitter.Parent = part
			table.insert(emitters, emitter)
		end
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local definition = (SoundConfig :: any).SFX.Elemental.Smoke["Smoke Leak"]
	if root and definition then
		local sound = Instance.new("Sound")
		sound.SoundId = definition.Id
		sound.Volume = definition.Volume
		sound.PlaybackSpeed = definition.Speed or 1
		sound.Parent = root
		sound:Play()
		Debris:AddItem(sound, LEAK_SECONDS)
	end

	return function()
		for _, emitter in emitters do
			emitter:Destroy()
		end
		release()
	end
end
