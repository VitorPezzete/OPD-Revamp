--!strict
--[[
	String fruit - Flapping Thread, while the key is held. Owner only: the aim point
	(InputController, so a gamepad or a touch screen aims too) is sent ten times a second
	as the ability's secondary input (phase 3) so the stream of spikes follows it; in the
	legacy game every spike carried the mouse position of its own request. The server
	throws the spikes on its own clock; each one is drawn by Effects.OneShot.StringFlap.

	Status value: "<fruit slot>|<ability slot>".
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
local AIM_INTERVAL = 0.1

local function noop() end

return function(_character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	if not isLocal or not fruitSlot or not abilitySlot then
		return noop
	end

	local abilityService = Knit.GetService("AbilityService")
	local inputController = Knit.GetController("InputController")
	local sinceAim = AIM_INTERVAL

	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceAim += deltaTime
		if sinceAim < AIM_INTERVAL then
			return
		end
		sinceAim = 0
		abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, inputController:GetAimPosition())
	end)

	return function()
		connection:Disconnect()
	end
end
