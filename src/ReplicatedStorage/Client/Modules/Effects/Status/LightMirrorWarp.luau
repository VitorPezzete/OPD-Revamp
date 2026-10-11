--!strict
--[[
	Light fruit - Yata Mirror, the 0.65 s after the user reappears at the end of the ray:
	the owner hangs where it arrived (the legacy zero-velocity BodyVelocity, even in
	mid-air) and plays one of the four arrival poses very fast. Status value: true; the
	server removes the status when the time is up.

	Owner only: movement and animation of a character are simulated by its own client
	and replicate from there.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

local POSES = {
	AnimationConfig.FruitAnims.CloneAttack1,
	AnimationConfig.FruitAnims.CloneAttack2,
	AnimationConfig.FruitAnims.CloneAttack3,
	AnimationConfig.FruitAnims.CloneAttack4,
}
local POSE_SPEED = 30
-- The legacy "Noclip" mover: zero velocity, default P, held for the 0.65 s.
local HOLD_FORCE = Vector3.new(100000, 100000, 100000)

local function noop() end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local hold: BodyVelocity? = nil
	if root and root:IsA("BasePart") then
		local mover = Instance.new("BodyVelocity")
		mover.Name = "LightMirrorHold"
		mover.MaxForce = HOLD_FORCE
		mover.Velocity = Vector3.zero
		mover.Parent = root
		hold = mover
	end

	local track: AnimationTrack? = nil
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local loaded = Animations.Get(animator, POSES[math.random(1, #POSES)])
		loaded:Play(0.1, 1, POSE_SPEED)
		track = loaded
	end

	return function()
		if hold then
			hold:Destroy()
		end

		if track then
			track:Stop(0.1)
		end
	end
end
