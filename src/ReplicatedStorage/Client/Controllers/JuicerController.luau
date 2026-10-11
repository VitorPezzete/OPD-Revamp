--!strict
--[[
	Spins the mixers of a juicing bowl while the server says it is mixing (attribute on
	the tagged bowl). Purely visual: the server only flips the attribute. One
	RenderStepped connection exists while at least one bowl is mixing.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)

local JUICING = FruitEconomyConfig.Juicing
local MIXERS = { "Mixer1", "Mixer2" }
-- The legacy loop turned the mixers 5 degrees per frame.
local SPIN_SPEED = math.rad(5 * 60)

local JuicerController = Knit.CreateController({
	Name = "JuicerController",
})

local mixing: { [Instance]: boolean } = {}
local stepConnection: RBXScriptConnection? = nil

local function step(deltaTime: number)
	local rotation = CFrame.Angles(0, SPIN_SPEED * deltaTime, 0)
	for bowl in mixing do
		for _, name in MIXERS do
			local mixer = bowl:FindFirstChild(name)
			if mixer and mixer:IsA("BasePart") then
				mixer.CFrame *= rotation
			end
		end
	end
end

local function refresh(bowl: Instance)
	mixing[bowl] = if bowl:GetAttribute(JUICING.MixingAttribute) == true and bowl:IsDescendantOf(workspace)
		then true
		else nil

	if next(mixing) and not stepConnection then
		stepConnection = RunService.RenderStepped:Connect(step)
	elseif not next(mixing) and stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
end

local function watch(bowl: Instance)
	bowl:GetAttributeChangedSignal(JUICING.MixingAttribute):Connect(function()
		refresh(bowl)
	end)
	refresh(bowl)
end

function JuicerController:KnitStart()
	CollectionService:GetInstanceAddedSignal(JUICING.Tag):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(JUICING.Tag):Connect(function(bowl: Instance)
		mixing[bowl] = nil
	end)
	for _, bowl in CollectionService:GetTagged(JUICING.Tag) do
		watch(bowl)
	end
end

return JuicerController
