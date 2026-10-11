--!strict
--[[
	Phoenix fruit - Soar.
	Status value: the fruit color string.

	Everyone: a wing of flames on each arm.
	Template: ReplicatedStorage.Assets.Models.Fruits.Phoenix.PhoenixWing.Wing. Colors: dark
	with armament haki, the fruit colors when it has an aura, else blue to yellow.

	Owner only, as the legacy client did:
	- hip height 10, so the character hovers above whatever it walks on;
	- an invisible 5000 x 2 x 5000 floor kept under the character at Y = 210: its top is
	  the sea surface (WorldConfig.SeaLevel), so a soaring phoenix runs across the sea,
	  ten studs above it, instead of falling in. Legacy put it in collision group 31,
	  whose rules are not in the dump; here it is a local part in the default group that
	  cannot be queried or touched;
	- the idle / run / walk / fall / jump clips of the character's Animate script are
	  swapped for the soaring ones and put back afterwards. Those asset ids are not in
	  AnimationConfig; they are the ones the legacy script wrote. The previous ids are
	  restored (legacy wrote hard-coded "default" ids back instead).

	The speed and jump bonuses are applied by the server.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HIP_HEIGHT = 10
local SKY_FLOOR_SIZE = Vector3.new(5000, 2, 5000)
-- Centre of the floor: its top face is the sea surface (legacy Y = 210 for a sea at 211).
local SKY_FLOOR_Y = WorldConfig.SeaLevel - SKY_FLOOR_SIZE.Y / 2
local SKY_FLOOR_INTERVAL = 0.1

-- { folder in Animate, Animation name, soaring clip }
local SOAR_ANIMATIONS = {
	{ "idle", "Animation1", "rbxassetid://72958727733402" },
	{ "idle", "Animation2", "rbxassetid://77163542179727" },
	{ "run", "RunAnim", "rbxassetid://117096093336626" },
	{ "walk", "WalkAnim", "rbxassetid://117096093336626" },
	{ "fall", "FallAnim", "rbxassetid://106997437362662" },
	{ "jump", "JumpAnim", "rbxassetid://83784385249358" },
}

local ARMS = { "Right Arm", "Left Arm" }
local HAKI_ATTRIBUTE = "Haki"
local HAKI_SEQUENCE = ColorSequence.new(Color3.fromRGB(16, 0, 26), Color3.fromRGB(60, 0, 97))
local DEFAULT_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 208, 255)),
	ColorSequenceKeypoint.new(0.798, Color3.fromRGB(0, 208, 255)),
	ColorSequenceKeypoint.new(0.926, Color3.fromRGB(230, 250, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 0)),
})

local function addWings(character: Model, colors: string): () -> ()
	local template = EffectAssets.FindFruit("Phoenix", "PhoenixWing", "Wing")
	if not template or not template:IsA("BasePart") then
		return function() end
	end

	local primary, secondary = FruitColor.Parse(colors)
	local normal = DEFAULT_SEQUENCE
	if primary and secondary then
		normal = ColorSequence.new({
			ColorSequenceKeypoint.new(0, primary),
			ColorSequenceKeypoint.new(0.798, primary),
			ColorSequenceKeypoint.new(0.926, secondary),
			ColorSequenceKeypoint.new(1, secondary),
		})
	end

	local wings: { Instance } = {}
	local emitters: { ParticleEmitter } = {}
	for _, armName in ARMS do
		local arm = character:FindFirstChild(armName)
		if not arm or not arm:IsA("BasePart") then
			continue
		end

		local wing = template:Clone()
		wing.Name = "PhoenixSoarWing"
		wing.Anchored = false
		wing.CanCollide = false
		wing.CanQuery = false
		wing.CanTouch = false
		wing.Massless = true
		for _, descendant in wing:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			elseif descendant:IsA("ParticleEmitter") then
				table.insert(emitters, descendant)
			end
		end
		wing.CFrame = arm.CFrame

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = wing
		weld.Parent = wing

		wing.Parent = character
		table.insert(wings, wing)
	end

	local function recolor()
		local sequence = if character:GetAttribute(HAKI_ATTRIBUTE) then HAKI_SEQUENCE else normal
		for _, emitter in emitters do
			emitter.Color = sequence
		end
	end
	recolor()
	local connection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(recolor)

	return function()
		connection:Disconnect()
		for _, wing in wings do
			wing:Destroy()
		end
	end
end

local function stopTracks(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop()
		end
	end
end

-- Returns the cleanup of the owner's side of the state, or nil without a humanoid.
local function startSoar(character: Model): (() -> ())?
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not foundHumanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return nil
	end
	local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot

	local swapped: { { Animation: Animation, Id: string } } = {}
	local animate = character:FindFirstChild("Animate")
	if animate then
		for _, entry in SOAR_ANIMATIONS do
			local folder = animate:FindFirstChild(entry[1])
			local animation = folder and folder:FindFirstChild(entry[2])
			if animation and animation:IsA("Animation") then
				table.insert(swapped, { Animation = animation, Id = animation.AnimationId })
				animation.AnimationId = entry[3]
			end
		end
	end
	-- So the Animate script starts the new clips right away.
	stopTracks(humanoid)

	local previousHipHeight = humanoid.HipHeight
	humanoid.HipHeight = HIP_HEIGHT

	local floor = Instance.new("Part")
	floor.Name = "PhoenixSkyFloor"
	floor.Size = SKY_FLOOR_SIZE
	floor.Anchored = true
	floor.Transparency = 1
	floor.CanQuery = false
	floor.CanTouch = false
	floor.CastShadow = false
	floor.CFrame = CFrame.new(root.Position.X, SKY_FLOOR_Y, root.Position.Z)
	floor.Parent = World.Effects()

	local running = true
	task.spawn(function()
		while running and root.Parent do
			floor.CFrame = CFrame.new(root.Position.X, SKY_FLOOR_Y, root.Position.Z)
			task.wait(SKY_FLOOR_INTERVAL)
		end
	end)

	return function()
		running = false
		floor:Destroy()
		humanoid.HipHeight = previousHipHeight
		for _, entry in swapped do
			entry.Animation.AnimationId = entry.Id
		end
		stopTracks(humanoid)
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local removeWings = addWings(character, if type(value) == "string" then value else "")
	local stopSoar = if isLocal then startSoar(character) else nil

	return function()
		if stopSoar then
			stopSoar()
		end
		removeWings()
	end
end
