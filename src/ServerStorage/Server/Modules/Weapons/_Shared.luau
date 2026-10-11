--!strict
--[[
	Helpers shared by the weapon modules. Not a weapon: AttackService skips modules whose
	name starts with an underscore.
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity

local SWEEP_STEP = 0.05

local WeaponShared = {}

local assetCache: { [string]: Instance | false } = {}

--[[
	A legacy template by name, anywhere under ReplicatedStorage.Assets.Models (the slash
	meshes came from ServerStorage.OtherStuff.SwordSlashes and their new folder could not
	be confirmed). Searched once per name.
]]
function WeaponShared.FindAsset(name: string): Instance?
	local cached = assetCache[name]
	if cached == nil then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local models = assets and assets:FindFirstChild("Models")
		cached = (models and models:FindFirstChild(name, true)) or false
		assetCache[name] = cached :: any
	end
	return if cached then cached :: Instance else nil
end

function WeaponShared.HasFruit(data: PlayerData.PlayerData, fruitName: string): boolean
	local fruits = data.Data.DevilFruits
	return fruits.Slot1.Name == fruitName or fruits.Slot2.Name == fruitName
end

function WeaponShared.ClockTime(): number
	return Lighting.ClockTime
end

-- The Divine Axe only works under the sun: legacy "daytime > 18 or daytime < 7" was night.
function WeaponShared.IsDaytime(): boolean
	local clock = Lighting.ClockTime
	return clock >= 7 and clock <= 18
end

-- Position of a limb, or of the root when the rig has no such part.
function WeaponShared.LimbPosition(entity: CharacterEntity, limbName: string): Vector3
	local limb = entity.Model:FindFirstChild(limbName)
	return if limb and limb:IsA("BasePart") then limb.Position else entity.Root.Position
end

--[[
	A box flying in a straight line, tested against the tracked characters only: it goes
	through walls, as the legacy slash parts did (non-colliding parts with a Touched
	connection). `size`: X width across the flight, Y height, Z depth along it.
	`onHit` runs once per character and returns true to stop the sweep.
]]
function WeaponShared.Sweep(
	owner: CharacterEntity,
	origin: Vector3,
	direction: Vector3,
	speed: number,
	lifetime: number,
	size: Vector3,
	onHit: (target: CharacterEntity) -> boolean?
)
	local started = os.clock()
	local travelled = 0
	local hit: { [CharacterEntity]: boolean } = {}

	-- lookAt is undefined for a vertical look vector with the default up axis.
	local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local orientation = CFrame.lookAt(origin, origin + direction, up)

	local function step()
		if owner.Dead then
			return
		end

		local elapsed = math.min(os.clock() - started, lifetime)
		local reached = elapsed * speed
		local center = orientation * CFrame.new(0, 0, -(travelled + reached) / 2)
		local box = Vector3.new(size.X, size.Y, reached - travelled + size.Z)
		travelled = reached

		for _, target in Hitbox.Box(center, box, owner) do
			if not hit[target] then
				hit[target] = true
				if onHit(target) then
					return
				end
			end
		end

		if elapsed < lifetime then
			task.delay(SWEEP_STEP, step)
		end
	end
	step()
end

return WeaponShared
