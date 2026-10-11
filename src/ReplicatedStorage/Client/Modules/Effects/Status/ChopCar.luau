--!strict
--[[
	Chop fruit - Chop Car. Status value: the fruit color string.

	Everyone: a wheel bar on each hand and foot.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Chop.Power3.ChopBar<Foot|Hand><Left|Right>,
	each a part with its own "Weld" (offset already authored, Part1 = the bar) and a
	"Wheel" child. Custom colors paint the bar with the first color and the wheel with
	the second.

	Owner only: the looped all-fours pose. It replicates to everyone through the animator.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local BARS: { [string]: string } = {
	ChopBarFootRight = "Right Leg",
	ChopBarFootLeft = "Left Leg",
	ChopBarHandRight = "Right Arm",
	ChopBarHandLeft = "Left Arm",
}

local function findAsset(...: string): Instance?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { ... } do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function addBars(character: Model, colors: string): { Instance }
	local created: { Instance } = {}
	local folder = findAsset("Models", "Fruits", "Chop", "Power3")
	if not folder then
		return created
	end

	local primary, secondary = FruitColor.Parse(colors)
	for templateName, limbName in BARS do
		local template = folder:FindFirstChild(templateName)
		local limb = character:FindFirstChild(limbName)
		if not template or not template:IsA("BasePart") or not limb or not limb:IsA("BasePart") then
			continue
		end

		local bar = template:Clone()
		bar.Anchored = false
		bar.CanCollide = false
		bar.CanQuery = false
		bar.CanTouch = false
		bar.Massless = true

		local wheel = bar:FindFirstChild("Wheel")
		if primary and secondary then
			bar.Color = primary
			if wheel and wheel:IsA("BasePart") then
				wheel.Color = secondary
			end
		end

		local weld = bar:FindFirstChild("Weld")
		if weld and weld:IsA("JointInstance") then
			weld.Part0 = limb
		else
			local fallback = Instance.new("Weld")
			fallback.Part0 = limb
			fallback.Part1 = bar
			fallback.Parent = bar
		end

		bar.Parent = limb
		table.insert(created, bar)
	end
	return created
end

local function playPose(character: Model): (() -> ())?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local id = (AnimationConfig.FruitAnims :: any).ChopCar
	if not animator or type(id) ~= "string" then
		return nil
	end

	local track = Animations.Get(animator, id)
	track.Looped = true
	track:Play()

	return function()
		track:Stop()
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local bars = addBars(character, if type(value) == "string" then value else "")
	local stopPose = if isLocal then playPose(character) else nil

	return function()
		if stopPose then
			stopPose()
		end
		for _, bar in bars do
			bar:Destroy()
		end
	end
end
