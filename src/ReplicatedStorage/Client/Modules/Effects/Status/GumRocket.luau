--!strict
--[[
	Gum fruit - Gum Rocket.
	Status value: "<Stretch|Fly>|<x>|<y>|<z>|<speed>|<fruit slot>|<ability slot>".

	Everyone: both arms stretched from the shoulders towards the target point, as plain
	SmoothPlastic parts with the color of the real arms (dark with armament haki); the
	real arms (and their haki shells) are hidden meanwhile.
	- Stretch: the arms grow at <speed> studs per second until they reach the target.
	  When the status goes away in this phase (released before the grab, or the target
	  was out of reach) they slide back at the same speed before disappearing, as in the
	  legacy game.
	- Fly: they are attached to the target and shorten as the body arrives.

	Owner only:
	- the character is kept turned towards the target for as long as the arms are out
	  (the legacy loop set the root's CFrame every frame);
	- while the value says Fly, the flight, with the legacy mover: a BodyVelocity in the
	  torso (MaxForce 400000 on each axis, P 1250) whose velocity is <speed> towards a
	  point 4 studs above the target, recomputed every frame. It is removed after
	  distance / <speed> seconds, counted here from the start of the flight as the legacy
	  client did, and the body keeps the speed it has. Jumping asks the server to end the
	  flight early (the ability's secondary input) and, as in the legacy game, aims the
	  flight 30 studs above the target for one frame before letting go.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local STATUS = "GumRocket"
local PHASE_ACTION = 3
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.new(0.1, 0.05, 0.1)
local HAKI_SHELL = "HakiShell"
local SHOULDERS = {
	{ Arm = "Left Arm", Offset = Vector3.new(-1.5, 0.5, 0) },
	{ Arm = "Right Arm", Offset = Vector3.new(1.5, 0.5, 0) },
}
local TARGET_LIFT = Vector3.new(0, 4, 0)
local JUMP_LIFT = Vector3.new(0, 30, 0)
local FLIGHT_FORCE = Vector3.new(400000, 400000, 400000)
-- The arms are gone once they are this short again, or after this long.
local RETRACTED_LENGTH = 2
local MAX_RETRACT_TIME = 5

-- Same counted hiding as Effects.OneShot.GumPunch (see there).
local HIDDEN_COUNT = "GumHiddenCount"
local HIDDEN_TRANSPARENCY = "GumHiddenTransparency"

local function hide(arm: BasePart)
	local count = arm:GetAttribute(HIDDEN_COUNT)
	if type(count) == "number" and count > 0 then
		arm:SetAttribute(HIDDEN_COUNT, count + 1)
		return
	end
	arm:SetAttribute(HIDDEN_TRANSPARENCY, arm.Transparency)
	arm:SetAttribute(HIDDEN_COUNT, 1)
	arm.Transparency = 1
	local shell = arm:FindFirstChild(HAKI_SHELL)
	if shell and shell:IsA("BasePart") then
		shell:SetAttribute(HIDDEN_TRANSPARENCY, shell.Transparency)
		shell.Transparency = 1
	end
end

local function show(arm: BasePart)
	local count = arm:GetAttribute(HIDDEN_COUNT)
	if type(count) ~= "number" then
		return
	end
	if count > 1 then
		arm:SetAttribute(HIDDEN_COUNT, count - 1)
		return
	end
	local transparency = arm:GetAttribute(HIDDEN_TRANSPARENCY)
	arm:SetAttribute(HIDDEN_COUNT, nil)
	arm:SetAttribute(HIDDEN_TRANSPARENCY, nil)
	arm.Transparency = if type(transparency) == "number" then transparency else 0
	-- A shell put on while the arm was hidden has nothing saved and is left alone.
	local shell = arm:FindFirstChild(HAKI_SHELL)
	local shellTransparency = shell and shell:GetAttribute(HIDDEN_TRANSPARENCY)
	if shell and shell:IsA("BasePart") and type(shellTransparency) == "number" then
		shell:SetAttribute(HIDDEN_TRANSPARENCY, nil)
		shell.Transparency = shellTransparency
	end
end

local function noop() end

type Stretched = { Part: BasePart, Real: BasePart?, Offset: Vector3 }

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local flying = fields[1] == "Fly"
	local x, y, z = tonumber(fields[2]), tonumber(fields[3]), tonumber(fields[4])
	local parsedSpeed = tonumber(fields[5])
	local fruitSlot, abilitySlot = tonumber(fields[6]), tonumber(fields[7])

	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not x or not y or not z or not parsedSpeed or parsedSpeed <= 0 then
		return noop
	end
	if not foundRoot or not foundRoot:IsA("BasePart") then
		return noop
	end
	local root: BasePart = foundRoot
	local speed: number = parsedSpeed
	local target = Vector3.new(x, y, z)
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	local foundTorso = character:FindFirstChild("Torso")
	local torso: BasePart = if foundTorso and foundTorso:IsA("BasePart") then foundTorso else root

	local arms: { Stretched } = {}
	for _, shoulder in SHOULDERS do
		local found = character:FindFirstChild(shoulder.Arm)
		local real: BasePart? = if found and found:IsA("BasePart") then found else nil

		local part = Instance.new("Part")
		part.Name = "GumRocketArm"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Size = Vector3.one
		part.Parent = World.Effects()

		if real then
			hide(real)
		end
		table.insert(arms, { Part = part, Real = real, Offset = shoulder.Offset })
	end

	-- Draws both arms `reach` studs long (no longer than the way to the target).
	local function draw(reach: number)
		local hakiOn = character:GetAttribute(HAKI_ATTRIBUTE) ~= nil
		for _, arm in arms do
			local shoulder = torso.CFrame:PointToWorldSpace(arm.Offset)
			local offset = target - shoulder
			local distance = offset.Magnitude
			if distance < 0.05 then
				continue
			end

			local length = math.min(reach, distance)
			local part = arm.Part
			part.Size = Vector3.new(1, 1, 1 + length)
			part.CFrame = CFrame.lookAt(shoulder + offset.Unit * (length / 2), shoulder)
			local real = arm.Real
			part.Color = if hakiOn then HAKI_COLOR elseif real then real.Color else part.Color
		end
	end

	local function removeArms()
		for _, arm in arms do
			arm.Part:Destroy()
			if arm.Real then
				show(arm.Real)
			end
		end
	end

	local started = os.clock()
	local function getReach(): number
		return if flying then math.huge else (os.clock() - started) * speed
	end

	local function update()
		draw(getReach())
		if isLocal and not (humanoid and humanoid.Sit) then
			local position = root.Position
			local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
			if flat.Magnitude > 0.1 then
				root.CFrame = CFrame.lookAt(position, position + flat)
			end
		end
	end
	update()
	local drawConnection = RunService.RenderStepped:Connect(update)

	-- Owner: the flight itself.
	local mover: BodyVelocity? = nil
	local flightConnection: RBXScriptConnection? = nil
	local jumpConnection: RBXScriptConnection? = nil

	local function stopFlight()
		if flightConnection then
			flightConnection:Disconnect()
			flightConnection = nil
		end
		if jumpConnection then
			jumpConnection:Disconnect()
			jumpConnection = nil
		end
		if mover then
			mover:Destroy()
			mover = nil
		end
	end

	if isLocal and flying then
		local goal = target + TARGET_LIFT

		local velocity = Instance.new("BodyVelocity")
		velocity.Name = "RocketVelocity"
		velocity.MaxForce = FLIGHT_FORCE
		velocity.Velocity = Vector3.zero
		velocity.Parent = torso
		mover = velocity

		local endsAt = os.clock() + (goal - torso.Position).Magnitude / speed
		local function steer()
			if os.clock() >= endsAt then
				stopFlight()
				return
			end
			local offset = goal - torso.Position
			if offset.Magnitude > 1e-3 then
				velocity.Velocity = offset.Unit * speed
			end
		end
		steer()
		if mover then
			flightConnection = RunService.RenderStepped:Connect(steer)
		end

		if mover and fruitSlot and abilitySlot then
			local abilityService = Knit.GetService("AbilityService")
			local jumped = false
			jumpConnection = UserInputService.JumpRequest:Connect(function()
				if jumped then
					return
				end
				jumped = true
				if flightConnection then
					flightConnection:Disconnect()
					flightConnection = nil
				end
				local kick = target + JUMP_LIFT - torso.Position
				if kick.Magnitude > 0.1 then
					velocity.Velocity = kick.Unit * speed
				end
				-- The aim point is unused; the root position always validates.
				abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, root.Position)
				RunService.RenderStepped:Wait()
				stopFlight()
			end)
		end
	end

	return function()
		stopFlight()
		drawConnection:Disconnect()

		-- A change of phase, or anything but a plain release: the arms just go.
		if flying or character:GetAttribute(STATUS) ~= nil or not character:IsDescendantOf(Workspace) then
			removeArms()
			return
		end

		local released = os.clock()
		local reach = math.min(getReach(), (target - torso.Position).Magnitude)
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - released
			local remaining = reach - elapsed * speed
			if remaining <= RETRACTED_LENGTH or elapsed >= MAX_RETRACT_TIME or not torso.Parent then
				connection:Disconnect()
				removeArms()
				return
			end
			draw(remaining)
		end)
	end
end
