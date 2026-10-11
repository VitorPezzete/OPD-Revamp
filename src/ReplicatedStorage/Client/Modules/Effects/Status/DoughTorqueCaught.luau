--!strict
--[[
	Dough fruit - stuck on someone's Torque Mochi.
	Status value: the user id of the player spinning it.

	The source handed the victim's root to the attacker's client, which wrote its CFrame on
	the ball every frame. Ownership stays where it is now: the VICTIM's own client does that
	write, on its own character (`isLocal`), reading the ball its Effects.Status.DoughTorqueMochi
	draws for the attacker (the Head of the model "DoughTorqueArm_<user id>"). Everybody else
	sees it through ordinary replication. The result on screen is the source's: the victim
	rides the ball, 4.5 studs from its centre, at a random tilt picked when it was caught.
	NPC victims are carried by the server instead (Abilities/Dough/Torque Mochi).

	Nothing the server decides depends on this: being caught, sealed, damaged and launched
	are all server-side.

	When the status goes the character is stood upright where it is (the source's
	`CFrame.new(position)`), just before the server's upward push arrives.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local MODEL_PREFIX = "DoughTorqueArm_"
local BALL_NAME = "Head"
local BALL_DISTANCE = 4.5

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	if not isLocal or not root or not root:IsA("BasePart") then
		return noop
	end

	local modelName = MODEL_PREFIX .. tostring(value)
	local offset = CFrame.Angles(math.random(-360, 360), math.random(-360, 360), math.random(-360, 360))
		* CFrame.new(0, 0, -BALL_DISTANCE)

	local model: Instance? = nil
	local function findBall(): BasePart?
		if not model or not model.Parent then
			model = World.Effects():FindFirstChild(modelName) or Workspace:FindFirstChild(modelName)
		end
		local ball = model and model:FindFirstChild(BALL_NAME)
		return if ball and ball:IsA("BasePart") then ball else nil
	end

	local connection = RunService.RenderStepped:Connect(function()
		local ball = findBall()
		if not ball or not root.Parent then
			return
		end
		root.CFrame = ball.CFrame * offset
		-- Nothing accumulates while the character is being carried.
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)

	return function()
		connection:Disconnect()
		if root.Parent then
			root.CFrame = CFrame.new(root.Position)
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
end
