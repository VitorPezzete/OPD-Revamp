--!strict
--[[
	Phoenix fruit - Phoenix Pulse: healing flames around a character being healed by a
	pulse (the caster and everyone who was in range, NPC enemies included).
	Status value: true. The server removes it when the heal ends.

	Template: ReplicatedStorage.Assets.Models.Fruits.Phoenix.Power4.PhoenixPulse (a part
	holding the emitters), welded to the root as in the legacy control scripts. It keeps
	its authored colors: legacy did not recolor it.
]]
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

return function(character: Model, _value: any, _isLocal: boolean): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	local template = EffectAssets.FindFruit("Phoenix", "Power4", "PhoenixPulse")
	if not root or not root:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return function() end
	end

	local pulse = template:Clone()
	pulse.Anchored = false
	pulse.CanCollide = false
	pulse.CanQuery = false
	pulse.CanTouch = false
	pulse.Massless = true
	for _, descendant in pulse:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	pulse.CFrame = root.CFrame

	local weld = Instance.new("Weld")
	weld.Part0 = pulse
	weld.Part1 = root
	weld.Parent = pulse

	pulse.Parent = root

	return function()
		pulse:Destroy()
	end
end
