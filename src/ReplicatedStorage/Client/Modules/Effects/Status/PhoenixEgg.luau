--!strict
--[[
	Phoenix fruit - the egg a phoenix turns into instead of dying.
	Status value: the fruit color string.

	Template: ReplicatedStorage.Assets.Models.Fruits.Phoenix.PhoenixEgg.Phoenixegg (a mesh
	with the "PhoenixRevive1" / "PhoenixRevive2" emitters), placed on the torso and welded
	to it as in the legacy game. With an aura the egg and the first emitter take the first
	fruit color and the second emitter the second.

	The emitters start when the egg can be cracked (3 s in): the server then sets the
	replicated "PhoenixEggHits" attribute (hits left), which is all this reads.

	Owner only: the looped curl clip. Its asset id is not in AnimationConfig (so it is not
	preloaded): it is the "EggCurl" animation of the legacy ServerPhoenixEgg script, which
	this place has no permission to load.
	Owner only too: the egg weighs double (a force of one more gravity on the root, as the
	legacy egg stun applied), so it drops fast and its jumps are half as high.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HITS_ATTRIBUTE = "PhoenixEggHits"
local CURL_ANIMATION = "rbxassetid://107430794648515"

local function addEgg(character: Model, colors: string): () -> ()
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	local template = EffectAssets.FindFruit("Phoenix", "PhoenixEgg", "Phoenixegg")
	if not torso or not torso:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return function() end
	end

	local egg = template:Clone()
	egg.Anchored = false
	egg.CanCollide = false
	egg.CanQuery = false
	egg.CanTouch = false
	egg.Massless = true

	local primary, secondary = FruitColor.Parse(colors)
	if primary then
		egg.Color = primary
	end

	local emitters: { ParticleEmitter } = {}
	for _, descendant in egg:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") then
			if primary and secondary then
				descendant.Color = ColorSequence.new(if descendant.Name == "PhoenixRevive2" then secondary else primary)
			end
			table.insert(emitters, descendant)
		end
	end

	local function refresh()
		local armed = character:GetAttribute(HITS_ATTRIBUTE) ~= nil
		for _, emitter in emitters do
			emitter.Enabled = armed
		end
	end
	refresh()
	local connection = character:GetAttributeChangedSignal(HITS_ATTRIBUTE):Connect(refresh)

	egg.CFrame = torso.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = egg
	weld.Part1 = torso
	weld.Parent = egg
	egg.Parent = character

	return function()
		connection:Disconnect()
		egg:Destroy()
	end
end

local function curl(character: Model): (() -> ())?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end

	local track = Animations.Get(animator, CURL_ANIMATION)
	track.Looped = true
	track:Play()

	return function()
		track:Stop()
	end
end

local function weigh(character: Model): (() -> ())?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "PhoenixEggWeight"
	attachment.Parent = root

	local force = Instance.new("VectorForce")
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.new(0, -root.AssemblyMass * Workspace.Gravity, 0)
	force.Parent = attachment

	return function()
		attachment:Destroy()
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local removeEgg = addEgg(character, if type(value) == "string" then value else "")
	local uncurl = if isLocal then curl(character) else nil
	local unweigh = if isLocal then weigh(character) else nil

	return function()
		if uncurl then
			uncurl()
		end
		if unweigh then
			unweigh()
		end
		removeEgg()
	end
end
