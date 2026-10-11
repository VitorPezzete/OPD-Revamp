--!strict
--[[
	Pieces shared by the Conqueror's Haki effects (ConquerorBurst, ConquerorClash,
	ConquerorCoating, Conquered). Templates: ReplicatedStorage.Assets.Models.Conqueror.

	Every template is looked up when it is needed and every caller copes with nil: a
	place missing one of them shows the effect without that piece.
]]
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local World = require(ReplicatedStorage.Shared.Util.World)
local EffectAssets = require(script.Parent.EffectAssets)

local WAVE_SECONDS = 0.5
local WAVE_INFO = TweenInfo.new(WAVE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RING_INFO = TweenInfo.new(WAVE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local TINT_TEMPLATE = "HaoClash_ColorCorrectionEffect"
local SOUND_REACH = 400
-- A sound that never loads never ends: its holder is removed after this long anyway.
local SOUND_TIMEOUT = 30

local random = Random.new()

local ConquerorFx = {}

function ConquerorFx.Asset(name: string): Instance?
	return EffectAssets.Find("Models", "Conqueror", name)
end

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- An invisible anchored stud to hang emitters on. The caller destroys it.
function ConquerorFx.Holder(position: Vector3): Part
	local holder = Instance.new("Part")
	holder.Name = "ConquerorFx"
	holder.Size = Vector3.one
	holder.Transparency = 1
	holder.CFrame = CFrame.new(position)
	prepare(holder)
	holder.Parent = World.Effects()
	return holder
end

-- Every emitter under `root`, tinted when a colour is given.
function ConquerorFx.Emitters(root: Instance, color: Color3?): { ParticleEmitter }
	local emitters: { ParticleEmitter } = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			if color then
				descendant.Color = ColorSequence.new(color)
			end
			table.insert(emitters, descendant)
		end
	end
	return emitters
end

-- The HakiBall sphere swelling to `scale` (the scale of its mesh) while it fades.
function ConquerorFx.Shockwave(position: Vector3, scale: number)
	local template = ConquerorFx.Asset("HakiBall")
	if not template or not template:IsA("BasePart") then
		return
	end

	local ball = template:Clone()
	prepare(ball)
	ball.CFrame = CFrame.new(position)
	ball.Parent = World.Effects()

	local mesh = ball:FindFirstChildWhichIsA("DataModelMesh")
	if mesh then
		TweenService:Create(mesh, WAVE_INFO, { Scale = Vector3.one * scale }):Play()
	else
		TweenService:Create(ball, WAVE_INFO, { Size = Vector3.one * scale }):Play()
	end
	TweenService:Create(ball, WAVE_INFO, { Transparency = 1 }):Play()
	Debris:AddItem(ball, WAVE_SECONDS + 0.1)
end

-- The MeatyRing growing from nothing to `size` at a random tilt while it fades.
function ConquerorFx.Ring(position: Vector3, size: Vector3, color: Color3)
	local template = ConquerorFx.Asset("MeatyRing")
	if not template or not template:IsA("BasePart") then
		return
	end

	local turn = math.pi * 2
	local ring = template:Clone()
	prepare(ring)
	ring.Color = color
	ring.Size = Vector3.zero
	ring.CFrame = CFrame.new(position)
		* CFrame.Angles(random:NextNumber(0, turn), random:NextNumber(0, turn), random:NextNumber(0, turn))
	ring.Parent = World.Effects()

	TweenService:Create(ring, RING_INFO, { Transparency = 1, Size = size }):Play()
	Debris:AddItem(ring, WAVE_SECONDS + 0.1)
end

-- A sound of SoundConfig.Conqueror at a point of the world. Unknown names play nothing.
function ConquerorFx.PlaySound(name: string, position: Vector3)
	local sounds = (SoundConfig :: any).Conqueror
	local definition = sounds and sounds[name]
	if type(definition) ~= "table" or type(definition.Id) ~= "string" then
		return
	end

	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain

	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume or 1
	sound.PlaybackSpeed = definition.Speed or 1
	sound.RollOffMaxDistance = SOUND_REACH
	sound.Parent = holder
	sound.Ended:Once(function()
		holder:Destroy()
	end)
	sound:Play()
	Debris:AddItem(holder, SOUND_TIMEOUT)
end

-- The screen tint of the technique, in Lighting on this client only. Returns the copy
-- (nil when the template is missing); the caller destroys it.
function ConquerorFx.Tint(): ColorCorrectionEffect?
	local template = ConquerorFx.Asset(TINT_TEMPLATE)
	if not template or not template:IsA("ColorCorrectionEffect") then
		return nil
	end
	local tint = template:Clone()
	tint.Enabled = true
	tint.Parent = Lighting
	return tint
end

return ConquerorFx
