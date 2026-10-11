--!strict
--[[
	Magma fruit - Magma Pool.
	params: { Diameter: number, GrowTime: number, ShrinkTime: number, Haki: boolean,
	          Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Magma.Power3.Pool (a cylinder lying
	flat: its X axis is the thickness).

	`origin` is the centre of the pool (3 studs under the caster's root). The diameter
	grows linearly to `Diameter`, then everything shrinks to nothing; meanwhile the
	thickness breathes between 1 and 7 studs, as in the legacy game. The pool is removed
	early if its caster dies or leaves (the server stops burning then).

	Sounds on the pool: "Magma Impact" when it appears, "Magma Pool" looping.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(255, 0, 0)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local MIN_THICKNESS = 1
local MAX_THICKNESS = 7
local MIN_SIZE = Vector3.new(0.1, 0.1, 0.1)
local FLAT_ROTATION = CFrame.Angles(0, 0, math.rad(-90))
local IMPACT_SOUND_SECONDS = 2.5

local function playSound(name: string, parent: Instance): Sound?
	local definition = (SoundConfig :: any).SFX.Elemental.Magma[name]
	if not definition then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.Looped = definition.Looped == true
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Parent = parent
	sound:Play()
	return sound
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params or type(params.Diameter) ~= "number" or params.Diameter <= 0 then
		return
	end
	local diameter: number = params.Diameter
	local growTime: number = if type(params.GrowTime) == "number" then params.GrowTime else 13
	local shrinkTime: number = if type(params.ShrinkTime) == "number" then params.ShrinkTime else 6

	local template = EffectAssets.FindFruit("Magma", "Power3", "Pool")
	if not template or not template:IsA("BasePart") then
		return
	end

	local pool = template:Clone()
	pool.Anchored = true
	pool.CanCollide = false
	pool.CanQuery = false
	pool.CanTouch = false

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	pool.Color = if params.Haki then HAKI_COLOR elseif primary then primary else DEFAULT_COLOR
	for _, descendant in pool:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") and primary and secondary then
			descendant.Color = FruitColor.ToSequence(primary, secondary)
		end
	end

	pool.Size = Vector3.new(MIN_THICKNESS, 1, 1)
	pool.CFrame = CFrame.new(origin) * FLAT_ROTATION
	pool.Parent = World.Effects()

	local impact = playSound("Magma Impact", pool)
	if impact then
		Debris:AddItem(impact, IMPACT_SOUND_SECONDS)
	end
	playSound("Magma Pool", pool)

	local caster: Model? = if typeof(params.Caster) == "Instance" and params.Caster:IsA("Model") then params.Caster else nil
	local humanoid = caster and caster:FindFirstChildOfClass("Humanoid")

	local started = os.clock()
	-- Size reached at the end of the growth: the shrink starts from it (the thickness
	-- stops breathing then, as in the legacy game).
	local final: Vector3? = nil
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - started
		local wave = (math.sin(os.clock() * 2) + 1) / 2
		local grown = Vector3.new(MIN_THICKNESS + (MAX_THICKNESS - MIN_THICKNESS) * wave, diameter, diameter)

		if caster and (not caster.Parent or (humanoid and humanoid.Health <= 0)) then
			elapsed = growTime + shrinkTime
		end

		if elapsed <= growTime then
			local alpha = elapsed / growTime
			pool.Size = Vector3.new(grown.X, math.max(diameter * alpha, 0.1), math.max(diameter * alpha, 0.1))
		elseif elapsed < growTime + shrinkTime then
			local from = final or grown
			final = from
			pool.Size = from:Lerp(MIN_SIZE, (elapsed - growTime) / shrinkTime)
		else
			connection:Disconnect()
			pool:Destroy()
		end
	end)
end
