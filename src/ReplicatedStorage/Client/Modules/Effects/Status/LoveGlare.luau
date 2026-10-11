--!strict
--[[
	Love fruit - Glare, while the key is held: the owner's character turns to face the
	mouse every frame (the whole legacy power). Nothing is drawn for other players.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function noop() end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local mouse = Players.LocalPlayer:GetMouse()
	local connection = RunService.RenderStepped:Connect(function()
		local root = character.PrimaryPart
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Sit then
			return
		end

		local hit = mouse.Hit.Position
		local target = Vector3.new(hit.X, root.Position.Y, hit.Z)
		if (target - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, target)
		end
	end)

	return function()
		connection:Disconnect()
	end
end
