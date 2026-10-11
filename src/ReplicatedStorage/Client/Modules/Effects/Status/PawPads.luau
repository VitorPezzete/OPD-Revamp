--!strict
--[[
	Paw fruit - the paw pads of its owner (passive, Server.Modules.Passives.Paw).
	Status value: true.

	As the source Customize script built them: on each arm a copy of the paw model,
	0.7 x 0.7 x 0.233 studs, 1 stud down the arm (on the palm) and turned to face along it,
	in its own material, colored (204, 130, 146). Welded to the arm, so it follows every
	animation.

	A pad is seen only while its arm is. Several effects take the real arm away by setting
	its Transparency to 1 and draw another one in its place (the stretched arms of Gum
	Pistol / Bazooka / Gatling / Rocket, the flying fists of Smoke): the pad is a part of
	its own, so it stayed behind, floating where the hidden arm was. Rather than teaching
	every such effect about the pads, each pad watches its own arm: hidden the moment the
	arm's Transparency reaches 1, back (at the transparency it had) the moment the arm is
	shown again, whoever hid it and for however long. Effects that hide a limb with the
	local modifier (Chop, Ope, CharacterHide, Invisible) already cover what is inside it.
]]
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local ARMS = { "Right Arm", "Left Arm" }
local SIZE = Vector3.new(0.7, 0.7, 0.233)
local OFFSET = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)
local COLOR = Color3.fromRGB(204, 130, 146)
local PAD_NAME = "PawPad"
-- An arm at this Transparency has been taken away by another effect.
local HIDDEN_TRANSPARENCY = 1

local function noop() end

-- Keeps `pad` hidden for exactly as long as `arm` is. Returns the connection doing it.
local function followArm(arm: BasePart, pad: BasePart): RBXScriptConnection
	local hidden = false
	local shown = pad.Transparency
	local function update()
		local armHidden = arm.Transparency >= HIDDEN_TRANSPARENCY
		if armHidden == hidden then
			return
		end
		hidden = armHidden
		if armHidden then
			-- What the pad goes back to: its look at the time, as the arm's own hiders do.
			shown = pad.Transparency
			pad.Transparency = HIDDEN_TRANSPARENCY
		else
			pad.Transparency = shown
		end
	end
	update()
	return arm:GetPropertyChangedSignal("Transparency"):Connect(update)
end

return function(character: Model, _value: any, _isLocal: boolean): () -> ()
	local template = EffectAssets.FindFruit("Paw", "PawModel")
	if not template or not template:IsA("BasePart") then
		return noop
	end

	local padTemplate: BasePart = template

	local pads: { [Instance]: BasePart } = {}
	local following: { RBXScriptConnection } = {}
	local function attach(arm: Instance)
		if not arm:IsA("BasePart") or not table.find(ARMS, arm.Name) or pads[arm] then
			return
		end

		local pad = padTemplate:Clone()
		pad.Name = PAD_NAME
		pad.Anchored = false
		pad.CanCollide = false
		pad.CanQuery = false
		pad.CanTouch = false
		pad.Massless = true
		pad.Size = SIZE
		pad.Color = COLOR
		pad.CFrame = arm.CFrame * OFFSET

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = pad
		weld.Part1 = arm
		weld.Parent = pad

		pad.Parent = arm
		pads[arm] = pad
		table.insert(following, followArm(arm, pad))
	end
	for _, child in character:GetChildren() do
		attach(child)
	end
	-- The status can be on the model before its arms are here (a character that is still
	-- replicating, or streaming in): the source pads were on the server, always there.
	local added = character.ChildAdded:Connect(attach)

	return function()
		added:Disconnect()
		for _, connection in following do
			connection:Disconnect()
		end
		for _, pad in pads do
			pad:Destroy()
		end
	end
end
