--!strict
--[[
	Smoke fruit - White Fist, while the key is held.
	Status value: "<fruit slot>|<ability slot>|<fruit colors>".

	Everyone: the two real arms are hidden and two smoke fists (arm-sized parts trailing
	Assets.Models.Fruits.Smoke.Power3.SmokeFist) follow the positions the server
	simulates and mirrors as the Vector3 attributes "SmokeFistRight" / "SmokeFistLeft".
	The server moves them ten times a second; here each fist keeps flying at the speed
	of its last step between two updates (and is eased onto that point), so the picture
	stays on the spot that hits instead of trailing behind it.

	Owner only: the mouse position is sent up to ten times a second (the rate at which
	the legacy server asked for it), when it moved, as the ability's secondary input
	(phase 3). The server validates and clamps it; nothing else is sent.

	The legacy game detached the real arms and pushed them with BodyVelocity on the
	server; here the arms never leave the body, they are only invisible on each client.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
local AIM_INTERVAL = 0.1
-- An aim that moved less than this (studs) since the last one sent is not sent again.
local AIM_MIN_MOVE = 0.5
-- Seconds between two server steps of the fists, and their speed in studs per second.
local SERVER_TICK = 0.1
local FIST_SPEED = 125
-- Kept under AbilityConfig.MaxAimDistance so an aim at the skybox is not rejected.
local MAX_AIM_DISTANCE = 900
-- Fraction of the remaining distance covered per second (easing of the corrections).
local FOLLOW_RATE = 30
-- The legacy gyro pointed the arm's lower end at the target.
local FIST_ROTATION = CFrame.Angles(math.rad(90), 0, 0)

local SIDES = {
	{ Arm = "Right Arm", Attribute = "SmokeFistRight" },
	{ Arm = "Left Arm", Attribute = "SmokeFistLeft" },
}

type Fist = {
	Part: BasePart,
	Attribute: string,
	Arm: BasePart,
	ArmTransparency: number,
	-- Last position received, the velocity of that step and the seconds since.
	Last: Vector3?,
	Velocity: Vector3,
	Since: number,
}

local function addLoopSound(parent: Instance)
	local definition = (SoundConfig :: any).SFX.Elemental.Smoke["Smoke Loop"]
	if not definition then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.Looped = true
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Parent = parent
	sound:Play()
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local primary, secondary = FruitColor.Parse(fields[3] or "")

	local template = EffectAssets.FindFruit("Smoke", "Power3", "SmokeFist")
	local fists: { Fist } = {}

	for _, side in SIDES do
		local arm = character:FindFirstChild(side.Arm)
		if not arm or not arm:IsA("BasePart") then
			continue
		end

		local part = Instance.new("Part")
		part.Name = "SmokeFist"
		part.Size = arm.Size
		part.Color = arm.Color
		part.Material = arm.Material
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CFrame = arm.CFrame

		if template and template:IsA("ParticleEmitter") then
			local emitter = template:Clone()
			if primary and secondary then
				emitter.Color = FruitColor.ToSequence(primary, secondary)
			end
			emitter.Parent = part
		end
		addLoopSound(part)
		part.Parent = World.Effects()

		table.insert(fists, {
			Part = part,
			Attribute = side.Attribute,
			Arm = arm,
			ArmTransparency = arm.Transparency,
			Last = nil,
			Velocity = Vector3.zero,
			Since = 0,
		})
		arm.Transparency = 1
	end

	local followConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
		local alpha = math.min(deltaTime * FOLLOW_RATE, 1)
		for _, fist in fists do
			local target = character:GetAttribute(fist.Attribute)
			if typeof(target) ~= "Vector3" then
				continue
			end

			local last = fist.Last
			if target ~= last then
				local step = if last then (target - last) / SERVER_TICK else Vector3.zero
				fist.Velocity = if step.Magnitude > FIST_SPEED then step.Unit * FIST_SPEED else step
				fist.Last = target
				fist.Since = 0
			else
				fist.Since += deltaTime
				-- No new step: the fist has arrived.
				if fist.Since > SERVER_TICK * 1.5 then
					fist.Velocity = Vector3.zero
				end
			end
			local goal = target + fist.Velocity * math.min(fist.Since, SERVER_TICK)

			local position = fist.Part.Position
			local offset = goal - position
			local nextPosition = position:Lerp(goal, alpha)
			if offset.Magnitude > 0.05 then
				fist.Part.CFrame = CFrame.lookAt(nextPosition, nextPosition + offset) * FIST_ROTATION
			else
				fist.Part.CFrame = fist.Part.CFrame.Rotation + nextPosition
			end
		end
	end)

	local aimConnection: RBXScriptConnection? = nil
	if isLocal and fruitSlot and abilitySlot then
		local abilityService = Knit.GetService("AbilityService")
		local mouse = Players.LocalPlayer:GetMouse()
		local sinceAim = 0
		local lastAim: Vector3? = nil

		aimConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
			sinceAim += deltaTime
			if sinceAim < AIM_INTERVAL then
				return
			end

			local root = character.PrimaryPart
			if not root then
				return
			end
			local aim = mouse.Hit.Position
			local offset = aim - root.Position
			if offset.Magnitude > MAX_AIM_DISTANCE then
				aim = root.Position + offset.Unit * MAX_AIM_DISTANCE
			end
			if lastAim and (aim - lastAim).Magnitude < AIM_MIN_MOVE then
				return
			end
			sinceAim = 0
			lastAim = aim
			abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, aim)
		end)
	end

	return function()
		followConnection:Disconnect()
		if aimConnection then
			aimConnection:Disconnect()
		end
		for _, fist in fists do
			fist.Part:Destroy()
			fist.Arm.Transparency = fist.ArmTransparency
		end
	end
end
