--!strict
--[[
	Barrier fruit - Barrier Body: barrier plates over the head, torso and limbs while the
	status is active. The status value is the fruit's saved color string.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Barrier.Power6.Barrier<Part>
	(limb-sized parts).

	Plates are local welded clones, so nothing has to be cleaned up on the server. The
	pose of the user is not played here: the body raises the BarrierActive status, like
	every other barrier (Effects.Status.BarrierActive).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local PLATES: { [string]: string } = {
	["Head"] = "BarrierHead",
	["Torso"] = "BarrierTorso",
	["Right Arm"] = "BarrierRArm",
	["Left Arm"] = "BarrierLArm",
	["Right Leg"] = "BarrierRLeg",
	["Left Leg"] = "BarrierLLeg",
}

return function(character: Model, value: any): () -> ()
	local primary = FruitColor.Parse(if type(value) == "string" then value else "")

	local plates: { BasePart } = {}
	local folder = EffectAssets.FindFruit("Barrier", "Power6")
	if folder then
		for limbName, plateName in PLATES do
			local limb = character:FindFirstChild(limbName)
			local template = folder:FindFirstChild(plateName)
			if limb and limb:IsA("BasePart") and template and template:IsA("BasePart") then
				local part = template:Clone()
				part.Anchored = false
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Massless = true
				part.CFrame = limb.CFrame
				if primary then
					part.Color = primary
				end

				local weld = Instance.new("Weld")
				weld.Part0 = limb
				weld.Part1 = part
				weld.Parent = part

				part.Parent = limb
				table.insert(plates, part)
			end
		end
	end

	return function()
		for _, part in plates do
			part:Destroy()
		end
	end
end
