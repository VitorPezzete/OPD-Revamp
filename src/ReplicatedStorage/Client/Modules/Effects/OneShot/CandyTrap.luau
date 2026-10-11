--!strict
--[[
	Candy fruit - Syrup Trap.
	params: { Diameter: number, GrowTime: number, HoldTime: number, ShrinkTime: number,
	          Haki: boolean, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Candy.Power4.Pool (a cylinder lying
	flat: its X axis is the thickness; it holds a "CandyParticle" emitter).

	`origin` is the centre of the pool (3 studs under the caster's root). As in the legacy
	game the diameter grows linearly to `Diameter` while the thickness grows to 7 studs,
	the pool then stays for `HoldTime` and everything shrinks back at the same rate.

	First fruit color on the pool, both on the emitter; dark with armament haki.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local THICKNESS = 7
local MIN_AXIS = 0.1
local FLAT_ROTATION = CFrame.Angles(0, 0, math.rad(-90))

return function(origin: Vector3, params: { [string]: any }?)
	if not params or type(params.Diameter) ~= "number" or params.Diameter <= 0 then
		return
	end
	local diameter: number = params.Diameter
	local growTime: number = if type(params.GrowTime) == "number" then params.GrowTime else 10
	local holdTime: number = if type(params.HoldTime) == "number" then params.HoldTime else 5
	local shrinkTime: number = if type(params.ShrinkTime) == "number" then params.ShrinkTime else 10
	if growTime <= 0 or shrinkTime <= 0 or holdTime < 0 then
		return
	end

	local template = EffectAssets.FindFruit("Candy", "Power4", "Pool")
	if not template or not template:IsA("BasePart") then
		return
	end

	local pool = template:Clone()
	pool.Anchored = true
	pool.CanCollide = false
	pool.CanQuery = false
	pool.CanTouch = false

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	if params.Haki then
		pool.Color = HAKI_COLOR
	elseif primary then
		pool.Color = primary
	end
	for _, descendant in pool:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("ValueBase") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") and primary and secondary and not params.Haki then
			descendant.Color = FruitColor.ToSequence(primary, secondary)
		end
	end

	pool.Size = Vector3.new(MIN_AXIS, MIN_AXIS, MIN_AXIS)
	pool.CFrame = CFrame.new(origin) * FLAT_ROTATION
	pool.Parent = World.Effects()

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - started
		local alpha = 1
		if elapsed < growTime then
			alpha = elapsed / growTime
		elseif elapsed >= growTime + holdTime + shrinkTime then
			connection:Disconnect()
			pool:Destroy()
			return
		elseif elapsed > growTime + holdTime then
			alpha = 1 - (elapsed - growTime - holdTime) / shrinkTime
		end

		local across = math.max(diameter * alpha, MIN_AXIS)
		pool.Size = Vector3.new(math.max(THICKNESS * alpha, MIN_AXIS), across, across)
	end)
end
