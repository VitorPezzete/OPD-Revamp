--!strict
--[[
	The building blocks of the legacy interface.

	The old game's screens were drawn by hand in Studio, every element placed in scale by
	eye, which is why nothing in them lines up and text comes in every size. The legacy
	interface is the same look - parchment panels, plank buttons, the flat blue shop
	buttons, white lettering with a dark outline - rebuilt from these pieces, in code, on
	a pixel grid (design pixels of a 1920x1080 screen; UI.Util.ScreenScale takes them to
	the real one), with layouts doing the aligning.

		local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

		Kit.Screen(scope, { Name = "Storage", DisplayOrder = 10, Children = { ... } })
		Kit.Window(scope, { Title = "Storage", Size = UDim2.fromOffset(900, 600), OnClose = close, Children = { ... } })
		Kit.Panel(scope, { Size = ..., Padding = Kit.Space.M, Children = { ... } })
		Kit.Button(scope, { Text = "Buy", Variant = "Blue", Size = UDim2.fromOffset(180, 44), OnClick = buy })
		Kit.Label(scope, { Text = "Beri: 100", TextSize = Kit.TextSize.Body })
		Kit.Stack(scope, { Direction = "Horizontal", Gap = Kit.Space.S, Children = { a, b } })
		Kit.Scroll(scope, { Size = UDim2.fromScale(1, 1), Gap = 6, Children = rows })
		Kit.Bar(scope, { Value = fraction, Color = Kit.Colors.Charge, Size = UDim2.new(1, 0, 0, 18) })
		Kit.TextInput(scope, { Placeholder = "Enter Code", Text = value, OnChanged = set })
		Kit.Badge(scope, { Text = count })       -- the round red counter
		Kit.Image(scope, { Image = id, Size = ... })

	Every prop that takes a value also takes a Fusion state object. The placement props
	(Name, Position, AnchorPoint, Size, LayoutOrder, Visible, ZIndex) are the same on all
	of them. Sizes are given by the caller; a Label or a Stack without one wraps its
	content.

	Text is Arimo, white, with a black outline at half transparency, at a fixed size from
	Kit.TextSize: sizes agree across a screen because they are chosen, not fitted. Fit =
	true on a Label or a Button lets a text that may be long (a player's name, an item)
	shrink to its box instead of being cut, never growing past its size.

	Elements built here are already in their final style; UI.Legacy.Style is only for the
	generated layouts that are still in use and skips anything marked by this module.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

export type Layout = {
	Name: string?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: Vector2?,
	Size: UsedAs<UDim2>?,
	LayoutOrder: UsedAs<number>?,
	Visible: UsedAs<boolean>?,
	ZIndex: UsedAs<number>?,
}

local ARIMO = "rbxasset://fonts/families/Arimo.json"
-- UI.Legacy.Style leaves an element with this attribute set to false alone.
local STYLE_ATTRIBUTE = "LegacyStyle"

local Kit = {}

Kit.Fonts = table.freeze({
	Bold = Font.new(ARIMO, Enum.FontWeight.Bold),
	Regular = Font.new(ARIMO, Enum.FontWeight.Regular),
})

-- Design pixels.
Kit.TextSize = table.freeze({
	Title = 34,
	Heading = 28,
	Button = 24,
	Body = 22,
	Small = 18,
	Tiny = 15,
})

Kit.Space = table.freeze({ XS = 4, S = 8, M = 12, L = 16, XL = 24 })

Kit.Colors = table.freeze({
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(190, 190, 190),
	TextDark = Color3.fromRGB(35, 30, 25),
	Outline = Color3.fromRGB(0, 0, 0),
	-- The states the old game wrote in colour.
	Selected = Color3.fromRGB(50, 255, 50),
	Good = Color3.fromRGB(50, 255, 50),
	Bad = Color3.fromRGB(255, 80, 80),
	Gold = Color3.fromRGB(255, 226, 57),
	Info = Color3.fromRGB(126, 255, 255),
	-- Flat buttons.
	Blue = Color3.fromRGB(46, 130, 235),
	Green = Color3.fromRGB(60, 170, 70),
	Red = Color3.fromRGB(216, 60, 50),
	Orange = Color3.fromRGB(235, 110, 50),
	Grey = Color3.fromRGB(120, 120, 120),
	-- The tint under a plank and under a sunken area of a parchment.
	Plank = Color3.fromRGB(100, 100, 100),
	Sunken = Color3.fromRGB(0, 0, 0),
	Box = Color3.fromRGB(255, 255, 255),
	Charge = Color3.fromRGB(0, 255, 255),
	BarBack = Color3.fromRGB(0, 0, 0),
	Badge = Color3.fromRGB(216, 26, 26),
})

Kit.OutlineTransparency = 0.5

Kit.Images = table.freeze({
	-- The plain parchment of the menu column and of most panels.
	Parchment = "rbxassetid://1012757720",
	-- The second parchment (talent pages).
	ParchmentAlt = "rbxassetid://1012757434",
	-- The burnt-edged sheet of the big windows (shop, crew, invitations).
	Sheet = "rbxassetid://100570812821023",
	-- The wooden plank laid over a button.
	Plank = "rbxassetid://1012758197",
	-- The rounded bar of gauges.
	Bar = "rbxassetid://4895148919",
})

local function place(props: Layout, into: { [any]: any }): { [any]: any }
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
Kit.place = place

local function padding(scope: Scope, amount: number): Instance
	return scope:New("UIPadding")({
		PaddingTop = UDim.new(0, amount),
		PaddingBottom = UDim.new(0, amount),
		PaddingLeft = UDim.new(0, amount),
		PaddingRight = UDim.new(0, amount),
	})
end

-- A ceiling for a text that shrinks to its box (Fit).
local function fit(scope: Scope, size: number): Instance
	return scope:New("UITextSizeConstraint")({ MinTextSize = 8, MaxTextSize = size })
end

local function marked(instance: Instance): Instance
	instance:SetAttribute(STYLE_ATTRIBUTE, false)
	return instance
end

---------------------------------------------------------------------------------------

export type ScreenProps = {
	Name: string,
	DisplayOrder: number?,
	IgnoreGuiInset: boolean?,
	Children: Fusion.Child?,
}

-- The ScreenGui of a screen. UIController enables, scales and parents it.
function Kit.Screen(scope: Scope, props: ScreenProps): ScreenGui
	return scope:New("ScreenGui")({
		Name = props.Name,
		DisplayOrder = props.DisplayOrder or 0,
		IgnoreGuiInset = props.IgnoreGuiInset or false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		[Children] = props.Children,
	}) :: any
end

---------------------------------------------------------------------------------------

export type LabelProps = Layout & {
	Text: UsedAs<string>?,
	TextSize: number?,
	Color: UsedAs<Color3>?,
	-- false: the regular weight (paragraphs).
	Bold: boolean?,
	TextXAlignment: Enum.TextXAlignment?,
	TextYAlignment: Enum.TextYAlignment?,
	Wrapped: boolean?,
	-- Shrinks to its box when the text is too long for it. Needs a Size.
	Fit: boolean?,
	RichText: boolean?,
	-- false: no outline (text on a light box).
	Outline: boolean?,
	Transparency: UsedAs<number>?,
	Children: Fusion.Child?,
}

function Kit.Label(scope: Scope, props: LabelProps): TextLabel
	local size = props.TextSize or Kit.TextSize.Body
	local outlined = props.Outline ~= false
	return marked(scope:New("TextLabel")(place(props, {
		Name = "Label",
		BackgroundTransparency = 1,
		AutomaticSize = if props.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.XY,
		FontFace = if props.Bold == false then Kit.Fonts.Regular else Kit.Fonts.Bold,
		Text = props.Text or "",
		TextSize = size,
		TextScaled = props.Fit == true,
		TextWrapped = props.Wrapped == true or props.Fit == true,
		RichText = props.RichText == true,
		TextColor3 = props.Color or (if outlined then Kit.Colors.Text else Kit.Colors.TextDark),
		TextTransparency = props.Transparency or 0,
		TextStrokeColor3 = Kit.Colors.Outline,
		TextStrokeTransparency = if not outlined
			then 1
			elseif props.Transparency
				then scope:Computed(function(use): number
					-- The outline fades with the text.
					local faded = use(props.Transparency :: any)
					return Kit.OutlineTransparency + (1 - Kit.OutlineTransparency) * faded
				end)
			else Kit.OutlineTransparency,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		[Children] = {
			if props.Fit then fit(scope, size) else nil,
			props.Children,
		} :: { any },
	}))) :: any
end

---------------------------------------------------------------------------------------

export type Variant = "Plank" | "Blue" | "Green" | "Red" | "Orange" | "Grey" | "Box" | "Ghost"

export type ButtonProps = Layout & {
	Text: UsedAs<string>?,
	-- Plank (default): the wooden button of the menus. Blue / Green / Red / Orange / Grey:
	-- the flat buttons of shops and prompts. Box: a white box with dark text (a key).
	-- Ghost: nothing but its text.
	Variant: UsedAs<Variant>?,
	TextSize: number?,
	TextColor: UsedAs<Color3>?,
	-- The active one of a group: its text turns green, as the old menu did.
	Selected: UsedAs<boolean>?,
	-- Greyed and deaf.
	Disabled: UsedAs<boolean>?,
	-- Shrinks a long text to the button (default true).
	Fit: boolean?,
	Wrapped: boolean?,
	OnClick: (() -> ())?,
	OnHover: ((hovering: boolean) -> ())?,
	Children: Fusion.Child?,
}

local FLAT: { [string]: Color3 } = {
	Blue = Kit.Colors.Blue,
	Green = Kit.Colors.Green,
	Red = Kit.Colors.Red,
	Orange = Kit.Colors.Orange,
	Grey = Kit.Colors.Grey,
	Box = Kit.Colors.Box,
}

function Kit.Button(scope: Scope, props: ButtonProps): TextButton
	local size = props.TextSize or Kit.TextSize.Button
	local hovering = scope:Value(false)
	local pressing = scope:Value(false)

	local function variant(use: Fusion.Use): string
		return (if props.Variant then use(props.Variant) else "Plank") :: string
	end
	local function disabled(use: Fusion.Use): boolean
		return props.Disabled ~= nil and use(props.Disabled) == true
	end

	local button = scope:New("TextButton")(place(props, {
		Name = "Button",
		Size = UDim2.fromOffset(200, 44),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Active = scope:Computed(function(use): boolean
			return not disabled(use)
		end),
		Selectable = scope:Computed(function(use): boolean
			return not disabled(use)
		end),
		BackgroundColor3 = scope:Computed(function(use): Color3
			local kind = variant(use)
			local base = FLAT[kind] or Kit.Colors.Plank
			if disabled(use) then
				return if FLAT[kind] and kind ~= "Box" then Kit.Colors.Grey else base
			end
			if FLAT[kind] then
				if use(pressing) then
					return base:Lerp(Color3.new(0, 0, 0), 0.2)
				elseif use(hovering) then
					return base:Lerp(Color3.new(1, 1, 1), 0.15)
				end
			end
			return base
		end),
		BackgroundTransparency = scope:Computed(function(use): number
			local kind = variant(use)
			if kind == "Ghost" then
				return if use(hovering) and not disabled(use) then 0.85 else 1
			elseif kind == "Plank" then
				return 0.7
			end
			return 0
		end),
		-- The text is a label of its own: a button draws its text under its children,
		-- and the plank is one.
		Text = "",
		[OnEvent("Activated")] = function()
			if props.OnClick then
				props.OnClick()
			end
		end,
		[OnEvent("MouseEnter")] = function()
			hovering:set(true)
			if props.OnHover then
				props.OnHover(true)
			end
		end,
		[OnEvent("MouseLeave")] = function()
			hovering:set(false)
			pressing:set(false)
			if props.OnHover then
				props.OnHover(false)
			end
		end,
		[OnEvent("MouseButton1Down")] = function()
			pressing:set(true)
		end,
		[OnEvent("MouseButton1Up")] = function()
			pressing:set(false)
		end,
		[OnEvent("SelectionGained")] = function()
			if props.OnHover then
				props.OnHover(true)
			end
		end,
		[OnEvent("SelectionLost")] = function()
			if props.OnHover then
				props.OnHover(false)
			end
		end,
		[Children] = {
			scope:New("ImageLabel")({
				Name = "Plank",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
				Image = Kit.Images.Plank,
				Visible = scope:Computed(function(use): boolean
					return variant(use) == "Plank"
				end),
				ImageColor3 = scope:Computed(function(use): Color3
					if disabled(use) then
						return Color3.fromRGB(150, 150, 150)
					elseif use(pressing) then
						return Color3.fromRGB(200, 200, 200)
					elseif use(hovering) then
						return Color3.fromRGB(255, 255, 255)
					end
					return Color3.fromRGB(232, 232, 232)
				end),
			}),
			marked(scope:New("TextLabel")({
				Name = "Text",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				-- Room around the text, so a fitted label never touches the edge.
				Size = UDim2.new(1, -16, 1, -8),
				ZIndex = 2,
				FontFace = Kit.Fonts.Bold,
				Text = props.Text or "",
				TextSize = size,
				TextScaled = props.Fit ~= false,
				TextWrapped = props.Wrapped == true or props.Fit ~= false,
				TextColor3 = scope:Computed(function(use): Color3
					if disabled(use) then
						return Kit.Colors.TextDim
					elseif props.Selected ~= nil and use(props.Selected) then
						return Kit.Colors.Selected
					elseif props.TextColor then
						return use(props.TextColor)
					end
					return if variant(use) == "Box" then Kit.Colors.TextDark else Kit.Colors.Text
				end),
				TextStrokeColor3 = Kit.Colors.Outline,
				TextStrokeTransparency = scope:Computed(function(use): number
					return if variant(use) == "Box" then 1 else Kit.OutlineTransparency
				end),
				[Children] = { if props.Fit ~= false then fit(scope, size) else nil } :: { any },
			})),
			props.Children,
		} :: { any },
	}))
	return marked(button) :: any
end

---------------------------------------------------------------------------------------

export type PanelProps = Layout & {
	-- Kit.Images.Parchment by default; "" for a plain tinted box.
	Image: UsedAs<string>?,
	ImageColor: UsedAs<Color3>?,
	ImageTransparency: UsedAs<number>?,
	-- A tint behind (or instead of) the picture.
	Color: UsedAs<Color3>?,
	Transparency: UsedAs<number>?,
	Padding: number?,
	Clips: boolean?,
	AutomaticSize: Enum.AutomaticSize?,
	Children: Fusion.Child?,
}

-- A parchment (or any picture, or a plain tint) that holds children.
function Kit.Panel(scope: Scope, props: PanelProps): ImageLabel
	return scope:New("ImageLabel")(place(props, {
		Name = "Panel",
		Size = UDim2.fromOffset(400, 300),
		AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.None,
		BackgroundColor3 = props.Color or Kit.Colors.Sunken,
		BackgroundTransparency = props.Transparency or 1,
		BorderSizePixel = 0,
		ClipsDescendants = props.Clips == true,
		Image = props.Image or Kit.Images.Parchment,
		ImageColor3 = props.ImageColor or Color3.new(1, 1, 1),
		ImageTransparency = props.ImageTransparency or 0,
		[Children] = {
			if props.Padding then padding(scope, props.Padding) else nil,
			props.Children,
		} :: { any },
	})) :: any
end

-- A darkened area of a parchment (a list, a slot, a text box's well).
function Kit.Well(scope: Scope, props: PanelProps): ImageLabel
	local merged: any = table.clone(props)
	merged.Image = props.Image or ""
	merged.Color = props.Color or Kit.Colors.Sunken
	merged.Transparency = props.Transparency or 0.75
	merged.Name = props.Name or "Well"
	return Kit.Panel(scope, merged)
end

---------------------------------------------------------------------------------------

export type WindowProps = Layout & {
	Title: UsedAs<string>?,
	-- Kit.Images.Sheet by default (the big windows); Kit.Images.Parchment for the small ones.
	Image: UsedAs<string>?,
	-- Draws a red X at the top right and lets the gamepad's B close the window.
	OnClose: (() -> ())?,
	Padding: number?,
	TitleSize: number?,
	-- Extra content at the right of the title, before the X.
	HeaderChildren: Fusion.Child?,
	Children: Fusion.Child?,
}

local HEADER_HEIGHT = 48
local CLOSE_SIZE = 36

--[[
	A sheet with its title across the top and a body (the frame named "Body": the window
	minus the header and the padding, so children can use scale sizes against it).
	Centred by default. NavigationController gives a screen holding a "Window" the
	gamepad selection when it opens.
]]
function Kit.Window(scope: Scope, props: WindowProps): ImageLabel
	local pad = props.Padding or Kit.Space.XL
	local hasHeader = props.Title ~= nil or props.OnClose ~= nil or props.HeaderChildren ~= nil
	local header = if hasHeader then HEADER_HEIGHT else 0

	local window = scope:New("ImageLabel")(place(props, {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(800, 500),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = props.Image or Kit.Images.Sheet,
		[Children] = {
			padding(scope, pad),
			if hasHeader
				then scope:New("Frame")({
					Name = "Header",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, header),
					[Children] = {
						if props.Title
							then Kit.Label(scope, {
								Name = "Title",
								Text = props.Title,
								TextSize = props.TitleSize or Kit.TextSize.Title,
								Fit = true,
								Size = UDim2.new(1, -2 * (CLOSE_SIZE + Kit.Space.S), 1, 0),
								AnchorPoint = Vector2.new(0.5, 0),
								Position = UDim2.fromScale(0.5, 0),
							})
							else nil,
						scope:New("Frame")({
							Name = "Actions",
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.fromScale(1, 0.5),
							Size = UDim2.fromOffset(0, CLOSE_SIZE),
							AutomaticSize = Enum.AutomaticSize.X,
							[Children] = {
								scope:New("UIListLayout")({
									FillDirection = Enum.FillDirection.Horizontal,
									HorizontalAlignment = Enum.HorizontalAlignment.Right,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									SortOrder = Enum.SortOrder.LayoutOrder,
									Padding = UDim.new(0, Kit.Space.S),
								}),
								props.HeaderChildren,
								if props.OnClose
									then Kit.Button(scope, {
										Name = "Close",
										Text = "X",
										Variant = "Red",
										Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
										LayoutOrder = 100,
										OnClick = props.OnClose,
									})
									else nil,
							} :: { any },
						}),
					} :: { any },
				})
				else nil,
			scope:New("Frame")({
				Name = "Body",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, if hasHeader then header + Kit.Space.S else 0),
				Size = UDim2.new(1, 0, 1, if hasHeader then -(header + Kit.Space.S) else 0),
				[Children] = props.Children,
			}),
		} :: { any },
	}))

	if props.OnClose then
		Closers.register(scope, window, props.OnClose)
	end
	return window :: any
end

---------------------------------------------------------------------------------------

export type StackProps = Layout & {
	Direction: ("Vertical" | "Horizontal")?,
	Gap: number?,
	Padding: number?,
	HorizontalAlignment: Enum.HorizontalAlignment?,
	VerticalAlignment: Enum.VerticalAlignment?,
	AutomaticSize: Enum.AutomaticSize?,
	-- A flowing grid of items instead of one line.
	Wraps: boolean?,
	Children: Fusion.Child?,
}

-- An invisible frame that lays its children out in a row or a column, by LayoutOrder.
function Kit.Stack(scope: Scope, props: StackProps): Frame
	local horizontal = props.Direction == "Horizontal"
	return scope:New("Frame")(place(props, {
		Name = "Stack",
		BackgroundTransparency = 1,
		AutomaticSize = props.AutomaticSize or (if props.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.XY),
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
				HorizontalAlignment = props.HorizontalAlignment or Enum.HorizontalAlignment.Left,
				VerticalAlignment = props.VerticalAlignment or Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, props.Gap or 0),
				Wraps = props.Wraps == true,
			}),
			if props.Padding then padding(scope, props.Padding) else nil,
			props.Children,
		} :: { any },
	})) :: any
