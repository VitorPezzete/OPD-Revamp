--!strict
--[[
	Conqueror's Haki - two users' bursts meeting.
	params: { Color: Color3 (the two colours mixed), Seconds: number }

	`origin` is the point halfway between them. For the whole clash, twenty times a second:
	a sphere swelling to 65, a ring of the mixed colour growing to 150 studs at a random
	tilt, and a puff from every emitter of the two templates (HaoEmit emits as many
	particles as each emitter's name says; "Conquerors Haki" emits 2, 2 and 1 from FX1,
	FX2 and FX3). The clash sound plays once, and everyone within 250 studs sees the world
	take the mixed colour until it is over.
	Templates: HakiBall, MeatyRing, HaoEmit, Conquerors Haki, HaoClash_ColorCorrectionEffect.

	The place this came from asked for two more sounds ("HAO CLASH", "HAO CLASH END")
	that it did not have either; only the one in SoundConfig.Conqueror is played.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ConquerorConfig = require(ReplicatedStorage.Shared.Configs.ConquerorConfig)
local World = require(ReplicatedStorage.Shared.Util.World)
local ConquerorFx = require(script.Parent.Parent.Util.ConquerorFx)

local VISUAL = ConquerorConfig.Visual
local CLASH = ConquerorConfig.Clash
local DEFAULT_COLOR = ConquerorConfig.Palette[1]
local WAVE_SCALE = VISUAL.Burst.Scale
local MAX_SECONDS = 30
local DEFAULT_EMIT = 5
local AURA_EMITS: { [string]: number } = { FX1 = 2, FX2 = 2, FX3 = 1 }
local FADE_SECONDS = 3
local TINT_SECONDS = 0.3
local TINT_INFO = TweenInfo.new(TINT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TINT_CONTRAST = 0.9
-- A haki colour can be pure black, which as a tint is a black screen: the tint is always
-- lifted halfway to white.
local TINT_LIFT = 0.5
local WHITE = Color3.new(1, 1, 1)

-- A template of emitters standing at the clash: what to destroy afterwards, and its emitters.
local function stand(name: string, position: Vector3, color: Color3): (Instance?, { ParticleEmitter })
	local template = ConquerorFx.Asset(name)
	if not template then
		return nil, {}
	end

	local copy = template:Clone()
	local owner: Instance = copy
	if copy:IsA("BasePart") then
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CFrame = CFrame.new(position)
		copy.Parent = World.Effects()
	else
		owner = ConquerorFx.Holder(position)
		copy.Parent = owner
	end

	local emitters = ConquerorFx.Emitters(copy, color)
	for _, emitter in emitters do
		emitter.Enabled = false
	end
	return owner, emitters
end

local function isNear(origin: Vector3): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character.PrimaryPart
	return root ~= nil and (root.Position - origin).Magnitude <= CLASH.LightRange
end

local function tintWorld(color: Color3, seconds: number)
	local tint = ConquerorFx.Tint()
	if not tint then
		return
	end

	TweenService:Create(tint, TINT_INFO, {
		Saturation = 1,
		TintColor = color:Lerp(WHITE, TINT_LIFT),
		Contrast = TINT_CONTRAST,
	}):Play()
	task.delay(math.max(0, seconds - TINT_SECONDS), function()
		TweenService:Create(tint, TINT_INFO, { Saturation = 0, TintColor = WHITE, Contrast = 0 }):Play()
		task.wait(TINT_SECONDS)
		tint:Destroy()
	end)
end

return function(origin: Vector3, params: { [string]: any }?)
	local color = if params and typeof(params.Color) == "Color3" then params.Color else DEFAULT_COLOR
	local seconds = if params and type(params.Seconds) == "number"
		then math.clamp(params.Seconds, 0, MAX_SECONDS)
		else CLASH.Seconds

	local sparks, sparkEmitters = stand("HaoEmit", origin, color)
	local aura, auraEmitters = stand("Conquerors Haki", origin, color)

	ConquerorFx.PlaySound("Clash", origin)
	if isNear(origin) then
		tintWorld(color, seconds)
	end

	local endsAt = os.clock() + seconds
	while os.clock() < endsAt do
		ConquerorFx.Shockwave(origin, WAVE_SCALE)
		ConquerorFx.Ring(origin, VISUAL.ClashRing, color)
		for _, emitter in sparkEmitters do
			emitter:Emit(tonumber(emitter.Name) or DEFAULT_EMIT)
		end
		for _, emitter in auraEmitters do
			local count = AURA_EMITS[emitter.Name]
			if count then
				emitter:Emit(count)
			end
		end
		task.wait(VISUAL.ClashInterval)
	end

	task.wait(FADE_SECONDS)
	if sparks then
		sparks:Destroy()
	end
	if aura then
		aura:Destroy()
	end
end
