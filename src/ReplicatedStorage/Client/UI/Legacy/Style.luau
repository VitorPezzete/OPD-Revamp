--!strict
--[[
	The look of the legacy interface's text, applied to every generated layout as it is
	built (UIController:BuildLayout) and to whatever a screen adds to it later.

	The layouts are the old game's own: same panels, same places, same textures. What the
	old game did badly was its text, and that is what changes here, in one place:

	- One typeface, Arimo, in the weight the label already had.
	- White with a black outline at half transparency. A text that carries a meaning in its
	  colour (green for owned, red for a warning, yellow for a price) keeps that colour;
	  only the neutral ones (white, greys, black) become white. A label sitting on a light,
	  opaque box (the key of a keybind) is written dark with no outline instead: white on
	  white could not be read.
	- Sizes that agree. Every legacy label is TextScaled with nothing holding it back, so a
	  short word filled its box and its longer neighbour came out a third smaller ("Crews"
	  over "Challenges"). Each label now has a ceiling taken from the height of its own box
	  (and an absolute one), so labels in boxes of the same height read at the same size
	  and a long one still shrinks to fit. The ceiling follows the box when the screen or
	  the player's UI Scale resizes it. The few single-line labels the old game left at a
	  fixed size are scaled the same way, so they fit their box on every screen.

	A label opts out with the attribute LegacyStyle = false. A UITextSizeConstraint the
	layout already carries is left as it is.

		Style.apply(root)   -- root and its descendants, now and as they are added
]]
local ARIMO = "rbxasset://fonts/families/Arimo.json"
local TEXT_COLOR = Color3.new(1, 1, 1)
local STROKE_COLOR = Color3.new(0, 0, 0)
local STROKE_TRANSPARENCY = 0.5
-- Text on a light box.
local DARK_TEXT_COLOR = Color3.fromRGB(35, 30, 25)

-- A colour below this saturation says nothing: it becomes white.
local NEUTRAL_SATURATION = 0.2
-- ... and so does one darker than this, whatever its hue.
local DARK_VALUE = 0.35
-- A background at least this bright and this opaque is a light box.
local LIGHT_VALUE = 0.75
local LIGHT_SATURATION = 0.25
local SOLID_TRANSPARENCY = 0.5
-- How far up a label looks for the box it sits on.
local BOX_DEPTH = 2

