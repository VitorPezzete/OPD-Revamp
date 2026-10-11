--!strict
--[[
	Plasma fruit - Energize: plasma under both feet and glowing footprints while the
	status is active. Status value: the fruit color string.

	Templates (ReplicatedStorage.Assets.Models.Fruits.Plasma.Power1):
	- Particles (ParticleEmitter): one under each foot, right foot in the first fruit
	  color and left foot in the second;
	- PlasmaRushFoot (part with a "Particles" emitter): dropped under the right foot every
	  0.15 s and removed 0.35 s later. The legacy script meant to alternate feet but never
	  flipped its flag, so it was always the right one; that is kept.

	The legacy April 1st recolor is not ported.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LEGS = { "Right Leg", "Left Leg" }
local FOOT_OFFSET = CFrame.new(0, -1, 0)
local FOOTPRINT_INTERVAL = 0.15
local FOOTPRINT_LIFE = 0.35

return function(character: Model, value: any): () -> ()
	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
	local template = EffectAssets.FindFruit("Plasma", "Power1", "Particles")
	local footprint = EffectAssets.FindFruit("Plasma", "Power1", "PlasmaRushFoot")

	local attachments: { Attachment } = {}
	if template and template:IsA("ParticleEmitter") then
		for index, legName in LEGS do
			local leg = character:FindFirstChild(legName)
			if leg and leg:IsA("BasePart") then
				local attachment = Instance.new("Attachment")
				attachment.Name = "PlasmaRush"
				attachment.CFrame = FOOT_OFFSET

				local emitter = template:Clone()
				if primary and secondary then
					emitter.Color = ColorSequence.new(if index == 1 then primary else secondary)
				end
				emitter.Enabled = true
				emitter.Parent = attachment

				attachment.Parent = leg
				table.insert(attachments, attachment)
			end
		end
	end

	local alive = true
	if footprint and footprint:IsA("BasePart") then
		-- Typed copy: the closure below cannot rely on the narrowing above.
		local footprintTemplate: BasePart = footprint
		task.spawn(function()
			while alive do
				task.wait(FOOTPRINT_INTERVAL)
				local leg = character:FindFirstChild(LEGS[1])
				if not alive or not leg or not leg:IsA("BasePart") then
					continue
				end

				local mark = footprintTemplate:Clone()
				mark.Anchored = true
				mark.CanCollide = false
				mark.CanQuery = false
				mark.CanTouch = false
				mark.CFrame = leg.CFrame * FOOT_OFFSET
				local particles = mark:FindFirstChild("Particles")
				if primary and particles and particles:IsA("ParticleEmitter") then
					particles.Color = ColorSequence.new(primary)
				end
				mark.Parent = World.Effects()
				Debris:AddItem(mark, FOOTPRINT_LIFE)
			end
		end)
	end

	return function()
		alive = false
		for _, attachment in attachments do
			attachment:Destroy()
		end
	end
end