end

export type ScrollProps = Layout & {
	Direction: ("Vertical" | "Horizontal")?,
	Gap: number?,
	Padding: number?,
	-- Giving a cell size makes it a grid.
	CellSize: Vector2?,
	HorizontalAlignment: Enum.HorizontalAlignment?,
	-- false: no darkened background, only the scrolling.
	Background: boolean?,
	Children: Fusion.Child?,
}

-- A scrolling list or grid; the canvas follows the content.
function Kit.Scroll(scope: Scope, props: ScrollProps): ScrollingFrame
	local horizontal = props.Direction == "Horizontal"
	local gap = props.Gap or Kit.Space.S
	local cell = props.CellSize
	return scope:New("ScrollingFrame")(place(props, {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.Colors.Sunken,
		BackgroundTransparency = if props.Background == false then 1 else 0.8,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(60, 40, 20),
		[Children] = {
			if cell
				then scope:New("UIGridLayout")({
					CellSize = UDim2.fromOffset(cell.X, cell.Y),
					CellPadding = UDim2.fromOffset(gap, gap),
					HorizontalAlignment = props.HorizontalAlignment or Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
				})
				else scope:New("UIListLayout")({
					FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
					HorizontalAlignment = props.HorizontalAlignment or Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, gap),
				}),
			padding(scope, props.Padding or Kit.Space.S),
			props.Children,
		} :: { any },
	})) :: any
