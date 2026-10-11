--!strict
--[[
	Spring fruit - Jump. The legacy script raised Humanoid.HipHeight to the jump height for
	one frame and set it back to 0: the humanoid's leg spring does the launch. Only the
	client that simulates the character can do that, so every other client ignores this.
	There was no visual or sound.
]]
local Players = game:GetService("Players")

return function(_origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	local height = params and params.Height
	if typeof(caster) ~= "Instance" or caster ~= Players.LocalPlayer.Character or typeof(height) ~= "number" then
		return
	end
	local humanoid = caster:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid.HipHeight = height
	task.wait()
	if humanoid.Parent then
		humanoid.HipHeight = 0
	end
end
