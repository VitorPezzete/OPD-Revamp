--!strict
--[[
	Gravity fruit - Meteor Shower, one small meteor.
	params: { Start: Vector3, Landing: Vector3, FallTime: number, ExplosionSize: number,
	          ShockwaveSize: number, Colors: string, Caster: Model }
	Templates under ReplicatedStorage.Assets.Models.Fruits.Gravity:
	  Power5.GravityMeteor (MeshPart), Power5.GravityBlastEffect (Part),
	  Power4.GravityShockwave (a part with a "Mesh" inside).

	`origin` is the centre of the impact. The meteor travels from `Start` to `Landing` (a
	few studs off that centre) in `FallTime`, slowing down as it arrives like the legacy
	tween (default easing), then a blast grows to `ExplosionSize` over 1.5 s while fading
	and a shockwave grows to `ShockwaveSize` over 0.6 s. The meteor takes the first fruit
	color, the blast the second.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local SHOCKWAVE_COLOR = Color3.fromRGB(212, 216, 225)
local BLAST_START = Vector3.new(0.1, 0.1, 0.1)
local BLAST_TIME = 1.5
local SHOCKWAVE_TIME = 0.6
local LINGER = 2

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
	local landing: Vector3 = if typeof(params.Landing) == "Vector3" then params.Landing else origin
	local fallTime: number = if type(params.FallTime) == "number" and params.FallTime > 0 then params.FallTime else 1
	local explosionSize: number = if type(params.ExplosionSize) == "number" then params.ExplosionSize else 100
	local shockwaveSize: number = if type(params.ShockwaveSize) == "number" then params.ShockwaveSize else 4
	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")

	local meteorTemplate = EffectAssets.FindFruit("Gravity", "Power5", "GravityMeteor")
	if meteorTemplate and meteorTemplate:IsA("BasePart") then
		local created = meteorTemplate:Clone()
		prepare(created)
		if primary then
			created.Color = primary
		end
		created.Position = start
		created.Parent = World.Effects()
		TweenService:Create(created, TweenInfo.new(fallTime), { Position = landing }):Play()
		Debris:AddItem(created, fallTime + LINGER)
	end

	task.delay(fallTime, function()
		local blastTemplate = EffectAssets.FindFruit("Gravity", "Power5", "GravityBlastEffect")
		if blastTemplate and blastTemplate:IsA("BasePart") then
			local blast = blastTemplate:Clone()
			prepare(blast)
			if secondary then
				blast.Color = secondary
			end
			blast.Size = BLAST_START
			blast.Transparency = 0
			blast.CFrame = CFrame.new(origin)
			blast.Parent = World.Effects()
			TweenService:Create(blast, TweenInfo.new(BLAST_TIME), {
				Size = Vector3.new(explosionSize, explosionSize, explosionSize),
				Transparency = 1,
			}):Play()
			Debris:AddItem(blast, LINGER)
		end

		local waveTemplate = EffectAssets.FindFruit("Gravity", "Power4", "GravityShockwave")
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
			Debris:AddItem(wave, LINGER)
		end
	end)
end
