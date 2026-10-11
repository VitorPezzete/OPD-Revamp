--!strict
--[[
	Gravity fruit - Meteor Crash, while the owner holds the key: a dot on the point the
	meteor will land on and a pulsing vertical marker above it. Owner only, as in the
	legacy game (both parts lived in the LocalScript).

	Status value: the fruit color string (the dot takes the first color, the four decals
	of the pole the second).
	Templates under ReplicatedStorage.Assets.Models.Fruits._Shared: GravityTargetingDot (a
	Ball) and GravityTargetingPole (a 4 stud bar with "Decal1".."Decal4", stood upright).

	The point is the one the server will use (Abilities/Gravity/Meteor Crash): the first
	thing on the line from SIGHT_HEIGHT studs above the user to the aim point. The pole's
	thickness swings between 0.1 and 1 stud, as the legacy loop did (0.1 per frame at
	30 frames per second).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local SIGHT_HEIGHT = 1000
local POLE_LENGTH = 4
local POLE_OFFSET = Vector3.new(0, 2, 0)
local POLE_UPRIGHT = CFrame.Angles(0, 0, -math.pi / 2)
local POLE_MIN_WIDTH = 0.1
local POLE_MAX_WIDTH = 1
local PULSE_PERIOD = 0.6

local function noop() end

local function prepare(template: Instance?): BasePart?
	if not template or not template:IsA("BasePart") then
		return nil
	end
	local part = template:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	local foundDot = prepare(EffectAssets.FindFruit("_Shared", "GravityTargetingDot"))
	if not foundRoot or not foundRoot:IsA("BasePart") or not foundDot then
		return noop
	end
	local root: BasePart, dot: BasePart = foundRoot, foundDot
	local pole = prepare(EffectAssets.FindFruit("_Shared", "GravityTargetingPole"))

	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
	if primary and secondary then
		dot.Color = primary
		if pole then
			for _, child in pole:GetChildren() do
				if child:IsA("Decal") then
					child.Color3 = secondary
				end
			end
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local inputController = Knit.GetController("InputController")
	local started = os.clock()
	local function place()
		local aim: Vector3 = inputController:GetAimPosition()
		local origin = root.Position + Vector3.new(0, SIGHT_HEIGHT, 0)
		local result = Workspace:Raycast(origin, aim - origin, params)
		local point = if result then result.Position else aim

		dot.CFrame = CFrame.new(point)
		if pole then
			local phase = ((os.clock() - started) / PULSE_PERIOD) % 1
			local swing = 1 - math.abs(phase * 2 - 1)
			local width = POLE_MIN_WIDTH + (POLE_MAX_WIDTH - POLE_MIN_WIDTH) * swing
			pole.Size = Vector3.new(POLE_LENGTH, width, width)
			pole.CFrame = CFrame.new(point + POLE_OFFSET) * POLE_UPRIGHT
		end
	end
	place()
	dot.Parent = World.Effects()
	if pole then
		pole.Parent = World.Effects()
	end
	local connection = RunService.RenderStepped:Connect(place)

	return function()
		connection:Disconnect()
		dot:Destroy()
		if pole then
			pole:Destroy()
		end
	end
end
