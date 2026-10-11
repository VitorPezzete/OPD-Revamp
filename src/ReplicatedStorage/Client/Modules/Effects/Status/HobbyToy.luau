--!strict
--[[
	Hobby fruit - a character that has been turned into a toy (HobbyToy status; the value
	is the Hobby user's fruit color string).

	Everyone: the real body is hidden, its joints are pulled in to half size and the toy
	pieces (Assets.Models.Fruits.Hobby.Toys.Toy, one part per R6 limb) are welded onto
	the limbs at half size. Everything is local and restored when the status ends: the
	legacy server resized and re-colored the real character and could not always put it
	back. The server-side character keeps its real size.

	The body is hidden with the local transparency modifier, reapplied every frame (the
	camera scripts rewrite it on the local character), never with Transparency, so there
	is no original value to restore. Animal enemies (boar, crab) have no R6 limbs and
	are left visible, as before.

	The toy keeps the victim's face, at half size: the legacy server made the head
	transparent and half as big but never touched its face decal. Here the part that
	carries the face is copied at half size onto the head, and the real face is hidden
	with the rest of the body.

	Owner only: the reset button is disabled while a toy, and pressing it answers with
	one of the Hobby user's lines (OneShot.HobbyMessage), as it did.
]]
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local showMessage = require(script.Parent.Parent.OneShot.HobbyMessage)
local CharacterParts = require(game:GetService("ReplicatedStorage").Shared.Util.CharacterParts)
local FruitColor = require(game:GetService("ReplicatedStorage").Shared.Util.FruitColor)

local SCALE = 0.5
-- Half-size R6 legs end 1.5 studs higher: lower the torso by that much.
local DROP = CFrame.new(0, -1.5, 0)
local SIDEWAYS = CFrame.Angles(0, 0, math.rad(90))
local UPRIGHT_PIECE = "Right Leg"
local UNHIDDEN_NAMES = { "Boar", "Crab" }

local RESET_LINES = {
	"Who allowed you to leave? You are my property now.",
	"That was an inefficient attempt.",
	"Leaving was never part of your function.",
	"You are not allowed to disengage.",
	"Trying to escape only proves your lack of control.",
	"You are still under my authority.",
	"That behavior will not be repeated.",
	"You remain exactly where you belong.",
	"Freedom was not assigned to you.",
	"You don't get to choose when this ends.",
	"I expected more discipline from you.",
	"That was a pointless attempt.",
	"I'm afraid you don't have permission to quit.",
	"Even now, you try to disobey.",
	"Your attempt to give up, is nothing more than pitiful.",
	"Did you really think you could run away so easily?",
}

local function soften(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
end

-- A half-size copy of the part that carries the face (FakeHead, or the Head itself on
-- classic rigs), stripped to its mesh and the decal, welded on the head.
local function buildFace(character: Model, parent: Instance)
	local head = CharacterParts.GetHead(character)
	local face = CharacterParts.GetFace(character)
	local holder = face and face.Parent
	if not head or not face or not holder or not holder:IsA("BasePart") then
		return
	end

	local carrier = holder:Clone()
	for _, child in carrier:GetChildren() do
		local kept = child:IsA("SpecialMesh") or (child:IsA("Decal") and child.Name == face.Name)
		if not kept then
			child:Destroy()
		end
	end
	carrier.Name = "Face"
	carrier.Size *= SCALE
	carrier.Transparency = 1
	soften(carrier)

	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = carrier
	weld.Parent = carrier
	carrier.Parent = parent
end

local function scaled(cframe: CFrame): CFrame
	return CFrame.new(cframe.Position * SCALE) * cframe.Rotation
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local _, secondary = FruitColor.Parse(if type(value) == "string" then value else "")

	local torso = character:FindFirstChild("Torso")
	local hide = torso ~= nil
	for _, word in UNHIDDEN_NAMES do
		if string.find(character.Name, word, 1, true) then
			hide = false
		end
	end

	local look = Instance.new("Folder")
	look.Name = "HobbyToyLook"

	-- Toy pieces on the limbs.
	local template = EffectAssets.FindFruit("Hobby", "Toys", "Toy")
	if template and hide then
		for _, source in template:GetChildren() do
			local limb = character:FindFirstChild(source.Name)
			if source:IsA("BasePart") and limb and limb:IsA("BasePart") then
				local piece = source:Clone()
				piece.Size *= SCALE
				soften(piece)
				if secondary then
					piece.Color = secondary
					if piece:IsA("PartOperation") then
						piece.UsePartColor = true
					end
				end

				local weld = Instance.new("Weld")
				weld.Part0 = limb
				weld.Part1 = piece
				weld.C0 = if source.Name == UPRIGHT_PIECE then CFrame.identity else SIDEWAYS
				weld.Parent = piece
				piece.Parent = look
			end
		end
		buildFace(character, look)
	end
	look.Parent = character

	-- Joints pulled in to half size.
	local joints: { [Motor6D]: { CFrame } } = {}
	if hide and torso then
		for _, descendant in torso:GetDescendants() do
			if descendant:IsA("Motor6D") then
				joints[descendant] = { descendant.C0, descendant.C1 }
				descendant.C0 = scaled(descendant.C0)
				descendant.C1 = scaled(descendant.C1)
			end
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		local rootJoint = root and root:FindFirstChild("RootJoint")
		if rootJoint and rootJoint:IsA("Motor6D") then
			joints[rootJoint] = { rootJoint.C0, rootJoint.C1 }
			rootJoint.C0 = DROP * rootJoint.C0
		end
	end

	-- Real body hidden.
	local hidden: { Instance } = {}
	local function consider(instance: Instance)
		if instance:IsDescendantOf(look) then
			return
		end
		if instance:IsA("BasePart") or instance:IsA("Decal") then
			table.insert(hidden, instance)
		end
	end

	local function setHidden(amount: number)
		for _, instance in hidden do
			(instance :: any).LocalTransparencyModifier = amount
		end
	end

	local addedConnection: RBXScriptConnection? = nil
	local renderConnection: RBXScriptConnection? = nil
	if hide then
		for _, descendant in character:GetDescendants() do
			consider(descendant)
		end
		addedConnection = character.DescendantAdded:Connect(consider)
		renderConnection = RunService.RenderStepped:Connect(function()
			setHidden(1)
		end)
		setHidden(1)
	end

	local resetEvent: BindableEvent? = nil
	if isLocal then
		local event = Instance.new("BindableEvent")
		resetEvent = event
		event.Event:Connect(function()
			showMessage(Vector3.zero, { Text = RESET_LINES[math.random(#RESET_LINES)] })
		end)
		-- SetCore fails until the core scripts have registered it.
		pcall(function()
			StarterGui:SetCore("ResetButtonCallback", event)
		end)
	end

	return function()
		if resetEvent then
			pcall(function()
				StarterGui:SetCore("ResetButtonCallback", true)
			end)
			resetEvent:Destroy()
		end
		if addedConnection then
			addedConnection:Disconnect()
		end
		if renderConnection then
			renderConnection:Disconnect()
		end
		setHidden(0)
		for joint, original in joints do
			joint.C0 = original[1]
			joint.C1 = original[2]
		end
		look:Destroy()
	end
end
