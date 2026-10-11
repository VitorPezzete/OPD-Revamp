--!strict
--[[
	Hot fruit - Hot Body. Status value: the fruit color string.

	A glowing shell welded over the head, torso and each limb.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Hot.Power2.Hot<Head|Torso|LArm|RArm|LLeg|RLeg>,
	each a part with a "HotBodyEffect" ParticleEmitter.

	Custom colors paint the shell with the first color and its particles with the
	second; without them the authored look is kept. While armament haki is on (the
	"Haki" attribute) the shells turn dark, and go back when it ends.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local SHELLS: { [string]: string } = {
	Head = "HotHead",
	Torso = "HotTorso",
	["Right Arm"] = "HotRArm",
	["Left Arm"] = "HotLArm",
	["Right Leg"] = "HotRLeg",
	["Left Leg"] = "HotLLeg",
}
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 0, 25)

local function noop() end

local function findAsset(...: string): Instance?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { ... } do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

return function(character: Model, value: any): () -> ()
	local folder = findAsset("Models", "Fruits", "Hot", "Power2")
	if not folder then
		return noop
	end

	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")

	-- Shell -> the color it has while haki is off.
	local shells: { [BasePart]: Color3 } = {}
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

		if primary and secondary then
			shell.Color = primary
			local emitter = shell:FindFirstChild("HotBodyEffect")
			if emitter and emitter:IsA("ParticleEmitter") then
				emitter.Color = ColorSequence.new(secondary)
			end
		end
		shells[shell] = shell.Color

		local weld = Instance.new("Weld")
		weld.Name = "HotWeld"
		weld.Part0 = limb
		weld.Part1 = shell
		weld.Parent = shell

		shell.Parent = limb
	end

	local function applyHaki()
		local hakiOn = character:GetAttribute(HAKI_ATTRIBUTE) ~= nil
		for shell, color in shells do
			shell.Color = if hakiOn then HAKI_COLOR else color
		end
	end
	local hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(applyHaki)
	applyHaki()

	return function()
		hakiConnection:Disconnect()
		for shell in shells do
			shell:Destroy()
		end
	end
end
