--!strict
--[[
	Quake fruit - Quake Stomp.
	params: { Ground: Vector3 (landing point), FallTime: number, Charge: number (4-60),
	          Percent: number (charge / 60), Affinity: number, LevelScale: number,
	          Haki: boolean, Colors: string, Caster: Model }

	`origin` is where the shock ball starts (5 studs under the caster's root). As in the
	legacy game:
	- a 3 stud force-field ball falls to Ground in FallTime seconds, then swells to
	  20 * LevelScale * Affinity * Percent studs in 0.25 s and vanishes;
	- cracks spread flat on the ground (force Charge / 6), with the "Quake Crack" and
	  "Quake Earth Shake" sounds;
	- clamp(23 * Percent, 16, 23) rocks jut out in a ring of radius
	  clamp(20 * Percent * Affinity, 5, 40): each is the RockTypeA model sized
	  (25, 125, 25) * Affinity * Percent, sunk 30 * Affinity * Percent studs and tilted
	  55 to 60 degrees; they stay 5 seconds and are solid, as the legacy server parts
	  were (each client collides its own character with its own copy).
	Template: ReplicatedStorage.Assets.Models.Fruits.Quake.Power3.RockTypeA.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local playCrack = require(script.Parent.QuakeCrack)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local BALL_SIZE = Vector3.new(3, 3, 3)
local SWELL_SECONDS = 0.25
local SWELL_SIZE = 20
local CRACK_DIVISOR = 6
local SHAKE_SOUND_SECONDS = 3.5

local ROCKS = 23
local ROCKS_MIN = 16
local RING_RADIUS = 20
local RING_MIN = 5
local RING_MAX = 40
local ROCK_SIZE = Vector3.new(25, 125, 25)
local ROCK_DEPTH = 30
local ROCK_SECONDS = 5

local random = Random.new()

local function newBall(material: Enum.Material, transparency: number): Part
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Material = material
	ball.Transparency = transparency
	ball.Color = Color3.fromRGB(255, 255, 255)
	ball.Size = BALL_SIZE
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	return ball
end

local function playAt(name: string, position: Vector3, seconds: number)
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
	Debris:AddItem(holder, seconds)
end

local function raiseRocks(ground: Vector3, percent: number, affinity: number, color: Color3?)
	local template = EffectAssets.FindFruit("Quake", "Power3", "RockTypeA")
	local power = affinity * percent
	if not template or not template:IsA("BasePart") or power <= 0 then
		return
	end

	local count = math.clamp(ROCKS * percent, ROCKS_MIN, ROCKS)
	local radius = math.clamp(RING_RADIUS * power, RING_MIN, RING_MAX)
	local base = ground - Vector3.new(0, ROCK_DEPTH * power, 0)

	local heading = 0
	for _ = 1, math.floor(count) do
		heading += 360 / count + random:NextInteger(0, 1)
		local radians = math.rad(heading)
		local outward = Vector3.new(math.sin(radians), 0, math.cos(radians))

		local rock = template:Clone()
		for _, descendant in rock:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		rock.Anchored = true
		rock.CanTouch = false
		rock.Size = ROCK_SIZE * power
		if color then
			rock.Color = color
		end

		local tilt = CFrame.Angles(
			0,
			math.rad(heading + random:NextNumber(90, 100)),
			math.rad(random:NextNumber(55, 60))
		)
		rock.CFrame = tilt + (base + outward * radius)
		rock.Parent = World.Effects()
		Debris:AddItem(rock, ROCK_SECONDS)
	end
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Ground) ~= "Vector3" then
		return
	end
	local ground: Vector3 = params.Ground
	local fallTime: number = if type(params.FallTime) == "number" then math.max(params.FallTime, 0.03) else 0.03
	local charge: number = if type(params.Charge) == "number" then params.Charge else 4
	local percent: number = if type(params.Percent) == "number" then params.Percent else charge / 60
	local affinity: number = if type(params.Affinity) == "number" then params.Affinity else 1
	local levelScale: number = if type(params.LevelScale) == "number" then params.LevelScale else 1
	local colors = if type(params.Colors) == "string" then params.Colors else ""
	local primary = FruitColor.Parse(colors)
	local color: Color3? = if params.Haki then HAKI_COLOR else primary

	local outer = newBall(Enum.Material.ForceField, 0.5)
	local inner = newBall(Enum.Material.Neon, 0.8)
	outer.Position = origin
	inner.Position = origin
	outer.Parent = World.Effects()
	inner.Parent = outer

	local fall = TweenInfo.new(fallTime, Enum.EasingStyle.Linear)
	TweenService:Create(outer, fall, { Position = ground }):Play()
	TweenService:Create(inner, fall, { Position = ground }):Play()
	task.wait(fallTime)

	inner:Destroy()
	local swell = math.max(SWELL_SIZE * levelScale * affinity * percent, BALL_SIZE.X)
	TweenService:Create(outer, TweenInfo.new(SWELL_SECONDS), { Size = Vector3.new(swell, swell, swell) }):Play()
	Debris:AddItem(outer, SWELL_SECONDS)

	playCrack(ground, {
		CFrame = CFrame.new(ground) * CFrame.Angles(math.rad(90), 0, 0),
		Force = charge / CRACK_DIVISOR,
		Haki = params.Haki,
		Colors = colors,
		Sound = true,
	})
	playAt("Quake Earth Shake", ground, SHAKE_SOUND_SECONDS)

	raiseRocks(ground, percent, affinity, color)
end
