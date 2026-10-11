--!strict
--[[
	Magma fruit - logia pass-through: a melee or sword hit went through the body.
	params: { Caster: Model (the logia user), Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Magma.Logia.Fire (a Fire).

	For one second the head, torso and limbs turn the color of magma (first fruit color,
	red by default) and burn. The tint is a BodyPaint layer, so the body gets its own look
	back whatever else painted it meanwhile. The legacy server rewrote Body Colors from
	the saved skin instead, and skipped the effect while a body ability was painting the
	body (the passive does not send it then; the check here covers a body turned on
	before the effect arrives).

	The "Magma Eruption" sound plays on the root for that second.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DEFAULT_COLOR = Color3.fromRGB(255, 0, 0)
local DURATION = 1
-- Body abilities that paint the body themselves (the legacy list).
local BODY_ATTRIBUTES = { "MagmaBody", "CandyBody", "SnowBody", "VenomBody", "Gum2nd" }

return function(_origin: Vector3, params: { [string]: any }?)
	local character = params and params.Caster
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end
	for _, attribute in BODY_ATTRIBUTES do
		if character:GetAttribute(attribute) then
			return
		end
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local definition = (SoundConfig :: any).SFX.Elemental.Magma["Magma Eruption"]
	if root and definition then
		local sound = Instance.new("Sound")
		sound.SoundId = definition.Id
		sound.Volume = definition.Volume
		sound.PlaybackSpeed = definition.Speed or 1
		sound.Parent = root
		sound:Play()
		Debris:AddItem(sound, DURATION)
	end

	local template = EffectAssets.FindFruit("Magma", "Logia", "Fire")
	local primary = FruitColor.Parse(if params and type(params.Colors) == "string" then params.Colors else "")
	local color = primary or DEFAULT_COLOR

	local limbs = BodyPaint.Limbs(character, LIMBS)
	local release = BodyPaint.Paint(limbs, { Color = color, Material = Enum.Material.Plastic })

	local fires: { Instance } = {}
	if template and template:IsA("Fire") then
		for _, limb in limbs do
			local clone = template:Clone()
			clone.Color = color
			clone.Enabled = true
			clone.Parent = limb
			table.insert(fires, clone)
		end
	end

	task.delay(DURATION, function()
		release()
		for _, fire in fires do
			fire:Destroy()
		end
	end)
end
