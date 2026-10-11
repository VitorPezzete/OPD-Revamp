--!strict
--[[
	Raid bosses (Bosses/_Global) - Candy: the giant jawbreaker in flight.
	params: { Velocity: Vector3 (launch velocity), Gravity: number, Drag: number (share of
	          the velocity lost per second), Lifetime: number, Scale: number, Haki: boolean,
	          Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Candy.Power3.CandyJawbreaker, each
	axis at least 4 studs, times Scale (about 127 studs across for the boss).

	Unlike a player's jawbreaker, which is a solid physical part, the boss's ball collided
	with nothing: thrown at 600 studs per second it loses half a percent of its speed per
	frame, falls and goes through the map and through characters, until it is removed
	after Lifetime seconds. `origin` is the hand it leaves. The copy follows the curve the
	server sweeps for the hits, recomputed from the clock every frame.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local FALLBACK_COLOR = Color3.fromRGB(31, 128, 29)
local FALLBACK_DIAMETER = 50
local MIN_AXIS = 4
local MAX_LIFETIME = 10

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Velocity) ~= "Vector3" then
		return
	end
	local velocity: Vector3 = params.Velocity
	local gravity: number = if type(params.Gravity) == "number" then params.Gravity else Workspace.Gravity
	local drag: number = if type(params.Drag) == "number" then math.max(params.Drag, 0) else 0
	local lifetime: number = if type(params.Lifetime) == "number" then math.clamp(params.Lifetime, 0.1, MAX_LIFETIME) else 6
	local scale: number = if type(params.Scale) == "number" and params.Scale > 0 then params.Scale else 1

	local ball: BasePart
	local template = EffectAssets.FindFruit("Candy", "Power3", "CandyJawbreaker")
	if template and template:IsA("BasePart") then
		ball = template:Clone()
		for _, descendant in ball:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("ValueBase") or descendant:IsA("JointInstance") then
				descendant:Destroy()
			end
		end
	else
		local plain = Instance.new("Part")
		plain.Shape = Enum.PartType.Ball
		plain.Material = Enum.Material.SmoothPlastic
		plain.Size = Vector3.new(FALLBACK_DIAMETER, FALLBACK_DIAMETER, FALLBACK_DIAMETER)
		ball = plain
	end

	local authored = ball.Size
	ball.Size = Vector3.new(
		math.max(authored.X, MIN_AXIS) * scale,
		math.max(authored.Y, MIN_AXIS) * scale,
		math.max(authored.Z, MIN_AXIS) * scale
	)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	ball.Color = if params.Haki then HAKI_COLOR else primary or FALLBACK_COLOR

	local rotation = ball.CFrame.Rotation
	ball.CFrame = rotation + origin
	ball.Parent = World.Effects()

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local age = os.clock() - started
		if age >= lifetime or not ball.Parent then
			connection:Disconnect()
			ball:Destroy()
			return
		end

		-- Same curve as `ballistic` in Bosses/_Global.
		local position: Vector3
		if drag > 1e-6 then
			local decayed = (1 - math.exp(-drag * age)) / drag
			position = origin + velocity * decayed - Vector3.yAxis * (gravity / drag * (age - decayed))
		else
			position = origin + velocity * age - Vector3.yAxis * (gravity * age * age / 2)
		end
		if position.Y < Workspace.FallenPartsDestroyHeight then
			connection:Disconnect()
			ball:Destroy()
			return
		end
		ball.CFrame = rotation + position
	end)
end
