--!strict
--[[
	Love fruit - Beam / Slave Arrow while the salvo leaves. Owner only, nothing is drawn:
	the mouse position is sent as the ability's secondary input (phase 3) ten times a
	second, so every heart or arrow leaves towards where the player is aiming at that
	moment (the legacy client sent the mouse with each shot). The server decides what
	leaves and when; it only reads the aim.

	Status value: "<fruit slot>|<ability slot>".
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
-- Two shots are 0.1 s (arrows) or 0.2 s (hearts) apart; well inside the input budget.
local SEND_INTERVAL = 0.1
-- Kept under AbilityConfig.MaxAimDistance so an aim at the skybox is not rejected.
local MAX_AIM_DISTANCE = 900

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	if not isLocal or not fruitSlot or not abilitySlot then
		return noop
	end

	local abilityService = Knit.GetService("AbilityService")
	local mouse = Players.LocalPlayer:GetMouse()
	local sinceSent = SEND_INTERVAL

	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceSent += deltaTime
		local root = character.PrimaryPart
		if sinceSent < SEND_INTERVAL or not root then
			return
		end
		sinceSent = 0

		local aim = mouse.Hit.Position
		local offset = aim - root.Position
		if offset.Magnitude > MAX_AIM_DISTANCE then
			aim = root.Position + offset.Unit * MAX_AIM_DISTANCE
		end
		abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, aim)
	end)

	return function()
		connection:Disconnect()
	end
end
