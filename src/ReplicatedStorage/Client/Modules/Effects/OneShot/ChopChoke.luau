--!strict
--[[
	Chop fruit - Chop Choke: the detached left arm flying to the target's head and
	holding on to it.
	params: { Target: Model, Speed: number }   (plus Caster, added by the server)
	Template: ReplicatedStorage.Assets.Models.Fruits.Chop.Power1.Power1, an invisible
	handle. The legacy server welded the real arm to it; here an anchored copy of the
	caster's arm (its color and shells, not its sleeve) rides it with the same weld offset.

	Purely cosmetic and anchored: it follows the same rule as the server's simulated arm
	(home on the head at Speed, grab within 5 studs, hold 2 s). The server stays the
	judge of the hit, so the two can be a moment apart. The arm disappears as soon as the
	caster's "ChopChoke" status is cleared (interrupt, death, timeout).
]]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local STATUS = "ChopChoke"
local LIMB = "Left Arm"
local HIT_DISTANCE = 5
local HOLD_SECONDS = 2
local HOLD_OFFSET = CFrame.new(0, -1, -1)
local MAX_LIFETIME = 16
-- The effect can arrive before the status attribute does; wait this long for it.
local STATUS_GRACE = 1

-- The template is welded on the real arm with this C0 (its look direction is the hand).
local DEFAULT_GRIP = CFrame.new(0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -1, 0)

-- An anchored copy of the caster's arm as it looks now (color, haki shell), without joints.
local function cloneLimb(limb: BasePart): BasePart
	local copy = limb:Clone()
	for _, descendant in copy:GetDescendants() do
		if
			descendant:IsA("JointInstance")
			or descendant:IsA("WeldConstraint")
			or descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Attachment")
		then
			descendant:Destroy()
		end
	end
	for _, part in { copy :: Instance, table.unpack(copy:GetDescendants()) } do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.LocalTransparencyModifier = 0
		end
	end
	return copy
end

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

return function(origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	local target = params and params.Target
	local speed = params and params.Speed
	if typeof(caster) ~= "Instance" or typeof(target) ~= "Instance" or type(speed) ~= "number" or speed <= 0 then
		return
	end

	local template = findAsset("Models", "Fruits", "Chop", "Power1", "Power1")
	if not template or not template:IsA("BasePart") then
		return
	end

	-- The template's own weld to the caster's arm has no Part0, so it is inert here.
	local arm = template:Clone()
	for _, descendant in arm:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	arm.Anchored = true
	arm.CanCollide = false
	arm.CanQuery = false
	arm.CanTouch = false

	local limb = caster:FindFirstChild(LIMB)
	arm.CFrame = if limb and limb:IsA("BasePart") then limb.CFrame else CFrame.new(origin)
	arm.Parent = World.Effects()

	-- The template itself is invisible: in the legacy game the real arm was welded to it.
	local grip = arm:FindFirstChildOfClass("ManualWeld")
	local limbOffset = (if grip then grip.C0 else DEFAULT_GRIP):Inverse()
	local visual: BasePart? = nil
	if limb and limb:IsA("BasePart") then
		local copy = cloneLimb(limb)
		copy:PivotTo(arm.CFrame * limbOffset)
		copy.Parent = World.Effects()
		visual = copy
	end
	local function place(cframe: CFrame)
		arm.CFrame = cframe
		if visual then
			visual:PivotTo(cframe * limbOffset)
		end
	end

	local elapsed = 0
	local statusSeen = false
	local heldSince: number? = nil
	local connection: RBXScriptConnection

	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime

		local statusSet = caster:GetAttribute(STATUS) ~= nil
		statusSeen = statusSeen or statusSet

		local head = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
		local finished = elapsed > MAX_LIFETIME
			or (statusSeen and not statusSet)
			or (not statusSeen and elapsed > STATUS_GRACE)
			or caster.Parent == nil
			or target.Parent == nil
			or not head
			or not head:IsA("BasePart")
			or (heldSince ~= nil and elapsed - heldSince >= HOLD_SECONDS)
		if finished then
			connection:Disconnect()
			arm:Destroy()
			if visual then
				visual:Destroy()
			end
			return
		end

		local headPart = head :: BasePart
		if heldSince then
			place(headPart.CFrame * HOLD_OFFSET)
			return
		end

		local offset = headPart.Position - arm.Position
		local travel = speed * deltaTime
		if offset.Magnitude - travel <= HIT_DISTANCE then
			heldSince = elapsed
			place(headPart.CFrame * HOLD_OFFSET)
		else
			local position = arm.Position + offset.Unit * travel
			place(CFrame.lookAt(position, headPart.Position))
		end
	end)
end
