--!strict
--[[
	Conqueror's Haki, stage 3 - the coating: emitters and beams of the wearer's colour on
	every limb for as long as the status is on.
	Value: the colour as a hex string (ConquerorConfig.ParseColor).
	Template: ReplicatedStorage.Assets.Models.Conqueror.HaoFullCoat, one child per limb
	name, each holding what goes on that limb.

	Everything is a local copy parented to the limb, removed with the status. A limb the
	character does not have is skipped.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConquerorConfig = require(ReplicatedStorage.Shared.Configs.ConquerorConfig)
local ConquerorFx = require(script.Parent.Parent.Util.ConquerorFx)

local DEFAULT_COLOR = ConquerorConfig.Palette[1]

local function noop() end

local function tint(instance: Instance, color: Color3)
	if instance:IsA("ParticleEmitter") or instance:IsA("Beam") then
		instance.Color = ColorSequence.new(color)
	end
end

return function(character: Model, value: any): () -> ()
	local template = ConquerorFx.Asset("HaoFullCoat")
	if not template then
		return noop
	end

	local color = ConquerorConfig.ParseColor(value) or DEFAULT_COLOR
	local pieces: { Instance } = {}
	for _, limbTemplate in template:GetChildren() do
		local limb = character:FindFirstChild(limbTemplate.Name)
		if limb and limb:IsA("BasePart") then
			for _, child in limbTemplate:GetChildren() do
				local piece = child:Clone()
				tint(piece, color)
				for _, descendant in piece:GetDescendants() do
					tint(descendant, color)
				end
				piece.Parent = limb
				table.insert(pieces, piece)
			end
		end
	end

	return function()
		for _, piece in pieces do
			piece:Destroy()
		end
	end
end
