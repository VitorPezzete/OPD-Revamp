--!strict
--[[
	Gravity fruit - Gravity Assault, one rock.
	params: { Direction: Vector3, Speed: number, GhostTime: number, Size: number,
	          Delay: number, Haki: boolean, Probe: Vector3, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Gravity.Power3.Rock (a MeshPart with
	an Attachment holding a "GravityThrowable" emitter).

	`origin` is where the rock floats before the throw. As in the legacy game it comes
	out of the ground 5 studs below with a random rotation, grows to `Size` in 0.6 s and
	takes the material and color of the ground within 10 studs under `Probe` (the point
	the server found ground under; the dark of haki with armament haki).

	After `Delay` it is thrown exactly as the legacy server threw it: the part is let go
	with `Direction` * `Speed` as its velocity and nothing holding it up, so it arcs
	under gravity; it goes through everything for `GhostTime` (0.2 s), then collides,
	bounces and rolls. It sheds particles for 4 s and is removed 3 s later. The rock is a
	local part, simulated by each client for itself; the hits are the server's.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local World = require(ReplicatedStorage.Shared.Util.World)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local START_SIZE = Vector3.new(0.1, 0.1, 0.1)
local START_DEPTH = Vector3.new(0, 5, 0)
local GROUND_REACH = 10
local GROW_TIME = 0.6
local RISE_TIME = 0.1
-- Seconds after the throw.
local EMITTER_TIME = 4
local LIFETIME = 7

local random = Random.new()

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local direction = params.Direction
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-3 then
		return
	end
	local speed: number = if type(params.Speed) == "number" and params.Speed > 0 then params.Speed else 550
	local ghostTime: number = if type(params.GhostTime) == "number" then params.GhostTime else 0.2
	local size: number = if type(params.Size) == "number" then math.max(params.Size, 0.1) else 10
	local throwDelay: number = if type(params.Delay) == "number" then params.Delay else 0.8

	local template = EffectAssets.FindFruit("Gravity", "Power3", "Rock")
	if not template or not template:IsA("BasePart") then
		return
	end

	local rock = template:Clone()
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CanTouch = false

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = if typeof(params.Caster) == "Instance" then { params.Caster } else {}

	if params.Haki then
		rock.Color = HAKI_COLOR
	else
		local probe: Vector3 = if typeof(params.Probe) == "Vector3" then params.Probe else origin
		local ground = Workspace:Raycast(probe, Vector3.new(0, -GROUND_REACH, 0), rayParams)
		-- Terrain has no part color, and some of its materials cannot be put on a part.
		if ground and ground.Instance:IsA("BasePart") and not ground.Instance:IsA("Terrain") then
			rock.Material = ground.Instance.Material
			rock.Color = ground.Instance.Color
		end
	end

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local emitters: { ParticleEmitter } = {}
	for _, descendant in rock:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") then
			if primary then
				descendant.Color = ColorSequence.new(primary)
			end
			table.insert(emitters, descendant)
		end
	end

	local rotation = CFrame.Angles(
		random:NextNumber(0, math.pi * 2),
		random:NextNumber(0, math.pi * 2),
		random:NextNumber(0, math.pi * 2)
	)
	rock.Size = START_SIZE
	rock.CFrame = rotation + (origin - START_DEPTH)
	rock.Parent = World.Effects()

	TweenService:Create(rock, TweenInfo.new(GROW_TIME), { Size = Vector3.new(size, size, size) }):Play()
	TweenService:Create(rock, TweenInfo.new(RISE_TIME), { CFrame = rotation + origin }):Play()

	local velocity = direction.Unit * speed

	task.delay(throwDelay, function()
		if not rock.Parent then
			return
		end
		rock.Anchored = false
		rock.AssemblyLinearVelocity = velocity
		task.delay(ghostTime, function()
			rock.CanCollide = true
		end)
		task.delay(EMITTER_TIME, function()
			for _, emitter in emitters do
				emitter.Enabled = false
			end
		end)
		Debris:AddItem(rock, LIFETIME)
	end)
end
