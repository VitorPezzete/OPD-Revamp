--!strict
--[[
	Flare fruit - Flame Emperor, the thrown sun.
	params: { Direction: Vector3, Speed: number, Range: number, Size: number,
	          Held: number (seconds charged), Scale: number (sniper affinity * level
	          scale, times 3 with the Divine Axe), LingerTime: number, Haki: boolean, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Flare.Power6.CruelSun.

	A local anchored copy flies from `origin` along the direction the server is casting.
	Like the server's (and the legacy sun, whose small centre part ended the flight on
	anything it touched) it stops at the first wall or character its centre meets, stays
	`LingerTime` seconds and disappears.

	The sun leaves as Effects.Status.FlareSunCharging drew it after `Held` seconds: shell
	glow, light range and particle size; the particles keep growing in flight (0 ->
	floor(7.5 * seconds since the charge began), 50 * Scale at most), as the legacy
	script inside the sun did.
	Colors: the first fruit color on the core, the light and the start of the particles,
	the second on the shell and the end of the particles; dark with armament haki.
	The thrower's own client also plays the throw animation (FruitAnims.SunPos2).
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

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local HAKI_PARTICLES = ColorSequence.new(Color3.new(0.051, 0, 0.133), Color3.new(0.098, 0.067, 0.098))
local SHELL_RATIO = 45 / 44.5
local SHELL_FADE_PER_SECOND = 0.06
local SHELL_TRANSPARENCY = 0.85
local LIGHT_START_RANGE = 1
local LIGHT_RANGE_PER_SECOND = 3
local MAX_LIGHT_RANGE = 50
local PARTICLE_GROWTH = 7.5
local MAX_PARTICLE_SIZE = 50
-- The part at the centre of the sun that stops it (mirrors the server's cast).
local CORE_RADIUS = 1
local FADE_TIME = 0.5
local THROW_FADE = 0.1

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local direction = params.Direction
	local size = params.Size
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-3 or type(size) ~= "number" then
		return
	end
	local speed: number = if type(params.Speed) == "number" and params.Speed > 0 then params.Speed else 100
	local range: number = if type(params.Range) == "number" then params.Range else 2000
	local lingerTime: number = if type(params.LingerTime) == "number" then params.LingerTime else 2
	local held: number = if type(params.Held) == "number" then math.max(params.Held, 0) else 0
	local scale: number = if type(params.Scale) == "number" then params.Scale else 1

	local caster = params.Caster
	local casterModel: Model? = if typeof(caster) == "Instance" and caster:IsA("Model") then caster else nil
	if casterModel and casterModel == Players.LocalPlayer.Character then
		local animator = Animations.FindAnimator(casterModel)
		if animator then
			Animations.Play(animator, AnimationConfig.FruitAnims.SunPos2, THROW_FADE, 1, 1)
		end
	end

	local template = EffectAssets.FindFruit("Flare", "Power6", "CruelSun")
	if not template or not template:IsA("BasePart") then
		return
	end

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local custom = primary ~= nil and secondary ~= nil
	local haki = params.Haki == true

	local sun = template:Clone()
	local shells: { BasePart } = {}
	local emitters: { ParticleEmitter } = {}
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
			descendant.Size = Vector3.one * (size * SHELL_RATIO)
			descendant.Transparency = math.max(1 - SHELL_FADE_PER_SECOND * held, SHELL_TRANSPARENCY)
			if haki then
				descendant.Color = HAKI_COLOR
			elseif custom and secondary then
				descendant.Color = secondary
			end
			table.insert(shells, descendant)
		elseif descendant:IsA("ParticleEmitter") then
			if haki then
				descendant.Color = HAKI_PARTICLES
			elseif primary and secondary then
				descendant.Color = FruitColor.ToSequence(primary, secondary)
			end
			table.insert(emitters, descendant)
		elseif descendant:IsA("PointLight") then
			descendant.Range = math.min(LIGHT_START_RANGE + LIGHT_RANGE_PER_SECOND * held, MAX_LIGHT_RANGE)
			if haki then
				descendant.Color = HAKI_COLOR
			elseif custom and primary then
				descendant.Color = primary
			end
		end
	end

	sun.Size = Vector3.one * size
	if haki then
		sun.Color = HAKI_COLOR
	elseif custom and primary then
		sun.Color = primary
	end
	for _, part in { sun, table.unpack(shells) } do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	if casterModel then
		rayParams.FilterDescendantsInstances = { casterModel }
	end

	local unit = direction.Unit
	local position = origin
	local travelled = 0
	local stoppedAt: number? = nil
	local particleSize = -1

	local function place()
		local cframe = CFrame.new(position)
		sun.CFrame = cframe
		for _, shell in shells do
			shell.CFrame = cframe
		end
	end

	place()
	sun.Parent = World.Effects()

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime: number)
		local now = os.clock()

		local wanted = math.floor(math.min(PARTICLE_GROWTH * (held + now - started), MAX_PARTICLE_SIZE * scale))
		if wanted ~= particleSize then
			particleSize = wanted
			for _, emitter in emitters do
				emitter.Size = NumberSequence.new(0, wanted)
			end
		end

		if not stoppedAt then
			local step = math.min(speed * deltaTime, range - travelled)
			local displacement = unit * step
			local result = if step > 0 then Workspace:Spherecast(position, CORE_RADIUS, displacement, rayParams) else nil
			if result then
				position += unit * result.Distance
				stoppedAt = now
			else
				position += displacement
				travelled += step
				if travelled >= range then
					stoppedAt = now
				end
			end
			place()
		elseif now - stoppedAt >= lingerTime then
			connection:Disconnect()
			for _, emitter in emitters do
				emitter.Enabled = false
			end
			for _, part in { sun, table.unpack(shells) } do
				part.Transparency = 1
			end
			task.delay(FADE_TIME, function()
				sun:Destroy()
			end)
		end
	end)
end