end

---------------------------------------------------------------------------------------

export type BarProps = Layout & {
	-- 0 to 1.
	Value: UsedAs<number>,
	Color: UsedAs<Color3>?,
	BackColor: UsedAs<Color3>?,
	-- Text drawn over the bar (a level, "120 / 500").
	Text: UsedAs<string>?,
	TextSize: number?,
	-- The fill grows upwards instead of to the right.
	Vertical: boolean?,
	Children: Fusion.Child?,
}

-- A gauge: a dark track with a coloured fill (health-like bars, experience, charges).
function Kit.Bar(scope: Scope, props: BarProps): Frame
	local function share(use: Fusion.Use): number
		local value = use(props.Value)
		return if type(value) == "number" and value == value then math.clamp(value, 0, 1) else 0
	end
	return scope:New("Frame")(place(props, {
		Name = "Bar",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = props.BackColor or Kit.Colors.BarBack,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			scope:New("Frame")({
				Name = "Fill",
				AnchorPoint = if props.Vertical then Vector2.new(0, 1) else Vector2.new(0, 0),
				Position = if props.Vertical then UDim2.new(0, 2, 1, -2) else UDim2.fromOffset(2, 2),
				BackgroundColor3 = props.Color or Kit.Colors.Charge,
				BorderSizePixel = 0,
				Size = scope:Computed(function(use): UDim2
					local value = share(use)
					return if props.Vertical
						then UDim2.new(1, -4, value, if value > 0 then -4 else 0)
						else UDim2.new(value, if value > 0 then -4 else 0, 1, -4)
				end),
				[Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }) },
			}),
			if props.Text
				then Kit.Label(scope, {
					Name = "Text",
					Text = props.Text,
					TextSize = props.TextSize or Kit.TextSize.Small,
					Fit = true,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 2,
				})
				else nil,
			props.Children,
		} :: { any },
	})) :: any
