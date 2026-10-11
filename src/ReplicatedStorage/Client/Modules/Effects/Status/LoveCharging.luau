--!strict
--[[
	Love fruit - Beam / Slave Arrow / Arrow Storm from the key press until the last shot
	of the salvo has left: a heart outline pops up in front of the chest (above the
	shoulder for Arrow Storm). The owner's character also faces the mouse and holds the
	charge pose of the power; the pose replicates through the Animator. The release
	animation belongs to the LoveRelease one-shot, so an interrupted charge just stops.

	Status value: "<Beam | Arrow | Storm>|<fruit colors>|<scale>" where scale is
	sniper affinity * (sniper level / cap).
	Templates: ReplicatedStorage.Assets.Models.Fruits.Love.Power4.LoveHeartTrim (Beam) and
	Love.Power5.LoveHeartTrim (arrows): a MeshPart with a LoveHeartTrimFill child.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

type Kind = { Folder: string, Size: Vector3, Offset: CFrame, WindUp: string, Held: string }

-- Sizes and offsets of the legacy charge hearts (size is multiplied by scale).
local KINDS: { [string]: Kind } = {
	Beam = {
		Folder = "Power4",
		Size = Vector3.new(0.9315, 0.861, 0.136),
		Offset = CFrame.new(0, 0.55, -2),
		WindUp = AnimationConfig.FruitAnims.LoveBeamCharge,
		Held = AnimationConfig.FruitAnims.LoveBeamCharged,
	},
	Arrow = {
		Folder = "Power5",
		Size = Vector3.new(4.747, 4.387, 0.693),
		Offset = CFrame.new(0, 0.55, -2),
		WindUp = AnimationConfig.FruitAnims.SArrowCharge,
		Held = AnimationConfig.FruitAnims.SArrowCharged,
	},
	Storm = {
		Folder = "Power5",
		Size = Vector3.new(4.747, 4.387, 0.693),
		-- The legacy weld passed degrees to CFrame.Angles (an arbitrary tilt); the heart is
		-- laid flat above the shoulder instead, facing the sky the arrows leave for.
		Offset = CFrame.new(-0.5, 2.5, -1.75) * CFrame.Angles(math.rad(-90), 0, 0),
		WindUp = AnimationConfig.FruitAnims.S2ArrowCharge,
		Held = AnimationConfig.FruitAnims.S2ArrowCharged,
	},
}
local START_SIZE = Vector3.new(0.1, 0.1, 0.1)
-- The heart is at its full size a quarter of a second after the key press.
local GROW_TIME = 0.25
local FILL_NAME = "LoveHeartTrimFill"

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local kind = KINDS[fields[1] or ""] or KINDS.Beam
	local primary = FruitColor.Parse(fields[2] or "")
	local scale = math.max(tonumber(fields[3]) or 1, 0.05)

	local heart: BasePart? = nil
	local torso = character:FindFirstChild("Torso")
	local template = EffectAssets.FindFruit("Love", kind.Folder, "LoveHeartTrim")
	if torso and torso:IsA("BasePart") and template and template:IsA("BasePart") then
		local clone = template:Clone()
		local parts: { BasePart } = { clone }
		local fill = clone:FindFirstChild(FILL_NAME)
		if fill and fill:IsA("BasePart") then
			table.insert(parts, fill)
		end

		local tweenInfo = TweenInfo.new(GROW_TIME, Enum.EasingStyle.Linear)
		for _, part in parts do
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.Size = START_SIZE
			if primary then
				part.Color = primary
			end
			TweenService:Create(part, tweenInfo, { Size = kind.Size * scale }):Play()
		end

		local weld = Instance.new("Weld")
		weld.Part0 = torso
		weld.Part1 = clone
		weld.C0 = kind.Offset
		weld.Parent = clone

		clone.Parent = torso
		heart = clone
	end

	local active = true
	local connection: RBXScriptConnection? = nil
	local stoppedConnection: RBXScriptConnection? = nil
	local tracks: { AnimationTrack } = {}
	if isLocal then
		local mouse = Players.LocalPlayer:GetMouse()
		connection = RunService.RenderStepped:Connect(function()
			local root = character.PrimaryPart
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or humanoid.Sit then
				return
			end

			local hit = mouse.Hit.Position
			local target = Vector3.new(hit.X, root.Position.Y, hit.Z)
			if (target - root.Position).Magnitude > 0.5 then
				root.CFrame = CFrame.lookAt(root.Position, target)
			end
		end)

		local animator = Animations.FindAnimator(character)
		if animator then
			local windUp = Animations.Get(animator, kind.WindUp)
			local held = Animations.Get(animator, kind.Held)
			tracks = { windUp, held }
			stoppedConnection = windUp.Stopped:Connect(function()
				if active then
					held:Play()
				end
			end)
			windUp:Play()
		end
	end

	return function()
		active = false
		if connection then
			connection:Disconnect()
		end
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end
		if heart then
			heart:Destroy()
		end
	end
end
