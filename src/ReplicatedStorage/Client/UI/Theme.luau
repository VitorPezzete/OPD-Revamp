--!strict
--[[
	The look of the interface: ship's timber. Brown surfaces, a darker brown for lines
	and for what can be pressed, cream text.

	Rules the components follow, so that the screens do not have to:
	- square corners, one-pixel lines;
	- backgrounds are solid, but few: a piece that reads well on its own (the spawn
	  buttons, the player list) has no box behind it at all;
	- warm, never harsh: cream on brown, never white on black, and colour only where it means
	  something (health, money, danger).

	Every component reads its colours, fonts, sizes and radii here, so a screen never
	writes a Color3 or a font of its own. All sizes are design pixels on a 1920x1080
	screen; ScreenScale turns them into real pixels.

		Theme.Colors.Primary        Theme.Fonts.Heading        Theme.TextSize.Body
		Theme.Radius.Medium         Theme.Space.M              Theme.Motion.Speed
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

export type Scope = Fusion.Scope<typeof(Fusion)>
export type UsedAs<T> = Fusion.UsedAs<T>

-- Placement fields every component accepts and forwards to its root instance.
export type Layout = {
	Name: string?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: Vector2?,
	Size: UsedAs<UDim2>?,
	LayoutOrder: UsedAs<number>?,
	Visible: UsedAs<boolean>?,
	ZIndex: UsedAs<number>?,
}

local function family(font: Enum.Font, weight: Enum.FontWeight?): Font
	return Font.new(Font.fromEnum(font).Family, weight or Enum.FontWeight.Regular)
end

local Theme = {}

Theme.Colors = {
	-- Surfaces: brown. Sunken is the darkest (wells), Hover the lightest.
	Sunken = Color3.fromRGB(70, 48, 31),
	Background = Color3.fromRGB(102, 72, 47),
	Surface = Color3.fromRGB(114, 82, 54),
	Raised = Color3.fromRGB(128, 93, 62),
	Hover = Color3.fromRGB(146, 108, 74),

	-- Lines: a darker brown, like the grain of the same wood.
	Border = Color3.fromRGB(50, 33, 20),
	BorderStrong = Color3.fromRGB(30, 19, 11),

	-- What can be pressed: the dark brown, with cream text on it.
	Primary = Color3.fromRGB(54, 36, 22),
	PrimaryHover = Color3.fromRGB(72, 49, 31),
	PrimaryPressed = Color3.fromRGB(38, 25, 15),
	-- The selected / highlighted thing.
	PrimaryDark = Color3.fromRGB(60, 40, 25),
	-- Titles and highlights: the lightest cream.
	Accent = Color3.fromRGB(250, 236, 200),

	-- Text: cream, on the brown and on the dark brown alike.
	Text = Color3.fromRGB(244, 230, 194),
	TextMuted = Color3.fromRGB(224, 206, 166),
	TextDim = Color3.fromRGB(192, 172, 134),
	TextOnPrimary = Color3.fromRGB(244, 230, 194),

	Success = Color3.fromRGB(164, 204, 106),
	Danger = Color3.fromRGB(240, 116, 92),
	Warning = Color3.fromRGB(244, 196, 84),

	-- Game meanings.
	Beri = Color3.fromRGB(246, 208, 98),
	Gems = Color3.fromRGB(132, 218, 228),
	Health = Color3.fromRGB(44, 196, 62),
	-- The trough of a health bar: what is missing shows red.
	HealthLost = Color3.fromRGB(216, 26, 26),
	Shield = Color3.fromRGB(112, 160, 192),
	Haki = Color3.fromRGB(146, 64, 214),
	Stamina = Color3.fromRGB(226, 172, 60),

	-- Behind dialogs, and the halo of text drawn over the world.
	Backdrop = Color3.fromRGB(16, 10, 6),
	Halo = Color3.fromRGB(26, 16, 9),
	-- Curtains that hide the world altogether (spawn transition, meditation), and the
	-- see-through sheet of the player list.
	Black = Color3.fromRGB(0, 0, 0),
	-- Text that sits on a coloured bar or on the black strips of the player list.
	White = Color3.fromRGB(255, 255, 255),
	-- The tiles of the status effects under the health bar.
	Grey = Color3.fromRGB(96, 96, 96),
}

Theme.Fonts = {
	-- Hand-lettered: screen titles, big numbers.
	Display = family(Enum.Font.Fondamento),
	-- Everything else is one old serif, set heavy enough to read at a glance.
	Heading = family(Enum.Font.Garamond, Enum.FontWeight.Bold),
	BodyBold = family(Enum.Font.Garamond, Enum.FontWeight.Bold),
	Body = family(Enum.Font.Garamond, Enum.FontWeight.SemiBold),
	Mono = family(Enum.Font.SpecialElite),
}

-- The serif faces draw smaller than a grotesque at the same size.
Theme.TextSize = {
	Display = 50,
	Title = 34,
	Heading = 28,
	Body = 24,
	Small = 21,
	Tiny = 18,
}

-- Square corners everywhere. The names stay so that a component still says which kind
-- of corner it means.
Theme.Radius = {
	Small = 0,
	Medium = 0,
	Large = 0,
	Pill = 0,
}

Theme.Stroke = {
	Thin = 1,
	-- Lines are drawn faint; the strong one is for the selected / focused thing.
	Transparency = 0.35,
	StrongTransparency = 0,
}

Theme.Space = {
	XS = 4,
	S = 8,
	M = 12,
	L = 16,
	XL = 24,
}

-- Springs used for hover, press and progress animations.
Theme.Motion = {
	Speed = 32,
	Damping = 1,
	SlowSpeed = 14,
}

Theme.Transparency = {
	Backdrop = 0.55,
	Window = 0,
	Panel = 0,
	-- HUD pieces sit straight over the world.
	Hud = 0,
	-- Buttons and inputs at rest.
	Control = 0,
	-- Wells: scrolling areas, bar troughs, text boxes.
	Sunken = 0,
}

-- Copies the placement fields of `props` into the property table of a root instance.
function Theme.place(props: Layout, into: { [any]: any }): { [any]: any }
	into.Name = props.Name or into.Name
	into.Position = props.Position or into.Position
	into.AnchorPoint = props.AnchorPoint or into.AnchorPoint
	into.Size = props.Size or into.Size
	into.LayoutOrder = props.LayoutOrder or into.LayoutOrder
	into.ZIndex = props.ZIndex or into.ZIndex
	if props.Visible ~= nil then
		into.Visible = props.Visible
	end
	return into
end

return Theme
