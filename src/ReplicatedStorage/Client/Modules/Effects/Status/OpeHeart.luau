--!strict
--[[
	Ope fruit - Scalpel: the stolen heart held in the caster's right hand for as long as
	the "OpeHeart" status (the victim's name) is on. The legacy gave a "Heart" tool; its
	handle is welded to the arm the way the tool grip held it.

	Template: ReplicatedStorage.Assets.Models.FruitItems.LegacyPowerTool.Heart.Handle.
]]
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local ARM_NAME = "Right Arm"
-- The R6 tool grip on the right arm, and the Heart tool's own Grip.
local ARM_GRIP = CFrame.new(0, -1, 0, 1, 0, 0, 0, 0, 1, 0, -1, 0)
local TOOL_GRIP = CFrame.new(0, -0.2, 0.3)

local function noop() end

return function(character: Model): () -> ()
	local template = EffectAssets.Find("Models", "FruitItems", "LegacyPowerTool", "Heart", "Handle")
	local arm = character:FindFirstChild(ARM_NAME)
	if not template or not template:IsA("BasePart") or not arm or not arm:IsA("BasePart") then
		return noop
	end

	local heart = template:Clone()
	for _, descendant in heart:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("ValueBase") then
			descendant:Destroy()
		end
	end
	heart.Name = "OpeHeart"
	heart.Anchored = false
	heart.CanCollide = false
	heart.CanQuery = false
	heart.CanTouch = false
	heart.Massless = true

	local weld = Instance.new("Weld")
	weld.Part0 = arm
	weld.Part1 = heart
	weld.C0 = ARM_GRIP
	weld.C1 = TOOL_GRIP
	weld.Parent = heart
	heart.Parent = arm

	return function()
		heart:Destroy()
	end
end
