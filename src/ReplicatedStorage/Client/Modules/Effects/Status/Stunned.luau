--!strict
--[[
	Stunned (StatusService:ApplyStun and the abilities that set the status themselves):
	the owner loses its controls for as long as the status is on its character.

	The server already roots a stunned character (walk speed 0), which does not stop
	jumping; the legacy StunClient disabled the whole control module, and so does this.
	The camera is handed back to the humanoid, in case an ability had taken it.

	A Phoenix user stunned inside its egg keeps its controls: it may jump (the legacy
	client asked the server to jump for it through a remote; the character is simulated
	by its owner here, so the plain jump works).

	Nothing is drawn: each stun has its own visual status.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local EGG_STATUS = "PhoenixEgg"

local function noop() end

local function getControls(): any
	local playerScripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if not module or not module:IsA("ModuleScript") then
		return nil
	end

	local ok, controls = pcall(function()
		return (require :: any)(module):GetControls()
	end)
	return if ok then controls else nil
end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local controls = getControls()
	if not controls then
		return noop
	end

	local function apply()
		local inEgg = character:GetAttribute(EGG_STATUS)
		if inEgg ~= nil and inEgg ~= false then
			controls:Enable()
		else
			controls:Disable()
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local camera = Workspace.CurrentCamera
	if humanoid and camera then
		camera.CameraSubject = humanoid
		camera.CameraType = Enum.CameraType.Custom
	end

	local connection = character:GetAttributeChangedSignal(EGG_STATUS):Connect(apply)
	apply()

	return function()
		connection:Disconnect()
		controls:Enable()
	end
end
