--!strict
--[[
	Sand fruit - Sandstorm: a character tied to a storm (3 seconds, timed by the server;
	the storm's next tick ties it again while it is still inside).
	Status value: "<x>|<y>|<z>|<vx>|<vy>|<vz>|<server time>": the storm's pull point at
	that server time and its drift in studs per second.

	Victim only: the legacy storm tied each victim's root to itself with an invisible
	1 stud RopeConstraint. Players simulate their own character, so the rope is built
	here: an anchored point that follows the storm's path and a 1 stud rope to the root,
	taut from the first instant as the legacy one was (the victim is snatched in). Everyone else sees the victim dragged through
	replication; NPC victims are pulled by the server instead.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local ROPE_LENGTH = 1

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local fields = EffectAssets.Unpack(value)
	local x, y, z = tonumber(fields[1]), tonumber(fields[2]), tonumber(fields[3])
	local vx, vy, vz = tonumber(fields[4]), tonumber(fields[5]), tonumber(fields[6])
	local started = tonumber(fields[7])
	local root = character:FindFirstChild("HumanoidRootPart")
	if not x or not y or not z or not vx or not vy or not vz or not started or not root or not root:IsA("BasePart") then
		return noop
	end
	local origin = Vector3.new(x, y, z)
	local velocity = Vector3.new(vx, vy, vz)

	local function pullPoint(): CFrame
		return CFrame.new(origin + velocity * (Workspace:GetServerTimeNow() - started))
	end

	local anchor = Instance.new("Part")
	anchor.Name = "SandRopeAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = pullPoint()

	local anchorAttachment = Instance.new("Attachment")
	anchorAttachment.Parent = anchor
	local rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "SandRope"
	rootAttachment.Parent = root

	local rope = Instance.new("RopeConstraint")
	rope.Name = "SandPullRope"
	rope.Visible = false
	rope.Attachment0 = rootAttachment
	rope.Attachment1 = anchorAttachment
	rope.Length = ROPE_LENGTH
	rope.Parent = anchor
	anchor.Parent = World.Effects()

	local connection = RunService.Heartbeat:Connect(function()
		anchor.CFrame = pullPoint()
	end)

	return function()
		connection:Disconnect()
		rootAttachment:Destroy()
		anchor:Destroy()
	end
end
