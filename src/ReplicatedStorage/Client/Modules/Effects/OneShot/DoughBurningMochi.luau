--!strict
--[[
	Dough fruit - a Burning Mochi in flight.
	params: { Direction: Vector3 (unit), Speed: number (studs per second),
	          Distance: number (the furthest the server lets it fly), Radius: number,
	          Haki: boolean, Colors: string, Caster: Model }
	`origin` is where the server launched it from (the right hand).

	The fist the charge showed (Effects.Status.DoughCharging) leaves the arm: a fresh copy
	of ReplicatedStorage.Assets.Models.Fruits.Dough.Power1.Arm without its Cover, its launch
	fire on and one shockwave, flying nose first with the "Mochi Burning" / "Mochi Spining"
	loops on it, and "Ignite" where it left.

	The server decides where it explodes (Effects.OneShot.DoughExplosion). This copy flies
	the same line at the same speed and stops at the first thing in its way that is not
	its user, or at Distance, whichever comes first - the same test the server runs.

	The user's own client also plays the throw clip (PunchRight at three times its speed).
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local FLIGHT_ANGLES = CFrame.Angles(math.rad(90), math.rad(-90), math.rad(180))
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local IGNITE_LIFETIME = 2
local THROW_SPEED = 3
local THROW_FADE = 0.1

local function makeSound(name: string, parent: Instance)
	local definition = (SoundConfig :: any).Fruits.Dough[name]
	if not definition then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Looped = definition.Looped == true
	sound.Parent = parent
	sound:Play()
end

local function tint(emitter: Instance?, color: Color3)
	if emitter and emitter:IsA("ParticleEmitter") then
		emitter.Color = ColorSequence.new(color)
	end
end

local function paint(part: Instance?, color: Color3, material: Enum.Material?)
	if part and part:IsA("BasePart") then
		part.Color = color
		if material then
			part.Material = material
		end
	end
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local direction, speed, distance = params.Direction, params.Speed, params.Distance
	if typeof(direction) ~= "Vector3" or type(speed) ~= "number" or type(distance) ~= "number" then
		return
	end
	if direction.Magnitude < 1e-4 or speed <= 0 then
		return
	end
	direction = direction.Unit
	local radius: number = if type(params.Radius) == "number" then params.Radius else 1

	local caster = params.Caster
	local casterModel: Model? = if typeof(caster) == "Instance" and caster:IsA("Model") then caster else nil
	if casterModel and casterModel == Players.LocalPlayer.Character then
		local animator = Animations.FindAnimator(casterModel)
		if animator then
			Animations.Play(animator, (AnimationConfig :: any).Fruits.Dough.PunchRight, THROW_FADE, 1, THROW_SPEED)
		end
	end

	local ignite = Instance.new("Attachment")
	ignite.WorldPosition = origin
	ignite.Parent = Workspace.Terrain
	makeSound("Ignite", ignite)
	Debris:AddItem(ignite, IGNITE_LIFETIME)

	local template = EffectAssets.FindFruit("Dough", "Power1", "Arm")
	if not template or not template:IsA("Model") then
		return
	end
	local fist = template:Clone()
	local core = fist.PrimaryPart or fist:FindFirstChild("Hot")
	if not core or not core:IsA("BasePart") then
		fist:Destroy()
		return
	end
	local cover = fist:FindFirstChild("Cover")
	if cover then
		cover:Destroy()
	end
	for _, descendant in fist:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end

	local top, knuckles = fist:FindFirstChild("Top"), fist:FindFirstChild("Fist")
	local launch = core:FindFirstChild("LaunchEffects")
	local launchFire = launch and launch:FindFirstChild("Fire")
	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	if primary and secondary then
		paint(top, primary)
		paint(knuckles, primary)
		paint(core, secondary)
		tint(core:FindFirstChild("Mochi"), primary)
		tint(core:FindFirstChild("Fire"), secondary)
		tint(launchFire, secondary)
	end
	if params.Haki then
		paint(top, HAKI_COLOR, Enum.Material.SmoothPlastic)
		paint(knuckles, HAKI_COLOR, Enum.Material.SmoothPlastic)
	end

	-- Places the model by its core part, as the source did (SetPrimaryPartCFrame).
	local pivotOffset = core.CFrame:ToObjectSpace(fist:GetPivot())
	local function place(position: Vector3)
		fist:PivotTo(CFrame.lookAt(position, position + direction) * FLIGHT_ANGLES * pivotOffset)
	end
	place(origin)
	fist.Parent = World.Effects()

	if launchFire and launchFire:IsA("ParticleEmitter") then
		launchFire.Enabled = true
	end
	local shockwave = launch and launch:FindFirstChild("Shockwave")
	if shockwave and shockwave:IsA("ParticleEmitter") then
		shockwave:Emit(1)
	end
	makeSound("MochiBurning", core)
	makeSound("MochiSpining", core)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local ignored: { Instance } = { fist }
	local effects = World.Effects()
	if effects ~= Workspace then
		table.insert(ignored, effects)
	end
	if casterModel then
		table.insert(ignored, casterModel)
	end
	rayParams.FilterDescendantsInstances = ignored

	local position = origin
	local travelled = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		local step = math.min(speed * deltaTime, distance - travelled)
		if step <= 0 then
			connection:Disconnect()
			fist:Destroy()
			return
		end
		local displacement = direction * step
		local met = Workspace:Spherecast(position, radius, displacement, rayParams)
		position += displacement
		travelled += step
		place(position)
		if met or travelled >= distance then
			connection:Disconnect()
			fist:Destroy()
		end
	end)
end
