--!strict
--[[
	Dough fruit - Donut Roll while it is on.
	Status value: "<f>|<fruit colors>", f = the server's power factor (jump strength 5 * f).

	Everyone (the source's "DonutRoll" client effect):
	- a mochi donut around the character: a copy of
	  ReplicatedStorage.Assets.Models.Fruits.Dough.Effects["Donut Roll"].Donut, growing from
	  a twentieth of its size to full size in 1 s, standing upright along the character's
	  heading and spinning faster as the roll accelerates (15 degrees per stud per second of
	  speed, per second). Custom colors: donut = first, its Mochi particles = second.
	- the character is hidden for as long as the roll lasts (Effects.Util.CharacterHide):
	  parts, face, accessories, tools, and whatever is welded onto it while it rolls
	  (armament haki shells). The source wrote Transparency 1 on the parts it found at the
	  start and gave the old values back at the end: the face (a decal) stayed, anything
	  added later stayed, and a value changed meanwhile was overwritten.
	- sounds on the donut: "Mochi Formating", "Mochi Roll Start" after 0.25 s and the
	  "Mochi Roll" loop 1.5 s later. At the end: 10 "Deforming" particles and
	  "Mochi Formating" on the root.

	Owner only - the movement, the source's LocalScript number for number:
	- a BodyPosition (vertical force only) holds the character's height; every frame the
	  root's CFrame is written and the BodyPosition follows it.
	- speed: +2.5 studs per second every 0.05 s, 100 times (250 studs per second after
	  about 5 s), always straight ahead; the character still turns as usual.
	- a ray 7.5 studs down from 5 studs ahead finds the floor, a ray 7.5 studs ahead finds
	  a wall. Wall: climb straight up at the current speed. Floor: ride 5 studs above it.
	  Neither, and less than 7.5 studs above the sea line (Y 210.5): ride 5 studs above
	  the sea. Otherwise fall, the fall speed growing by Workspace.Gravity / 25 per second.
	- jump (on the floor only): for 0.25 s the character rises by `5 * f`, less
	  `5 * f / 5` per second, while moving ahead.
	The source applied the rise and the fall per FRAME, not per second; they are scaled to
	the 60 frames a second the numbers were tuned at, so a faster or slower client rolls
	the same.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local CharacterHide = require(script.Parent.Parent.Util.CharacterHide)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local MAX_SPEED = 250
local SPEED_STEPS = 100
local SPEED_STEP_TIME = 0.05
local SPIN_PER_SPEED = 15
local GROW_INFO = TweenInfo.new(1, Enum.EasingStyle.Quad)
local START_SCALE = 0.05

local FLOOR_AHEAD = 5
local FLOOR_REACH = 7.5
local WALL_REACH = 7.5
local RIDE_HEIGHT = 5
-- The source's fixed 210.5: half a stud under the sea surface.
local SEA_Y = WorldConfig.SeaLevel - 0.5
local JUMP_BASE = 5
local JUMP_TIME = 0.25
local GRAVITY_DIVISOR = 25
-- Frames per second the source's per-frame rise and fall were tuned at.
local SOURCE_RATE = 60

local function addSound(name: string, parent: Instance, lifetime: number?)
	local definition = (SoundConfig :: any).Fruits.Dough[name]
	if not definition then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Looped = definition.Looped == true
	sound.Parent = parent
	sound:Play()
	if lifetime then
		Debris:AddItem(sound, lifetime)
	end
end

-- The source's acceleration: a counter raised in steps. Returns (read, stop).
local function accelerate(): (() -> number, () -> ())
	local speed = 0
	local running = true
	task.spawn(function()
		for _ = 1, SPEED_STEPS do
			if not running then
				return
			end
			speed += MAX_SPEED / SPEED_STEPS
			task.wait(SPEED_STEP_TIME)
		end
	end)
	return function(): number
		return speed
	end, function()
		running = false
	end
end

local function yawOnly(cframe: CFrame): CFrame
	local _, yaw = cframe:ToOrientation()
	return CFrame.new(cframe.Position) * CFrame.Angles(0, yaw, 0)
end

-- The owner's movement. Returns its cleanup.
local function drive(character: Model, root: BasePart, factor: number): () -> ()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local antiGravity = Instance.new("BodyPosition")
	antiGravity.Name = "DoughRollHold"
	antiGravity.MaxForce = Vector3.new(0, math.huge, 0)
	antiGravity.Position = root.Position
	antiGravity.Parent = root

	local getSpeed, stopSpeed = accelerate()

	local jumping = false
	local onFloor = false
	local jumpConstant, jumpForce = JUMP_BASE * factor, 0
	local gravity, gravityProcessing = 0, false

	local jumpRequest = UserInputService.JumpRequest:Connect(function()
		if not jumping and onFloor then
			jumping = true
			jumpForce = jumpConstant
			task.wait(JUMP_TIME)
			jumping = false
		end
	end)

	local renderStepped = RunService.RenderStepped:Connect(function(deltaTime: number)
		local speed = getSpeed() * deltaTime
		local frames = deltaTime * SOURCE_RATE

		local rootPosition = root.Position
		local heading = yawOnly(root.CFrame)

		local floor = Workspace:Raycast((heading * CFrame.new(0, 0, -FLOOR_AHEAD)).Position, Vector3.new(0, -FLOOR_REACH, 0), params)
		local wall = Workspace:Raycast(rootPosition, heading.LookVector * WALL_REACH, params)

		if floor then
			onFloor = true
			gravityProcessing = false
		elseif not jumping and not gravityProcessing then
			onFloor = false
			gravityProcessing = true
			gravity = 0
		end

		if jumping then
			gravityProcessing = false
			jumpForce -= math.clamp(jumpConstant / 5, 0, jumpConstant) * deltaTime
			root.CFrame *= CFrame.new(0, jumpForce * frames, -speed)
			antiGravity.Position = root.Position
			return
		end

		if gravityProcessing then
			gravity += Workspace.Gravity / GRAVITY_DIVISOR * deltaTime
		end

		if wall then
			root.CFrame *= CFrame.new(0, speed, 0)
		elseif floor then
			root.CFrame = CFrame.new(rootPosition.X, floor.Position.Y + RIDE_HEIGHT, rootPosition.Z)
				* heading.Rotation
				* CFrame.new(0, 0, -speed)
		elseif rootPosition.Y - FLOOR_REACH < SEA_Y then
			root.CFrame = CFrame.new(rootPosition.X, SEA_Y + RIDE_HEIGHT, rootPosition.Z)
				* heading.Rotation
				* CFrame.new(0, 0, -speed)
		else
			root.CFrame *= CFrame.new(0, -gravity * frames, -speed)
		end

		antiGravity.Position = root.Position
	end)

	return function()
		stopSpeed()
		jumpRequest:Disconnect()
		renderStepped:Disconnect()
		antiGravity:Destroy()
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local factor = tonumber(fields[1]) or 0
	local primary, secondary = FruitColor.Parse(fields[2] or "")

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return function() end
	end

	local folder = EffectAssets.FindFruit("Dough", "Effects", "Donut Roll")
	local template = folder and folder:FindFirstChild("Donut")

	local running = true
	local donut: BasePart? = nil
	local spinConnection: RBXScriptConnection? = nil
	local stopSpin: (() -> ())? = nil
	if template and template:IsA("BasePart") then
		local created = template:Clone()
		created.Anchored = true
		created.CanCollide = false
		created.CanQuery = false
		created.CanTouch = false
		created.Size = template.Size * START_SCALE
		if primary and secondary then
			created.Color = primary
			local mochi = created:FindFirstChild("Mochi")
			if mochi and mochi:IsA("ParticleEmitter") then
				mochi.Color = ColorSequence.new(secondary)
			end
		end
		created.CFrame = yawOnly(root.CFrame) * CFrame.Angles(0, math.rad(-90), 0)
		created.Parent = World.Effects()
		donut = created

		TweenService:Create(created, GROW_INFO, { Size = template.Size }):Play()

		addSound("MochiFormating", created)
		task.delay(0.25, function()
			if not running then
				return
			end
			addSound("MochiRollStart", created, 3)
			task.wait(1.5)
			if running then
				addSound("MochiRoll", created)
			end
		end)

		-- Each client keeps its own copy of the acceleration for the spin, as in the source.
		local getSpeed, stop = accelerate()
		stopSpin = stop
		local spin = 0
		spinConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
			if not root.Parent then
				return
			end
			spin += math.rad(getSpeed() * SPIN_PER_SPEED * deltaTime)
			created.CFrame = yawOnly(root.CFrame) * CFrame.Angles(0, math.rad(-90), spin)
		end)
	end

	-- The donut is in the effects folder, not in the character: it is all that is seen.
	local showBody = CharacterHide.Hide(character)

	local stopDriving = if isLocal then drive(character, root, factor) else nil

	return function()
		running = false
		showBody()
		if stopDriving then
			stopDriving()
		end
		if spinConnection then
			spinConnection:Disconnect()
		end
		if stopSpin then
			stopSpin()
		end
		if donut then
			donut:Destroy()
		end

		if not root.Parent then
			return
		end
		local particles = folder and folder:FindFirstChild("Deforming")
		if particles and particles:IsA("ParticleEmitter") then
			local emitter = particles:Clone()
			if secondary then
				emitter.Color = ColorSequence.new(secondary)
			end
			emitter.Parent = root
			emitter:Emit(10)
			Debris:AddItem(emitter, 1)
		end
		addSound("MochiFormating", root, 2.5)
	end
end
