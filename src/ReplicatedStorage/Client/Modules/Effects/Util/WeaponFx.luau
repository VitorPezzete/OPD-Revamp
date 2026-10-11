--!strict
--[[
	Helpers shared by the weapon effect modules (Effects/Util is not loaded as effects).
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WeaponFx = {}

WeaponFx.HakiColor = Color3.fromRGB(25, 12, 25)

local cache: { [string]: Instance | false } = {}

-- A legacy template by name, anywhere under ReplicatedStorage.Assets.Models. The new
-- folder of the weapon templates could not be confirmed, so they are searched once.
function WeaponFx.FindAsset(name: string): Instance?
	local cached = cache[name]
	if cached == nil then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local models = assets and assets:FindFirstChild("Models")
		cached = (models and models:FindFirstChild(name, true)) or false
		cache[name] = cached :: any
	end
	return if cached then cached :: Instance else nil
end

-- An anchored, non-interacting part that removes itself after `life` seconds.
function WeaponFx.Part(props: { [string]: any }, life: number?, parent: Instance?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent or Workspace
	if life then
		Debris:AddItem(part, life)
	end
	return part
end

function WeaponFx.Tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- Makes a cloned template purely visual: no scripts, no physics, no collisions.
function WeaponFx.Neutralize(instance: Instance)
	local all = instance:GetDescendants()
	table.insert(all, instance)
	for _, descendant in all do
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

-- Per container, the latest request to light its trails: an older one must not put out
-- the trails a newer swing has just lit.
local lit: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

--[[
	Switches on every Trail under `container` for `seconds`: the blade trails a held
	weapon model carries, off as authored (Kanshou and Bakuya lit theirs for a quarter of
	a second on every swing and on the dash).
]]
function WeaponFx.LightTrails(container: Instance, seconds: number)
	local trails: { Trail } = {}
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("Trail") then
			descendant.Enabled = true
			table.insert(trails, descendant)
		end
	end
	if #trails == 0 then
		return
	end

	local request = (lit[container] or 0) + 1
	lit[container] = request
	task.delay(seconds, function()
		if lit[container] ~= request then
			return
		end
		lit[container] = nil
		for _, trail in trails do
			trail.Enabled = false
		end
	end)
end

function WeaponFx.Sound(id: string, parent: Instance, volume: number?, speed: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 1
	sound.PlaybackSpeed = speed or 1
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 6)
end

return WeaponFx
