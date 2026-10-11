--!strict
--[[
	Dough fruit - Mochi Gatling while the key is held.
	Status value: "<fruit slot>|<ability slot>".

	Nothing is drawn here: every punch is its own DoughGatling one-shot. Owner only: its
	client keeps the server's aim point on the mouse by sending it as the ability's
	secondary input a few times a second (the source server asked for the mouse position
	before each punch; the server fires the punches itself now and only reads the
	position, after validating it).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
-- One aim per punch (the server fires every 0.125 s), inside the input budget.
local SEND_INTERVAL = 0.125
local AIM_DISTANCE = 1000

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local fruitSlot, abilitySlot = tonumber(fields[1]), tonumber(fields[2])
	if not isLocal or not fruitSlot or not abilitySlot then
		return noop
	end

	local abilityService = Knit.GetService("AbilityService")
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local function getAim(): Vector3?
		local camera = Workspace.CurrentCamera
		local root = character.PrimaryPart
		if not camera or not root or Players.LocalPlayer.Character ~= character then
			return nil
		end

		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, rayParams)
		local aim = if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE

		-- The server brings back aim points too far from the character: keep it in range.
		local offset = aim - root.Position
		local limit = AbilityConfig.MaxAimDistance - 10
		if offset.Magnitude > limit then
			aim = root.Position + offset.Unit * limit
		end
		return aim
	end

	local elapsed = 0
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= SEND_INTERVAL then
			elapsed = 0
			local aim = getAim()
			if aim then
				abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, aim)
			end
		end
	end)

	return function()
		connection:Disconnect()
	end
end
