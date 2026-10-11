--!strict
--[[
	Light fruit - while Light Blast or Yata Mirror is charging, or Sacred Jewels is
	firing, the owner's character keeps facing the point it is aiming at (the legacy
	P2Looker / P3Looker / P5Looker render steps). Status value: true.

	Local movement of the owner only; nothing to draw for anyone else. Like the legacy
	code it does nothing while seated.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local function noop() end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	-- The same aim point the abilities send: cursor, or screen centre without one.
	local inputController = Knit.GetController("InputController")

	local connection = RunService.RenderStepped:Connect(function()
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Sit then
			return
		end

		local aim: Vector3 = inputController:GetAimPosition()
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
