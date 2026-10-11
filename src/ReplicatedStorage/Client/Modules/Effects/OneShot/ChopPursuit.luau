--!strict
--[[
	Chop fruit - Chop Pursuit: the detached right arm, blades out, chasing the target.
	params: { Target: Model, ChaseSpeed: number, CloseSpeed: number }   (plus Caster)
	Template: ReplicatedStorage.Assets.Models.Fruits.Chop.Power2.Power2, an invisible
	handle with blade parts Sword1 / Sword2 / Sword3 (given the fruit's first color). The
	legacy server welded the real arm to it; here an anchored copy of the caster's arm
	(its color and shells, not its sleeve) rides it with the same weld offset.

	Purely cosmetic and anchored. It follows the same rule as the server's simulated arm:
	fly in a straight line, re-aim at the target every 0.5 s, crawl once within 5 studs.
	The server stays the judge of every cut. The arm disappears when the caster's
	"ChopPursuit" status is cleared (10 s elapsed, target dead, interrupt).
]]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local STATUS = "ChopPursuit"
local LIMB = "Right Arm"
local BLADES = { "Sword1", "Sword2", "Sword3" }
local HIT_DISTANCE = 5
local STEER_INTERVAL = 0.5
local MAX_LIFETIME = 11
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
	local chaseSpeed = params and params.ChaseSpeed
	local closeSpeed = params and params.CloseSpeed
	if
		typeof(caster) ~= "Instance"
		or typeof(target) ~= "Instance"
		or type(chaseSpeed) ~= "number"
		or type(closeSpeed) ~= "number"
	then
		return
	end

	local template = findAsset("Models", "Fruits", "Chop", "Power2", "Power2")
	if not template or not template:IsA("BasePart") then
		return
	end

	-- The template's own weld to the caster's arm has no Part0, so it is inert here;
	-- the welds holding the blades are left alone.
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

	local primary = FruitColor.Parse(if params and type(params.Colors) == "string" then params.Colors else "")
	if primary then
		for _, bladeName in BLADES do
			local blade = arm:FindFirstChild(bladeName)
			if blade and blade:IsA("BasePart") then
				blade.Color = primary
			end
		end
	end

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
	local velocity = Vector3.zero
	local nextSteer = 0
	local connection: RBXScriptConnection

	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime

		local statusSet = caster:GetAttribute(STATUS) ~= nil
		statusSeen = statusSeen or statusSet

		local root = target:FindFirstChild("HumanoidRootPart")
		local finished = elapsed > MAX_LIFETIME
			or (statusSeen and not statusSet)
			or (not statusSeen and elapsed > STATUS_GRACE)
			or caster.Parent == nil
			or target.Parent == nil
			or not root
			or not root:IsA("BasePart")
		if finished then
			connection:Disconnect()
			arm:Destroy()
			if visual then
				visual:Destroy()
			end
			return
		end

		local goal = (root :: BasePart).Position
		local position = arm.Position + velocity * deltaTime
		local offset = goal - position

		if elapsed >= nextSteer and offset.Magnitude > 0.001 then
			nextSteer = elapsed + STEER_INTERVAL
			velocity = offset.Unit * (if offset.Magnitude < HIT_DISTANCE then closeSpeed else chaseSpeed)
		end

		place(if offset.Magnitude > 0.001 then CFrame.lookAt(position, goal) else CFrame.new(position))
	end)
end