end

---------------------------------------------------------------------------------------

export type TextInputProps = Layout & {
	-- The text in the box; the box follows it and OnChanged reports what the player types.
	Text: UsedAs<string>?,
	Placeholder: string?,
	MaxLength: number?,
	TextSize: number?,
	OnChanged: ((text: string) -> ())?,
	-- Enter pressed (or the box left with enter on a phone).
	OnSubmit: ((text: string) -> ())?,
}

-- A white box to type in, with dark text (the old game's text boxes).
function Kit.TextInput(scope: Scope, props: TextInputProps): TextBox
	local limit = props.MaxLength
	local box: TextBox
	box = marked(scope:New("TextBox")(place(props, {
		Name = "TextInput",
		Size = UDim2.fromOffset(260, 40),
		BackgroundColor3 = Kit.Colors.Box,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		FontFace = Kit.Fonts.Bold,
		PlaceholderText = props.Placeholder or "",
		PlaceholderColor3 = Color3.fromRGB(140, 130, 120),
		Text = props.Text or "",
		TextColor3 = Kit.Colors.TextDark,
		TextSize = props.TextSize or Kit.TextSize.Body,
		TextTruncate = Enum.TextTruncate.AtEnd,
		[Fusion.OnChange("Text")] = function(text: string)
			if limit and #text > limit then
				box.Text = string.sub(text, 1, limit)
				return
			end
			if props.OnChanged then
				props.OnChanged(text)
			end
		end,
		[OnEvent("FocusLost")] = function(enterPressed: boolean)
			if enterPressed and props.OnSubmit then
				props.OnSubmit(box.Text)
			end
		end,
		[Children] = {
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		},
	}))) :: any
	return box
end

---------------------------------------------------------------------------------------

export type BadgeProps = Layout & {
	Text: UsedAs<string>,
	Color: UsedAs<Color3>?,
	TextSize: number?,
}

-- The round red counter hung on a button (rewards waiting, challenges to claim).
function Kit.Badge(scope: Scope, props: BadgeProps): TextLabel
	local height = (props.TextSize or Kit.TextSize.Tiny) + 8
	return marked(scope:New("TextLabel")(place(props, {
		Name = "Badge",
		Size = UDim2.fromOffset(height, height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = props.Color or Kit.Colors.Badge,
		BorderSizePixel = 0,
		FontFace = Kit.Fonts.Bold,
		Text = props.Text,
		TextColor3 = Kit.Colors.Text,
		TextSize = props.TextSize or Kit.TextSize.Tiny,
		ZIndex = 5,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
		},
	}))) :: any
end

export type ImageProps = Layout & {
	Image: UsedAs<string>,
	Color: UsedAs<Color3>?,
	Transparency: UsedAs<number>?,
	ScaleType: Enum.ScaleType?,
	Children: Fusion.Child?,
}

-- A picture with nothing behind it (an icon, a portrait). Fit keeps its proportions.
function Kit.Image(scope: Scope, props: ImageProps): ImageLabel
	return scope:New("ImageLabel")(place(props, {
		Name = "Image",
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		Image = props.Image,
		ImageColor3 = props.Color or Color3.new(1, 1, 1),
		ImageTransparency = props.Transparency or 0,
		ScaleType = props.ScaleType or Enum.ScaleType.Fit,
		[Children] = props.Children,
	})) :: any
end

-- A thin dark line across a parchment.
function Kit.Divider(scope: Scope, props: Layout): Frame
	return scope:New("Frame")(place(props, {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Color3.fromRGB(60, 40, 20),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
	})) :: any
end

return Kit
