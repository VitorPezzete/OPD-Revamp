--!strict
--[[
	Chilly fruit - frozen victim: a shell of ice over the head, torso and each limb for
	as long as the "ChillyPunched" status lasts. Runs on players and NPC enemies.

	Status value: the attacker's fruit color string (first color paints the ice).
	Templates: ReplicatedStorage.Assets.Models.Fruits.Chilly.Stun.ChillyIcePart<Head|Torso|LArm|RArm|LLeg|RLeg>.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local SHELLS: { [string]: string } = {
	Head = "ChillyIcePartHead",
	Torso = "ChillyIcePartTorso",
	["Left Arm"] = "ChillyIcePartLArm",
	["Right Arm"] = "ChillyIcePartRArm",
	["Left Leg"] = "ChillyIcePartLLeg",
	["Right Leg"] = "ChillyIcePartRLeg",
}

local function noop() end

return function(character: Model, value: any): () -> ()
	local folder = EffectAssets.FindFruit("Chilly", "Stun")
	if not folder then
		return noop
	end

	local primary = FruitColor.Parse(if type(value) == "string" then value else "")

	local shells: { BasePart } = {}
	for limbName, templateName in SHELLS do
		local limb = character:FindFirstChild(limbName)
		local template = folder:FindFirstChild(templateName)
		if not limb or not limb:IsA("BasePart") or not template or not template:IsA("BasePart") then
			continue
		end

		local shell = template:Clone()
		shell.Anchored = false
		shell.CanCollide = false
		shell.CanQuery = false
		shell.CanTouch = false
		shell.Massless = true
		shell.CFrame = limb.CFrame
		if primary then
			shell.Color = primary
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = shell
		weld.Part1 = limb
		weld.Parent = shell

		shell.Parent = limb
		table.insert(shells, shell)
	end

	return function()
		for _, shell in shells do
			shell:Destroy()
		end
	end
end
