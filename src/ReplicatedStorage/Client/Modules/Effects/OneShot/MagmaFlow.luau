--!strict
--[[
	Magma fruit - Magma Flow, the blobs of magma.
	params: { Direction: Vector3, Seed: number, Factor: number (sniper affinity * level
	          scale), Haki: boolean, Colors: string, Caster: Model }
	Templates: ReplicatedStorage.Assets.Models.Fruits.Magma.Power4.NormalFlow / WaterFlow.

	The server only sends a seed: `layout` rebuilds the same rows of landing points and
	delays it used (keep it identical to the one in Abilities/Magma/Magma Flow). Each
	blob is dropped on the ground under its point; with no ground it floats on the sea.
	- on land: (10, 3, 10) * Factor growing to (15, 4, 15) * Factor in 2.5 s, darkening
	  after 3 s, gone after 10 s;
	- on water: (4, 1, 4) growing to (40, 8, 40) * Factor in 2.5 s, gone after 30 s. As
	  in the legacy game this one is solid: cooled magma to stand on. The copy is local,
	  which is enough to carry this client's own character.

	One blob in three plays "Magma Impact", one in three "Magma Eruption".
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local World = require(ReplicatedStorage.Shared.Util.World)

local ROWS = 15
local ROW_SPACING = 20
local SPREAD_PER_ROW = 15 / 4
local MIN_DELAY = 1 / 60
local FLOOR_PROBE = 50
-- Height of the sea surface in the legacy map.
local SEA_LEVEL = 211

local DEFAULT_COLOR = Color3.fromRGB(255, 0, 0)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local GROW_TIME = 2.5
local LAND_LIFETIME = 10
local WATER_LIFETIME = 30
local FADE_TIME = 0.5
local BLOB_ROTATION = CFrame.Angles(0, math.rad(90), 0)

-- Flat landing targets and spawn delays of every blob. Mirrors the server.
local function layout(seed: number, origin: Vector3, direction: Vector3): { { Point: Vector3, Delay: number } }
	local rng = Random.new(seed)
	local result = {}
	local delay = 0
	for row = 1, ROWS do
		local count = rng:NextInteger(math.floor(1 + row / 3), row)
		local spread = math.floor(SPREAD_PER_ROW * row)
		for _ = 1, count do
			local x = rng:NextInteger(-spread, spread)
			local z = rng:NextInteger(-spread, spread)
			table.insert(result, {
				Point = origin + direction * (row * ROW_SPACING) + Vector3.new(x, 0, z),
				Delay = delay,
			})
			delay += math.max(rng:NextInteger(10 // row, 25 // row) / 100, MIN_DELAY)
		end
	end
	return result
end

local SOUNDS = { "Magma Impact", "Magma Eruption" }

-- Local folder of the solid blobs on the sea: the floor rays of later blobs ignore it,
-- like the server, which has no such parts.
local platforms: Folder? = nil

local function getPlatforms(): Folder
	local folder = platforms
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "MagmaPlatforms"
		folder.Parent = World.RuntimeParent()
		platforms = folder
	end
	return folder
end

local function playSound(name: string?, parent: Instance)
	local definition = if name then (SoundConfig :: any).SFX.Elemental.Magma[name] else nil
	if not definition then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Parent = parent
	sound:Play()
end

local function spawnBlob(template: BasePart, position: Vector3, color: Color3, factor: number, onWater: boolean)
	local blob = template:Clone()
	blob.Anchored = true
	blob.CanCollide = onWater
	blob.CanQuery = onWater
	blob.CanTouch = false
	blob.Color = color
	blob.CFrame = CFrame.new(position) * BLOB_ROTATION

	local lifetime
	if onWater then
		lifetime = WATER_LIFETIME
		blob.Size = Vector3.new(4, 1, 4)
		TweenService:Create(blob, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(40, 8, 40) * factor,
		}):Play()
	else
		lifetime = LAND_LIFETIME
		blob.Size = Vector3.new(10, 3, 10) * factor
		TweenService:Create(blob, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = Vector3.new(15, 4, 15) * factor,
		}):Play()
		-- Cooling down: the legacy blob lost half its brightness over 5 s.
		task.delay(GROW_TIME + 0.5, function()
			if blob.Parent then
				TweenService:Create(blob, TweenInfo.new(5), {
					Color = Color3.new(color.R * 0.5, color.G * 0.5, color.B * 0.5),
				}):Play()
			end
		end)
	end

	blob.Parent = if onWater then getPlatforms() else World.Effects()
	playSound(SOUNDS[math.random(1, 3)], blob)
	task.delay(lifetime, function()
		if blob.Parent then
			TweenService:Create(blob, TweenInfo.new(FADE_TIME), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(blob, lifetime + FADE_TIME)
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local direction = params.Direction
	local seed = params.Seed
	local factor = params.Factor
	if typeof(direction) ~= "Vector3" or type(seed) ~= "number" or type(factor) ~= "number" or factor <= 0 then
		return
	end

	local landTemplate = EffectAssets.FindFruit("Magma", "Power4", "NormalFlow")
	local waterTemplate = EffectAssets.FindFruit("Magma", "Power4", "WaterFlow")
	if not landTemplate or not landTemplate:IsA("BasePart") then
		return
	end

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local color = if params.Haki then HAKI_COLOR elseif primary then primary else DEFAULT_COLOR

	-- Blobs land on the map, never on characters.
	local ignored: { Instance } = { getPlatforms() }
	local enemies = World.AliveRoot()
	if enemies then
		table.insert(ignored, enemies)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignored, player.Character)
		end
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignored

	for _, entry in layout(seed, origin, direction) do
		task.delay(entry.Delay, function()
			local result = Workspace:Raycast(
				entry.Point + Vector3.new(0, FLOOR_PROBE, 0),
				Vector3.new(0, -2 * FLOOR_PROBE, 0),
				rayParams
			)
			if result then
				spawnBlob(landTemplate, result.Position, color, factor, false)
			elseif waterTemplate and waterTemplate:IsA("BasePart") then
				local point = entry.Point
				spawnBlob(waterTemplate, Vector3.new(point.X, SEA_LEVEL - 3, point.Z), color, factor, true)
			end
		end)
	end
end
