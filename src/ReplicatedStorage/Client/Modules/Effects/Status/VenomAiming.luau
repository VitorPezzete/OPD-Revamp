--!strict
--[[
	Venom fruit - while Poison Breath is being breathed, or Venom Hydra / Chloro Ball is
	charging, the owner's character keeps facing the point it is aiming at (the legacy
	P1Looker / P3Looker / P4Looker render steps). Status value: true.

	Local movement of the owner only; nothing to draw for anyone else. Like the legacy
	code it does nothing while seated.

	The charging poses are Effects.Status.VenomHydraCharging and VenomChloroCharging.
]]
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AIM_RANGE = 900

local function noop() end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local connection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not camera or not root or not root:IsA("BasePart") or not humanoid or humanoid.Sit then
			return
		end

		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_RANGE, params)
		local aim = if result then result.Position else ray.Origin + ray.Direction * AIM_RANGE

		local position = root.Position
		local flat = Vector3.new(aim.X, position.Y, aim.Z)
		if (flat - position).Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(position, flat)
		end
	end)

	return function()
		connection:Disconnect()
	end
end
