--!strict
--[[
	Gravity fruit - Gravity Assault. Status value: "<fruit slot>;<ability slot>".

	The rocks themselves are drawn by Effects.OneShot.GravityRock. This status only
	exists while the owner holds the key: the owner's client tells the server where it
	is aiming every 0.2 s, as phase 3 inputs, and each one the server accepts throws the
	next rock (the legacy client sent one message per rock with the sight point). The
	server enforces the pace and the count.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local PHASE_ACTION = 3
local SEND_INTERVAL = 0.2
-- Stays inside AbilityConfig.MaxAimDistance even with the camera far behind.
local AIM_RANGE = 800

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
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
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local active = true
	task.spawn(function()
		while true do
			-- The press itself threw the first rock.
			task.wait(SEND_INTERVAL)
			if not active then
				return
			end

			local camera = Workspace.CurrentCamera
			if camera then
				local mouse = UserInputService:GetMouseLocation()
				local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
				local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_RANGE, params)
				local aim = if result then result.Position else ray.Origin + ray.Direction * AIM_RANGE

				abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, aim)
			end
		end
	end)

	return function()
		active = false
	end
end
