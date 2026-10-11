--!strict
--[[
	Smoke fruit - Whiteout Burst: a character choking on the smoke. The status is set by
	Whiteout Burst next to its suffocation DoT, for as long as it ticks.
	Status value: the caster's fruit color string.

	Smoke around the face and a cough every second (the legacy tick rate).
	Template: ReplicatedStorage.Assets.Models.Fruits.Smoke.Power4.Suffocating (ParticleEmitter).

	The smoke takes the caster's fruit colors, as in the legacy game.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local FACE_OFFSET = CFrame.new(0, -0.25, -0.5)
local COUGH_INTERVAL = 1

local function noop() end

return function(character: Model, value: any, _isLocal: boolean): () -> ()
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return noop
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "SmokeSuffocating"
	attachment.CFrame = FACE_OFFSET
	attachment.Parent = head

	local template = EffectAssets.FindFruit("Smoke", "Power4", "Suffocating")
	if template and template:IsA("ParticleEmitter") then
		local emitter = template:Clone()
		local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
		if primary and secondary then
			emitter.Color = FruitColor.ToSequence(primary, secondary)
		end
		emitter.Parent = attachment
	end

	local active = true
	local definition = (SoundConfig :: any).SFX["To-Organize"].Cough
	if definition then
		task.spawn(function()
			while active do
				local sound = Instance.new("Sound")
				sound.SoundId = definition.Id
				sound.Volume = definition.Volume
				sound.PlaybackSpeed = definition.Speed or 1
				sound.Parent = attachment
				sound:Play()
				Debris:AddItem(sound, COUGH_INTERVAL)
				task.wait(COUGH_INTERVAL)
			end
		end)
	end

	return function()
		active = false
		attachment:Destroy()
	end
end
