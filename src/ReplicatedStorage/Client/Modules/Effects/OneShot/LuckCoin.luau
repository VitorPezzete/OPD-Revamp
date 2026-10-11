--!strict
--[[
	Luck fruit - Coin throw: the spinning coin homing on its target.
	params: { Target: Model?, Point: Vector3, Speed: number }   (plus Caster, Colors)
	Template: ReplicatedStorage.Assets.Models.Fruits.Luck.Power4.Coin (a part).

	Purely cosmetic: the server rolls the result after distance / speed seconds. The coin
	flies straight at the target's root (or at Point when it was thrown at a piece of
	the map), spinning, and disappears within 5 studs of it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local HAND = "Right Arm"
local HIT_DISTANCE = 5
local MAX_LIFETIME = 4
-- Radians per second.
local SPIN_SPEED = 15

return function(origin: Vector3, params: { [string]: any }?)
	local target = params and params.Target
	local speed = params and params.Speed
	local caster = params and params.Caster
	local point = params and params.Point
	if type(speed) ~= "number" or (typeof(target) ~= "Instance" and typeof(point) ~= "Vector3") then
		return
	end

	local template = EffectAssets.FindFruit("Luck", "Power4", "Coin")
	if not template or not template:IsA("BasePart") then
		return
	end

	local coin = template:Clone()
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CanTouch = false

	local hand = if typeof(caster) == "Instance" then caster:FindFirstChild(HAND) else nil
	local position = if hand and hand:IsA("BasePart") then hand.Position else origin
	coin.CFrame = CFrame.new(position)
	coin.Parent = World.Effects()

	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime

		local goal: Vector3? = nil
		if typeof(target) == "Instance" then
			local root = target:FindFirstChild("HumanoidRootPart")
			if target.Parent ~= nil and root and root:IsA("BasePart") then
				goal = root.Position
			end
		elseif typeof(point) == "Vector3" then
			goal = point
		end
		if elapsed > MAX_LIFETIME or not goal then
			connection:Disconnect()
			coin:Destroy()
			return
		end
		local offset = goal - position
		local distance = offset.Magnitude
		if distance < HIT_DISTANCE then
			connection:Disconnect()
			coin:Destroy()
			return
		end

		position += offset.Unit * math.min(speed * deltaTime, distance)
		coin.CFrame = CFrame.lookAt(position, goal) * CFrame.Angles(0, 0, elapsed * SPIN_SPEED)
	end)
end
