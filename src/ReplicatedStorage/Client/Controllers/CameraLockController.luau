--!strict
--[[
	Camera lock for players without a mouse (gamepad, touch): the camera keeps one
	character in view, so attacks and abilities land on it while the player only moves.

		CameraLockController:Toggle()        lock the character nearest the aim point, or let go
		CameraLockController:GetTarget()     -> BasePart? (its root)
		CameraLockController.Changed         (target: BasePart?)

	Framing. The camera is not pointed straight at the target: that hides it behind the
	player's own character. It looks past the character's shoulder instead - the nearer
	the target, the wider the angle - and tilts down a little so both are in the picture.
	The shoulder is the side the camera is already on; it changes sides when something
	stands between the camera and the target there.

	The player keeps the camera. Turning it by hand never breaks the lock: the pull simply
	waits until the camera has been left alone for a moment, then eases back. While the
	target is out of the picture the aim reticle shows an arrow towards it (AimReticle).
	Aim still goes to the target the whole time (InputController:GetAimPosition).

	Settings.Camera_Lock is its strength: 0 turns it off, 1-3 is how fast the camera comes
	back and how soon after the player lets go. The lock ends by itself when the target
	dies, goes out of range or the player's character is gone.

	Gamepad: InputController's action "CameraLock", the right stick button unless the
	player bound another one (Settings > Keybinds > Controller). That button is also the
	engine's camera zoom, and an action bound to it takes the press away from the engine,
	so both live on it: a tap locks or lets go, holding it steps the zoom as the engine
	would (close, far, first person). Touch: the lock button of MobileContext.

	Root lock (Settings.Root_Lock), also for players without a mouse: the character always
	faces where the camera looks, which a mouse gets from the engine's shift lock. It is the
	engine's own switch for that (UserGameSettings.RotationType = CameraRelative), so the
	turning is done by the humanoid as with shift lock and costs nothing here; anything that
	takes the rotation away from the humanoid (AutoRotate off during an ability) still wins.
	Back on a mouse the switch returns to the engine's default.

	The turn is applied right after the engine's camera update, around the camera's focus.
	The engine's camera starts each frame from the camera's current look direction, so the
	turn carries over and nothing snaps back when the lock ends. A look direction that is
	not the one left on the previous frame, while a finger is on the screen or the right
	stick is pushed, is the player's hand.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local AimAssist = require(ReplicatedStorage.Client.Util.AimAssist)
local World = require(ReplicatedStorage.Shared.Util.World)

local SETTING = "Camera_Lock"
local ROOT_SETTING = "Root_Lock"
local STEP_NAME = "CameraLock"
-- By strength (1-3): how fast the camera closes on the framing per second, and the
-- seconds it waits after the player's hand left the camera.
local PULL = { 2.5, 5, 9 }
local RESUME_SECONDS = { 2.2, 1.4, 0.8 }
-- The lock lets go beyond this distance (studs) from the character.
local RELEASE_DISTANCE = 350

-- Studs the camera's line of sight passes beside the character; the angle this makes
-- shrinks as the target gets further away. Never wider than MAX_SIDE_ANGLE.
local SHOULDER_STUDS = 5
local MAX_SIDE_ANGLE = math.rad(28)
-- Downward tilt added to the line towards the target: more of it up close.
local TILT_NEAR = math.rad(16)
local TILT_FAR = math.rad(6)
local TILT_FAR_DISTANCE = 80
-- The camera is never pulled to look further up or down than this.
local MAX_PITCH_UP = math.rad(40)
local MAX_PITCH_DOWN = math.rad(-55)
-- A frame-to-frame turn above this (radians) is the player turning the camera.
local HAND_ANGLE = math.rad(0.15)
-- Deflection of the right stick that counts as pushing it.
local STICK_DEADZONE = 0.2
-- The lock button held this long (seconds) steps the camera zoom instead of locking.
local ZOOM_HOLD_SECONDS = 0.35
-- The engine's own gamepad zoom steps (studs), and the first-person one.
local ZOOM_NEAR = 10
local ZOOM_FAR = 20
local ZOOM_FIRST_PERSON = 0
-- Seconds between two checks of what stands between the camera and the target.
local SIGHT_INTERVAL = 0.25

local CameraLockController = Knit.CreateController({
	Name = "CameraLockController",
})

CameraLockController.Changed = Signal.new() :: Signal.Signal<BasePart?>

local InputController
local SettingsController

local localPlayer = Players.LocalPlayer
local target: BasePart? = nil
local bound = false

-- Which shoulder the camera looks past: 1 or -1.
local side = 1
-- The look direction this controller left on the previous frame.
local lastLook: Vector3? = nil
local resumeAt = 0
local untilSight = 0
-- What the player's hand is doing: fingers on the screen, deflection of the right stick.
local touches = 0
local stick = 0

local function getStrength(): number
	local value = SettingsController:Get(SETTING)
	return if type(value) == "number" then math.clamp(math.floor(value), 0, #PULL) else 0
end

local function isAlive(part: BasePart): boolean
	local model = part.Parent
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not model or not part:IsDescendantOf(Workspace) or not humanoid then
		return false
	end
	local health = model:GetAttribute("Health")
	return (if type(health) == "number" then health else humanoid.Health) > 0
end

local function setTarget(part: BasePart?)
	if target == part then
		return
	end
	target = part
	lastLook = nil
	resumeAt = 0
	untilSight = 0
	if part and not bound then
		bound = true
		RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function(delta: number)
			CameraLockController:_step(delta)
		end)
	elseif not part and bound then
		bound = false
		RunService:UnbindFromRenderStep(STEP_NAME)
	end
	CameraLockController.Changed:Fire(part)
end

-- The look direction that frames `part` past the given shoulder of the character.
local function framing(root: BasePart, part: BasePart, shoulder: number): Vector3
	local offset = part.Position - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local distance = flat.Magnitude
	if distance < 0.5 then
		-- On top of each other: keep facing wherever the character faces.
		flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		distance = 0.5
	end

	local sideAngle = math.min(math.atan(SHOULDER_STUDS / distance), MAX_SIDE_ANGLE) * shoulder
	local yaw = math.atan2(-flat.X, -flat.Z) + sideAngle
	local tilt = TILT_NEAR + (TILT_FAR - TILT_NEAR) * math.clamp(distance / TILT_FAR_DISTANCE, 0, 1)
	local pitch = math.clamp(math.atan2(offset.Y, distance) - tilt, MAX_PITCH_DOWN, MAX_PITCH_UP)
	return (CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)).LookVector
end

-- Whether the target would be seen from where that look direction puts the camera.
local function inSight(character: Model, part: BasePart, focus: Vector3, look: Vector3, distance: number): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { character }
	if part.Parent then
		table.insert(ignore, part.Parent)
	end
	-- What this client draws never hides a target: a thrown sword slash answers queries
	-- (Effects.OneShot.WeaponSlash) and would otherwise stand between the two.
	local effects = World.Effects()
	if effects ~= Workspace then
		table.insert(ignore, effects)
	end
	params.FilterDescendantsInstances = ignore
	local origin = focus - look * distance
	return Workspace:Raycast(origin, part.Position - origin, params) == nil
end

function CameraLockController:_step(delta: number)
	local camera = Workspace.CurrentCamera
	local part = target
	local character = localPlayer.Character
	local root = character and character.PrimaryPart
	local strength = getStrength()
	if not camera or not part or not character or not root or strength == 0 or not isAlive(part) then
		setTarget(nil)
		return
	end
	if (part.Position - root.Position).Magnitude > RELEASE_DISTANCE then
		setTarget(nil)
		return
	end

	local focus = camera.Focus.Position
	local distance = (camera.CFrame.Position - focus).Magnitude
	local look = camera.CFrame.LookVector
	if distance < 0.01 then
		lastLook = look
		return
	end

	-- The player turned the camera since the last frame: it is theirs for a while.
	local now = os.clock()
	local previous = lastLook
	local handOn = touches > 0 or stick > STICK_DEADZONE
	if handOn and previous and math.acos(math.clamp(look:Dot(previous), -1, 1)) > HAND_ANGLE then
		resumeAt = now + RESUME_SECONDS[strength]
		-- The shoulder follows the side the player left the camera on.
		local toTarget = part.Position - root.Position
		local cross = look:Cross(Vector3.new(toTarget.X, 0, toTarget.Z))
		if math.abs(cross.Y) > 1e-3 then
			side = if cross.Y > 0 then -1 else 1
		end
	end
	if now < resumeAt then
		lastLook = look
		return
	end

	local wanted = framing(root, part, side)
	untilSight -= delta
	if untilSight <= 0 then
		untilSight = SIGHT_INTERVAL
		if not inSight(character, part, focus, wanted, distance) then
			local other = framing(root, part, -side)
			if inSight(character, part, focus, other, distance) then
				side = -side
				wanted = other
			end
		end
	end

	local alpha = 1 - math.exp(-PULL[strength] * delta)
	local turned = look:Lerp(wanted, alpha)
	if turned.Magnitude < 1e-3 then
		lastLook = look
		return
	end
	turned = turned.Unit
	camera.CFrame = CFrame.lookAt(focus - turned * distance, focus)
	lastLook = camera.CFrame.LookVector
end

function CameraLockController:GetTarget(): BasePart?
	return target
end

function CameraLockController:IsEnabled(): boolean
	return getStrength() > 0
end

function CameraLockController:Unlock()
	setTarget(nil)
end

-- Locks onto the character nearest the aim point, or lets go of the current one.
function CameraLockController:Toggle()
	if target then
		setTarget(nil)
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera or getStrength() == 0 then
		return
	end
	setTarget(AimAssist.FindTarget(camera, InputController:GetAimPoint(), localPlayer.Character))
end

-- The next zoom distance after the current one, as the engine cycles them. The camera
-- script offers no call for it: pinning the player's zoom limits for a moment moves it.
local function stepZoom()
	local camera = Workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local current = (camera.CFrame.Position - camera.Focus.Position).Magnitude
	local wanted = if current < ZOOM_NEAR / 2
		then ZOOM_NEAR
		elseif current < (ZOOM_NEAR + ZOOM_FAR) / 2 then ZOOM_FAR
		else ZOOM_FIRST_PERSON
	local minimum, maximum = localPlayer.CameraMinZoomDistance, localPlayer.CameraMaxZoomDistance
	wanted = math.clamp(wanted, minimum, math.max(minimum, maximum))
	localPlayer.CameraMaxZoomDistance = wanted
	localPlayer.CameraMinZoomDistance = wanted
	task.delay(0.1, function()
		localPlayer.CameraMinZoomDistance = minimum
		localPlayer.CameraMaxZoomDistance = maximum
	end)
end

local function applyRootLock()
	local locked = SettingsController:Get(ROOT_SETTING) == true and InputController:GetDeviceKind() ~= "KeyboardMouse"
	local ok, problem = pcall(function()
		local gameSettings = (UserSettings() :: any):GetService("UserGameSettings")
		gameSettings.RotationType = if locked then Enum.RotationType.CameraRelative else Enum.RotationType.MovementRelative
	end)
	if not ok then
		warn(`[CameraLock] root lock could not be applied: {tostring(problem)}`)
	end
end

function CameraLockController:KnitInit()
	InputController = Knit.GetController("InputController")
	SettingsController = Knit.GetController("SettingsController")
end

function CameraLockController:KnitStart()
	-- A tap locks; a hold zooms (see the header). Counted per press, so a release that
	-- belongs to an older press does nothing.
	local press = 0
	local down = false
	InputController:OnAction("CameraLock", function(phase: string)
		if phase == "Begin" then
			press += 1
			down = true
			local current = press
			task.delay(ZOOM_HOLD_SECONDS, function()
				if down and press == current then
					-- The release of this press is no longer a tap.
					down = false
					stepZoom()
				end
			end)
		elseif phase == "End" and down then
			-- An "End" also arrives alone (input suspended): only a press seen here counts.
			down = false
			CameraLockController:Toggle()
		end
	end)

	-- Turned off in the settings, back on a mouse, or no body: nothing stays locked.
	SettingsController:Observe(SETTING, function()
		if getStrength() == 0 then
			setTarget(nil)
		end
	end)
	InputController.DeviceKindChanged:Connect(function(kind: string)
		if kind == "KeyboardMouse" then
			setTarget(nil)
		end
		applyRootLock()
	end)
	SettingsController:Observe(ROOT_SETTING, applyRootLock)
	localPlayer.CharacterRemoving:Connect(function()
		setTarget(nil)
	end)

	UserInputService.TouchStarted:Connect(function()
		touches += 1
	end)
	UserInputService.TouchEnded:Connect(function()
		touches = math.max(0, touches - 1)
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.new(input.Position.X, input.Position.Y).Magnitude
		end
	end)
end

return CameraLockController
