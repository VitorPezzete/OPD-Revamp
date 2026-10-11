--!strict
--[[
	The control layout of the local player (Settings.Control_Layout: "Default", "Auto" or
	"Custom"): what is saved, what the editor is trying out, and who gets told.

		ControlsController:GetLayout()           -> "Default" | "Auto" | "Custom"
		ControlsController:IsCustom()            the layout setting is "Custom"
		ControlsController:UsesBehaviors()       the buttons follow a behaviour (Auto, Custom)
		ControlsController:GetButton(id)         -> ButtonEntry? (nil: the default button)
		ControlsController:GetBehavior(id)       -> "Hold", "Arm", ... for that button, now
		ControlsController:GetAimOffset()        -> Vector2, share of the viewport (zero when off)
		ControlsController.Changed               after anything above may have changed

	With the layout on "Default" every answer is the default one, whatever the profile
	holds: the saved Controls table is not even looked at. "Auto" does not look at it
	either: its buttons stay where they are, at their size, and GetBehavior answers what
	ControlsConfig.Auto gives the button for what its action is - for an ability button,
	how the ability on it uses its key (FruitConfig.GetPress), so the answer changes with
	the fruits and Changed says so. Only "Custom" reads the table.

	Who applies what (all of it on the client; the server only stores the table):
	- camera offset: here, see below. Gamepad and touch.
	- aim offset: InputController:GetAimPoint adds it; AimReticle draws the cross there.
	  Gamepad and touch.
	- touch buttons (place, size, behaviour): UI.Util.TouchControls, for the buttons of
	  MobileContext and of the touch AbilityBar.

	Camera offset. Humanoid.CameraOffset is the engine's own mechanism: its camera then
	follows a point beside the character and everything else (zoom, the walls it avoids,
	CameraLockController turning it around its focus) keeps working unchanged. Nothing else
	in the game writes that property. The engine reads it in the character's frame, which
	would swing the camera whenever the character turns, so the offset is kept in the
	camera's own level frame instead (right, up, back): while it has a sideways or depth
	part, one render step ahead of the engine's camera rewrites the property for the way
	the camera faces. A purely vertical offset is the same in both frames: it is written
	once and nothing runs per frame. It is written again when the character or its
	humanoid is replaced and taken away when the layout goes back to "Default" or the
	device becomes a keyboard and mouse.

	The editor (screen ControlsEditor) works on a draft: BeginEdit copies the saved table,
	the Set... methods change the copy - which is what everything above answers from while
	editing, so the result shows live - and Save sends it. EndEdit throws the draft away.
	Nothing reaches the server before Save. While editing, InputController is suspended:
	touching and dragging the controls must not use them.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local ControlsConfig = require(ReplicatedStorage.Shared.Configs.ControlsConfig)
local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)

type Controls = ControlsConfig.Controls
type ButtonEntry = ControlsConfig.ButtonEntry

local SETTING = ControlsConfig.LayoutSetting
local DATA_PATH = "Controls"
local STEP_NAME = "ControlsCameraOffset"
-- A change of the offset smaller than this (studs) is not worth writing.
local OFFSET_EPSILON = 1e-3

local ControlsController = Knit.CreateController({
	Name = "ControlsController",
})

-- Whenever the layout, the device, the saved table or the draft changed.
ControlsController.Changed = Signal.new()
-- (editing: boolean) when the editor starts or stops working on a draft.
ControlsController.EditingChanged = Signal.new() :: Signal.Signal<boolean>
-- (id: string?) the button selected in the editor.
ControlsController.SelectionChanged = Signal.new() :: Signal.Signal<string?>

local DataController
local InputController
local SettingsController
local SettingsService

local localPlayer = Players.LocalPlayer

local layout: string = ControlsConfig.Layouts.Default
local custom = false
local saved: Controls = ControlsConfig.Default()
local draft: Controls? = nil
local selected: string? = nil
-- The aim offset in force, kept ready: GetAimOffset is read every frame by the reticle.
local aimOffset = Vector2.zero

-- What the offset is applied to, and whether this controller left one on it.
local humanoid: Humanoid? = nil
local humanoidConnection: RBXScriptConnection? = nil
local stepBound = false

local function current(): Controls
	return draft or saved
end

-- Camera and aim offsets are for players without a mouse.
local function offsetsActive(): boolean
	return custom and InputController:GetDeviceKind() ~= "KeyboardMouse"
end

local function cameraOffset(): Vector3
	if not offsetsActive() then
		return Vector3.zero
	end
	local offset = current().CameraOffset
	return Vector3.new(offset.X, offset.Y, offset.Z)
end

local function write(target: Humanoid, offset: Vector3)
	if (target.CameraOffset - offset).Magnitude > OFFSET_EPSILON then
		target.CameraOffset = offset
	end
end

-- Ahead of the engine's camera, every frame, while the offset has a sideways or depth part.
local function stepCamera()
	local camera = Workspace.CurrentCamera
	local target = humanoid
	local root = target and target.RootPart
	if not camera or not target or not root then
		return
	end
	local offset = cameraOffset()
	-- The engine's camera never rolls: its right vector is level.
	local right = camera.CFrame.RightVector * Vector3.new(1, 0, 1)
	if right.Magnitude < OFFSET_EPSILON then
		return
	end
	right = right.Unit
	local back = Vector3.new(-right.Z, 0, right.X)
	local world = right * offset.X + Vector3.yAxis * offset.Y + back * offset.Z
	write(target, root.CFrame:VectorToObjectSpace(world))
end

local function setStep(wanted: boolean)
	if wanted and not stepBound then
		stepBound = true
		RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value - 1, stepCamera)
	elseif not wanted and stepBound then
		stepBound = false
		RunService:UnbindFromRenderStep(STEP_NAME)
	end