-- Share of its box's height a label's text may take, and the size no label goes over
-- (design pixels; the ScreenGui's UIScale takes them to the screen).
local HEIGHT_SHARE = 0.72
local MAX_TEXT_SIZE = 32
local MIN_TEXT_SIZE = 8

local OPT_OUT_ATTRIBUTE = "LegacyStyle"
local CEILING_NAME = "LegacyTextCeiling"

type TextObject = TextLabel | TextButton | TextBox

local Style = {}

-- White, a grey, black, or a colour too dark to read as one (the engine's default text
-- colour is a very dark blue).
local function isNeutral(color: Color3): boolean
	local _, saturation, value = color:ToHSV()
	return saturation < NEUTRAL_SATURATION or value < DARK_VALUE
end

local function isLight(object: GuiObject): boolean
	local _, saturation, value = object.BackgroundColor3:ToHSV()
	return value >= LIGHT_VALUE and saturation <= LIGHT_SATURATION
end

-- Whether the label is drawn on a light, opaque box (its own background or one just above).
local function onLightBox(object: GuiObject): boolean
	local current: Instance? = object
	for _ = 0, BOX_DEPTH do
		if not current or not current:IsA("GuiObject") then
			return false
		end
		-- A picture hides its background colour: a textured panel is not a "light box".
		local textured = (current:IsA("ImageLabel") or current:IsA("ImageButton")) and current.Image ~= ""
		-- One of the engine's own button skins (the blue buttons of the spawn screen) or
		-- frame skins is drawn instead of the background colour.
		if current:IsA("TextButton") and current.Style ~= Enum.ButtonStyle.Custom then
			return false
		elseif current:IsA("Frame") and current.Style ~= Enum.FrameStyle.Custom then
			return false
		end
		if not textured and current.BackgroundTransparency <= SOLID_TRANSPARENCY then
			return isLight(current)
		end
		current = current.Parent
	end
	return false
end

-- Every UIScale above the object, multiplied: screen pixels per design pixel there.
local function scaleAbove(object: Instance): number
	local scale = 1
	local current: Instance? = object
	while current and not current:IsA("LayerCollector") do
		local own = current:FindFirstChildWhichIsA("UIScale")
		if own then
			scale *= own.Scale
		end
		current = current.Parent
	end
	if current then
		local own = current:FindFirstChildWhichIsA("UIScale")
		if own then
			scale *= own.Scale
		end
	end
	return math.max(scale, 0.01)
end

local function addCeiling(object: TextObject)
	if object:FindFirstChildWhichIsA("UITextSizeConstraint") then
		return
	end
	if not object.TextScaled then
		-- A paragraph at a fixed size stays one: scaled, it would grow to fill its box.
		if object.TextWrapped then
			return
		end
		object.TextScaled = true
	end
	local ceiling = Instance.new("UITextSizeConstraint")
	ceiling.Name = CEILING_NAME
	ceiling.MinTextSize = MIN_TEXT_SIZE
	ceiling.MaxTextSize = MAX_TEXT_SIZE
	ceiling.Parent = object

	local function update()
		local height = object.AbsoluteSize.Y
		-- Not laid out yet (no parent, or a parent of no size).
		if height <= 0 then
			return
		end
		local design = height / scaleAbove(object)
		ceiling.MaxTextSize = math.clamp(math.floor(design * HEIGHT_SHARE + 0.5), MIN_TEXT_SIZE, MAX_TEXT_SIZE)
	end
	-- Dies with the label; nothing to keep.
	object:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
end

local function styleText(object: TextObject)
	if object:GetAttribute(OPT_OUT_ATTRIBUTE) == false then
		return
	end
	local face = object.FontFace
	local weight = if face.Weight.Value >= Enum.FontWeight.SemiBold.Value
		then Enum.FontWeight.Bold
		else Enum.FontWeight.Regular
	object.FontFace = Font.new(ARIMO, weight, face.Style)

	if onLightBox(object) then
		if isNeutral(object.TextColor3) then
			object.TextColor3 = DARK_TEXT_COLOR
		end
		object.TextStrokeTransparency = 1
	else
		if isNeutral(object.TextColor3) then
			object.TextColor3 = TEXT_COLOR
		end
		-- An outline the layout drew as a UIStroke stays the one outline.
		local stroke = object:FindFirstChildWhichIsA("UIStroke")
		if stroke and stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			stroke.Color = STROKE_COLOR
			stroke.Transparency = STROKE_TRANSPARENCY
			object.TextStrokeTransparency = 1
		else
			object.TextStrokeColor3 = STROKE_COLOR
			object.TextStrokeTransparency = STROKE_TRANSPARENCY
		end
	end

	addCeiling(object)
end

local function visit(object: Instance)
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		styleText(object)
	end
end

function Style.apply(root: Instance)
	visit(root)
	for _, descendant in root:GetDescendants() do
		visit(descendant)
	end
	-- Rows a screen clones and elements it builds in code. Deferred: a clone arrives with
	-- its properties still being written by the screen.
	root.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			task.defer(function()
				if not descendant.Parent then
					return
				end
				local copied = descendant:FindFirstChild(CEILING_NAME)
				if copied then
					-- A clone of a styled label: only its ceiling is stale (it followed
					-- the box of the original). Its colours are the screen's business.
					copied:Destroy()
					addCeiling(descendant :: any)
				else
					styleText(descendant :: any)
				end
			end)
		end
	end)
end

return Style
