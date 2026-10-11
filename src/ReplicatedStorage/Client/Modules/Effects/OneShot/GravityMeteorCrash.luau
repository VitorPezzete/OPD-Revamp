--!strict
--[[
	Gravity fruit - Meteor Crash.
	params: { Start: Vector3, FallTime: number, Size: number, ExplosionSize: number,
	          ShockwaveSize: number, Colors: string, Caster: Model }
	Templates under ReplicatedStorage.Assets.Models.Fruits.Gravity:
	  Power6.GravityMeteor (MeshPart), Power5.GravityBlastEffect (Part),
	  Power4.GravityShockwave (a part with a "Mesh" inside).

	`origin` is the impact point. The meteor (`Size` studs wide, random rotation, first
	fruit color) accelerates from `Start` to it over `FallTime`. On impact a solid blast
	1.5 times the meteor (authored color) sits around it and, three times 0.3 s apart, a
	blast grows from 1.3 times the meteor to `ExplosionSize` over 1.5 s while fading
	(second fruit color) and a shockwave grows to `ShockwaveSize` over 0.6 s. The meteor
	and the solid blast disappear a second after landing.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local SHOCKWAVE_COLOR = Color3.fromRGB(212, 216, 225)
local BLASTS = 3
local BLAST_INTERVAL = 0.3
local BLAST_START_FACTOR = 1.3
local CORE_FACTOR = 1.5
local BLAST_TIME = 1.5
local SHOCKWAVE_TIME = 0.6
local BLAST_LINGER = 2
local METEOR_LINGER = 1

local random = Random.new()

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Start) ~= "Vector3" then
		return
	end
	local start: Vector3 = params.Start
	local fallTime: number = if type(params.FallTime) == "number" and params.FallTime > 0 then params.FallTime else 10
	local size: number = if type(params.Size) == "number" then math.max(params.Size, 0.1) else 100
	local explosionSize: number = if type(params.ExplosionSize) == "number" then params.ExplosionSize else 400
	local shockwaveSize: number = if type(params.ShockwaveSize) == "number" then params.ShockwaveSize else 10
	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")

	local meteorTemplate = EffectAssets.FindFruit("Gravity", "Power6", "GravityMeteor")
	if meteorTemplate and meteorTemplate:IsA("BasePart") then
		local meteor = meteorTemplate:Clone()
		prepare(meteor)
		if primary then
			meteor.Color = primary
		end
		meteor.Size = Vector3.new(size, size, size)

		local rotation = CFrame.Angles(
			random:NextNumber(0, math.pi * 2),
			random:NextNumber(0, math.pi * 2),
			random:NextNumber(0, math.pi * 2)
		)
		meteor.CFrame = rotation + start
		meteor.Parent = World.Effects()

		-- The legacy tween ended on an unrotated CFrame, so the meteor also turned as it fell.
		TweenService:Create(meteor, TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(origin),
		}):Play()
		Debris:AddItem(meteor, fallTime + METEOR_LINGER)
	end

	task.delay(fallTime, function()
		local blastTemplate = EffectAssets.FindFruit("Gravity", "Power5", "GravityBlastEffect")
		local waveTemplate = EffectAssets.FindFruit("Gravity", "Power4", "GravityShockwave")
		local blastStart = size * BLAST_START_FACTOR

		if blastTemplate and blastTemplate:IsA("BasePart") then
			local core = blastTemplate:Clone()
			prepare(core)
			core.Size = Vector3.new(size, size, size) * CORE_FACTOR
			core.Transparency = 0
			core.CFrame = CFrame.new(origin)
			core.Parent = World.Effects()
			Debris:AddItem(core, METEOR_LINGER)
		end

		for _ = 1, BLASTS do
			if blastTemplate and blastTemplate:IsA("BasePart") then
				local blast = blastTemplate:Clone()
				prepare(blast)
				if secondary then
					blast.Color = secondary
				end
				blast.Size = Vector3.new(blastStart, blastStart, blastStart)
				blast.Transparency = 0
				blast.CFrame = CFrame.new(origin)
				blast.Parent = World.Effects()
				TweenService:Create(blast, TweenInfo.new(BLAST_TIME), {
					Size = Vector3.new(explosionSize, explosionSize, explosionSize),
					Transparency = 1,
				}):Play()
				Debris:AddItem(blast, BLAST_LINGER)
			end

			if waveTemplate and waveTemplate:IsA("BasePart") then
				local wave = waveTemplate:Clone()
				prepare(wave)
				wave.Color = primary or SHOCKWAVE_COLOR
				wave.Position = origin
				wave.Parent = World.Effects()

				local tweenInfo = TweenInfo.new(SHOCKWAVE_TIME, Enum.EasingStyle.Linear)
				local mesh = wave:FindFirstChildWhichIsA("DataModelMesh")
				if mesh then
					TweenService:Create(mesh, tweenInfo, {
						Scale = Vector3.new(shockwaveSize, shockwaveSize, shockwaveSize),
					}):Play()
				end
				TweenService:Create(wave, tweenInfo, { Transparency = 1 }):Play()
				Debris:AddItem(wave, BLAST_LINGER)
			end

			task.wait(BLAST_INTERVAL)
		end
	end)
end
