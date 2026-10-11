--!strict
--[[
	Blood fruit - Blood Supernova: the drops of blood and their explosion. Cosmetic; the
	server evaluates the same straight-line motion without instances.

	Three messages share this effect, told apart by params:
	  throw     { Points: { Vector3 }, Target: Vector3?, Speed, Delay, MoveTime, Life,
	              Concentrate: boolean }
	            With Target, Points are where each drop appears and they all fly at
	            Target after Delay. Without it, every drop leaves `origin` and Points
	            are their directions; they stop after MoveTime.
	  detonate  { Detonate = true, Positions: { Vector3 }, Radius: number }
	  cancel    { Cancel = true }
	All carry Caster (the drops are remembered per caster) and Colors.

	Template: ReplicatedStorage.Assets.Models.Fruits.Blood.Power3.Supernova - a part
	with an "Attachment" of burst emitters, an "Enable" holder of trail emitters and an
	"Explosion" part that swells when the drop blows up.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local EXPLOSION_TIME = 0.5

-- Drops in the air, per caster character.
local live: { [Instance]: { BasePart } } = {}

local function clear(caster: Instance)
	local drops = live[caster]
	if drops then
		live[caster] = nil
		for _, drop in drops do
			drop:Destroy()
		end
	end
end

local function makeDrop(template: BasePart, colors: any, position: Vector3): BasePart
	local drop = template:Clone()
	drop.Anchored = true
	drop.CanCollide = false
	drop.CanQuery = false
	drop.CanTouch = false

	local explosion = drop:FindFirstChild("Explosion")
	if explosion and explosion:IsA("BasePart") then
		-- It swells to the size of the blast: it must not catch clicks or camera rays.
		explosion.CanCollide = false
		explosion.CanQuery = false
		explosion.CanTouch = false
	end

	local primary, secondary = FruitColor.Parse(if type(colors) == "string" then colors else "")
	if primary and secondary then
		for _, descendant in drop:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				descendant.Color = FruitColor.ToSequence(primary, secondary)
			end
		end
		if explosion and explosion:IsA("BasePart") then
			explosion.Color = primary
		end
	end

	-- PivotTo keeps the Explosion part with the drop whether or not it is welded.
	drop:PivotTo(CFrame.new(position))
	drop.Parent = World.Effects()
	return drop
end

local function explode(template: BasePart, colors: any, position: Vector3, radius: number)
	local drop = makeDrop(template, colors, position)
	local attachment = drop:FindFirstChild("Attachment")
	if attachment then
		for _, descendant in attachment:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				descendant.Enabled = true
			end
		end
	end

	local explosion = drop:FindFirstChild("Explosion")
	if explosion and explosion:IsA("BasePart") then
		explosion.Anchored = true
		TweenService:Create(explosion, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.one * radius * 2,
		}):Play()
		TweenService:Create(explosion, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	end
	Debris:AddItem(drop, EXPLOSION_TIME)
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Caster) ~= "Instance" then
		return
	end
	local caster: Instance = params.Caster

	local template = EffectAssets.FindFruit("Blood", "Power3", "Supernova")
	if not template or not template:IsA("BasePart") then
		return
	end

	if params.Cancel then
		clear(caster)
		return
	end

	if params.Detonate then
		clear(caster)
		local radius: number = if type(params.Radius) == "number" then params.Radius else 10
		if type(params.Positions) == "table" then
			for _, position in params.Positions do
				if typeof(position) == "Vector3" then
					explode(template, params.Colors, position, radius)
				end
			end
		end
		return
	end

	if type(params.Points) ~= "table" then
		return
	end
	local speed: number = if type(params.Speed) == "number" then params.Speed else 100
	local startDelay: number = if type(params.Delay) == "number" then params.Delay else 0
	local moveTime: number = if type(params.MoveTime) == "number" then params.MoveTime else 0.75
	local life: number = if type(params.Life) == "number" then params.Life else 4
	local target = if typeof(params.Target) == "Vector3" then params.Target else nil

	clear(caster)
	local drops: { BasePart } = {}
	live[caster] = drops

	for _, point in params.Points do
		if typeof(point) ~= "Vector3" then
			continue
		end

		local start: Vector3, direction: Vector3
		if target then
			start = point
			local offset = target - point
			direction = if offset.Magnitude > 1e-3 then offset.Unit else Vector3.yAxis
		else
			start = origin
			direction = point
		end

		local drop = makeDrop(template, params.Colors, start)
		if params.Concentrate then
			local attachment = drop:FindFirstChild("Attachment")
			local extra = attachment and attachment:FindFirstChild("Water7")
			if extra and extra:IsA("ParticleEmitter") then
				extra.Enabled = true
			end
		end
		table.insert(drops, drop)

		local travelTime = math.min(moveTime, life - startDelay)
		task.delay(startDelay, function()
			if drop.Parent and travelTime > 0 then
				TweenService:Create(drop, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {
					CFrame = CFrame.new(start + direction * speed * travelTime),
				}):Play()
			end
		end)
	end

	task.delay(life, function()
		-- Only if these are still the caster's drops (not detonated, not thrown again).
		if live[caster] == drops then
			clear(caster)
		end
	end)
end
