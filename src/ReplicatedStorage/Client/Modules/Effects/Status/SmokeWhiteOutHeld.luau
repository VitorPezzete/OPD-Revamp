--!strict
--[[
	Smoke fruit - White Out: a character caught by the smoke (5 seconds, timed by the
	server). Status value: the caster's fruit color string.

	Everyone: the smoke that caught it keeps swirling on its root.
	Template: ReplicatedStorage.Assets.Models.Fruits.Smoke.Power2.FollowingSmoke (ParticleEmitter).

	Victim only: held where it was caught, lifted 2 studs, like the legacy BodyPosition
	the server used to put inside the victim's root. Players simulate their own character,
	so the hold has to run on the victim's client; the server side of it is a walk speed
	of 0. NPC victims are only stopped by that.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIFT = Vector3.new(0, 2, 0)
local HOLD_FORCE = 1000000
local HOLD_RESPONSIVENESS = 50

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return noop
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "SmokeWhiteOutHold"
	attachment.Parent = root

	local template = EffectAssets.FindFruit("Smoke", "Power2", "FollowingSmoke")
	if template and template:IsA("ParticleEmitter") then
		local emitter = template:Clone()
		local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
		if primary and secondary then
			emitter.Color = FruitColor.ToSequence(primary, secondary)
		end
		emitter.Parent = attachment
	end

	local definition = (SoundConfig :: any).SFX.Elemental.Smoke["Smoke Loop"]
	if definition then
		local sound = Instance.new("Sound")
		sound.SoundId = definition.Id
		sound.Volume = definition.Volume
		sound.Looped = true
		sound.PlaybackSpeed = definition.Speed or 1
		sound.Parent = attachment
		sound:Play()
	end

	if isLocal then
		local hold = Instance.new("AlignPosition")
		hold.Mode = Enum.PositionAlignmentMode.OneAttachment
		hold.Attachment0 = attachment
		hold.Position = root.Position + LIFT
		hold.MaxForce = HOLD_FORCE
		hold.Responsiveness = HOLD_RESPONSIVENESS
		hold.Parent = attachment
	end

	return function()
		attachment:Destroy()
	end
end
