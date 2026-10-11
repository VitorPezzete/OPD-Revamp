--!strict
--[[
	Paw fruit - Pressure Bubble while charging: a translucent paw at the end of the right
	arm, wrapped in particles.

	Status value: "<factor>|<fruit colors>|<1 with armament haki>" where factor is the
	uncharged (level / cap) * affinity / 2.

	As in the source: the paw appears 4 f x 4 f x 2.666 f and invisible, 2 studs down the
	arm and turned to face along it, and settles in 0.5 s (elastic) at 2 f x 2 f x 1.333 f
	and 0.75 transparency. It carries the Particles emitter on itself and Orbits, Wind and
	Smoke on an attachment, and the three charge sounds. Dark with haki; otherwise the
	first fruit color for the paw and the second for the particles (their own colors when
	the fruit has none).

	Owner only: faces the aim point and plays BeamChargeRight then BeamChargedRight (they
	replicate through the Animator). The thrown paw and the release clip belong to
	Effects.OneShot.PawPressureBubble.
]]
local TweenService = game:GetService("TweenService")

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local PawFx = require(script.Parent.Parent.Util.PawFx)

local GROUP = "PressureBubble"
local HAND_OFFSET = CFrame.new(0, -2, 0) * CFrame.Angles(math.rad(-90), 0, 0)
local SETTLE_TIME = 0.5
local TRANSPARENCY = 0.75
local ATTACHED = { "Orbits", "Wind", "Smoke" }
local SOUNDS = { "ChargeBegan1", "Charge1", "Charge2" }

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local factor = math.max(tonumber(fields[1]) or 0, 0.01)
	local primary, secondary = PawFx.Colors(fields[2])
	local haki = fields[3] == "1"
	local pawColor = if haki then PawFx.HAKI_COLOR else primary
	local particleColor = if haki then PawFx.HAKI_COLOR else secondary

	local stopFacing: (() -> ())? = nil
	local stopCharge: (() -> ())? = nil
	if isLocal then
		stopFacing = PawFx.FaceAim(character)
		stopCharge = PawFx.PlayCharge(character, PawFx.Anims.BeamChargeRight, PawFx.Anims.BeamChargedRight)
	end

	local paw: BasePart? = nil
	local arm = character:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		paw = PawFx.NewPaw(PawFx.Size(factor * 2), pawColor, 1)
	end
	if paw and arm and arm:IsA("BasePart") then
		paw.Anchored = false
		paw.CFrame = arm.CFrame * HAND_OFFSET

		local particles = PawFx.Emitter(GROUP, "Particles", particleColor)
		if particles then
			particles.Parent = paw
		end
		local attachment = Instance.new("Attachment")
		attachment.Parent = paw
		for _, name in ATTACHED do
			local emitter = PawFx.Emitter(GROUP, name, particleColor)
			if emitter then
				emitter.Parent = attachment
			end
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = paw
		weld.Part1 = arm
		weld.Parent = paw
		paw.Parent = arm

		for _, name in SOUNDS do
			PawFx.Sound(name, paw)
		end
		TweenService:Create(paw, TweenInfo.new(SETTLE_TIME, Enum.EasingStyle.Elastic), {
			Size = PawFx.Size(factor),
			Transparency = TRANSPARENCY,
		}):Play()
	end

	return function()
		if stopFacing then
			stopFacing()
		end
		if stopCharge then
			stopCharge()
		end
		if paw then
			paw:Destroy()
		end
	end
end
