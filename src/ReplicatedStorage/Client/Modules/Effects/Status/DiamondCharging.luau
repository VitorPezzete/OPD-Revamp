--!strict
--[[
	Diamond fruit - Diamond Cluster, while the owner holds the key: charge animation
	(wind-up clip, then the held clip) and the character turned towards the mouse.

	Only the owner runs anything: the animation replicates through the Animator and
	the facing through the character's own physics. The release animation is played by
	the DiamondCluster one-shot effect, so an interrupted charge just stops.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

local RENDER_STEP_NAME = "DiamondClusterFacing"

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
	-- Typed copies: the closures below cannot rely on the narrowing above.
	local humanoid: Humanoid = foundHumanoid
	local root: BasePart = foundRoot

	local active = true
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil

	local foundAnimator = humanoid:FindFirstChildOfClass("Animator")
	if foundAnimator then
		local animator: Animator = foundAnimator
		local function load(animationId: string): AnimationTrack
			local track = Animations.Get(animator, animationId)
			table.insert(tracks, track)
			return track
		end

		local windUp = load(AnimationConfig.FruitAnims.VenomHydraCharge)
		local held = load(AnimationConfig.FruitAnims.VenomHydraCharged)
		stoppedConnection = windUp.Stopped:Connect(function()
			if active then
				held:Play()
			end
		end)
		windUp:Play()
	end

	local mouse = Players.LocalPlayer:GetMouse()
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value, function()
		if humanoid.Sit then
			return
		end

		local position = root.Position
		local target = mouse.Hit.Position
		local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
		if flat.Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(position, position + flat)
		end
	end)

	return function()
		active = false
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end
	end
end
