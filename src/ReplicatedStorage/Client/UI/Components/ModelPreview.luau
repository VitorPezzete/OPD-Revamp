--!strict
--[[
	A 3D preview of a part or model in a ViewportFrame: accessories, items, anything that
	is better turned around than drawn as a flat icon.

		ModelPreview(scope, {
			Source = AppearanceAssets.GetExtra(name),   -- or a state object; nil shows nothing
			Spin = isHovered,                            -- slow turntable (default true)
			Angle = Vector2.new(35, 20),                 -- yaw / pitch in degrees (default a 3/4 view)
			Size = UDim2.fromScale(1, 1),
		})

	The source is copied (scripts, GUIs, sounds, emitters and joints stripped, parts anchored),
	centred on its bounding box and framed so that it fits at any angle. The camera faces the
	front (-Z) of the source's pivot. A new source replaces the copy; the copy goes with the
	scope.

	Spinning moves the camera (and the light with it) from one RenderStepped connection that
	only exists while the preview is spinning and in the game, and skips frames while the
	preview is hidden.
]]
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Source: UsedAs<Instance?>,
	Spin: UsedAs<boolean>?,
	-- Yaw and pitch of the camera, in degrees. Yaw 0 looks at the front of the source.
	Angle: Vector2?,
}

-- The copy, centred at the origin, and the radius of the sphere around it.
type Framed = {
	Model: Model,
	Radius: number,
}

local FIELD_OF_VIEW = 30
local DEFAULT_ANGLE = Vector2.new(35, 20)
-- Radians per second: a slow turntable.
local SPIN_SPEED = 0.6
-- Room around the bounding sphere.
local MARGIN = 1.08
-- How often a spinning preview checks whether it is on screen.
local VISIBILITY_CHECK = 0.25
-- Seconds between the redraws that follow a new copy (see redraw below).
local REDRAW_DELAYS = { 0, 0.25, 1 }
-- Where the light comes from, in camera space: over the viewer's left shoulder.
local LIGHT = Vector3.new(0.6, -1, -0.8).Unit

-- The eight corners of a box, as signs of its half size.
local CORNERS = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
}

-- Instances that only matter in the world (behaviour, effects, physics, interfaces).
local CLUTTER = {
	"LuaSourceContainer",
	"GuiBase",
	"Sound",
	"ParticleEmitter",
	"Trail",
	"Beam",
	"Fire",
	"Smoke",
	"Sparkles",
	"Light",
	"JointInstance",
	"WeldConstraint",
	"Constraint",
	"BodyMover",
	"ProximityPrompt",
	"ClickDetector",
}

local function isClutter(instance: Instance): boolean
	for _, className in CLUTTER do
		if instance:IsA(className) then
			return true
		end
	end
	return false
end

-- Copies `source` even when it is not Archivable; nil when it cannot be copied.
local function copy(source: Instance): Instance?
	local wasArchivable = source.Archivable
	source.Archivable = true
	local ok, clone = pcall(function(): Instance?
		return source:Clone()
	end)
	source.Archivable = wasArchivable
	return if ok then clone else nil
end

-- Orientation that the preview treats as "front up".
local function pivotOf(root: Instance, parts: { BasePart }): CFrame
	if root:IsA("PVInstance") then
		return (root :: PVInstance):GetPivot()
	end
	return parts[1].CFrame
end

-- Builds the centred copy inside `scope` (destroyed with it); nil when there is nothing to draw.
local function frame(scope: Scope, source: Instance): Framed?
	local clone = copy(source)
	if not clone then
		return nil
	end
	table.insert(scope, clone)

	local parts: { BasePart } = {}
	for _, descendant in clone:GetDescendants() do
		if isClutter(descendant) then
			descendant:Destroy()
		end
	end
	if clone:IsA("BasePart") then
		table.insert(parts, clone)
	end
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 then
		return nil
	end

	-- Work in the space of the source's pivot, so the framing does not depend on where the
	-- asset happens to sit in its folder.
	local pivot = pivotOf(clone, parts)
	local low = Vector3.one * math.huge
	local high = -Vector3.one * math.huge
	local placed: { CFrame } = {}
	for index, part in parts do
		local relative = pivot:ToObjectSpace(part.CFrame)
		placed[index] = relative
		local half = part.Size / 2
		for _, corner in CORNERS do
			local point = relative * (half * corner)
			low = low:Min(point)
			high = high:Max(point)
		end
	end
	local centre = (low + high) / 2
	local radius = math.max(((high - low) / 2).Magnitude, 0.05)

	-- Joints are gone, so every part is moved on its own.
	for index, part in parts do
		part.Anchored = true
		part.CanCollide = false
		part.CFrame = placed[index] - centre
	end

	local model: Model
	if clone:IsA("Model") then
		model = clone
	else
		model = scope:New("Model")({ Name = "Preview" }) :: any
		clone.Parent = model
	end
	return { Model = model, Radius = radius }
end

