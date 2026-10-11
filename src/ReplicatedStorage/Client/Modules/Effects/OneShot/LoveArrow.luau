--!strict
--[[
	Love fruit - Slave Arrow / Arrow Storm: one arrow. Cosmetic copy of the point the
	server simulates: position = origin + velocity * t + gravity * t^2 / 2, turned along
	its velocity, until it meets a wall or floor or its lifetime ends. The heart on the
	arrow grows to its full size over GrowTime.

	params: { Velocity: Vector3, GrowTime: number, HeartSize: number (full width in
	          studs), Lifetime: number, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Love.Power5.LoveArrow (a Model with a
	PrimaryPart, a LoveHeart part and parts carrying a Trail).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local World = require(ReplicatedStorage.Shared.Util.World)

-- The legacy model points along its X axis.
local MODEL_ROTATION = CFrame.Angles(0, math.rad(90), 0)
-- Depth of the legacy heart relative to its width (5 / 17.5).
local HEART_DEPTH_RATIO = 5 / 17.5
local LINGER = 0.5

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end

	local velocity = params.Velocity
	if typeof(velocity) ~= "Vector3" or velocity.Magnitude < 1 then
		return
	end
	local template = EffectAssets.FindFruit("Love", "Power5", "LoveArrow")
	if not template or not template:IsA("Model") then
		return
	end

	local growTime: number = if type(params.GrowTime) == "number" then params.GrowTime else 1
	local heartSize: number = if type(params.HeartSize) == "number" then params.HeartSize else 17.5
	local lifetime: number = if type(params.Lifetime) == "number" then params.Lifetime else 10
	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")

	local arrow = template:Clone()
	for _, descendant in arrow:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			if primary then
				descendant.Color = primary
			end
		elseif descendant:IsA("Trail") and primary then
			descendant.Color = ColorSequence.new(primary)
		elseif descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end

	local function place(position: Vector3, heading: Vector3)
		-- At the very top of a vertical shot the velocity is momentarily zero.
		if heading.Magnitude < 1e-3 then
			heading = Vector3.yAxis
		end
		local up = if math.abs(heading.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
		arrow:PivotTo(CFrame.lookAt(position, position + heading, up) * MODEL_ROTATION)
	end
	place(origin, velocity)
	arrow.Parent = World.Effects()

	local heart = arrow:FindFirstChild("LoveHeart")
	if heart and heart:IsA("BasePart") then
		TweenService:Create(heart, TweenInfo.new(growTime, Enum.EasingStyle.Linear), {
			Size = Vector3.new(heartSize, heartSize, heartSize * HEART_DEPTH_RATIO),
		}):Play()
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local filtered: { Instance } = {}
	local caster = params.Caster
	if typeof(caster) == "Instance" then
		table.insert(filtered, caster)
	end
	-- Characters do not stop an arrow.
	local enemies = World.AliveRoot()
	if enemies then
		table.insert(filtered, enemies)
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(filtered, player.Character)
		end
	end
	raycastParams.FilterDescendantsInstances = filtered

	local gravity = Vector3.new(0, -Workspace.Gravity, 0)
	local elapsed = 0
	local position = origin
	local connection: RBXScriptConnection

	local function finish()
		connection:Disconnect()
		task.delay(LINGER, function()
			arrow:Destroy()
		end)
	end

	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		local nextPosition = origin + velocity * elapsed + gravity * (elapsed * elapsed / 2)
		local heading = velocity + gravity * elapsed
		local result = Workspace:Raycast(position, nextPosition - position, raycastParams)
		if result then
			place(result.Position, heading)
			finish()
			return
		end

		position = nextPosition
		place(position, heading)
		if elapsed >= lifetime then
			finish()
		end
	end)
end
