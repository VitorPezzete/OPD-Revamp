--!strict
--[[
	Slip fruit trail: one emitter under each foot while the status is active.
	The status value is the fruit's saved color string ("None" keeps a white trail).
	Template: Assets.Models.Fruits.Slip.Power1.Slip (ParticleEmitter, the legacy
	ServerStorage.Powers.Slip.Power1.Slip); Assets.Particles.Slip is the older location.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LEGS = { "Left Leg", "Right Leg" }
local FOOT_OFFSET = CFrame.new(0, -1, 0)
local DEFAULT_COLORS = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 200))

local function noop() end

return function(character: Model, value: any): () -> ()
	local template = EffectAssets.FindFruit("Slip", "Power1", "Slip") or EffectAssets.Find("Particles", "Slip")
	if not template or not template:IsA("ParticleEmitter") then
		return noop
	end

	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
	local colors = if primary and secondary then FruitColor.ToSequence(primary, secondary) else DEFAULT_COLORS

	local attachments: { Attachment } = {}
	for _, legName in LEGS do
		local leg = character:FindFirstChild(legName)
		if leg and leg:IsA("BasePart") then
			local attachment = Instance.new("Attachment")
			attachment.Name = "SlipTrail"
			attachment.CFrame = FOOT_OFFSET

			local emitter = template:Clone()
			emitter.Color = colors
			emitter.Enabled = true
			emitter.Parent = attachment

			attachment.Parent = leg
			table.insert(attachments, attachment)
		end
	end

	return function()
		for _, attachment in attachments do
			attachment:Destroy()
		end
	end
end
