--!strict
--[[
	Flare fruit - Flame Emperor while charging: a sun growing above the caster.
	Status value: "<k>|<fruit color string>|<cap factor>", k = sniper affinity * (sniper
	level / cap); the factor (3 with the Divine Axe, else 1) multiplies the three caps.
	Template: ReplicatedStorage.Assets.Models.Fruits.Flare.Power6.CruelSun (a neon ball
	with an outer shell part, an attachment holding two emitters, and a light).

	Growth mirrors Abilities/Flare/Flame Emperor (keep the constants identical):
		diameter = min(1 + 2.6176 * k * seconds, 44.5 * k)
		height   = 10 + min(1.75 * k * seconds, 30 * k) above the root
	The rest follows the legacy scripts, which grew these with time, not with the sun:
		shell     45 / 44.5 of the core, fading in from invisible to 0.85 transparency
		          over 2.5 s
		light     range 1 + 3 * seconds, 50 at most
		particles size 0 -> floor(7.5 * seconds), 50 * k at most (both emitters)
	The clock starts when this client sees the status, so someone who arrives mid-charge
	sees a smaller sun than the one that will be thrown.

	Colors: the first fruit color on the core, the light and the start of the particles,
	the second on the shell and the end of the particles; all dark for as long as
	armament haki is on; the authored colors otherwise.

	Owner only: the charge pose (FruitAnims.SunPos) and the body kept facing the mouse
	(legacy "P6Looker"). The throw animation belongs to the FlareSun one-shot.

	The sun is a local anchored copy placed every frame. The legacy one was a server part
	resized every Heartbeat, carrying a "characterFloaty" part that is dropped here.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local RENDER_STEP_NAME = "FlareSunFacing"
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local HAKI_PARTICLES = ColorSequence.new(Color3.fromRGB(16, 0, 26))

local START_SIZE = 1
local GROWTH = 2.617647059
local MAX_SIZE = 44.5
local BASE_HEIGHT = 10
local RISE = 1.75
local MAX_RISE = 30

-- Outer shell relative to the core (legacy 45 / 44.5).
local SHELL_RATIO = 45 / 44.5
local SHELL_FADE_PER_SECOND = 0.06
local SHELL_TRANSPARENCY = 0.85
local LIGHT_START_RANGE = 1
local LIGHT_RANGE_PER_SECOND = 3
local MAX_LIGHT_RANGE = 50
local PARTICLE_GROWTH = 7.5
local MAX_PARTICLE_SIZE = 50

local function noop() end

-- Returns the cleanup of the owner's pose and facing, or nil.
local function startCharging(character: Model): (() -> ())?
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not foundHumanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return nil
	end
	-- Typed copies: the closure below cannot rely on the narrowing above.
	local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot

	local track: AnimationTrack? = nil
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local loaded = Animations.Get(animator, AnimationConfig.FruitAnims.SunPos)
		loaded:Play()
		track = loaded
	end

	local mouse = Players.LocalPlayer:GetMouse()
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value, function()
		if humanoid.Sit then
			return
		end

		local position = root.Position
		local target = mouse.Hit.Position
		local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
		if flat.Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(position, position + flat)
		end
	end)

	return function()
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		if track then
			track:Stop()
		end
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	local template = EffectAssets.FindFruit("Flare", "Power6", "CruelSun")
	if not root or not root:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return noop
	end

	local fields = EffectAssets.Unpack(value)
	local scale = tonumber(fields[1]) or 1
	local primary, secondary = FruitColor.Parse(fields[2] or "")
	-- 3 for an owner of the Divine Axe: the caps are tripled, the growth rates are not.
	local capScale = scale * (tonumber(fields[3]) or 1)

	local sun = template:Clone()
	local shells: { BasePart } = {}
	local emitters: { ParticleEmitter } = {}
	local light: PointLight? = nil
	for _, descendant in sun:GetDescendants() do
		if not descendant:IsDescendantOf(sun) then
			continue
		end
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("JointInstance")
			or descendant:IsA("WeldConstraint")
			or descendant.Name == "characterFloaty"
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			table.insert(shells, descendant)
		elseif descendant:IsA("ParticleEmitter") then
			table.insert(emitters, descendant)
		elseif descendant:IsA("PointLight") then
			light = descendant
		end
	end

	for _, part in { sun, table.unpack(shells) } do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end

	local authoredCore = sun.Color
	local authoredShells: { [BasePart]: Color3 } = {}
	for _, shell in shells do
		authoredShells[shell] = shell.Color
	end
	local authoredParticles: { [ParticleEmitter]: ColorSequence } = {}
	for _, emitter in emitters do
		authoredParticles[emitter] = emitter.Color
	end
	local authoredLight = if light then light.Color else authoredCore
	local custom = primary ~= nil and secondary ~= nil

	local function paint()
		local haki = character:GetAttribute(HAKI_ATTRIBUTE)
		sun.Color = if haki then HAKI_COLOR elseif custom and primary then primary else authoredCore
		for shell, color in authoredShells do
			shell.Color = if haki then HAKI_COLOR elseif custom and secondary then secondary else color
		end
		for emitter, color in authoredParticles do
			emitter.Color = if haki
				then HAKI_PARTICLES
				elseif primary and secondary then FruitColor.ToSequence(primary, secondary)
				else color
		end
		if light then
			light.Color = if haki then HAKI_COLOR elseif custom and primary then primary else authoredLight
		end
	end
	paint()
	local hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)

	local started = os.clock()
	local particleSize = -1
	local function place()
		local elapsed = os.clock() - started
		local size = math.min(START_SIZE + GROWTH * scale * elapsed, math.max(MAX_SIZE * capScale, START_SIZE))
		local height = BASE_HEIGHT + math.min(RISE * scale * elapsed, MAX_RISE * capScale)
		local cframe = root.CFrame.Rotation + (root.Position + Vector3.new(0, height, 0))

		sun.Size = Vector3.one * size
		sun.CFrame = cframe
		local shellTransparency = math.max(1 - SHELL_FADE_PER_SECOND * elapsed, SHELL_TRANSPARENCY)
		for _, shell in shells do
			shell.Size = Vector3.one * (size * SHELL_RATIO)
			shell.CFrame = cframe
			shell.Transparency = shellTransparency
		end

		local wanted = math.floor(math.min(PARTICLE_GROWTH * elapsed, MAX_PARTICLE_SIZE * capScale))
		if wanted ~= particleSize then
			particleSize = wanted
			for _, emitter in emitters do
				emitter.Size = NumberSequence.new(0, wanted)
			end
		end
		if light then
			light.Range = math.min(LIGHT_START_RANGE + LIGHT_RANGE_PER_SECOND * elapsed, MAX_LIGHT_RANGE)
		end
	end

	place()
	sun.Parent = World.Effects()
	local connection = RunService.RenderStepped:Connect(place)
	local stopCharging = if isLocal then startCharging(character) else nil

	return function()
		if stopCharging then
			stopCharging()
		end
		connection:Disconnect()
		hakiConnection:Disconnect()
		sun:Destroy()
	end
end
