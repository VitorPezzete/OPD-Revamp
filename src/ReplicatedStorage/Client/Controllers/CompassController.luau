--!strict
--[[
	The Burning Compass in the local player's hand (CompassService).

	Using the tool by day wakes it: its needle turns towards the target the server stored
	on it (CompassConfig.TargetAttribute), its flame grows towards noon and a beacon burns
	above the target. When the holder gets within CompassConfig.ArrivalRadius the client
	tells the server so, with no arguments: the server measures the distance itself.

	All of it ran on the server in the legacy tool script, in a 0.1 s loop per compass.
	Here the loop only exists on the holder's client while the compass is awake.

	Tool parts used when present (legacy names): Handle (with a "Fire" emitter),
	CompassArrow (with a "Weld" to the handle), Portal (with a "Flare Fire" emitter).
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CompassConfig = require(ReplicatedStorage.Shared.Configs.CompassConfig)

local STEP = 0.1
-- Seconds between two "I have arrived" messages while standing on the target.
local ARRIVE_RETRY = 2
local SLEEP_DELAY = 0.5

local CompassController = Knit.CreateController({
	Name = "CompassController",
})

local CompassService

local awake: { [Tool]: boolean } = {}

local function isDay(): boolean
	local clock = Lighting.ClockTime
	return clock > CompassConfig.DayStart and clock < CompassConfig.DayEnd
end

-- Flame of the handle: strongest at noon (legacy curve, mult = 100 - (clock - 12)^2).
local function updateFlame(fire: ParticleEmitter)
	local strength = 100 - (Lighting.ClockTime - 12) ^ 2
	fire.Enabled = true
	fire.Lifetime = NumberRange.new(math.clamp(0.025 * strength / 100, 0.1, 0.3))
	fire.Rate = strength / 3
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.00625 * strength * 2),
		NumberSequenceKeypoint.new(0.564, 0.00435 * strength * 2),
		NumberSequenceKeypoint.new(1, 0.0244 * strength * 2),
	})
end

local function run(tool: Tool, target: Vector3)
	local player = Players.LocalPlayer
	local handle = tool:FindFirstChild("Handle")
	local arrow = tool:FindFirstChild("CompassArrow")
	local weld = arrow and arrow:FindFirstChild("Weld")
	local portal = tool:FindFirstChild("Portal")
	local fire = handle and handle:FindFirstChild("Fire")
	local beacon = portal and portal:FindFirstChild("Flare Fire")

	if arrow and arrow:IsA("BasePart") then
		arrow.Transparency = 0
	end
	if portal and portal:IsA("BasePart") and portal.Anchored then
		portal.Position = target + Vector3.new(0, CompassConfig.BeaconHeight, 0)
	end

	local nextArrive = 0
	while tool.Parent == player.Character and player.Character ~= nil and isDay() do
		if fire and fire:IsA("ParticleEmitter") then
			updateFlame(fire)
		end
		if beacon and beacon:IsA("ParticleEmitter") then
			beacon.Enabled = true
		end

		if handle and handle:IsA("BasePart") and weld and weld:IsA("Weld") and weld.Part0 then
			-- Needle: the angle between where the handle looks and where the target is.
			local offset = target - weld.Part0.Position
			local look = handle.CFrame.LookVector
			local angle = math.atan2(-look.Z, look.X) - math.atan2(-offset.Z, offset.X)
			weld.C1 = CFrame.new(-0.08, 0, 0) * CFrame.Angles(angle, 0, 0) * CFrame.Angles(-math.rad(90), 0, 0)
		end

		local root = player.Character.PrimaryPart
		local now = os.clock()
		if root and now >= nextArrive and (root.Position - target).Magnitude <= CompassConfig.ArrivalRadius then
			nextArrive = now + ARRIVE_RETRY
			CompassService.Arrive:Fire()
		end
		task.wait(STEP)
	end

	if fire and fire:IsA("ParticleEmitter") then
		fire.Enabled = false
	end
	if beacon and beacon:IsA("ParticleEmitter") then
		beacon.Enabled = false
	end
	task.wait(SLEEP_DELAY)
	if arrow and arrow:IsA("BasePart") and arrow.Parent then
		arrow.Transparency = 1
	end
end

local function bind(tool: Tool)
	if awake[tool] ~= nil then
		return
	end
	awake[tool] = false

	tool.Activated:Connect(function()
		local target = tool:GetAttribute(CompassConfig.TargetAttribute)
		if awake[tool] or typeof(target) ~= "Vector3" or not isDay() then
			return
		end
		awake[tool] = true
		run(tool, target)
		if awake[tool] ~= nil then
			awake[tool] = false
		end
	end)
	tool.Destroying:Once(function()
		awake[tool] = nil
	end)
end

local function watch(container: Instance)
	local function check(child: Instance)
		if child:IsA("Tool") and child:GetAttribute(CompassConfig.TargetAttribute) ~= nil then
			bind(child)
		end
	end
	container.ChildAdded:Connect(check)
	for _, child in container:GetChildren() do
		check(child)
	end
end

function CompassController:KnitStart()
	CompassService = Knit.GetService("CompassService")

	local player = Players.LocalPlayer
	-- The compass is handed into the backpack; a new backpack comes with every respawn.
	player.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Backpack") then
			watch(child)
		end
	end)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watch(backpack)
	end
end

return CompassController
