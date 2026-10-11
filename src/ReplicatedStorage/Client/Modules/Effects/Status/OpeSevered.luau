--!strict
--[[
	Ope fruit - Severance: the victim's arms and legs come off and float around it
	until the status ends. The server only stuns the victim; nothing here touches the
	real joints (the legacy destroyed and rebuilt the shoulder and hip Motor6Ds on the
	server).

	Each limb is hidden with the local transparency modifier (reapplied every frame,
	since the camera scripts rewrite it on the local character) and replaced by an
	anchored copy that drifts 1-5 studs away, slowly turning, as the legacy
	BodyPosition / BodyAngularVelocity pair did. Cleanup removes the copies and shows
	the limbs again, so nothing can stay detached.

	The victim's own client also holds its body where it was cut (platform stand plus a
	position and orientation hold on the root, the legacy BodyPosition / BodyGyro on the
	torso), so a victim caught in the air hangs there. A server teleport (Shambles swap)
	moves the hold with it.

	R6 limb names; a character without them simply shows nothing.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Limp = require(ReplicatedStorage.Client.Modules.Effects.Util.Limp)
local World = require(ReplicatedStorage.Shared.Util.World)

local LIMBS = { "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local DRIFT_SPEED = 4
local SPIN = Vector3.new(1, 1, 1)
local HOLD_FORCE = 1e5
local HOLD_RESPONSIVENESS = 100
-- Further than this from the hold in one frame: the server moved the character.
local TELEPORT_DISTANCE = 8

type Piece = {
	Limb: BasePart,
	Copy: BasePart,
	Goal: Vector3,
}

local function noop() end

local function setHidden(limb: BasePart, amount: number)
	limb.LocalTransparencyModifier = amount
	for _, descendant in limb:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			(descendant :: any).LocalTransparencyModifier = amount
		end
	end
end

-- Pins the local character in place. Returns the per-frame update and the release.
local function hold(character: Model): ((() -> ())?, (() -> ())?)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local found = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not rootPart:IsA("BasePart") or not found then
		return nil, nil
	end
	local root: BasePart = rootPart
	local humanoid: Humanoid = found

	local attachment = Instance.new("Attachment")
	attachment.Name = "OpeSeveredHold"
	attachment.Parent = root

	local position = Instance.new("AlignPosition")
	position.Mode = Enum.PositionAlignmentMode.OneAttachment
	position.Attachment0 = attachment
	position.Position = root.Position
	position.MaxForce = HOLD_FORCE
	position.Responsiveness = HOLD_RESPONSIVENESS
	position.Parent = attachment

	local orientation = Instance.new("AlignOrientation")
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = attachment
	orientation.CFrame = root.CFrame.Rotation
	orientation.MaxTorque = HOLD_FORCE
	orientation.Responsiveness = HOLD_RESPONSIVENESS
	orientation.Parent = attachment

	-- Counted: another status may hold the character limp at the same time.
	local stand = Limp.hold(humanoid)

	local function update()
		if (root.Position - position.Position).Magnitude > TELEPORT_DISTANCE then
			position.Position = root.Position
			orientation.CFrame = root.CFrame.Rotation
		end
	end

	local function release()
		attachment:Destroy()
		stand()
	end

	return update, release
end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	local pieces: { Piece } = {}
	local random = Random.new()

	for _, limbName in LIMBS do
		local limb = character:FindFirstChild(limbName)
		if not limb or not limb:IsA("BasePart") then
			continue
		end

		local copy = limb:Clone()
		for _, descendant in copy:GetDescendants() do
			if
				descendant:IsA("JointInstance")
				or descendant:IsA("WeldConstraint")
				or descendant:IsA("LuaSourceContainer")
				or descendant:IsA("BasePart")
			then
				descendant:Destroy()
			end
		end
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CFrame = limb.CFrame
		copy.Parent = World.Effects()

		table.insert(pieces, {
			Limb = limb,
			Copy = copy,
			Goal = limb.Position
				+ Vector3.new(random:NextInteger(1, 3), random:NextInteger(1, 3), random:NextInteger(1, 5)),
		})
		setHidden(limb, 1)
	end

	local updateHold: (() -> ())?, releaseHold: (() -> ())? = nil, nil
	if isLocal then
		updateHold, releaseHold = hold(character)
	end

	if #pieces == 0 and not releaseHold then
		return noop
	end

	local connection = RunService.RenderStepped:Connect(function(deltaTime: number)
		if updateHold then
			updateHold()
		end
		local alpha = math.clamp(DRIFT_SPEED * deltaTime, 0, 1)
		for _, piece in pieces do
			setHidden(piece.Limb, 1)
			local copy = piece.Copy
			local position = copy.Position:Lerp(piece.Goal, alpha)
			copy.CFrame = CFrame.new(position)
				* copy.CFrame.Rotation
				* CFrame.Angles(SPIN.X * deltaTime, SPIN.Y * deltaTime, SPIN.Z * deltaTime)
		end
	end)

	return function()
		connection:Disconnect()
		if releaseHold then
			releaseHold()
		end
		for _, piece in pieces do
			piece.Copy:Destroy()
			if piece.Limb.Parent then
				setHidden(piece.Limb, 0)
			end
		end
	end
end
