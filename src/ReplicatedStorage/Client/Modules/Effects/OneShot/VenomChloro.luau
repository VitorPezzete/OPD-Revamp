--!strict
--[[
	Venom fruit - Chloro Ball: the thrown ball of poison.
	origin: the hand it leaves from.
	params: { Direction: Vector3, Size: number (diameter), Speed: number, Decay: number,
	          Gravity: number, Floor: number (height under which it is gone),
	          Lifetime: number, Demon: boolean, Hand: "Right" | "Left", Colors: string,
	          Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Venom.Power4.ChrolloBall (a part with
	a VenomHydraCharge ParticleEmitter).

	The ball follows the same closed formula as the server (Abilities/Venom/Chloro Ball):
	a fast throw slowed by drag and bent down by gravity, through walls and ground like
	the legacy non-colliding part, until it falls under the world (or its lifetime ends).
	Its particles are a quarter of its diameter, as in the legacy game.
	Colors: first fruit color (particles: both); with Venom Demon the second one
	(particles swapped), or a dull red by default.

	The thrower's own client also plays the throw clip of that hand (replicated by the
	Animator), at the legacy speed.
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

local DEMON_COLOR = Color3.fromRGB(163, 75, 75)
local THROW_FADE = 0.01
local THROW_SPEED = 32

return function(origin: Vector3, params: { [string]: any }?)
	local direction = params and params.Direction
	if not params or typeof(direction) ~= "Vector3" or direction.Magnitude < 0.05 then
		return
	end

	local localPlayer = Players.LocalPlayer
	local caster = params.Caster
	if typeof(caster) == "Instance" and localPlayer and caster == localPlayer.Character then
		local animator = Animations.FindAnimator(caster)
		if animator then
			local anims = AnimationConfig.FruitAnims
			local throw = if params.Hand == "Left" then anims.Punch1LeftPunch else anims.Punch1RightPunch
			Animations.Play(animator, throw, THROW_FADE, 1, THROW_SPEED)
		end
	end

	local size = if type(params.Size) == "number" then math.clamp(params.Size, 1, 2000) else 1
	local speed = if type(params.Speed) == "number" then params.Speed else 600
	local decay = if type(params.Decay) == "number" and params.Decay > 0 then params.Decay else 0.603
	local gravity = if type(params.Gravity) == "number" then params.Gravity else Workspace.Gravity
	local floor = if type(params.Floor) == "number" then params.Floor else Workspace.FallenPartsDestroyHeight
	local lifetime = if type(params.Lifetime) == "number" then math.clamp(params.Lifetime, 0.1, 30) else 10

	local template = EffectAssets.FindFruit("Venom", "Power4", "ChrolloBall")
	if not template or not template:IsA("BasePart") then
		return
	end

	local ball = template:Clone()
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Size = Vector3.new(size, size, size)

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local demon = params.Demon == true
	if primary and secondary then
		ball.Color = if demon then secondary else primary
	elseif demon then
		ball.Color = DEMON_COLOR
	end
	for _, descendant in ball:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Size = NumberSequence.new(math.max(size / 4, 1))
			if primary and secondary then
				descendant.Color = if demon
					then FruitColor.ToSequence(secondary, primary)
					else FruitColor.ToSequence(primary, secondary)
			elseif demon then
				descendant.Color = ColorSequence.new(DEMON_COLOR)
			end
		end
	end

	local unit = direction.Unit
	ball.CFrame = CFrame.new(origin)
	ball.Parent = World.Effects()

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local age = os.clock() - started
		local fade = 1 - math.exp(-decay * age)
		local position = origin
			+ unit * (speed / decay * fade)
			- Vector3.new(0, gravity / decay * (age - fade / decay), 0)

		-- NaN compares false: without a destroy height only the lifetime ends it.
		if not ball.Parent or age >= lifetime or position.Y + size / 2 < floor then
			connection:Disconnect()
			ball:Destroy()
			return
		end
		ball.CFrame = CFrame.new(position)
	end)
end
