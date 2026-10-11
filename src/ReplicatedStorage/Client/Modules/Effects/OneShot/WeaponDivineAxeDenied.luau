--!strict
--[[
	The Divine Axe refused someone: the body catches fire limb by limb as it falls.
	Legacy cloned a ParticleEmitter (child of the prompt script, not in the dump) into
	the torso, head, arms and legs; a Fire per limb stands in for it here.
	The "denies you" text arrives through NotifyService.
	params: { Caster: Model }
]]
local Debris = game:GetService("Debris")

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local LIFE = 6

return function(_origin: Vector3, params: { [string]: any }?)
	local character = params and params.Caster
	if typeof(character) ~= "Instance" then
		return
	end

	for _, limbName in LIMBS do
		local limb = character:FindFirstChild(limbName)
		if limb and limb:IsA("BasePart") then
			local fire = Instance.new("Fire")
			fire.Heat = 12
			fire.Size = 6
			fire.Color = Color3.fromRGB(255, 170, 60)
			fire.SecondaryColor = Color3.fromRGB(255, 80, 0)
			fire.Parent = limb
			Debris:AddItem(fire, LIFE)
		end
	end
end
