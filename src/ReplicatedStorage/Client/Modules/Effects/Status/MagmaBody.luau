--!strict
--[[
	Magma fruit - Magma Body: flames on the head, torso and limbs, and the body painted
	the color of magma while the status is active. Status value: the fruit color string.
	Template: ReplicatedStorage.Assets.Models.Fruits.Magma.Power2.Fire (a Fire).

	Colors: body = first fruit color (bright red by default), flames = second / first
	color (red / brown by default); everything dark with armament haki.

	The legacy server rewrote the character's Body Colors and restored the skin from the
	saved data when toggled off. Here the six parts are tinted locally through a BodyPaint
	layer, so they get their own color back whatever else painted them meanwhile and
	nothing has to be restored on the server.

	The "Magma Flow" sound loops on the root while the body is on.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local HAKI_ATTRIBUTE = "Haki"

local DEFAULT_BODY = BrickColor.new("Bright red").Color
local DEFAULT_FIRE = Color3.fromRGB(255, 0, 0)
local DEFAULT_FIRE_SECONDARY = Color3.fromRGB(139, 80, 55)
local HAKI_BODY = Color3.fromRGB(25, 12, 25)
local HAKI_FIRE = Color3.fromRGB(26, 13, 26)

return function(character: Model, value: any): () -> ()
	local template = EffectAssets.FindFruit("Magma", "Power2", "Fire")
	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")

	local limbs = BodyPaint.Limbs(character, LIMBS)
	local fires: { Fire } = {}
	if template and template:IsA("Fire") then
		for _, limb in limbs do
			local clone = template:Clone()
			clone.Enabled = true
			clone.Parent = limb
			table.insert(fires, clone)
		end
	end

	local function bodyColor(): Color3
		return if character:GetAttribute(HAKI_ATTRIBUTE) then HAKI_BODY elseif primary then primary else DEFAULT_BODY
	end
	local release, repaint = BodyPaint.Paint(limbs, { Color = bodyColor() })

	local function paint()
		local haki = character:GetAttribute(HAKI_ATTRIBUTE)
		repaint({ Color = bodyColor() })
		for _, fire in fires do
			if haki then
				fire.Color = HAKI_FIRE
				fire.SecondaryColor = HAKI_FIRE
			elseif primary and secondary then
				fire.Color = secondary
				fire.SecondaryColor = primary
			else
				fire.Color = DEFAULT_FIRE
				fire.SecondaryColor = DEFAULT_FIRE_SECONDARY
			end
		end
	end

	paint()
	local hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)

	local sound: Sound? = nil
	local root = character:FindFirstChild("HumanoidRootPart")
	local definition = (SoundConfig :: any).SFX.Elemental.Magma["Magma Flow"]
	if root and definition then
		local loop = Instance.new("Sound")
		loop.SoundId = definition.Id
		loop.Volume = definition.Volume
		loop.Looped = true
		loop.PlaybackSpeed = definition.Speed or 1
		loop.Parent = root
		loop:Play()
		sound = loop
	end

	return function()
		hakiConnection:Disconnect()
		if sound then
			sound:Destroy()
		end
		release()
		for _, fire in fires do
			fire:Destroy()
		end
	end
end
