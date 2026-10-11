--!strict
--[[
	Aura customization: pick the two effect colours of an eaten fruit and buy them.

	Opened with { Slot = 1 | 2 } by the "customize aura" buttons of the menu's stats tab
	(Screens/MenuNew/Stats).

	The old window, centred on its plank: the rainbow "Customize Aura" across the top with
	the close button, an editor at each side (primary on the left, secondary on the
	right) and, between them, the fruit's name, the saved pair, the rainbow arrow and the
	pair being edited, then the price button and the gems. An editor is a preview disc,
	one line per channel (<< < the track > >>, the track being a slider that follows the
	mouse or a finger) and nine preset discs. Buying asks for confirmation in place.

	Buying sends the slot and the two colours to AuraService; the price is charged (or
	refused) by the server. The gem counter only turns red as a hint that it will refuse.

	The old editors stored their state in the ImageColor3 of a label and re-read it as
	floats (a channel could drift by one after a few clicks); here each colour is a
	Fusion value holding whole 0-255 channels.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local AppearanceConfig = require(ReplicatedStorage.Shared.Configs.AppearanceConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local peek = Fusion.peek

local WHITE = Color3.new(1, 1, 1)

type Channel = { Key: string, Color: Color3 }
local CHANNELS: { Channel } = {
	{ Key = "R", Color = Color3.fromRGB(255, 0, 0) },
	{ Key = "G", Color = Color3.fromRGB(0, 255, 0) },
	{ Key = "B", Color = Color3.fromRGB(0, 0, 255) },
}
-- The step buttons of a channel, left to right; the track stands between the two pairs.
local LOWER = { { Text = "<<", Delta = -10 }, { Text = "<", Delta = -1 } }
local RAISE = { { Text = ">", Delta = 1 }, { Text = ">>", Delta = 10 } }

-- The nine presets under an editor.
local PALLET = {
	Color3.fromRGB(255, 0, 0),
	Color3.fromRGB(255, 127, 0),
	Color3.fromRGB(255, 255, 0),
	Color3.fromRGB(0, 255, 0),
	Color3.fromRGB(0, 0, 255),
	Color3.fromRGB(127, 0, 255),
	Color3.fromRGB(255, 0, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(0, 0, 0),
}

local BACKGROUND = "rbxassetid://1012758197"
local DISC = "rbxassetid://607507441"
local ARROW = "rbxassetid://2299722691"
local GEM_ICON = "rbxassetid://1954296071"

local FRUIT_COLOR = Color3.fromRGB(109, 26, 211)
local GEMS_COLOR = Color3.fromRGB(126, 255, 255)
local PRICE_COLOR = Color3.fromRGB(0, 255, 255)
local REFUSED_COLOR = Color3.fromRGB(255, 0, 0)
local BUYING_TEXT = "Buying..."

local RAINBOW = {
	Color3.new(1, 0, 0),
	Color3.new(1, 1, 0),
	Color3.new(0, 1, 0),
	Color3.new(0, 1, 1),
	Color3.new(0, 0, 1),
	Color3.new(1, 0, 1),
}
local RAINBOW_INFO = TweenInfo.new(1, Enum.EasingStyle.Linear)
-- The title, one letter per colour of the rainbow, as the old header spelt it.
local TITLE_COLORS = {
	C = "255,0,0",
	u = "255,127,0",
	s = "255,255,0",
	t = "127,255,0",
	o = "0,255,0",
	m = "0,255,127",
	i = "0,255,255",
	z = "0,127,255",
	e = "0,0,255",
}
local TITLE = (string.gsub("Customize", ".", function(letter: string): string
	return `<font color="rgb({TITLE_COLORS[letter]})">{letter}</font>`
end)) .. ' <font color="rgb(127,0,255)">A</font><font color="rgb(255,0,255)">u</font>' .. '<font color="rgb(255,0,127)">r</font><font color="rgb(255,127,127)">a</font>'

local WINDOW_SIZE = Vector2.new(1100, 600)
-- What Kit.Window puts above its body: the header and the gap under it.
local HEADER_HEIGHT = 48 + Kit.Space.S
local EDITOR_WIDTH = 330
local PREVIEW_SIZE = 120
local VALUE_HEIGHT = 20
local STEP_HEIGHT = 32
local STEP_WIDTH = 34
local WIDE_STEP_WIDTH = 42
local TRACK_HEIGHT = 20
local HANDLE_WIDTH = 8
local PALLET_SIZE = 30
local CAPTION_HEIGHT = 28
-- The saved and the edited pair: the first colour's disc on the second colour's.
local OUTER_DISC = 124
local INNER_DISC = 104
local ARROW_SIZE = 64
local CENTER_WIDTH = 360
local FRUIT_HEIGHT = 40
local BUY_HEIGHT = 64
local GEMS_HEIGHT = 40
local CONFIRM_HEIGHT = 56

local function toChannels(color: Color3): { [string]: number }
	return {
		R = math.round(color.R * 255),
		G = math.round(color.G * 255),
		B = math.round(color.B * 255),
	}
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function disc(scope: Scope, color: Fusion.UsedAs<Color3>, size: number, zIndex: number?): ImageLabel
	return Kit.Image(scope, {
		Image = DISC,
		Color = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = zIndex,
	})
end

-- One channel of a colour: its figure over "<< <  track  > >>".
local function channelRow(scope: Scope, channel: Channel, picked: Fusion.Value<Color3>, order: number): Instance
	local key = channel.Key
	local amount = scope:Computed(function(use): number
		return toChannels(use(picked))[key]
	end)

	local function setChannel(value: number)
		local channels = toChannels(peek(picked))
		channels[key] = math.clamp(math.round(value), 0, 255)
		picked:set(Color3.fromRGB(channels.R, channels.G, channels.B))
	end

	local function stepButton(step: { Text: string, Delta: number }, stepOrder: number): Instance
		return Kit.Button(scope, {
			Name = step.Text,
			Text = step.Text,
			Variant = "Box",
			TextSize = Kit.TextSize.Small,
			LayoutOrder = stepOrder,
			Size = UDim2.fromOffset(if math.abs(step.Delta) > 1 then WIDE_STEP_WIDTH else STEP_WIDTH, STEP_HEIGHT),
			OnClick = function()
				setChannel(peek(amount) + step.Delta)
			end,
		})
	end

	local stepsWidth = 2 * (STEP_WIDTH + WIDE_STEP_WIDTH) + 4 * Kit.Space.XS
	local track: Frame

	-- The track is a slider: a press on it, held and moved, sets the channel from where
	-- the pointer is.
	local dragging: InputObject? = nil
	local function follow(input: InputObject)
		local width = track.AbsoluteSize.X
		if width > 0 then
			setChannel((input.Position.X - track.AbsolutePosition.X) / width * 255)
		end
	end
	Bind.connect(scope, UserInputService.InputChanged, function(input: InputObject)
		local held = dragging
		if not held then
			return
		end
		-- A finger moves as the input that began; a mouse as a separate movement input.
		if
			input == held
			or (held.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
		then
			follow(input)
		end
	end)
	Bind.connect(scope, UserInputService.InputEnded, function(input: InputObject)
		local held = dragging
		if held and (input == held or input.UserInputType == held.UserInputType) then
			dragging = nil
		end
	end)

	track = scope:New("Frame")({
		Name = "Track",
		BackgroundColor3 = channel.Color,
		BorderSizePixel = 0,
		Active = true,
		Size = UDim2.new(1, 0, 0, TRACK_HEIGHT),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		[OnEvent("InputBegan")] = function(input: InputObject)
			if isPress(input) then
				dragging = input
				follow(input)
			end
		end,
		[Children] = {
			scope:New("Frame")({
				Name = "Bar",
				BackgroundColor3 = WHITE,
				BorderColor3 = Kit.Colors.Outline,
				BorderSizePixel = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(HANDLE_WIDTH, TRACK_HEIGHT + 6),
				Position = scope:Computed(function(use): UDim2
					return UDim2.fromScale(use(amount) / 255, 0.5)
				end),
			}),
		},
	}) :: any

	return Kit.Stack(scope, {
		Name = "Frame" .. key,
		LayoutOrder = order,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Size = UDim2.fromOffset(EDITOR_WIDTH, VALUE_HEIGHT + STEP_HEIGHT),
		Children = {
			Kit.Label(scope, {
				TextSize = Kit.TextSize.Small,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, VALUE_HEIGHT),
				Text = scope:Computed(function(use): string
					return tostring(use(amount))
				end),
			}),
			Kit.Stack(scope, {
				Direction = "Horizontal",
				Gap = Kit.Space.XS,
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, STEP_HEIGHT),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Children = {
					stepButton(LOWER[1], 1),
					stepButton(LOWER[2], 2),
					scope:New("Frame")({
						Name = "Slider",
						BackgroundTransparency = 1,
						LayoutOrder = 3,
						Size = UDim2.fromOffset(EDITOR_WIDTH - stepsWidth - HANDLE_WIDTH, STEP_HEIGHT),
						[Children] = track,
					}),
					stepButton(RAISE[1], 4),
					stepButton(RAISE[2], 5),
				},
			}),
		},
	})
end

-- One editor: the colour being picked, its three channels, the presets and its name.
local function editor(scope: Scope, name: string, caption: string, picked: Fusion.Value<Color3>, anchor: number): Instance
	local rows: { any } = {
		scope:New("Frame")({
			Name = "Preview",
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(PREVIEW_SIZE, PREVIEW_SIZE),
			[Children] = disc(scope, picked, PREVIEW_SIZE),
		}),
	}
	for order, channel in CHANNELS do
		table.insert(rows, channelRow(scope, channel, picked, 1 + order))
	end

	local presets: { Instance } = {}
	for order, color in PALLET do
		table.insert(
			presets,
			scope:New("Frame")({
				Name = `Pallet{order}`,
				BackgroundTransparency = 1,
				LayoutOrder = order,
				Size = UDim2.fromOffset(PALLET_SIZE, PALLET_SIZE),
				[Children] = {
					disc(scope, color, PALLET_SIZE, 1),
					Kit.Button(scope, {
						Variant = "Ghost",
						Text = "",
						Size = UDim2.fromScale(1, 1),
						ZIndex = 2,
						OnClick = function()
							picked:set(color)
						end,
					}),
				},
			})
		)
	end
	table.insert(
		rows,
		Kit.Stack(scope, {
			Name = "Pallet",
			Direction = "Horizontal",
			Gap = Kit.Space.XS,
			LayoutOrder = 10,
			Children = presets,
		})
	)
	table.insert(
		rows,
		Kit.Label(scope, {
			Name = "Label",
			Text = caption,
			LayoutOrder = 11,
			Size = UDim2.fromOffset(EDITOR_WIDTH, CAPTION_HEIGHT),
		})
	)

	return Kit.Stack(scope, {
		Name = name,
		Gap = Kit.Space.S,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		AnchorPoint = Vector2.new(anchor, 0),
		Position = UDim2.fromScale(anchor, 0),
		Size = UDim2.new(0, EDITOR_WIDTH, 1, 0),
		Children = rows,
	})
end

-- A pair of colours: the disc of the first on the larger disc of the second.
local function pair(scope: Scope, name: string, first: Fusion.UsedAs<Color3>, second: Fusion.UsedAs<Color3>, order: number): Instance
	return scope:New("Frame")({
		Name = name,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromOffset(OUTER_DISC, OUTER_DISC),
		[Children] = {
			disc(scope, second, OUTER_DISC, 1),
			disc(scope, first, INNER_DISC, 2),
		},
	})
end

return {
	-- On a phone the engine's tool bar would be drawn over this window (UIController).
	HidesHotbar = true,

	Mount = function(scope: Scope, _gui: any, context: any)
		local AuraService = Knit.GetService("AuraService")

		local mounted = true
		table.insert(scope, function()
			mounted = false
		end)

		local args = context.Args
		local slot = if type(args) == "table" and args.Slot == 2 then 2 else 1
		local price = AppearanceConfig.Aura.Price

		local fruitName = Bind.data(scope, `DevilFruits.Slot{slot}.Name`, "None")
		local saved = Bind.data(scope, `DevilFruits.Slot{slot}.Color`, "None")
		local gems = Bind.data(scope, AppearanceConfig.Aura.Currency, 0)

		local primary = scope:Value(WHITE)
		local secondary = scope:Value(WHITE)
		local confirming = scope:Value(false)
		local buying = scope:Value(false)
		local canAfford = scope:Computed(function(use): boolean
			return (tonumber(use(gems)) or 0) >= price
		end)

		-- The editors start from the saved pair, and follow it when a purchase lands.
		local function seed()
			local first, second = FruitColor.Parse(tostring(peek(saved)))
			primary:set(first or WHITE)
			secondary:set(second or WHITE)
		end
		seed()
		scope:Observer(saved):onChange(seed)

		local function savedColor(index: number): Fusion.StateObject<Color3>
			return scope:Computed(function(use): Color3
				local first, second = FruitColor.Parse(tostring(use(saved)))
				return (if index == 1 then first else second) or WHITE
			end)
		end

		-- The arrow between the saved and the new pair cycles through the rainbow.
		local arrow = Kit.Image(scope, {
			Name = "Arrow",
			Image = ARROW,
			Color = RAINBOW[#RAINBOW],
			LayoutOrder = 2,
			Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE),
		})
		arrow.Rotation = 270
		local open = true
		table.insert(scope, function()
			open = false
		end)
		task.spawn(function()
			while open do
				for _, color in RAINBOW do
					if not open then
						break
					end
					TweenService:Create(arrow, RAINBOW_INFO, { ImageColor3 = color }):Play()
					task.wait(RAINBOW_INFO.Time)
				end
			end
		end)

		-- Red while the purchase is out of reach. Only a hint: the server decides whether
		-- the gems are enough.
		local gemsColor = scope:Computed(function(use): Color3
			return if use(canAfford) then GEMS_COLOR else REFUSED_COLOR
		end)

		local gemSize = BUY_HEIGHT - 2 * Kit.Space.M
		local function gem(side: number): Instance
			return Kit.Image(scope, {
				Image = GEM_ICON,
				AnchorPoint = Vector2.new(side, 0.5),
				Position = UDim2.new(side, if side == 0 then Kit.Space.L else -Kit.Space.L, 0.5, 0),
				Size = UDim2.fromOffset(gemSize, gemSize),
				ZIndex = 3,
			})
		end

		-- The price and the gems; replaced by the confirmation while it is asked.
		local offer = Kit.Stack(scope, {
			Name = "Center1",
			LayoutOrder = 3,
			Gap = Kit.Space.M,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Size = UDim2.fromOffset(CENTER_WIDTH, BUY_HEIGHT + Kit.Space.M + GEMS_HEIGHT),
			Visible = scope:Computed(function(use): boolean
				return not use(confirming)
			end),
			Children = {
				-- The button carries the price (AppearanceConfig), and says so while the server works.
				Kit.Button(scope, {
					Name = "Buy",
					Variant = "Blue",
					TextSize = Kit.TextSize.Title,
					TextColor = PRICE_COLOR,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(CENTER_WIDTH, BUY_HEIGHT),
					Text = scope:Computed(function(use): string
						return if use(buying) then BUYING_TEXT else Bind.formatNumber(price)
					end),
					OnClick = function()
						if not peek(buying) then
							confirming:set(true)
						end
					end,
					Children = { gem(0), gem(1) },
				}),
				Kit.Well(scope, {
					Name = "Gems",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(math.floor(CENTER_WIDTH * 0.7), GEMS_HEIGHT),
					Color = GEMS_COLOR,
					Transparency = 0.8,
					Children = {
						Kit.Label(scope, {
							Text = "Gems:",
							Color = gemsColor,
							TextXAlignment = Enum.TextXAlignment.Left,
							Position = UDim2.fromOffset(Kit.Space.S, 0),
							Size = UDim2.new(0.4, -Kit.Space.S, 1, 0),
						}),
						Kit.Label(scope, {
							Name = "GemsAmount",
							Color = gemsColor,
							Fit = true,
							TextXAlignment = Enum.TextXAlignment.Right,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -Kit.Space.S, 0, 0),
							Size = UDim2.new(0.6, -Kit.Space.S, 1, 0),
							Text = scope:Computed(function(use): string
								return Bind.formatNumber(tonumber(use(gems)) or 0)
							end),
						}),
					},
				}),
			},
		})

		local confirmWidth = (CENTER_WIDTH - Kit.Space.L) / 2
		local confirmation = Kit.Stack(scope, {
			Name = "Center2",
			LayoutOrder = 4,
			Gap = Kit.Space.M,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Size = UDim2.fromOffset(CENTER_WIDTH, BUY_HEIGHT + Kit.Space.M + GEMS_HEIGHT),
			Visible = confirming,
			Children = {
				Kit.Label(scope, {
					Text = "Please confirm your purchase.",
					Fit = true,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(CENTER_WIDTH, GEMS_HEIGHT),
				}),
				Kit.Stack(scope, {
					Direction = "Horizontal",
					Gap = Kit.Space.L,
					LayoutOrder = 2,
					Children = {
						Kit.Button(scope, {
							Name = "Confirm",
							Text = "CONFIRM",
							Variant = "Green",
							LayoutOrder = 1,
							Size = UDim2.fromOffset(confirmWidth, CONFIRM_HEIGHT),
							OnClick = function()
								confirming:set(false)
								if peek(buying) then
									return
								end
								buying:set(true)
								AuraService:SetColors(slot, peek(primary), peek(secondary)):catch(warn):finally(function()
									if mounted then
										buying:set(false)
									end
								end)
							end,
						}),
						Kit.Button(scope, {
							Name = "Decline",
							Text = "DECLINE",
							Variant = "Red",
							LayoutOrder = 2,
							Size = UDim2.fromOffset(confirmWidth, CONFIRM_HEIGHT),
							OnClick = function()
								confirming:set(false)
							end,
						}),
					},
				}),
			},
		})

		local center = Kit.Stack(scope, {
			Name = "Center",
			Gap = Kit.Space.L,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0, CENTER_WIDTH, 1, 0),
			Children = {
				Kit.Well(scope, {
					Name = "DevilFruit",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(CENTER_WIDTH - 2 * Kit.Space.XL, FRUIT_HEIGHT),
					Color = FRUIT_COLOR,
					Transparency = 0.55,
					Children = Kit.Label(scope, {
						Fit = true,
						Size = UDim2.fromScale(1, 1),
						Text = scope:Computed(function(use): string
							return tostring(use(fruitName))
						end),
					}),
				}),
				Kit.Stack(scope, {
					Name = "Pairs",
					Direction = "Horizontal",
					Gap = Kit.Space.M,
					LayoutOrder = 2,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Children = {
						pair(scope, "Saved", savedColor(1), savedColor(2), 1),
						arrow,
						pair(scope, "New", primary, secondary, 3),
					},
				}),
				offer,
				confirmation,
			},
		})

		return Kit.Screen(scope, {
			Name = "CustomizeAuras",
			-- Opened from the menu, which is still on the screen: above it.
			DisplayOrder = 5,
			Children = Kit.Window(scope, {
				Image = BACKGROUND,
				Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
				OnClose = function()
					context.Close()
				end,
				Children = {
					-- The title is written in rich text, which the window's own title is not:
					-- it is laid over the window's header from here.
					Kit.Label(scope, {
						Name = "Header",
						Text = TITLE,
						RichText = true,
						TextSize = Kit.TextSize.Title,
						Position = UDim2.fromOffset(0, -HEADER_HEIGHT),
						Size = UDim2.new(1, 0, 0, HEADER_HEIGHT - Kit.Space.S),
					}),
					editor(scope, "Frame1", "Primary Color", primary, 0),
					center,
					editor(scope, "Frame2", "Secondary Color", secondary, 1),
				},
			}),
		})
	end,
}
