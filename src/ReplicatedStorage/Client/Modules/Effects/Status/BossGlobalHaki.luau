--!strict
--[[
	Raid bosses (Bosses/_Global): the haki phase, under 65 % health. Head, torso and limbs
	turn haki black, as the legacy script painted every body part of the model.

	The fruit effects worn by the boss (candy armour and blades, magma, molten shell and
	sword) darken on their own through the "Haki" attribute, which the server sets at
	the same time. This one covers the bosses whose fruit has no body effect (Sand, Quake,
	Flare, Plasma). The black is a BodyPaint layer, so the parts get their own colors back
	when the status ends, whatever else painted them meanwhile.
]]
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local ROOT_NAME = "HumanoidRootPart"

return function(character: Model): () -> ()
	local parts: { BasePart } = {}
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= ROOT_NAME then
			table.insert(parts, child)
		end
	end

	local release = BodyPaint.Paint(parts, { Color = HAKI_COLOR })
	return release
end
