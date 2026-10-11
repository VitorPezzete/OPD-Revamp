--!strict
--[[
	Candy fruit - Jawbreaker: the throw.
	params: { Hand: "Right" | "Left", Caster: Model }   (plus Colors)

	The ball itself is a real physical part created and simulated by the server
	(Abilities/Candy/Jawbreaker), as it was in the legacy game, and replicates like any
	other part: nothing is drawn here. What is left for the client is the thrower's punch
	clip, played by its own client (it replicates through the Animator).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

local PUNCH_FADE = 0.1
local PUNCH_SPEED = 3

return function(_origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	if typeof(caster) ~= "Instance" or not caster:IsA("Model") or caster ~= Players.LocalPlayer.Character then
		return
	end

	local humanoid = caster:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	local anims = AnimationConfig.FruitAnims
	local left = params ~= nil and params.Hand == "Left"
	Animations.Play(animator, if left then anims.PunchLeft else anims.PunchRight, PUNCH_FADE, 1, PUNCH_SPEED)
end
