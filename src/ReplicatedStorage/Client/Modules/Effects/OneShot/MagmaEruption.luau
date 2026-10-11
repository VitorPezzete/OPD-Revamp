--!strict
--[[
	Magma fruit - Great Eruption, the flying fist.
	params: { Direction: Vector3, Speed: number, Drag: number, Gravity: number,
	          Lifetime: number, Percent: number (charge 0-1), Multiplier: number
	          (affinity * level scale), Haki: boolean, Hand: "Right" | "Left",
	          Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Magma.Power1["Great Eruption"] (a
	ball with a "Magma fist" emitter).

	Size, as in the legacy game: max(template size * Percent, 4) * Multiplier per axis;
	the particles follow the same rule from their first size keypoint. First fruit color
	(particles: both colors); dark with armament haki.

	The copy follows the curve the server sweeps for the hits (see Abilities/Magma/Great
	Eruption): launched at Speed, slowed by Drag and pulled down by Gravity, through
	characters and through the map, until it falls under the world (or Lifetime seconds).

	Sounds: "Magma Release" at the thrower, "Magma Flow" looping on the fist. The
	thrower's own client also turns towards the throw and plays the punch animation of
	that hand (replicated by the Animator).
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local MIN_SIZE = 4
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local HAKI_PARTICLES = ColorSequence.new(Color3.new(0.051, 0, 0.133), Color3.new(0.098, 0.067, 0.098))
local RELEASE_SOUND_SECONDS = 2.5
-- The legacy punch clip was played 32 times faster than authored.
local PUNCH_SPEED = 32

local function playSound(name: string, parent: Instance): Sound?
	local definition = (SoundConfig :: any).SFX.Elemental.Magma[name]
	if not definition then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.Looped = definition.Looped == true
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Parent = parent
	sound:Play()
	return sound
end

local function throw(character: Model, direction: Vector3, left: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and humanoid and not humanoid.Sit then
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude > 0.05 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end

	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local anims = AnimationConfig.FruitAnims
		Animations.Play(animator, if left then anims.Punch1LeftPunch else anims.Punch1RightPunch, 0.01, 1, PUNCH_SPEED)
	end
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local direction = params.Direction
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-3 then
		return
	end
	local unit = direction.Unit
	local speed: number = if type(params.Speed) == "number" and params.Speed > 0 then params.Speed else 800
	local drag: number = if type(params.Drag) == "number" and params.Drag > 0 then params.Drag else 0.603
	local gravity: number = if type(params.Gravity) == "number" then params.Gravity else Workspace.Gravity
	local lifetime: number = if type(params.Lifetime) == "number" then math.clamp(params.Lifetime, 0.1, 10) else 3
	local percent: number = if type(params.Percent) == "number" then params.Percent else 1
	local multiplier: number = if type(params.Multiplier) == "number" then params.Multiplier else 1

	local caster = params.Caster
	if typeof(caster) == "Instance" and caster:IsA("Model") then
		local root = caster:FindFirstChild("HumanoidRootPart")
		if root then
			local release = playSound("Magma Release", root)
			if release then
				Debris:AddItem(release, RELEASE_SOUND_SECONDS)
			end
		end
		if caster == Players.LocalPlayer.Character then
			throw(caster, unit, params.Hand == "Left")
		end
	end

	local template = EffectAssets.FindFruit("Magma", "Power1", "Great Eruption")
	if not template or not template:IsA("BasePart") then
		return
	end

	local fist = template:Clone()
	fist.Anchored = true
	fist.CanCollide = false
	fist.CanQuery = false
	fist.CanTouch = false

	local base = template.Size
	fist.Size = Vector3.new(
		math.max(base.X * percent, MIN_SIZE),
		math.max(base.Y * percent, MIN_SIZE),
		math.max(base.Z * percent, MIN_SIZE)
	) * multiplier

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	if params.Haki then
		fist.Color = HAKI_COLOR
	elseif primary then
		fist.Color = primary
	end

	for _, descendant in fist:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") then
			local keypoint = descendant.Size.Keypoints[1]
			local baseSize = if keypoint then keypoint.Value else 1
			descendant.Size = NumberSequence.new(math.max(baseSize * percent, MIN_SIZE) * multiplier)
			if params.Haki then
				descendant.Color = HAKI_PARTICLES
			elseif primary and secondary then
				descendant.Color = FruitColor.ToSequence(primary, secondary)
			end
		end
	end

	local rotation = CFrame.lookAt(origin, origin + unit).Rotation
	fist.CFrame = rotation + origin
	fist.Parent = World.Effects()
	playSound("Magma Flow", fist)

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local age = os.clock() - started
		if age >= lifetime or not fist.Parent then
			connection:Disconnect()
			fist:Destroy()
			return
		end
		local decayed = 1 - math.exp(-drag * age)
		local position = origin
			+ unit * (speed / drag * decayed)
			- Vector3.yAxis * (gravity / drag * (age - decayed / drag))
		if position.Y < Workspace.FallenPartsDestroyHeight then
			connection:Disconnect()
			fist:Destroy()
			return
		end
		fist.CFrame = rotation + position
	end)
end