-- Whether `gui` is drawn: every GuiObject above it visible, its ScreenGui enabled.
local function shown(gui: GuiObject): boolean
	if gui.AbsoluteSize.X <= 0 or gui.AbsoluteSize.Y <= 0 then
		return false
	end
	local current: Instance? = gui
	while current do
		if current:IsA("GuiObject") then
			if not (current :: GuiObject).Visible then
				return false
			end
		elseif current:IsA("LayerCollector") then
			return (current :: LayerCollector).Enabled
		end
		current = current.Parent
	end
	return false
end

return function(scope: Scope, props: Props): ViewportFrame
	local angle = props.Angle or DEFAULT_ANGLE
	local yaw = math.rad(angle.X)
	local pitch = math.rad(math.clamp(angle.Y, -80, 80))

	local camera: Camera = scope:New("Camera")({ FieldOfView = FIELD_OF_VIEW }) :: any

	local properties = Theme.place(props, {
		Name = "ModelPreview",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Sunken,
		BackgroundTransparency = Theme.Transparency.Sunken,
		BorderSizePixel = 0,
		-- Warm and bright enough to read on the brown well.
		Ambient = Theme.Colors.TextDim,
		LightColor = Theme.Colors.TextMuted,
		CurrentCamera = camera,
		[Fusion.Children] = { camera },
	})
	-- Visible also depends on the copy, which needs the viewport first: set below.
	properties.Visible = false
	local viewport: ViewportFrame = scope:New("ViewportFrame")(properties) :: any

	-- The copy is parented here directly (not through Children), and destroyed with the
	-- inner scope when the source changes.
	local framed = scope:Computed(function(use, inner: Scope): Framed?
		local source = use(props.Source)
		if source == nil then
			return nil
		end
		local result = frame(inner, source)
		if result then
			result.Model.Parent = viewport
		end
		return result
	end)

	-- Nothing at all when there is no copy: the caller draws its own placeholder.
	local visible = scope:Computed(function(use): boolean
		return use(props.Visible) ~= false and use(framed) ~= nil
	end)

	local function place()
		local current = Fusion.peek(framed)
		if not current then
			return
		end
		local size = viewport.AbsoluteSize
		local aspect = if size.Y > 0 then size.X / size.Y else 1
		local half = math.rad(FIELD_OF_VIEW / 2)
		-- The narrower of the two fields of view decides the distance.
		local fit = math.min(half, math.atan(math.tan(half) * aspect))
		local distance = current.Radius / math.sin(fit) * MARGIN
		local direction =
			Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
		local cframe = CFrame.lookAt(direction * distance, Vector3.zero)
		camera.CFrame = cframe
		viewport.LightDirection = cframe:VectorToWorldSpace(LIGHT)
	end

	local spinning = scope:Computed(function(use): boolean
		local spin = if props.Spin == nil then true else use(props.Spin)
		return spin == true and use(framed) ~= nil
	end)

	local connection: RBXScriptConnection? = nil
	local onScreen = false
	local untilCheck = 0
	local function step(delta: number)
		untilCheck -= delta
		if untilCheck <= 0 then
			untilCheck = VISIBILITY_CHECK
			onScreen = shown(viewport)
		end
		if onScreen then
			yaw = (yaw + delta * SPIN_SPEED) % (math.pi * 2)
			place()
		end
	end
	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end
	local function refresh()
		if Fusion.peek(spinning) and viewport:IsDescendantOf(game) then
			if not connection then
				untilCheck = 0
				connection = RunService.RenderStepped:Connect(step)
			end
		else
			stop()
		end
	end
	table.insert(scope, stop)
	table.insert(scope, viewport.AncestryChanged:Connect(refresh))
	table.insert(scope, viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))

	scope:Observer(visible):onBind(function()
		viewport.Visible = Fusion.peek(visible)
	end)
	scope:Observer(framed):onBind(place)

	--[[
		A still viewport draws only when something in it changes, and a draw made while it
		was off screen, not laid out yet or waiting for its meshes comes out empty. So the
		camera is nudged by a hair (alternating, so the value always changes) once the
		meshes are in, a little later, and whenever the preview moves (a list scrolling).
	]]
	local nudge = 0.001
	local function redraw()
		if not Fusion.peek(framed) then
			return
		end
		nudge = -nudge
		camera.CFrame *= CFrame.new(0, 0, nudge)
	end
	scope:Observer(framed):onBind(function()
		local current = Fusion.peek(framed)
		if not current then
			return
		end
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, { current.Model })
			for _, wait in REDRAW_DELAYS do
				task.wait(wait)
				if Fusion.peek(framed) ~= current then
					return
				end
				redraw()
			end
		end)
	end)
	table.insert(scope, viewport:GetPropertyChangedSignal("AbsolutePosition"):Connect(redraw))
	scope:Observer(visible):onChange(function()
		task.defer(redraw)
	end)
	scope:Observer(spinning):onBind(refresh)

	return viewport
end
