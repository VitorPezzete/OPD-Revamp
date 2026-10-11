--!strict
--[[
	Gum fruit - one stretching arm (Pistol, each arm of Bazooka, each punch of Gatling).
	params: { Direction: Vector3, Distance: number (studs to the tip the server found),
	          Time: number (seconds to reach it, the legacy "punch time"), Hold: number
	          (seconds the arm stays out), Hand: "Left" | "Right", Haki: boolean,
	          Face: boolean, Caster: Model, Colors: string }
	`origin` is the hand position the server cast from.

	No template: like the legacy arm it is a plain SmoothPlastic part with the color of
	the caster's arm (dark with armament haki), as thick as the arm. It stretches from the
	hand to the tip in `Time`, waits `Hold` and comes back in `Time`, with the default
	tween easing as in the legacy game: the fist arrives when the server's hit does.

	Legacy timings, kept:
	- Pistol / Bazooka (Face): the stretched arm is removed 1.5 * Time after it starts
	  coming back; the real arm (and its haki shell) reappears 1.75 * Time + 0.1 s after
	  the press, while the stretched one is still out.
	- Gatling: the stretched arm is removed Time + 0.1 s after it starts coming back;
	  the real arms stay hidden for the whole stream (Effects.Status.GumGatling).

	Pin, on the caster's own client. The legacy server put two movers in the user:
	- Pistol / Bazooka: a BodyPosition in the root (MaxForce 1e8, P 100000, D 1000) at
	  the spot the user was standing, or hanging in the air, and a BodyGyro in the head
	  (MaxTorque 1e8, P 100000) looking from the head at the tip, pitch included, both
	  removed with the stretched arm. They are created here, the owner being the one who
	  simulates its character.
	- Gatling: the two movers belong to the stream (Effects.Status.GumGatling); each
	  punch only turns its gyro towards its own tip.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local HAKI_COLOR = Color3.new(0.1, 0.05, 0.1)
local HAKI_SHELL = "HakiShell"
local DEFAULT_COLOR = Color3.fromRGB(234, 184, 146)
local DEFAULT_THICKNESS = 1
local MIN_LENGTH = 1

local PIN_FORCE = Vector3.new(1e8, 1e8, 1e8)
local PIN_POWER = 100000
local PIN_DAMPING = 1000
-- Shared with Effects.Status.GumGatling.
local GATLING_GYRO = "GatlingBG"
local GATLING_TAIL = "GumGatlingTail"

--[[
	Hidden real arms are counted, so overlapping punches of one arm restore it once. The
	count lives in client-side attributes on the arm because Effects.Status.GumRocket and
	GumGatling hide the same arms with the same two functions.
]]
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

-- The legacy movers of a Pistol / Bazooka punch (see the header), for `seconds`.
local function pin(character: Model, tip: Vector3, seconds: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return
	end

	local hold = Instance.new("BodyPosition")
	hold.Name = "GumPunchHold"
	hold.MaxForce = PIN_FORCE
	hold.P = PIN_POWER
	hold.D = PIN_DAMPING
	hold.Position = root.Position
	hold.Parent = root

	local turn = Instance.new("BodyGyro")
	turn.Name = "GumPunchTurn"
	turn.MaxTorque = PIN_FORCE
	turn.P = PIN_POWER
	if (tip - head.Position).Magnitude > 1e-3 then
		turn.CFrame = CFrame.lookAt(head.Position, tip)
	end
	turn.Parent = head

	Debris:AddItem(hold, seconds)
	Debris:AddItem(turn, seconds)
end

-- A Gatling punch of the local character: the stream's gyro looks at this punch.
local function aimStream(character: Model, tip: Vector3, tail: number)
	local head = character:FindFirstChild("Head")
	local turn = head and head:FindFirstChild(GATLING_GYRO)
	if head and head:IsA("BasePart") and turn and turn:IsA("BodyGyro") and (tip - head.Position).Magnitude > 1e-3 then
		turn.CFrame = CFrame.lookAt(head.Position, tip)
	end
	-- Until when the stream's movers must outlive the stream (read by GumGatling).
	character:SetAttribute(GATLING_TAIL, os.clock() + tail)
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local direction = params.Direction
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-3 then
		return
	end
	local unit: Vector3 = direction.Unit
	local punchTime: number = if type(params.Time) == "number" and params.Time > 0 then params.Time else 0.25
	local hold: number = if type(params.Hold) == "number" and params.Hold >= 0 then params.Hold else 0.1
	local distance: number = if type(params.Distance) == "number" then math.max(params.Distance, MIN_LENGTH) else 50

	local caster = params.Caster
	local realArm: BasePart? = nil
	if typeof(caster) == "Instance" and caster:IsA("Model") then
		local found = caster:FindFirstChild((if params.Hand == "Left" then "Left" else "Right") .. " Arm")
		if found and found:IsA("BasePart") then
			realArm = found
		end
	end

	local start = origin
	local thickness = DEFAULT_THICKNESS
	local color = DEFAULT_COLOR
	if realArm then
		start = realArm.Position
		thickness = realArm.Size.X
		color = realArm.Color
	end
	if params.Haki then
		color = HAKI_COLOR
	end

	local facing = CFrame.lookAt(start, start + unit)

	local arm = Instance.new("Part")
	arm.Name = "GumArm"
	arm.Anchored = true
	arm.CanCollide = false
	arm.CanQuery = false
	arm.CanTouch = false
	arm.CastShadow = false
	arm.Material = Enum.Material.SmoothPlastic
	arm.TopSurface = Enum.SurfaceType.Smooth
	arm.BottomSurface = Enum.SurfaceType.Smooth
	arm.Color = color

	local restSize = Vector3.new(thickness, thickness, MIN_LENGTH)
	arm.Size = restSize
	arm.CFrame = facing
	arm.Parent = World.Effects()

	local shownArm = realArm
	if shownArm then
		hide(shownArm)
	end

	local single = params.Face == true
	-- When the stretched arm is removed, and when the real one is shown again.
	local lifetime = punchTime + hold + (if single then punchTime * 1.5 else punchTime + 0.1)
	local shownAfter = if single then punchTime * 1.75 + 0.1 else lifetime
	if typeof(caster) == "Instance" and caster:IsA("Model") and caster == Players.LocalPlayer.Character then
		local tip = start + unit * distance
		if single then
			pin(caster, tip, lifetime)
		else
			aimStream(caster, tip, lifetime)
		end
	end

	local tweenInfo = TweenInfo.new(punchTime)
	TweenService:Create(arm, tweenInfo, {
		Size = Vector3.new(thickness, thickness, distance),
		CFrame = facing * CFrame.new(0, 0, -distance / 2),
	}):Play()

	task.delay(punchTime + hold, function()
		if arm.Parent then
			TweenService:Create(arm, tweenInfo, { Size = restSize, CFrame = facing }):Play()
		end
	end)

	task.delay(shownAfter, function()
		if shownArm then
			show(shownArm)
		end
	end)
	Debris:AddItem(arm, lifetime)
end
