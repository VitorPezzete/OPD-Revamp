--!strict
--[[
	Gravity fruit - the aura of a user bending gravity: particles on the head, the torso
	and each limb while flying or charging a power. Status value: the fruit color string
	(both ends of the particle color use the first color, as in the legacy game).

	Templates: ReplicatedStorage.Assets.Models.Fruits.Gravity.Power1.GravityPartHead and
	GravityPartLimb (parts with a ParticleEmitter and a Weld; the authored weld offsets
	are kept and only its Part0 is set, as the legacy server did).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HEAD_TEMPLATE = "GravityPartHead"
local LIMB_TEMPLATE = "GravityPartLimb"
local LIMBS: { [string]: string } = {
	Head = HEAD_TEMPLATE,
	Torso = LIMB_TEMPLATE,
	["Right Arm"] = LIMB_TEMPLATE,
	["Left Arm"] = LIMB_TEMPLATE,
	["Right Leg"] = LIMB_TEMPLATE,
	["Left Leg"] = LIMB_TEMPLATE,
}

local function noop() end

return function(character: Model, value: any): () -> ()
	local folder = EffectAssets.FindFruit("Gravity", "Power1")
	if not folder then
		return noop
	end

	local primary = FruitColor.Parse(if type(value) == "string" then value else "")

	local parts: { BasePart } = {}
	for limbName, templateName in LIMBS do
		local limb = character:FindFirstChild(limbName)
		local template = folder:FindFirstChild(templateName)
		if not limb or not limb:IsA("BasePart") or not template or not template:IsA("BasePart") then
			continue
		end

		local part = template:Clone()
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = limb.CFrame

		if primary then
			for _, descendant in part:GetDescendants() do
				if descendant:IsA("ParticleEmitter") then
					descendant.Color = ColorSequence.new(primary)
				end
			end
		end

		local weld = part:FindFirstChildOfClass("Weld")
		if not weld then
			weld = Instance.new("Weld")
			weld.Parent = part
		end
		if weld then
			weld.Part0 = limb
			weld.Part1 = part
		end

		part.Parent = limb
		table.insert(parts, part)
	end

	return function()
		for _, part in parts do
			part:Destroy()
		end
	end
end
