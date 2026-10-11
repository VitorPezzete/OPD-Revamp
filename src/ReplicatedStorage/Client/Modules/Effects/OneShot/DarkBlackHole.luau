--!strict
--[[
	Dark fruit - Black Hole.
	params: { Diameter: number, GrowTime: number, ShrinkTime: number, Colors: string,
	          Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Dark.Power3.Pool (a cylinder lying
	flat: its X axis is the thickness).

	`origin` is the centre of the pool (3 studs under the caster's root). The diameter
	grows linearly to `Diameter` over `GrowTime`, then shrinks back at a constant rate
	over `ShrinkTime`; meanwhile the thickness breathes between 1 and 1.5 studs. The
	closed pool lingers for 2 s (its particles), as in the legacy game.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local MIN_THICKNESS = 1
local MAX_THICKNESS = 1.5
local MIN_WIDTH = 0.1
local LINGER = 2
local FLAT_ROTATION = CFrame.Angles(0, 0, math.rad(-90))

return function(origin: Vector3, params: { [string]: any }?)
	if not params or type(params.Diameter) ~= "number" or params.Diameter <= 0 then
		return
	end
	local diameter: number = params.Diameter
	local growTime: number = if type(params.GrowTime) == "number" and params.GrowTime > 0 then params.GrowTime else 1.5
	local shrinkTime: number = if type(params.ShrinkTime) == "number" and params.ShrinkTime > 0
		then params.ShrinkTime
		else diameter / 60

	local template = EffectAssets.FindFruit("Dark", "Power3", "Pool")
	if not template or not template:IsA("BasePart") then
		return
	end

	local pool = template:Clone()
	pool.Anchored = true
	pool.CanCollide = false
	pool.CanQuery = false
	pool.CanTouch = false

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	if primary then
		pool.Color = primary
	end
	for _, descendant in pool:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") and primary and secondary then
			descendant.Color = FruitColor.ToSequence(primary, secondary)
		end
	end

	local placement = CFrame.new(origin) * FLAT_ROTATION
	pool.Size = Vector3.new(MIN_THICKNESS, MIN_WIDTH, MIN_WIDTH)
	pool.CFrame = placement
	pool.Parent = World.Effects()

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - started
		if elapsed >= growTime + shrinkTime then
			connection:Disconnect()
			pool.Size = Vector3.new(MIN_THICKNESS, MIN_WIDTH, MIN_WIDTH)
			task.delay(LINGER, function()
				pool:Destroy()
			end)
			return
		end

		local alpha = if elapsed <= growTime then elapsed / growTime else 1 - (elapsed - growTime) / shrinkTime
		local width = math.max(diameter * alpha, MIN_WIDTH)
		local wave = (math.sin(os.clock() * 2) + 1) / 2
		pool.Size = Vector3.new(MIN_THICKNESS + (MAX_THICKNESS - MIN_THICKNESS) * wave, width, width)
		pool.CFrame = placement
	end)
end
