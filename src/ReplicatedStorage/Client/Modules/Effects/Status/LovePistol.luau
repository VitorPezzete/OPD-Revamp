--!strict
--[[
	Love fruit - Pistol Kiss, while the burst lasts. Owner only: the character raises its
	arm (the legacy "beam charge" clip, replicated through the Animator), faces the
	mouse, and the mouse position is sent as the ability's secondary input (phase 3)
	once per shot interval. The server decides whether each request becomes a shot.

	Status value: "<fruit slot>|<ability slot>|<seconds between shots>".
	The shots themselves, and the recoil of each one, belong to Effects.OneShot.LovePistol.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
local DEFAULT_INTERVAL = 0.2
local RECOIL_GRACE = 0.2
-- Kept under AbilityConfig.MaxAimDistance so an aim at the skybox is not rejected.
local MAX_AIM_DISTANCE = 900

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local interval = tonumber(fields[3]) or DEFAULT_INTERVAL
	if not isLocal or not fruitSlot or not abilitySlot then
		return noop
	end

	local abilityService = Knit.GetService("AbilityService")
	local mouse = Players.LocalPlayer:GetMouse()
	local sinceShot = 0

	-- The recoil is played by the one-shot of each shot; it is only stopped here.
	local charge: AnimationTrack? = nil
	local recoil: AnimationTrack? = nil
	local animator = Animations.FindAnimator(character)
	if animator then
		charge = Animations.Play(animator, AnimationConfig.FruitAnims.BeamChargeRight)
		recoil = Animations.Get(animator, AnimationConfig.FruitAnims.BeamReleaseRight)
	end

	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		local root = character.PrimaryPart
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			return
		end

		local aim = mouse.Hit.Position
		if not humanoid.Sit then
			local target = Vector3.new(aim.X, root.Position.Y, aim.Z)
			if (target - root.Position).Magnitude > 0.5 then
				root.CFrame = CFrame.lookAt(root.Position, target)
			end
		end

		sinceShot += deltaTime
		if sinceShot < interval then
			return
		end
		sinceShot = 0

		local offset = aim - root.Position
		if offset.Magnitude > MAX_AIM_DISTANCE then
			aim = root.Position + offset.Unit * MAX_AIM_DISTANCE
		end
		abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, aim)
	end)

	return function()
		connection:Disconnect()
		if charge then
			charge:Stop()
		end
		if recoil then
			-- The last shot arrives together with the end of the burst: let it play.
			task.delay(RECOIL_GRACE, recoil.Stop, recoil)
		end
	end
end
