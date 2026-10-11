--!strict
--[[
	Alice fruit - Tea Party: a character drinks a cup of tea (the caster, or a guest
	forced to drink inside Wonderland).
	params: { Tea: string, Drinker: Model }   (plus Caster, Colors)
	Templates: ReplicatedStorage.Assets.Models.Fruits.Alice.Power2
		"Tea Cup"   Tool whose Handle has a joint named "Tea" for the liquid
		"Tea<Name>" the liquid of each tea (TeaMax, TeaBad, TeaHaki, ...)

	The legacy server equipped the Tool for 2 seconds. Here only its Handle is cloned
	and welded to the right arm with the Tool's own grip, so nothing is equipped and
	nothing replicates. The drinking animation is played by the drinker's own client
	(it replicates through the Animator).
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local HAND = "Right Arm"
local HOLD_TIME = 2
-- How a Tool's handle sits in the right hand (the stock RightGrip C0).
local HAND_GRIP = CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)

-- Where each liquid sits in the cup (legacy TeaRot table).
local LIQUID_OFFSETS: { [string]: CFrame } = {
	Max = CFrame.new(-0.007, 0.3, -0.2) * CFrame.fromOrientation(0, math.rad(90), 0),
	Bad = CFrame.new(-0.007, 0.25, -0.2) * CFrame.fromOrientation(0, 0, math.rad(90)),
	Haki = CFrame.new(-0.007, 0.3, -0.2) * CFrame.fromOrientation(0, math.rad(180), math.rad(90)),
	Neutral = CFrame.new(-0.007, 0.3, -0.2) * CFrame.fromOrientation(math.rad(-90), 0, 0),
	Health = CFrame.new(-0.007, 0.3, -0.13) * CFrame.fromOrientation(0, 0, math.rad(90)),
	Weird = CFrame.new(-0.007, 0.3, -0.2) * CFrame.fromOrientation(0, math.rad(-180), math.rad(90)),
}

local function soften(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
end

local function playDrink(drinker: Instance)
	if drinker ~= Players.LocalPlayer.Character then
		return
	end

	local humanoid = drinker:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		Animations.Play(animator, AnimationConfig.Fruits.Alice.Drink, 0.1, 1, 1)
	end
end

return function(_origin: Vector3, params: { [string]: any }?)
	local tea = params and params.Tea
	local drinker = params and params.Drinker
	if type(tea) ~= "string" or typeof(drinker) ~= "Instance" or drinker.Parent == nil then
		return
	end

	playDrink(drinker)

	local hand = drinker:FindFirstChild(HAND)
	local tool = EffectAssets.FindFruit("Alice", "Power2", "Tea Cup")
	local handleTemplate = tool and tool:FindFirstChild("Handle")
	if not hand or not hand:IsA("BasePart") or not handleTemplate or not handleTemplate:IsA("BasePart") then
		return
	end

	local handle = handleTemplate:Clone()
	soften(handle)
	for _, descendant in handle:GetDescendants() do
		if descendant:IsA("BasePart") then
			soften(descendant)
		end
	end

	local liquidTemplate = EffectAssets.FindFruit("Alice", "Power2", "Tea" .. tea)
	local joint = handle:FindFirstChild("Tea")
	local offset = LIQUID_OFFSETS[tea]
	if liquidTemplate and liquidTemplate:IsA("BasePart") and joint and joint:IsA("JointInstance") and offset then
		local liquid = liquidTemplate:Clone()
		soften(liquid)
		for _, descendant in liquid:GetDescendants() do
			if descendant:IsA("BasePart") then
				soften(descendant)
			end
		end
		joint.Part0 = handle
		joint.Part1 = liquid
		joint.C0 = offset
		liquid.Parent = handle
	end

	local grip = Instance.new("Weld")
	grip.Name = "AliceTeaGrip"
	grip.Part0 = hand
	grip.Part1 = handle
	grip.C0 = HAND_GRIP
	if tool and tool:IsA("Tool") then
		grip.C1 = tool.Grip
	end
	grip.Parent = handle

	handle.CFrame = hand.CFrame * HAND_GRIP
	handle.Parent = drinker
	Debris:AddItem(handle, HOLD_TIME)
end
