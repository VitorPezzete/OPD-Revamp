--!strict
--[[
	Float fruit hover, simulated by the owner (the client that owns the character's
	physics). Other clients see the result through normal replication and build nothing.

	Rise at 50 studs/s for 0.4 s, then hold the height: horizontal velocity follows the
	move direction at walk speed, vertical velocity is 50 while the FloatAscending
	attribute is set (Ascend held) and 0 otherwise. The character faces where it moves.
]]
local RunService = game:GetService("RunService")

local ASCENDING = "FloatAscending"
local RISE_SPEED = 50
local RISE_TIME = 0.4
local MAX_FORCE = 999999

local function noop() end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not foundHumanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return noop
	end
	local humanoid: Humanoid = foundHumanoid
	local root: BasePart = foundRoot

	local attachment = Instance.new("Attachment")
	attachment.Name = "FloatAttachment"
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "FloatVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = MAX_FORCE
	velocity.VectorVelocity = Vector3.new(0, RISE_SPEED, 0)
	velocity.Parent = root

	local orientation = Instance.new("AlignOrientation")
	orientation.Name = "FloatOrientation"
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = attachment
	orientation.MaxTorque = MAX_FORCE
	orientation.CFrame = root.CFrame.Rotation
	orientation.Parent = root

	local startedAt = os.clock()
	local connection = RunService.Heartbeat:Connect(function()
		if os.clock() - startedAt < RISE_TIME then
			return
		end

		local move = humanoid.MoveDirection
		local speed = humanoid.WalkSpeed
		local vertical = if character:GetAttribute(ASCENDING) == true then RISE_SPEED else 0
		velocity.VectorVelocity = Vector3.new(move.X * speed, vertical, move.Z * speed)

		if move.Magnitude > 0.1 then
			orientation.CFrame = CFrame.lookAt(Vector3.zero, move)
		end
	end)

	return function()
		connection:Disconnect()
		velocity:Destroy()
		orientation:Destroy()
		attachment:Destroy()
	end
end
