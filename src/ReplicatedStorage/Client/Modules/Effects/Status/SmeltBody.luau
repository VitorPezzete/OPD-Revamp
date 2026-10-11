--!strict
--[[
	Smelt fruit - Silver Body: a molten shell over the head, torso and limbs while the
	status is active. The status value is the fruit's saved color string.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Smelt.Power2.Smelt<Part> (limb-sized
	parts, each with a "SmeltBodyEffect" ParticleEmitter).

	Shells are local welded clones, so nothing has to be cleaned up on the server and a
	limb lost mid-effect cannot leave anything behind. They darken with armament haki.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local SHELLS: { [string]: string } = {
	["Head"] = "SmeltHead",
	["Torso"] = "SmeltTorso",
	["Right Arm"] = "SmeltRArm",
	["Left Arm"] = "SmeltLArm",
	["Right Leg"] = "SmeltRLeg",
	["Left Leg"] = "SmeltLLeg",
}
local EMITTER_NAME = "SmeltBodyEffect"
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 0, 25)

type Shell = {
	Part: BasePart,
	Emitter: ParticleEmitter?,
	AuthoredColor: Color3,
	AuthoredEmitterColor: ColorSequence?,
}

local function noop() end

return function(character: Model, value: any): () -> ()
	local models = ReplicatedStorage.Assets:FindFirstChild("Models")
	local fruits = models and models:FindFirstChild("Fruits")
	local fruit = fruits and fruits:FindFirstChild("Smelt")
	local folder = fruit and fruit:FindFirstChild("Power2")
	if not folder then
		return noop
	end

	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")

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

			local emitter = part:FindFirstChild(EMITTER_NAME)
			local particle = if emitter and emitter:IsA("ParticleEmitter") then emitter else nil
			table.insert(shells, {
				Part = part,
				Emitter = particle,
				AuthoredColor = part.Color,
				AuthoredEmitterColor = if particle then particle.Color else nil,
			})
			part.Parent = limb
		end
	end

	local function paint()
		local haki = character:GetAttribute(HAKI_ATTRIBUTE)
		for _, shell in shells do
			local emitter = shell.Emitter
			if haki then
				-- Legacy look: only the shell darkens, the particles keep their color.
				shell.Part.Color = HAKI_COLOR
			elseif primary and secondary then
				shell.Part.Color = primary
				if emitter then
					emitter.Color = ColorSequence.new(secondary)
				end
			else
				shell.Part.Color = shell.AuthoredColor
				if emitter and shell.AuthoredEmitterColor then
					emitter.Color = shell.AuthoredEmitterColor
				end
			end
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
