--!strict
--[[
	Quake fruit - cracks in the air: 16 thin glowing lines radiating in a plane, each
	forking in two at its tip. Played on its own for Quake Punch and required by the
	other Quake one-shots (Tsunami, Stomp, Seismic), which call it directly.

	params: { CFrame: CFrame (centre; the cracks spread in its XY plane), Force: number
	          (length scale), Haki: boolean, Sound: boolean? (play "Quake Crack"),
	          Colors: string }

	As in the legacy `air_crack`: each line is Force / (1.2 .. 2.0) studs long, the 16
	main lines are spread around the circle with up to 30 degrees of jitter, the forks
	bend 1 to 30 degrees either way; they stay Force / 10 seconds and then fade over
	Force / 8.3 seconds.

	Template: ReplicatedStorage.Assets.Models.Fruits._Shared.Crack (the legacy
	Resources.Crack: a thin grey neon part); a plain part like it without the asset.
	First fruit color when the fruit has custom ones, dark with armament haki.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local BRANCHES = 16
local THICKNESS = 0.05
local JITTER_DEGREES = 30
local DEFAULT_COLOR = Color3.fromRGB(163, 162, 165)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local STAY_DIVISOR = 10
local FADE_DIVISOR = 8.3
local SOUND_SECONDS = 4

local random = Random.new()

local function playSound(name: string, position: Vector3)
	local definition = (SoundConfig :: any).SFX.Elemental.Quake[name]
	if not definition then
		return
	end

	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain

	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, SOUND_SECONDS)
end

local function findTemplate(): BasePart?
	local found = EffectAssets.FindFruit("_Shared", "Crack") or EffectAssets.FindFruit("Quake", "Crack")
	return if found and found:IsA("BasePart") then found else nil
end

local function line(template: BasePart?, cframe: CFrame, length: number, color: Color3?, into: { BasePart }): BasePart
	local part: BasePart
	if template then
		part = template:Clone()
	else
		local plain = Instance.new("Part")
		plain.Material = Enum.Material.Neon
		plain.Color = DEFAULT_COLOR
		plain.CastShadow = false
		part = plain
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	if color then
		part.Color = color
	end
	part.Size = Vector3.new(THICKNESS, length, THICKNESS)
	part.CFrame = cframe * CFrame.new(0, length / 2, 0)
	part.Parent = World.Effects()
	table.insert(into, part)
	return part
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.CFrame) ~= "CFrame" then
		return
	end
	local force: number = if type(params.Force) == "number" then params.Force else 1
	if force <= 0 then
		return
	end

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local color: Color3? = if params.Haki then HAKI_COLOR else primary
	local center: CFrame = params.CFrame
	local template = findTemplate()

	local function length(): number
		return force / random:NextNumber(1.2, 2)
	end

	local parts: { BasePart } = {}
	for count = 1, BRANCHES do
		local angle = 360 / BRANCHES * count + random:NextNumber(-JITTER_DEGREES, JITTER_DEGREES)
		local trunk = line(template, center * CFrame.Angles(0, 0, math.rad(angle)), length(), color, parts)
		local tip = trunk.CFrame * CFrame.new(0, trunk.Size.Y / 2, 0)

		line(template, tip * CFrame.Angles(0, 0, math.rad(random:NextNumber(1, JITTER_DEGREES))), length(), color, parts)
		line(template, tip * CFrame.Angles(0, 0, math.rad(-random:NextNumber(1, JITTER_DEGREES))), length(), color, parts)
	end

	if params.Sound then
		playSound("Quake Crack", origin)
	end

	local fade = force / FADE_DIVISOR
	task.delay(force / STAY_DIVISOR, function()
		local info = TweenInfo.new(fade, Enum.EasingStyle.Linear)
		for _, part in parts do
			TweenService:Create(part, info, { Transparency = 1 }):Play()
			Debris:AddItem(part, fade)
		end
	end)
end
