--!strict
--[[
	Smoke fruit - Whiteout Burst, while the key is held.
	Status value: "<R or L>|<fruit colors>": the leg that will stomp.

	Everyone: smoke gathering under that foot and the looping hiss.
	Template: ReplicatedStorage.Assets.Models.Fruits.Smoke.Power4.SmokeCharge (ParticleEmitter).

	Owner only: the character keeps facing the mouse, as the legacy script did. The stomp
	itself (animation and cloud) belongs to the SmokeWhiteoutBurst one-shot effect.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local RENDER_STEP_NAME = "SmokeWhiteoutBurstFacing"
local FOOT_OFFSET = CFrame.new(0, -1, 0)

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local leg = character:FindFirstChild(if fields[1] == "R" then "Right Leg" else "Left Leg")

	local attachment: Attachment? = nil
	if leg and leg:IsA("BasePart") then
		local created = Instance.new("Attachment")
		created.Name = "SmokeCharge"
		created.CFrame = FOOT_OFFSET
		created.Parent = leg
		attachment = created

		local template = EffectAssets.FindFruit("Smoke", "Power4", "SmokeCharge")
		if template and template:IsA("ParticleEmitter") then
			local emitter = template:Clone()
			local primary, secondary = FruitColor.Parse(fields[2] or "")
			if primary and secondary then
				emitter.Color = FruitColor.ToSequence(primary, secondary)
			end
			emitter.Parent = created
		end

		local definition = (SoundConfig :: any).SFX.Elemental.Smoke["Smoke Loop"]
		if definition then
			local sound = Instance.new("Sound")
			sound.SoundId = definition.Id
			sound.Volume = definition.Volume
			sound.Looped = true
			sound.PlaybackSpeed = definition.Speed or 1
			sound.Parent = created
			sound:Play()
		end
	end

	local facing = false
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if isLocal and foundHumanoid and foundRoot and foundRoot:IsA("BasePart") then
		-- Typed copies: the closure below cannot rely on the narrowing above.
		local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot
		local mouse = Players.LocalPlayer:GetMouse()
		facing = true
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
	end

	return function()
		if facing then
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		end
		if attachment then
			attachment:Destroy()
		end
	end
end
