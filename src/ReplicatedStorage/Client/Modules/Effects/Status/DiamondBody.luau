--!strict
--[[
	Diamond fruit - Diamond Body: a diamond shell over the head, torso and limbs while
	the status is active. The status value is the fruit's saved color string.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Diamond.Power2.Diamond<Part>
	(limb-sized parts).

	Shells are local welded clones, so nothing has to be cleaned up on the server and a
	limb lost mid-effect cannot leave anything behind.

	Armament haki. Its own shells (Effects.Status.Haki) are smaller than these and end up
	inside them, where the glass hides them, so the diamond shells of the arms and legs -
	the limbs haki covers - take the haki colour instead. Head and torso stay diamond:
	the body still reads as diamond with haki on. (The legacy server repainted every shell
	ten times a second to follow haki, the whole body included, which left nothing of the
	diamond to see.)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local SHELLS: { [string]: string } = {
	["Head"] = "DiamondHead",
	["Torso"] = "DiamondTorso",
	["Right Arm"] = "DiamondRArm",
	["Left Arm"] = "DiamondLArm",
	["Right Leg"] = "DiamondRLeg",
	["Left Leg"] = "DiamondLLeg",
}
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 0, 25)
-- The limbs armament haki covers (Effects.Status.Haki).
local HAKI_LIMBS: { [string]: boolean } = {
	["Right Arm"] = true,
	["Left Arm"] = true,
	["Right Leg"] = true,
	["Left Leg"] = true,
}

type Shell = {
	Part: BasePart,
	AuthoredColor: Color3,
	-- On a limb that armament haki covers.
	Haki: boolean,
}

local function noop() end

return function(character: Model, value: any): () -> ()
	local models = ReplicatedStorage.Assets:FindFirstChild("Models")
	local fruits = models and models:FindFirstChild("Fruits")
	local fruit = fruits and fruits:FindFirstChild("Diamond")
	local folder = fruit and fruit:FindFirstChild("Power2")
	if not folder then
		return noop
	end

	local primary = FruitColor.Parse(if type(value) == "string" then value else "")

	local shells: { Shell } = {}
	for limbName, shellName in SHELLS do
		local limb = character:FindFirstChild(limbName)
		local template = folder:FindFirstChild(shellName)
		if limb and limb:IsA("BasePart") and template and template:IsA("BasePart") then
			local part = template:Clone()
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.CFrame = limb.CFrame

			local weld = Instance.new("Weld")
			weld.Part0 = limb
			weld.Part1 = part
			weld.Parent = part

			table.insert(shells, { Part = part, AuthoredColor = part.Color, Haki = HAKI_LIMBS[limbName] == true })
			part.Parent = limb
		end
	end

	local function paint()
		local haki = character:GetAttribute(HAKI_ATTRIBUTE)
		for _, shell in shells do
			shell.Part.Color = if haki and shell.Haki
				then HAKI_COLOR
				elseif primary then primary
				else shell.AuthoredColor
		end
	end

	paint()
	local hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)

	return function()
		hakiConnection:Disconnect()
		for _, shell in shells do
			shell.Part:Destroy()
		end
	end
end
