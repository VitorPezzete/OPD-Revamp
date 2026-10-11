--!strict
--[[
	Local side of Dash and Shave.

	Both are requests: the Dash / Shave actions of InputController send the aimed point
	to MovementService, which answers only when it accepts. The checks made here (level,
	cooldown, sitting, blocking statuses) exist to avoid pointless requests; the server
	repeats all of them.

	Dash: the server answers with a direction, a speed and the cooldown, and this client
	pushes its own character for MovementConfig.Dash.Duration seconds and plays the dash
	animation (the Animator replicates it). The legacy server parented a BodyVelocity to
	the root of a character it did not simulate, and loaded the animation on the server.

	Shave: the server moves the character itself; only the cooldown comes back.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)

type Technique = "Dash" | "Shave"

local DASH = MovementConfig.Dash
local SHAVE = MovementConfig.Shave

-- Minimum time between two requests of the same technique while waiting for an answer.
local REQUEST_INTERVAL = 0.25
local PUSH_FORCE = 1e6
local PUSH_NAME = "DashPush"
local ANIMATION_FADE = 0.1

local DashController = Knit.CreateController({
	Name = "DashController",
})

local DataController
local InputController
local MovementService

local localPlayer = Players.LocalPlayer
local readyAt: { [Technique]: number } = { Dash = 0, Shave = 0 }
local lastRequest: { [Technique]: number } = { Dash = 0, Shave = 0 }

local function getCharacter(): (Model?, Humanoid?, BasePart?)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function hasAny(character: Model, statuses: { string }): boolean
	for _, status in statuses do
		local value = character:GetAttribute(status)
		if value ~= nil and value ~= false then
			return true
		end
	end
	return false
end

local function canRequest(technique: Technique, requirement: number): boolean
	local now = os.clock()
	if now < readyAt[technique] or now - lastRequest[technique] < REQUEST_INTERVAL then
		return false
	end
	if (DataController:Get("Skills.Melee.Level") or 0) < requirement then
		return false
	end

	local character, humanoid = getCharacter()
	if not character or not humanoid or humanoid.Health <= 0 or humanoid.Sit then
		return false
	end
	if character:GetAttribute("Spawned") ~= true or hasAny(character, MovementConfig.BlockingStatuses) then
		return false
	end
	if technique == "Shave" and hasAny(character, MovementConfig.SlowingStatuses) then
		return false
	end

	lastRequest[technique] = now
	return true
end

local function playDashAnimation(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	-- Loaded (and downloaded) ahead of time by AnimationController.
	local playing = Animations.Play(animator, AnimationConfig.Dash, ANIMATION_FADE)
	-- The legacy clip is cut at half a second whatever its length.
	task.delay(DASH.AnimationSeconds, function()
		playing:Stop(ANIMATION_FADE)
	end)
end

local function push(direction: Vector3, speed: number)
	local _, humanoid, root = getCharacter()
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local previous = root:FindFirstChild(PUSH_NAME)
	if previous then
		previous:Destroy()
	end

	-- Face where the dash goes, upright: the legacy code tilted the whole root toward
	-- the aimed point.
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = PUSH_NAME
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.MaxForce = PUSH_FORCE
	velocity.VectorVelocity = direction * speed
	velocity.Parent = attachment

	Debris:AddItem(attachment, DASH.Duration)
	playDashAnimation(humanoid)
end

local function onDashed(direction: unknown, speed: unknown, cooldown: unknown)
	if typeof(direction) ~= "Vector3" or type(speed) ~= "number" or type(cooldown) ~= "number" then
		return
	end

	local unit = direction :: Vector3
	if unit.Magnitude < 0.5 or unit.Magnitude > 1.5 or speed ~= speed then
		return
	end

	readyAt.Dash = os.clock() + cooldown
	push(unit.Unit, math.clamp(speed, 0, DASH.Float.Max))
end

local function onShaved(cooldown: unknown)
	if type(cooldown) == "number" then
		readyAt.Shave = os.clock() + cooldown
	end
end

-- Seconds until the technique can be requested again (0 when ready), for HUD elements.
function DashController:GetCooldown(technique: Technique): number
	return math.max(0, readyAt[technique] - os.clock())
end

function DashController:KnitInit()
	DataController = Knit.GetController("DataController")
	InputController = Knit.GetController("InputController")
end

function DashController:KnitStart()
	MovementService = Knit.GetService("MovementService")

	MovementService.Dashed:Connect(onDashed)
	MovementService.Shaved:Connect(onShaved)

	InputController:OnAction("Dash", function(phase: string)
		if phase == "Begin" and canRequest("Dash", DASH.Requirement) then
			MovementService.Dash:Fire(InputController:GetAimPosition())
		end
	end)
	InputController:OnAction("Shave", function(phase: string)
		if phase == "Begin" and canRequest("Shave", SHAVE.Requirement) then
			MovementService.Shave:Fire(InputController:GetAimPosition())
		end
	end)
end

return DashController
