--!strict
--[[
	Vampire fruit - Bat Swarm latched onto its target: bats swarm the body for as long
	as the server keeps biting.

	params: { Target: Model, Duration: number, Rate: number (40-100), Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Vampire.Power5.VampireBatSwarmHit
	(a part full of emitters), welded to the target's root. Rate is the emitters' rate,
	which the legacy game set from the charge. Custom colors use the first color.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

return function(_origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Target) ~= "Instance" then
		return
	end
	local root = params.Target:FindFirstChild("HumanoidRootPart")
	local template = EffectAssets.FindFruit("Vampire", "Power5", "VampireBatSwarmHit")
	if not root or not root:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return
	end
	local duration: number = if type(params.Duration) == "number" then math.clamp(params.Duration, 0.25, 10) else 1
	local rate: number = if type(params.Rate) == "number" then math.clamp(params.Rate, 40, 100) else 40

	local swarm = template:Clone()
	swarm.Anchored = false
	swarm.CanCollide = false
	swarm.CanQuery = false
	swarm.CanTouch = false
	swarm.Massless = true

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	for _, descendant in swarm:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Rate = rate
			if primary then
				descendant.Color = ColorSequence.new(primary)
			end
		end
	end

	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = swarm
	weld.Parent = swarm

	swarm.Parent = root
	Debris:AddItem(swarm, duration)
end
