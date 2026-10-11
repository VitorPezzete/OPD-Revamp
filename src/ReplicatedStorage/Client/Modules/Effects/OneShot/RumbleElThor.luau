--!strict
--[[
	Rumble fruit - El Thor, the charged strike: a thunder cloud gathers over the aim
	point, and Delay seconds later the bolt comes down.
	origin: the aim point. params: { Charge: number (20-200), Affinity: number (sniper),
	Scale: number (sniper level / cap), Place: number (height of the bolt's center part),
	Delay: number, Colors: string, Caster: Model }

	Templates (ReplicatedStorage.Assets.Models.Fruits.Rumble.Power2.Charged), each a part
	sized through its mesh: Cloud, RumbleElThor (the bolt, long axis X), Wisp, Ring.
	With a = Affinity, p = Charge / 200, s = Scale, as in the legacy game:
	- cloud   at clamp(125 * a * p, 75, 260) studs up, mesh (150, 45, 150) * a * p,
	          growing the last 10% and fading in while it waits; second fruit color;
	- bolt    mesh (clamp(130 * a * p, 75, 260) * 19.23, w, w) with w = 800 * a * p * s,
	          standing on its end at Place; first fruit color;
	- wisp    mesh 2 * a * p at the foot of the bolt, turning for two seconds towards
	          `CFrame.Angles(0, 180, 0)` - 180 RADIANS in the legacy script, which is a
	          turn of about 127 degrees clockwise;
	- for two seconds, every 0.15 s (13 times): a half-transparent copy of the bolt that
	  doubles in width and fades (its length starts at clamp(130 * p, 75, 260), without
	  the affinity, and stretches to the bolt's), and a ring on the ground that widens to
	  4 * a * p and fades.
	Only the part colors are set (cloud: second fruit color, bolt and copies: first), as
	in the legacy game; the meshes keep their own vertex color.
	Everything is removed 2 s after the strike. The sounds are "Thunders" (cloud) and
	"Thunder Strike" (bolt). If the bolt template is missing a thick plain bolt is drawn.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local drawBolt = require(script.Parent.RumbleBolt)

local CHARGE_MAX = 200
local MESH_UNIT = 19.23076923
local STRIKE_LIFE = 2
local PULSES = 13
local PULSE_INTERVAL = 0.15
local PULSE_TIME = 0.4
local PULSE_LIFE = 0.75
local LINEAR = Enum.EasingStyle.Linear

local function playSound(name: string, parent: Instance, life: number)
	local sfx = (SoundConfig :: any).SFX
	local group = sfx and sfx.Elemental and sfx.Elemental.Rumble
	local definition = group and group[name]
	if not definition then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume or 0.5
	sound.PlaybackSpeed = definition.Speed or 1
	sound.RollOffMaxDistance = 1500
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, life)
end

-- A copy of one template, anchored and inert, with its mesh (nil if either is missing).
local function build(name: string): (BasePart?, DataModelMesh?)
	local template = EffectAssets.FindFruit("Rumble", "Power2", "Charged", name)
	if not template or not template:IsA("BasePart") then
		return nil, nil
	end

	local part = template:Clone()
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local mesh: any = part:FindFirstChildWhichIsA("DataModelMesh")
	return part, mesh
end

return function(origin: Vector3, params: { [string]: any }?)
	local options: { [string]: any } = params or {}
	local charge: number = if type(options.Charge) == "number" then options.Charge else 20
	local affinity: number = if type(options.Affinity) == "number" then options.Affinity else 1
	local scale: number = if type(options.Scale) == "number" then options.Scale else 1
	local place: number = if type(options.Place) == "number" then options.Place else 160
	local strikeDelay: number = if type(options.Delay) == "number" then math.clamp(options.Delay, 0, 5) else 1.5
	local percent = math.clamp(charge / CHARGE_MAX, 0, 1)
	local primary, secondary = FruitColor.Parse(if type(options.Colors) == "string" then options.Colors else "")

	local size = affinity * percent
	local boltLength = math.clamp(130 * size, 75, 260) * MESH_UNIT
	local boltWidth = 800 * size * scale
	local ghostLength = math.clamp(130 * percent, 75, 260) * MESH_UNIT

	-- The cloud.
	local cloud, cloudMesh = build("Cloud")
	if cloud then
		cloud.CFrame = CFrame.new(origin + Vector3.new(0, math.clamp(125 * size, 75, 260), 0))
		cloud.Transparency = 1
		if secondary then
			cloud.Color = secondary
		end
		if cloudMesh then
			local full = Vector3.new(150, 45, 150) * size
			cloudMesh.Scale = full / 1.1
			TweenService:Create(cloudMesh, TweenInfo.new(1, LINEAR), { Scale = full }):Play()
		end
		cloud.Parent = World.Effects()
		TweenService:Create(cloud, TweenInfo.new(0.75, LINEAR), { Transparency = 0 }):Play()
		Debris:AddItem(cloud, strikeDelay + STRIKE_LIFE)
		playSound("Thunders", cloud, strikeDelay + STRIKE_LIFE)
	end

	task.wait(strikeDelay)

	-- The bolt.
	local boltFrame = CFrame.new(origin + Vector3.new(0, place, 0)) * CFrame.Angles(0, 0, math.rad(-90))
	local bolt, boltMesh = build("RumbleElThor")
	if bolt then
		bolt.CFrame = boltFrame
		if primary then
			bolt.Color = primary
		end
		if boltMesh then
			boltMesh.Scale = Vector3.new(boltLength, boltWidth, boltWidth)
		end
		bolt.Parent = World.Effects()
		Debris:AddItem(bolt, STRIKE_LIFE)
		playSound("Thunder Strike", bolt, STRIKE_LIFE + 4)
	else
		drawBolt(origin + Vector3.new(0, math.clamp(125 * size, 75, 260), 0), {
			Target = origin,
			Color = primary,
			Thickness = math.clamp(boltWidth / MESH_UNIT, 1, 40),
			Step = 12,
			Jitter = 4,
			Life = STRIKE_LIFE,
			Shrink = true,
		})
	end

	local wisp, wispMesh = build("Wisp")
	if wisp then
		wisp.CFrame = CFrame.new(origin + Vector3.new(0, (charge - 20) / 12, 0))
		if wispMesh then
			wispMesh.Scale = Vector3.new(2, 2, 2) * size
		end
		wisp.Parent = World.Effects()
		TweenService:Create(wisp, TweenInfo.new(STRIKE_LIFE, LINEAR), {
			CFrame = wisp.CFrame * CFrame.Angles(0, 180, 0),
		}):Play()
		Debris:AddItem(wisp, STRIKE_LIFE)
	end

	-- Shock waves.
	for _ = 1, PULSES do
		local ghost, ghostMesh = build("RumbleElThor")
		if ghost then
			ghost.CFrame = boltFrame
			ghost.Transparency = 0.5
			if primary then
				ghost.Color = primary
			end
			if ghostMesh then
				ghostMesh.Scale = Vector3.new(ghostLength, boltWidth, boltWidth)
				TweenService:Create(ghostMesh, TweenInfo.new(PULSE_TIME, LINEAR), {
					Scale = Vector3.new(boltLength, boltWidth * 2, boltWidth * 2),
				}):Play()
			end
			ghost.Parent = World.Effects()
			TweenService:Create(ghost, TweenInfo.new(PULSE_TIME, LINEAR), { Transparency = 1 }):Play()
			Debris:AddItem(ghost, PULSE_LIFE)
		end

		local ring, ringMesh = build("Ring")
		if ring then
			ring.CFrame = CFrame.new(origin - Vector3.new(0, 15, 0))
			if ringMesh then
				ringMesh.Scale = Vector3.new(0.1, 0.1, 0.1)
				TweenService:Create(ringMesh, TweenInfo.new(PULSE_TIME, LINEAR), {
					Scale = Vector3.new(4, 4, 4) * size,
				}):Play()
			end
			ring.Parent = World.Effects()
			TweenService:Create(ring, TweenInfo.new(PULSE_TIME, LINEAR), { Transparency = 1 }):Play()
			Debris:AddItem(ring, PULSE_LIFE)
		end

		task.wait(PULSE_INTERVAL)
	end
end
