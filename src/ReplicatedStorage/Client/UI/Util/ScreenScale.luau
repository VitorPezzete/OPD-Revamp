--!strict
--[[
	Dynamic interface scaling.

	The legacy interface was authored for a 1920x1080 (16:9) screen. It mixes two kinds
	of sizes, and each one breaks differently on other screens:

	- Pixel sizes (offsets, TextSize, strokes, corners, paddings) never change, so they
	  look huge on a small screen and tiny on a 4K one.
	- Scale sizes follow the screen, so on a different aspect ratio (21:9, 4:3, phones)
	  every panel is stretched or squashed.

	ScreenScale fixes both without touching the layouts:

	1. One factor = min(width / 1920, height / 1080), kept up to date with the viewport.
	   A UIScale with that factor is put on every ScreenGui: under a ScreenGui it scales
	   pixel sizes only, scale sizes still resolve against the real screen.
	2. Every top-level panel has its size pinned to the pixels it measured at 1920x1080
	   (scale and SizeConstraint resolved against the reference screen), so with the
	   UIScale it is always "its 1080p size times the factor", whatever the ratio. Its
	   position is rewritten as a share of the free space around it, so a centred panel
	   stays centred and one near an edge stays as near to it, and everything inside it
	   is relative to it and follows.
	   Full-screen containers are walked through (their children are the panels), and
	   an axis that spans the screen (bars, curtains) keeps stretching.

	3. Phones and tablets (touch, no keyboard) have their whole interface enlarged on short
	   screens: the plain factor would leave buttons smaller than a thumb. A panel that would
	   then not fit on the screen gets a UIScale ("ScreenFit") that shrinks it until it does.

	4. The factor also carries the drawing scale of the mounted interface (UIConfig.DrawScale)
	   and the player's own enlargement (Settings.UI_Scale), both read from UI.Util.Interface,
	   so changing either resizes everything at once. A screen that belongs to the other
	   set (the rework's health bar under the legacy interface) is given that set's style
	   and keeps the size it has there.

		ScreenScale.apply(scope, screenGui)   -- UIController does it for every screen
		ScreenScale.apply(scope, gui, "Divine")   -- with the factor of that style
		ScreenScale.Factor                    -- Fusion value, for code that needs pixels
		ScreenScale.toPixels(96)              -- 96 design pixels on the current screen
		ScreenScale.Touch                     -- true on a phone or tablet
]]
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local UIConfig = require(ReplicatedStorage.Shared.Configs.UIConfig)
local Interface = require(ReplicatedStorage.Client.UI.Util.Interface)

type Scope = Fusion.Scope<typeof(Fusion)>

local REFERENCE = Vector2.new(1920, 1080)
-- Below this the interface stops shrinking: text would no longer be readable.
local MIN_FACTOR = 0.4
local MAX_FACTOR = 3
-- Screens shorter than this (phones, small windows) get their menus enlarged, because the
-- plain factor makes buttons too small to press there.
local SMALL_HEIGHT = 720
local MAX_BOOST = 1.6
-- A phone or tablet: the boost goes to the whole interface instead of a few menus.
local TOUCH_DEVICE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
-- Share of the screen a panel may take before ScreenFit shrinks it.
local FIT_SHARE = 0.96
local FIT_NAME = "ScreenFit"
-- Below this height the viewport is not a real screen yet.
local MIN_FIT_HEIGHT = 200
-- A scale at or above this on an axis means "spans the screen" on that axis.
local SPAN = 0.9
-- Height of the Roblox top bar, which guis without IgnoreGuiInset do not cover.
local TOP_BAR = 58
-- Full-screen containers nested deeper than this are treated as panels.
local MAX_DEPTH = 4
-- Name of the UIScale the scaler adds; panels opt out with the attribute set to false.
local SCALER_NAME = "ScreenScale"
local OPT_OUT_ATTRIBUTE = "ScreenScale"
local PINNED_ATTRIBUTE = "ScreenScalePinned"
-- A panel with less free space than this share of its parent keeps its authored position.
local MIN_FREE = 0.02

local ScreenScale = {}

local rootScope = Fusion.scoped(Fusion)
-- The screen alone: resolution, and the enlargement of phones.
local base = rootScope:Value(1)
local styleFactors: { [string]: Fusion.StateObject<number> } = {}
for style, drawScale in UIConfig.DrawScale do
	styleFactors[style] = rootScope:Computed(function(use): number
		return use(base) * drawScale * use(Interface.UserScale)
	end)
end
local factor = rootScope:Computed(function(use): number
	return use(styleFactors[use(Interface.Style)])
end)
local viewport = rootScope:Value(REFERENCE)
local boost = rootScope:Value(1)

ScreenScale.Reference = REFERENCE
-- Extra scale for the pieces a player has to hit with a thumb (see ScreenScale.boost).
ScreenScale.Boost = boost
ScreenScale.Factor = factor
ScreenScale.Viewport = viewport
ScreenScale.Touch = TOUCH_DEVICE

local function compute(size: Vector2): number
	if size.X <= 0 or size.Y <= 0 then
		return 1
	end
	return math.clamp(math.min(size.X / REFERENCE.X, size.Y / REFERENCE.Y), MIN_FACTOR, MAX_FACTOR)
end

-- 1 on anything at least SMALL_HEIGHT pixels tall, growing to MAX_BOOST below that.
local function computeBoost(size: Vector2): number
	if size.Y <= 0 then
		return 1
	end
	return math.clamp(SMALL_HEIGHT / size.Y, 1, MAX_BOOST)
end

local cameraConnection: RBXScriptConnection? = nil
local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local function update()
		local size = camera.ViewportSize
		local smallScreen = computeBoost(size)
		viewport:set(size)
		base:set(compute(size) * (if TOUCH_DEVICE then smallScreen else 1))
		boost:set(if TOUCH_DEVICE then 1 else smallScreen)
	end
	cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

-- Design pixels -> pixels on the current screen.
function ScreenScale.toPixels(designPixels: number): number
	return designPixels * Fusion.peek(factor)
end

--[[
	A UIScale to put inside a panel that must stay usable on small screens (the spawn
	menu, the menu column): it grows the panel around its AnchorPoint, on top of the
	factor every screen already has.
]]
function ScreenScale.boost(scope: Scope): UIScale
	return scope:New("UIScale")({
		Name = "SmallScreenBoost",
		Scale = boost,
	}) :: any
end

-- Size an element has on the reference screen, given the reference size of its parent.
local function designSize(size: UDim2, constraint: Enum.SizeConstraint, parentSize: Vector2): Vector2
	local basisX, basisY = parentSize.X, parentSize.Y
	if constraint == Enum.SizeConstraint.RelativeXX then
		basisY = parentSize.X
	elseif constraint == Enum.SizeConstraint.RelativeYY then
		basisX = parentSize.Y
	end
	return Vector2.new(size.X.Scale * basisX + size.X.Offset, size.Y.Scale * basisY + size.Y.Offset)
end

local pin: (scope: Scope, object: GuiObject, parentSize: Vector2, depth: number) -> ()

-- Pins the panels inside a full-screen container, including the ones added later.
local function pinChildren(scope: Scope, container: Instance, size: Vector2, depth: number)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			pin(scope, child, size, depth)
		end
	end
	table.insert(
		scope,
		container.ChildAdded:Connect(function(child: Instance)
			if child:IsA("GuiObject") then
				pin(scope, child, size, depth)
			end
		end)
	)
end

-- Position on one axis that keeps the element at the same share of the free space.
local function pinAxis(position: UDim, anchor: number, size: number, parent: number): UDim
	local free = parent - size
	if free < parent * MIN_FREE then
		return position
	end
	local share = (position.Scale * parent + position.Offset - anchor * size) / free
	return UDim.new(share, (anchor - share) * size)
end

function pin(scope: Scope, object: GuiObject, parentSize: Vector2, depth: number)
	if object:GetAttribute(OPT_OUT_ATTRIBUTE) == false or object:GetAttribute(PINNED_ATTRIBUTE) then
		return
	end
	object:SetAttribute(PINNED_ATTRIBUTE, true)

	-- What the screen asked for, in reference-screen terms; the instance holds the pinned form.
	local constraint = object.SizeConstraint
	local rawSize, rawPosition = object.Size, object.Position
	local pinnedSize, pinnedPosition = rawSize, rawPosition
	local walked = false
	local applying = false
	-- Design size of the panel once pinned (nil for a full-screen container), for ScreenFit.
	local fitSize: Vector2? = nil
	local fitScale: UIScale? = nil

	local function refit()
		local size = fitSize
		if not size or size.X <= 0 or size.Y <= 0 then
			return
		end
		local scale = Fusion.peek(factor)
		local screen = Fusion.peek(viewport)
		-- The window is not laid out yet (the first frames report a tiny viewport).
		if screen.Y < MIN_FIT_HEIGHT then
			return
		end
		local availableX = screen.X * FIT_SHARE
		local availableY = (screen.Y - GuiService:GetGuiInset().Y) * FIT_SHARE
		local fit = math.min(1, availableX / (size.X * scale), availableY / (size.Y * scale))
		if fit < 1 and not fitScale then
			-- A panel that scales itself (the small-screen boost) is left alone.
			if object:FindFirstChildWhichIsA("UIScale") then
				return
			end
			local created = Instance.new("UIScale")
			created.Name = FIT_NAME
			created.Parent = object
			fitScale = created
		end
		if fitScale then
			fitScale.Scale = fit
		end
	end

	local function update()
		if applying then
			return
		end
		-- Anything other than what was written here is a new request from the screen.
		if object.Size ~= pinnedSize then
			rawSize = object.Size
		end
		if object.Position ~= pinnedPosition then
			rawPosition = object.Position
		end

		local design = designSize(rawSize, constraint, parentSize)
		local spansX = design.X >= parentSize.X * SPAN
		local spansY = design.Y >= parentSize.Y * SPAN

		pinnedSize, pinnedPosition = rawSize, rawPosition
		if spansX and spansY then
			-- A full-screen container is not a panel: its children are.
			if not walked and depth < MAX_DEPTH then
				walked = true
				pinChildren(scope, object, design, depth + 1)
			end
		else
			-- An axis that spans the screen (bars, curtains) keeps doing so. A panel sized
			-- from a single axis (RelativeXX / RelativeYY) has no such axis: it is pinned whole.
			if constraint ~= Enum.SizeConstraint.RelativeXY then
				spansX, spansY = false, false
			end
			local anchor = object.AnchorPoint
			pinnedSize = UDim2.new(
				if spansX then rawSize.X else UDim.new(0, design.X),
				if spansY then rawSize.Y else UDim.new(0, design.Y)
			)
			pinnedPosition = UDim2.new(
				if spansX then rawPosition.X else pinAxis(rawPosition.X, anchor.X, design.X, parentSize.X),
				if spansY then rawPosition.Y else pinAxis(rawPosition.Y, anchor.Y, design.Y, parentSize.Y)
			)
			fitSize = Vector2.new(if spansX then 0 else design.X, if spansY then 0 else design.Y)
		end

		applying = true
		if pinnedSize ~= rawSize then
			object.SizeConstraint = Enum.SizeConstraint.RelativeXY
		end
		object.Size = pinnedSize
		object.Position = pinnedPosition
		applying = false
		refit()
	end

	-- Screens move, resize and tween their panels in scale: every new value is pinned again.
	table.insert(scope, object:GetPropertyChangedSignal("Size"):Connect(update))
	table.insert(scope, object:GetPropertyChangedSignal("Position"):Connect(update))
	scope:Observer(factor):onChange(refit)
	scope:Observer(viewport):onChange(refit)
	update()
	-- The viewport and the factor do not change in the same step: fit once both have.
	task.defer(refit)
end

--[[
	Makes a ScreenGui follow the screen. Safe to call once per built gui; panels a screen
	adds later are pinned as they appear, and whatever is inside a panel follows it.
]]
function ScreenScale.apply(scope: Scope, gui: ScreenGui, style: UIConfig.Style?)
	if gui:FindFirstChild(SCALER_NAME) or gui:GetAttribute(OPT_OUT_ATTRIBUTE) == false then
		return
	end

	scope:New("UIScale")({
		Name = SCALER_NAME,
		Scale = (style and styleFactors[style]) or factor,
		Parent = gui,
	})

	-- Without IgnoreGuiInset the top bar is taken out of the height the gui gets.
	local reference = if gui.IgnoreGuiInset then REFERENCE else REFERENCE - Vector2.new(0, TOP_BAR)
	pinChildren(scope, gui, reference, 0)
end

return ScreenScale