end

local function applyCamera()
	local offset = cameraOffset()
	local target = humanoid
	local turning = target ~= nil and (math.abs(offset.X) > OFFSET_EPSILON or math.abs(offset.Z) > OFFSET_EPSILON)
	setStep(turning)
	if not target then
		return
	end
	if turning then
		stepCamera()
	else
		-- Up and down only (or nothing at all): the same in the character's frame.
		write(target, Vector3.new(0, offset.Y, 0))
	end
end

local function bindCharacter(character: Model?)
	if humanoidConnection then
		humanoidConnection:Disconnect()
		humanoidConnection = nil
	end
	humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if character then
		-- A humanoid that arrives late, or replaces the first one.
		humanoidConnection = character.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Humanoid") then
				humanoid = child
				applyCamera()
			end
		end)
	end
	applyCamera()
end

local function refresh()
	local offset = current().AimOffset
	aimOffset = if offsetsActive() then Vector2.new(offset.X, offset.Y) else Vector2.zero
	applyCamera()
	ControlsController.Changed:Fire()
end

---------------------------------------------------------------------------------
-- Reading

function ControlsController:GetLayout(): string
	return layout
end

function ControlsController:IsCustom(): boolean
	return custom
end

-- Whether the touch buttons follow a behaviour of ControlsConfig ("Auto", "Custom") and
-- not the plain presses and clicks of the default layout.
function ControlsController:UsesBehaviors(): boolean
	return layout ~= ControlsConfig.Layouts.Default
end

-- How the ability on an ability button uses its key, nil for any other button, an empty
-- slot or a fruit this version does not know.
local function pressOf(id: string): string?
	local fruitSlot, letter = string.match(id, "^DF(%d)(%a)$")
	local abilitySlot = letter and table.find(InputConfig.SlotLetters, letter)
	if not fruitSlot or not abilitySlot then
		return nil
	end
	local fruitName = DataController:Get(`DevilFruits.Slot{fruitSlot}.Name`)
	local ability = if type(fruitName) == "string" then FruitConfig.GetAbility(fruitName, abilitySlot) else nil
	return if ability then FruitConfig.GetPress(ability) else nil
end

-- The table in force: the draft while editing, what is saved otherwise. Not to be changed.
function ControlsController:GetControls(): Controls
	return current()
end

-- What the player changed about that touch button; nil for the default button.
function ControlsController:GetButton(id: string): ButtonEntry?
	return if custom then current().Buttons[id] else nil
end

function ControlsController:GetBehavior(id: string): string
	if layout == ControlsConfig.Layouts.Auto then
		return ControlsConfig.AutoBehavior(id, pressOf(id))
	end
	local entry = if custom then current().Buttons[id] else nil
	return if entry then entry.Behavior else ControlsConfig.DefaultBehavior(id)
end

-- Share of the viewport the aim point is moved by; zero unless Custom on a gamepad or touch.
function ControlsController:GetAimOffset(): Vector2
	return aimOffset
end

---------------------------------------------------------------------------------
-- Editing

function ControlsController:IsEditing(): boolean
	return draft ~= nil
end

function ControlsController:GetSelected(): string?
	return selected
end

function ControlsController:Select(id: string?)
	if id ~= nil and (not draft or not ControlsConfig.Buttons[id]) then
		return
	end
	if selected ~= id then
		selected = id
		ControlsController.SelectionChanged:Fire(id)
	end
end

function ControlsController:BeginEdit()
	if draft then
		return
	end
	-- Read gives a table of its own: the draft never shares anything with what is saved.
	draft = ControlsConfig.Read(saved)
	InputController:SetSuspended(true)
	ControlsController.EditingChanged:Fire(true)
	refresh()
end

function ControlsController:EndEdit()
	if not draft then
		return
	end
	draft = nil
	ControlsController:Select(nil)
	InputController:SetSuspended(false)
	ControlsController.EditingChanged:Fire(false)
	refresh()
end

