--!strict
--[[
	Flare fruit - burning victim (damage over time left by Fire Fist / Fire Wave / Flame
	Pillar). Status value: true. Runs on players and NPC enemies.

	The legacy BurnOverTime flag had no visual of its own in the dump; fire on the torso
	is shown so the victim can tell why it is losing health.
	Template: ReplicatedStorage.Assets.Models.Fruits.Flare.Logia.FlareFire (a ParticleEmitter).
]]
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local function noop() end

return function(character: Model): () -> ()
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	local template = EffectAssets.FindFruit("Flare", "Logia", "FlareFire")
	if not torso or not template or not template:IsA("ParticleEmitter") then
		return noop
	end

	local fire = template:Clone()
	fire.Enabled = true
	fire.Parent = torso

	return function()
		fire:Destroy()
	end
end
