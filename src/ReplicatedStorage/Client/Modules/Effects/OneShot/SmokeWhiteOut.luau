--!strict
--[[
	Smoke fruit - White Out: the smoke leaving the caster's arms and chasing its targets.
	Purely cosmetic; the server runs the same chase as points and decides who is caught
	(a caught character then shows Effects.Status.SmokeWhiteOutHeld).

	origin: the caster's position when the key was pressed.
	params: { Targets: { Model }, Speed: number (studs per second), ChaseTime: number,
	          CatchRadius: number, HoldTime: number, Caster: Model, Colors: string }
	Templates: ReplicatedStorage.Assets.Models.Fruits.Smoke.Power2.SmokeArm / FollowingSmoke
	(ParticleEmitters).

	The caster's arms turn into smoke for HoldTime seconds: hidden on this client and
	replaced by a smoke emitter on each shoulder, then restored to what they were. As in
	the legacy game the sleeves (Arm1 / Arm2) and whatever is attached inside the arms
	(haki shell) disappear with them.
	A trail that catches its target lingers for HoldTime (the legacy emitter moved onto
	the victim, so its smoke stayed); one that gives up fades in 2 seconds.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local ARMS = {
	{ Name = "Left Arm", Offset = CFrame.new(-1.5, 0.5, 0) },
	{ Name = "Right Arm", Offset = CFrame.new(1.5, 0.5, 0) },
}
-- Time the last particles get to fade once a trail gives up.
local FADE_SECONDS = 2
local SLEEVES = { ["Left Arm"] = "Arm2", ["Right Arm"] = "Arm1" }

-- Hides a part and the parts inside it until `duration` has passed.
local function hide(part: Instance, duration: number)
	local pieces: { Instance } = part:GetDescendants()
	table.insert(pieces, part)
	for _, piece in pieces do
		if piece:IsA("BasePart") and piece.Transparency < 1 then
			local previous = piece.Transparency
			piece.Transparency = 1
			task.delay(duration, function()
				if piece.Parent then
					piece.Transparency = previous
				end
			end)
		end
	end
end

local function cloneEmitter(template: Instance?, parent: Instance, primary: Color3?, secondary: Color3?): ParticleEmitter?
	if not template or not template:IsA("ParticleEmitter") then
		return nil
	end
	local emitter = template:Clone()
	if primary and secondary then
		emitter.Color = FruitColor.ToSequence(primary, secondary)
	end
	emitter.Parent = parent
	return emitter
end

local function smokeArms(caster: Model, duration: number, template: Instance?, primary: Color3?, secondary: Color3?)
	local torso = caster:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end

	for _, arm in ARMS do
		local attachment = Instance.new("Attachment")
		attachment.CFrame = arm.Offset
		attachment.Parent = torso
		cloneEmitter(template, attachment, primary, secondary)
		Debris:AddItem(attachment, duration)

		local part = caster:FindFirstChild(arm.Name)
		if part then
			hide(part, duration)
		end
		local sleeve = caster:FindFirstChild(SLEEVES[arm.Name], true)
		if sleeve then
			hide(sleeve, duration)
		end
	end
end

local function chase(start: Vector3, target: Model, speed: number, chaseTime: number, catchRadius: number, holdTime: number, template: Instance?, primary: Color3?, secondary: Color3?)
	local terrain = Workspace.Terrain
	local attachment = Instance.new("Attachment")
	attachment.Parent = terrain
	attachment.WorldPosition = start

	local emitter = cloneEmitter(template, attachment, primary, secondary)

	local definition = (SoundConfig :: any).SFX.Elemental.Smoke["Smoke Loop"]
	if definition then
		local sound = Instance.new("Sound")
		sound.SoundId = definition.Id
		sound.Volume = definition.Volume
		sound.Looped = true
		sound.PlaybackSpeed = definition.Speed or 1
		sound.Parent = attachment
		sound:Play()
	end

	local position = start
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		local root = target:FindFirstChild("HumanoidRootPart")
		local offset = if root and root:IsA("BasePart") then root.Position - position else nil
		local travel = speed * deltaTime

		local caught = offset ~= nil and offset.Magnitude <= catchRadius + travel
		if not offset or caught or elapsed >= chaseTime then
			connection:Disconnect()
			if emitter then
				emitter.Enabled = false
			end
			Debris:AddItem(attachment, if caught then holdTime else FADE_SECONDS)
			return
		end

		position += offset.Unit * travel
		attachment.WorldPosition = position
	end)
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params or type(params.Targets) ~= "table" then
		return
	end
	local speed = params.Speed
	if type(speed) ~= "number" or speed <= 0 then
		return
	end
	local chaseTime: number = if type(params.ChaseTime) == "number" then params.ChaseTime else 10
	local catchRadius: number = if type(params.CatchRadius) == "number" then params.CatchRadius else 1.5
	local holdTime: number = if type(params.HoldTime) == "number" then params.HoldTime else 5

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local armTemplate = EffectAssets.FindFruit("Smoke", "Power2", "SmokeArm")
	local trailTemplate = EffectAssets.FindFruit("Smoke", "Power2", "FollowingSmoke")

	local caster = params.Caster
	local casterCFrame = CFrame.new(origin)
	if typeof(caster) == "Instance" and caster:IsA("Model") then
		smokeArms(caster, holdTime, armTemplate, primary, secondary)
		local root = caster:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			casterCFrame = root.CFrame
		end
	end

	local count = 0
	for _, target in params.Targets do
		-- A target that is not streamed in on this client arrives as nil and is skipped.
		if typeof(target) == "Instance" and target:IsA("Model") then
			local start = (casterCFrame * ARMS[count % 2 + 1].Offset).Position
			count += 1
			chase(start, target, speed, chaseTime, catchRadius, holdTime, trailTemplate, primary, secondary)
		end
	end
end
