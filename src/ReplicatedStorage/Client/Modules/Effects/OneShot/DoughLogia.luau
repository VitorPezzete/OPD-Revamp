--!strict
--[[
	Dough fruit - logia "the hit passed through": the body turns to mochi for one second.
	params: { Caster: Model, Colors: string }

	Head, torso and limbs take the first fruit color (plain white without one, as the
	source did) in Plastic, and each sheds mochi from a copy of
	ReplicatedStorage.Assets.Models.Fruits.Dough.Logia["Dough Logia"] (a ParticleEmitter,
	tinted with the first fruit color). The tint is a BodyPaint layer, so the body gets
	its own look back whatever else painted it meanwhile.
	The "Mochi Formating" sound plays on the root.
	The server sends this at most once every 1.2 s per character.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DURATION = 1
local SOUND_LIFETIME = 2.5
local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)

return function(_origin: Vector3, params: { [string]: any }?)
	local character = params and params.Caster
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end

	local primary = FruitColor.Parse(if type(params and params.Colors) == "string" then (params :: any).Colors else "")
	local template = EffectAssets.FindFruit("Dough", "Logia", "Dough Logia")

	local root = character:FindFirstChild("HumanoidRootPart")
	local definition = (SoundConfig :: any).Fruits.Dough.MochiFormating
	if root and definition then
		local sound = Instance.new("Sound")
		sound.SoundId = definition.Id
		sound.Volume = definition.Volume
		sound.PlaybackSpeed = definition.Speed or 1
		sound.Parent = root
		sound:Play()
		Debris:AddItem(sound, SOUND_LIFETIME)
	end

	local limbs = BodyPaint.Limbs(character, LIMBS)
	local release = BodyPaint.Paint(limbs, { Color = primary or DEFAULT_COLOR, Material = Enum.Material.Plastic })

	local emitters: { Instance } = {}
	if template and template:IsA("ParticleEmitter") then
		for _, limb in limbs do
			local emitter = template:Clone()
			if primary then
				emitter.Color = ColorSequence.new(primary)
			end
			emitter.Enabled = true
			emitter.Parent = limb
			table.insert(emitters, emitter)
		end
	end

	task.delay(DURATION, function()
		release()
		for _, emitter in emitters do
			emitter:Destroy()
		end
	end)
end
