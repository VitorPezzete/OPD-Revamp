--!strict
--[[
	Hobby fruit - a toy soldier made by Claim (HobbyClaimed status on the NPC; the value
	is the Hobby user's fruit color string).

	Its "ToyParts" are painted with the fruit's second color when the user has custom
	colors; otherwise the model keeps its own.

	The legacy soldier carried the stock R6 Animate script; its clips are still in the
	model (idle.Animation1, walk.WalkAnim). The server plays no visuals, so every client
	plays them here: idle while it stands, the walk (at speed / 14.5, as Animate did)
	while an order moves it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local IDLE_FALLBACK = "http://www.roblox.com/asset/?id=180435571"
local WALK_FALLBACK = "http://www.roblox.com/asset/?id=180426354"
local WALK_THRESHOLD = 0.75
local WALK_REFERENCE_SPEED = 14.5
local FADE = 0.1

local function findClip(character: Model, holderName: string, clipName: string, fallback: string): string
	local holder = character:FindFirstChild(holderName)
	local clip = holder and holder:FindFirstChild(clipName)
	if clip and clip:IsA("Animation") and clip.AnimationId ~= "" then
		return clip.AnimationId
	end
	return fallback
end

local function paint(character: Model, value: any): { [BasePart]: Color3 }
	local authored: { [BasePart]: Color3 } = {}
	local _, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
	local parts = character:FindFirstChild("ToyParts")
	if not secondary or not parts then
		return authored
	end

	for _, part in parts:GetChildren() do
		if part:IsA("BasePart") then
			authored[part] = part.Color
			part.Color = secondary
			if part:IsA("PartOperation") then
				part.UsePartColor = true
			end
		end
	end
	return authored
end

return function(character: Model, value: any): () -> ()
	local authored = paint(character, value)

	local connection: RBXScriptConnection? = nil
	local tracks: { AnimationTrack } = {}

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			local created = Instance.new("Animator")
			created.Parent = humanoid
			animator = created
		end

		local idle = Animations.Get(animator :: Animator, findClip(character, "idle", "Animation1", IDLE_FALLBACK))
		local walk = Animations.Get(animator :: Animator, findClip(character, "walk", "WalkAnim", WALK_FALLBACK))
		idle.Looped = true
		idle.Priority = Enum.AnimationPriority.Idle
		walk.Looped = true
		walk.Priority = Enum.AnimationPriority.Movement
		tracks = { idle, walk }
		idle:Play(FADE)

		local walking = false
		connection = RunService.Heartbeat:Connect(function()
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local moving = speed > WALK_THRESHOLD
			if moving then
				walk:AdjustSpeed(speed / WALK_REFERENCE_SPEED)
			end
			if moving == walking then
				return
			end

			walking = moving
			if moving then
				idle:Stop(FADE)
				walk:Play(FADE)
			else
				walk:Stop(FADE)
				idle:Play(FADE)
			end
		end)
	end

	return function()
		if connection then
			connection:Disconnect()
		end
		for _, track in tracks do
			track:Stop(FADE)
		end
		for part, color in authored do
			part.Color = color
		end
	end
end
