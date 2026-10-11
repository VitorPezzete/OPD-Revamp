--!strict
--[[
	Zombie Head: the character touched by it is zombie green (every body part except the
	root) for as long as the status is there, i.e. until it respawns. The green is a
	BodyPaint layer: the original colors come back if the status is ever removed, whatever
	else painted the body meanwhile. Status value: true.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UtilityConfig = require(ReplicatedStorage.Shared.Configs.UtilityConfig)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)

local ROOT_NAME = "HumanoidRootPart"

return function(character: Model, _value: any, _isLocal: boolean): () -> ()
	local limbs: { BasePart } = {}
	for _, limb in character:GetChildren() do
		if limb:IsA("BasePart") and limb.Name ~= ROOT_NAME then
			table.insert(limbs, limb)
		end
	end

	local release = BodyPaint.Paint(limbs, { Color = UtilityConfig.ZombieColor })
	return release
end
