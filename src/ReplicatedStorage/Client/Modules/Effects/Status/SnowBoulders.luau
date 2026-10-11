--!strict
--[[
	Snow fruit - Snow Boulder. Status value: "<fruit slot>;<ability slot>".

	The boulders themselves are server parts. This status only exists while the owner has
	boulders out: the owner's client tells the server where it is aiming (InputController,
	so a gamepad or a touch screen aims too) ten times a second, as phase 3 inputs, and
	the boulders are pushed there. The legacy client sent the mouse position every 0.1 s
	for 20 s per cast, which always outlasted the boulder (20 s at most).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local PHASE_ACTION = 3
-- The legacy rate, which is also the one AbilityConfig.InputBudget plans for an aim stream.
local SEND_INTERVAL = 0.1

local function noop() end

return function(_character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local fields = string.split(if type(value) == "string" then value else "", ";")
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	if not fruitSlot or not abilitySlot then
		return noop
	end

	local abilityService = Knit.GetService("AbilityService")
	local inputController = Knit.GetController("InputController")

	local active = true
	task.spawn(function()
		while active do
			abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, inputController:GetAimPosition())
			task.wait(SEND_INTERVAL)
		end
	end)

	return function()
		active = false
	end
end
