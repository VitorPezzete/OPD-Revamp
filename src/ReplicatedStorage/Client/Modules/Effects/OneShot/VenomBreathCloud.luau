--!strict
--[[
	Venom fruit - Poison Breath: where the breath is going. Sent by the server when a
	cloud leaves the mouth in a new direction (and twice a second otherwise).
	params: { Direction: Vector3, Caster: Model }

	The clouds are not drawn: the legacy ones were a transparent part (Fruits.Venom
	.Power1.Part), a hitbox that now only exists as numbers on the server. What is seen
	is the particle stream of Effects.Status.VenomBreath; this turns it towards the
	direction the clouds really take, by the C0 of its "Aim" weld (kept relative to the
	head, so it follows the character between two messages).

	The breather's own client aims its stream every frame and ignores these.
]]
local Players = game:GetService("Players")

local PART_NAME = "VenomBreathPart"
local WELD_NAME = "Aim"

return function(_origin: Vector3, params: { [string]: any }?)
	local direction = params and params.Direction
	local caster = params and params.Caster
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.05 then
		return
	end
	if typeof(caster) ~= "Instance" then
		return
	end
	local localPlayer = Players.LocalPlayer
	if localPlayer and caster == localPlayer.Character then
		return
	end

	local head = caster:FindFirstChild("Head")
	local breath = caster:FindFirstChild(PART_NAME)
	local weld = breath and breath:FindFirstChild(WELD_NAME)
	if not head or not head:IsA("BasePart") or not weld or not weld:IsA("Weld") then
		return
	end

	weld.C0 = CFrame.new(weld.C0.Position) * (head.CFrame.Rotation:Inverse() * CFrame.lookAt(Vector3.zero, direction))
end
