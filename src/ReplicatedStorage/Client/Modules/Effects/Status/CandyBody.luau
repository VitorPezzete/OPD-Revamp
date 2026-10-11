--!strict
--[[
	Candy fruit - Spike Body. Status value: the fruit color string.

	Head, torso and limbs turn to glass in the first fruit color (forest green without
	one), 30 % transparent, and each one:
	- carries its spike model: ReplicatedStorage.Assets.Models.Fruits.Candy.Power2.
	  CandyHead / CandyTorso / CandyRArm / CandyLArm / CandyRLeg / CandyLLeg, moved so that
	  its PrimaryPart sits on the limb and welded part by part, as the legacy server did.
	  Its parts named "CandyBlade" take the first fruit color;
	- sheds syrup from a copy of Power2.CandyParticle (second fruit color).
	Everything is dark while armament haki is on. Color and material are a BodyPaint
	layer, so the limbs get their own look back whatever else painted them meanwhile; the
	transparency is put back here when the status ends.

	The legacy server rewrote the character's Body Colors and restored them from the
	saved skin; here nothing is changed on the server, so there is nothing to restore
	wrongly (skin dye, another body effect).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = {
	{ Limb = "Head", Model = "CandyHead" },
	{ Limb = "Torso", Model = "CandyTorso" },
	{ Limb = "Right Arm", Model = "CandyRArm" },
	{ Limb = "Left Arm", Model = "CandyLArm" },
	{ Limb = "Right Leg", Model = "CandyRLeg" },
	{ Limb = "Left Leg", Model = "CandyLLeg" },
}
local SPIKE_NAME = "CandyBlade"
local BODY_COLOR = BrickColor.new("Forest green").Color
local SPIKE_COLOR = Color3.fromRGB(31, 128, 29)
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local BODY_TRANSPARENCY = 0.3

return function(character: Model, value: any): () -> ()
	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
	local emitterTemplate = EffectAssets.FindFruit("Candy", "Power2", "CandyParticle")

	local limbs: { BasePart } = {}
	-- Transparency each limb we faded had before.
	local faded: { [BasePart]: number } = {}
	local spikes: { BasePart } = {}
	local created: { Instance } = {}

	for _, info in LIMBS do
		local limb = character:FindFirstChild(info.Limb)
		if not limb or not limb:IsA("BasePart") then
			continue
		end

		table.insert(limbs, limb)
		-- Limbs hidden by something else (invisibility) stay hidden.
		if limb.Transparency == 0 then
			faded[limb] = limb.Transparency
			limb.Transparency = BODY_TRANSPARENCY
		end

		local template = EffectAssets.FindFruit("Candy", "Power2", info.Model)
		if template and template:IsA("Model") and template.PrimaryPart then
			local model = template:Clone()
			local anchor = model.PrimaryPart
			if anchor then
				local shift = limb.CFrame * anchor.CFrame:Inverse()
				for _, descendant in model:GetDescendants() do
					if descendant:IsA("LuaSourceContainer") or descendant:IsA("JointInstance") then
						descendant:Destroy()
					end
				end
				for _, descendant in model:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.CFrame = shift * descendant.CFrame
						descendant.Anchored = false
						descendant.CanCollide = false
						descendant.CanQuery = false
						descendant.CanTouch = false
						descendant.Massless = true

						local weld = Instance.new("Weld")
						weld.Name = "CandyWeld"
						weld.Part0 = limb
						weld.Part1 = descendant
						weld.C0 = limb.CFrame:ToObjectSpace(descendant.CFrame)
						weld.Parent = descendant

						if descendant.Name == SPIKE_NAME then
							table.insert(spikes, descendant)
						end
					end
				end
				model.Parent = character
				table.insert(created, model)
			else
				model:Destroy()
			end
		end

		if emitterTemplate and emitterTemplate:IsA("ParticleEmitter") then
			local emitter = emitterTemplate:Clone()
			if secondary then
				emitter.Color = ColorSequence.new(secondary)
			end
			emitter.Enabled = true
			emitter.Parent = limb
			table.insert(created, emitter)
		end
	end

	local function look(): BodyPaint.Look
		local haki = character:GetAttribute(HAKI_ATTRIBUTE)
		return {
			Color = if haki then HAKI_COLOR elseif primary then primary else BODY_COLOR,
			Material = Enum.Material.Glass,
		}
	end
	local release, repaint = BodyPaint.Paint(limbs, look())

	local function paint()
		local haki = character:GetAttribute(HAKI_ATTRIBUTE)
		repaint(look())
		for _, spike in spikes do
			spike.Color = if haki then HAKI_COLOR elseif primary then primary else SPIKE_COLOR
		end
	end
	paint()
	local hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)

	return function()
		hakiConnection:Disconnect()
		release()
		for limb, transparency in faded do
			-- Only undo our own change: another effect may have hidden the limb meanwhile.
			if limb.Parent and math.abs(limb.Transparency - BODY_TRANSPARENCY) < 0.01 then
				limb.Transparency = transparency
			end
		end
		for _, instance in created do
			instance:Destroy()
		end
	end
end
