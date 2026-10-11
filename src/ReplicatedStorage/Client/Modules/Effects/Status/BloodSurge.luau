--!strict
--[[
	Blood fruit - Blood Surge: the body streams as blood while the key is held.
	Status value: "<speed in studs per second>|<fruit color string>".

	Everyone: a pool of blood under the root and blood pouring off the six body parts.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Blood.Power4.BloodPool (an
	Attachment of emitters, used as authored: one of them is off) and .Power4.Body (a
	folder of emitters, one copy per body part, all switched on). They keep pouring for
	half a second after the stream ends and are then removed, as before.

	Owner only: the flight. The legacy client pushed the character away from the camera
	(camera position to character) at a constant speed with a BodyVelocity, and turned the
	whole body towards the point under the mouse with a BodyGyro on the head, pitch
	included. Same direction and same facing here: the push is the same BodyVelocity
	(MaxForce 400000, default P), because the server's 0.3 s hold after the blink is a
	second BodyVelocity and the two have to blend as they did; the turn is an
	AlignOrientation.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local BODY_PARTS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DEFAULT_SPEED = 15
local FLIGHT_FORCE = 400000
local TURN_TORQUE = 1e8
local LINGER = 0.5

local function tint(instance: Instance, sequence: ColorSequence?)
	if not sequence then
		return
	end
	if instance:IsA("ParticleEmitter") then
		instance.Color = sequence
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Color = sequence
		end
	end
end

local function addVisuals(character: Model, colors: string): { Instance }
	local created: { Instance } = {}
	local primary, secondary = FruitColor.Parse(colors)
	local sequence = if primary and secondary then FruitColor.ToSequence(primary, secondary) else nil

	local root = character:FindFirstChild("HumanoidRootPart")
	local poolTemplate = EffectAssets.FindFruit("Blood", "Power4", "BloodPool")
	if root and poolTemplate then
		local pool = poolTemplate:Clone()
		tint(pool, sequence)
		pool.Parent = root
		table.insert(created, pool)
	end

	local bodyFolder = EffectAssets.FindFruit("Blood", "Power4", "Body")
	if bodyFolder then
		for _, partName in BODY_PARTS do
			local part = character:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				for _, template in bodyFolder:GetChildren() do
					local emitter = template:Clone()
					tint(emitter, sequence)
					if emitter:IsA("ParticleEmitter") then
						emitter.Enabled = true
					end
					emitter.Parent = part
					table.insert(created, emitter)
				end
			end
		end
	end
	return created
end

local function startFlight(character: Model, speed: number): (() -> ())?
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not foundHumanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return nil
	end
	local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot
	local foundHead = character:FindFirstChild("Head")
	local head: BasePart = if foundHead and foundHead:IsA("BasePart") then foundHead else root
	local inputController = Knit.GetController("InputController")

	local attachment = Instance.new("Attachment")
	attachment.Name = "BloodSurgeFlight"
	attachment.Parent = root

	local velocity = Instance.new("BodyVelocity")
	velocity.Name = "BloodSurgeFlight"
	velocity.MaxForce = Vector3.new(FLIGHT_FORCE, FLIGHT_FORCE, FLIGHT_FORCE)
	velocity.Velocity = Vector3.zero
	velocity.Parent = root

	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = TURN_TORQUE
	align.Responsiveness = 200
	align.CFrame = root.CFrame.Rotation
	align.Parent = attachment

	local previousAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false

	local connection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		-- Away from the camera; in first person the two coincide, so use where it looks.
		local offset = root.Position - camera.CFrame.Position
		local direction = if offset.Magnitude > 1 then offset.Unit else camera.CFrame.LookVector
		velocity.Velocity = direction * speed

		local aim: Vector3 = inputController:GetAimPosition()
		local look = aim - head.Position
		-- Straight up or down has no heading: keep the last facing.
		if look.Magnitude > 1e-3 and math.abs(look.Unit.Y) < 0.999 then
			align.CFrame = CFrame.lookAt(Vector3.zero, look)
		end
	end)

	return function()
		connection:Disconnect()
		velocity:Destroy()
		attachment:Destroy()
		humanoid.AutoRotate = previousAutoRotate
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local speed = tonumber(fields[1]) or DEFAULT_SPEED
	local visuals = addVisuals(character, fields[2] or "")
	local stopFlight = if isLocal then startFlight(character, speed) else nil

	return function()
		if stopFlight then
			stopFlight()
		end
		for _, visual in visuals do
			Debris:AddItem(visual, LINGER)
		end
	end
end