-- axis: "X" | "Y" | "Z". Moves the draft's camera offset by a number of editor steps.
function ControlsController:StepCameraOffset(axis: string, steps: number)
	local range = (ControlsConfig.CameraOffset :: any)[axis]
	if not draft or type(range) ~= "table" then
		return
	end
	local offset = draft.CameraOffset :: any
	offset[axis] = ControlsConfig.Step(offset[axis], steps, ControlsConfig.CameraOffset.Step, range)
	refresh()
end

-- axis: "X" | "Y".
function ControlsController:StepAimOffset(axis: string, steps: number)
	local range = (ControlsConfig.AimOffset :: any)[axis]
	if not draft or type(range) ~= "table" then
		return
	end
	local offset = draft.AimOffset :: any
	offset[axis] = ControlsConfig.Step(offset[axis], steps, ControlsConfig.AimOffset.Step, range)
	refresh()
end

-- The draft's entry of a button, created as the default button when it has none.
local function entryOf(id: string): ButtonEntry?
	if not draft or not ControlsConfig.Buttons[id] then
		return nil
	end
	local entry = draft.Buttons[id]
	if not entry then
		entry = { Scale = ControlsConfig.Scale.Default, Behavior = ControlsConfig.DefaultBehavior(id) }
		draft.Buttons[id] = entry
	end
	return entry
end

-- Puts the centre of a button at a share (0-1) of the usable screen.
function ControlsController:MoveButton(id: string, x: number, y: number)
	local entry = entryOf(id)
	if not entry or x ~= x or y ~= y then
		return
	end
	local range = ControlsConfig.Position
	entry.X = math.clamp(x, range.Min, range.Max)
	entry.Y = math.clamp(y, range.Min, range.Max)
	refresh()
end

function ControlsController:StepButtonScale(id: string, steps: number)
	local entry = entryOf(id)
	if not entry then
		return
	end
	entry.Scale = ControlsConfig.Step(entry.Scale, steps, ControlsConfig.Scale.Step, ControlsConfig.Scale)
	refresh()
end

function ControlsController:CycleButtonBehavior(id: string)
	local entry = entryOf(id)
	if not entry then
		return
	end
	entry.Behavior = ControlsConfig.NextBehavior(id, entry.Behavior)
	refresh()
end

-- Back to the default button: its place in the default layout, its size, its behaviour.
function ControlsController:ResetButton(id: string)
	if draft and draft.Buttons[id] then
		draft.Buttons[id] = nil
		refresh()
	end
end

-- The whole draft back to the default table (saved only by Save, like any other change).
function ControlsController:ResetDraft()
	if draft then
		draft = ControlsConfig.Default()
		refresh()
	end
end

-- Sends the draft. Yields; true when the server stored it. The editor stays open either way.
function ControlsController:Save(): boolean
	local sending = draft
	if not sending then
		return false
	end
	-- Exactly what the server would rebuild from it; nil would be a bug of the editor.
	local clean = ControlsConfig.Validate(ControlsConfig.Read(sending))
	if not clean then
		return false
	end
	local ok, accepted = pcall(function(): boolean
		local resolved, result = SettingsService:SetControls(clean):await()
		return resolved and result == true
	end)
	if not ok or accepted ~= true then
		return false
	end
	-- The server stored this very table: it is the saved one from now, without waiting
	-- for the replication to say so (which would show the old layout for a moment).
	saved = clean
	refresh()
	return true
end

---------------------------------------------------------------------------------

function ControlsController:KnitInit()
	DataController = Knit.GetController("DataController")
	InputController = Knit.GetController("InputController")
	SettingsController = Knit.GetController("SettingsController")
end

function ControlsController:KnitStart()
	SettingsService = Knit.GetService("SettingsService")

	SettingsController:Observe(SETTING, function(value: any)
		-- Anything that is not a layout (a profile from another version) is the default one.
		local chosen = if value == ControlsConfig.Layouts.Custom or value == ControlsConfig.Layouts.Auto
			then value
			else ControlsConfig.Layouts.Default
		if chosen ~= layout then
			layout = chosen
			custom = chosen == ControlsConfig.Layouts.Custom
			-- Whoever follows the buttons lets go of what was held under the old layout.
			refresh()
		end
	end)
	-- "Auto" answers from the abilities on the buttons: other fruits, other behaviours.
	for fruitSlot = 1, 2 do
		DataController:Observe(`DevilFruits.Slot{fruitSlot}.Name`, function()
			if layout == ControlsConfig.Layouts.Auto then
				refresh()
			end
		end)
	end
	-- A profile without the table, or with buttons of another version, reads as what is valid.
	DataController:Observe(DATA_PATH, function(value: any)
		saved = ControlsConfig.Read(value)
		refresh()
	end)
	InputController.DeviceKindChanged:Connect(refresh)
	LocalCharacter.Observe(bindCharacter)
end

return ControlsController
