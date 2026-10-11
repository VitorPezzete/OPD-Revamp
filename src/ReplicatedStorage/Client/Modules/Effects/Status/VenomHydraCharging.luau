--!strict
--[[
	Venom fruit - Venom Hydra while the key is held: the owner's charging pose, the
	wind-up clip (FruitAnims.VenomHydraCharge) then the held one (VenomHydraCharged), as
	the legacy client chained them. Status value: true.

	Owner only; the Animator replicates the pose. Nothing waits on the clips: the pose
	ends when the status goes, and the release clip is played by the VenomHydra one-shot.
	Facing the aim is Effects.Status.VenomAiming.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

local function noop() end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	local animator = if isLocal then Animations.FindAnimator(character) else nil
	if not animator then
		return noop
	end

	local anims = AnimationConfig.FruitAnims
	local active = true
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil

	local held = Animations.Get(animator, anims.VenomHydraCharged)
	table.insert(tracks, held)
	if Animations.IsAvailable(anims.VenomHydraCharge) then
		local windUp = Animations.Get(animator, anims.VenomHydraCharge)
		table.insert(tracks, windUp)
		stoppedConnection = windUp.Stopped:Connect(function()
			if active then
				held:Play()
			end
		end)
		windUp:Play()
	else
		-- A clip that did not download never ends: go straight to the held pose.
		held:Play()
	end

	return function()
		active = false
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end
	end
end
