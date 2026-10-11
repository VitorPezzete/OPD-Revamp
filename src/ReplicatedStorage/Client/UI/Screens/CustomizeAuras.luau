--!strict
--[[
	Aura customization: pick the two effect colours of an eaten fruit and buy them.

	Opened with { Slot = 1 | 2 } by the "customize aura" buttons of the menu's stats tab.
	The top strip shows the saved pair next to the pair being edited; each of the two
	editors has nine swatches and, per channel, a slider and -10 / -1 / +1 / +10 buttons.

	Each colour is a Fusion value holding whole 0-255 channels. Buying sends the slot and
	the two colours to AuraService; the price is charged (or refused) by the server.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local AppearanceConfig = require(ReplicatedStorage.Shared.Configs.AppearanceConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local Swatch = require(ReplicatedStorage.Client.UI.Components.Swatch)

type Scope = Theme.Scope
type State<T> = Fusion.StateObject<T>
type Channels = { R: number, G: number, B: number }

local WHITE = Color3.new(1, 1, 1)
local GEM_ICON = "rbxassetid://1954296071"
-- The aura mark, tinted with the colour it stands for.
local AURA_ICON = "rbxassetid://607507441"

-- Aura colours offered as shortcuts (the legacy palette).
local PALETTE = {
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
local CHANNELS: { { Key: "R" | "G" | "B", Color: Color3 } } = {
	{ Key = "R", Color = Theme.Colors.Danger },
	{ Key = "G", Color = Theme.Colors.Success },
	{ Key = "B", Color = Theme.Colors.Shield },
}
local STEPS_DOWN = { { Text = "<<", Delta = -10 }, { Text = "<", Delta = -1 } }
local STEPS_UP = { { Text = ">", Delta = 1 }, { Text = ">>", Delta = 10 } }

local STRIP_HEIGHT = 96
local EDITOR_HEIGHT = 260
local FOOTER_HEIGHT = 52
local SWATCH = 40
local STEP = 38
local CHANNEL_HEIGHT = 44
local PREVIEW = 52

local function toChannels(color: Color3): Channels
	return {
		R = math.round(color.R * 255),
		G = math.round(color.G * 255),
		B = math.round(color.B * 255),
	}
end

local function editor(scope: Scope, title: string, picked: Fusion.Value<Color3>, props: { [string]: any }): Frame
	local function setChannel(key: string, amount: number)
		local channels: any = toChannels(Fusion.peek(picked))
		channels[key] = math.clamp(math.round(amount), 0, 255)
		picked:set(Color3.fromRGB(channels.R, channels.G, channels.B))
	end

	local swatches: { any } = {}
	for index, color in PALETTE do
		swatches[index] = Swatch(scope, {
			Name = `Pallet{index}`,
			Color = color,
			LayoutOrder = index,
			Size = UDim2.fromOffset(SWATCH, SWATCH),
			Selected = scope:Computed(function(use): boolean
				return use(picked) == color
			end),
			OnClick = function()
				picked:set(color)
			end,
		})
	end

	local rows: { any } = {}
	for index, channel in CHANNELS do
		local key = channel.Key
		local amount = scope:Computed(function(use): number
			return (toChannels(use(picked)) :: any)[key]
		end)

		local function stepButton(step: { Text: string, Delta: number }, order: number): TextButton
			return UI.Button(scope, {
				Name = step.Text,
				Text = step.Text,
				Variant = "Secondary",
				TextSize = Theme.TextSize.Small,
				LayoutOrder = order,
				Size = UDim2.fromOffset(STEP, STEP),
				OnClick = function()
					setChannel(key, Fusion.peek(amount) + step.Delta)
				end,
			})
		end

		-- Everything in the row except the slider has a fixed width.
		local fixed = 20 + STEP * 4 + 44 + Theme.Space.XS * 6
		rows[index] = UI.Stack(scope, {
			Name = `Frame{key}`,
			Direction = "Horizontal",
			Gap = Theme.Space.XS,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, CHANNEL_HEIGHT),
			Children = {
				UI.Label(scope, {
					Text = key,
					Variant = "BodyBold",
					Color = channel.Color,
					Size = UDim2.fromOffset(20, CHANNEL_HEIGHT),
					LayoutOrder = 1,
				}),
				stepButton(STEPS_DOWN[1], 2),
				stepButton(STEPS_DOWN[2], 3),
				UI.Slider(scope, {
					LayoutOrder = 4,
					Size = UDim2.new(1, -fixed, 0, 28),
					Color = channel.Color,
					Value = scope:Computed(function(use): number
						return use(amount) / 255
					end),
					OnChange = function(ratio: number)
						setChannel(key, ratio * 255)
					end,
				}),
				stepButton(STEPS_UP[1], 5),
				stepButton(STEPS_UP[2], 6),
				UI.Label(scope, {
					Name = "Amount",
					Text = scope:Computed(function(use): string
						return tostring(use(amount))
					end),
					Variant = "BodyBold",
					Font = Theme.Fonts.Mono,
					Size = UDim2.fromOffset(44, CHANNEL_HEIGHT),
					LayoutOrder = 7,
				}),
			},
		})
	end

	props.Padding = Theme.Space.M
	props.Children = {
		UI.Label(scope, {
			Text = title,
			Variant = "BodyBold",
			Color = Theme.Colors.Accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 24),
		}),
		UI.Stack(scope, {
			Name = "Palette",
			Direction = "Horizontal",
			Gap = Theme.Space.S,
			Position = UDim2.fromOffset(0, 24 + Theme.Space.S),
			Children = swatches,
		}),
		UI.Stack(scope, {
			Name = "Channels",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, #CHANNELS * CHANNEL_HEIGHT + (#CHANNELS - 1) * Theme.Space.S),
			Gap = Theme.Space.S,
			Children = rows,
		}),
	}
	return UI.Panel(scope, props :: any)
end

-- Two aura marks under a caption: a colour pair.
local function pair(scope: Scope, caption: string, first: State<Color3>, second: State<Color3>, order: number): Frame
	return UI.Stack(scope, {
		Name = caption,
		LayoutOrder = order,
		Gap = Theme.Space.XS,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Children = {
			UI.Label(scope, { Text = caption, Variant = "Tiny", Color = Theme.Colors.TextMuted, LayoutOrder = 1 }),
			UI.Stack(scope, {
				Direction = "Horizontal",
				Gap = Theme.Space.S,
				LayoutOrder = 2,
				Children = {
					UI.Image(scope, {
						Image = AURA_ICON,
						Color = first,
						Size = UDim2.fromOffset(PREVIEW, PREVIEW),
						LayoutOrder = 1,
					}),
					UI.Image(scope, {
						Image = AURA_ICON,
						Color = second,
						Size = UDim2.fromOffset(PREVIEW, PREVIEW),
						LayoutOrder = 2,
					}),
				},
			}),
		},
	})
end

return {
	-- On a phone the engine's tool bar would be drawn over this window (UIController).
	HidesHotbar = true,
	Mount = function(scope: Scope, _gui: any, context: any)
		local AuraService = Knit.GetService("AuraService")

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

		local mounted = true
		table.insert(scope, function()
			mounted = false
		end)

		-- The editors start from the saved pair, and follow it when a purchase lands.
		local function seed()
			local first, second = FruitColor.Parse(tostring(Fusion.peek(saved)))
			primary:set(first or WHITE)
			secondary:set(second or WHITE)
		end
		seed()
		scope:Observer(saved):onChange(seed)

		local function savedColor(index: number): State<Color3>
			return scope:Computed(function(use): Color3
				local first, second = FruitColor.Parse(tostring(use(saved)))
				return (if index == 1 then first else second) or WHITE
			end)
		end

		local canAfford = scope:Computed(function(use): boolean
			return (tonumber(use(gems)) or 0) >= price
		end)
		local notConfirming = scope:Computed(function(use): boolean
			return not use(confirming)
		end)

		local function buy()
			confirming:set(false)
			buying:set(true)
			AuraService:SetColors(slot, Fusion.peek(primary), Fusion.peek(secondary)):catch(warn):finally(function()
				if mounted then
					buying:set(false)
				end
			end)
		end

		local editorY = STRIP_HEIGHT + Theme.Space.M
		local bodyHeight = editorY + EDITOR_HEIGHT + Theme.Space.L + FOOTER_HEIGHT

		return UI.Screen(scope, {
			Name = "CustomizeAuras",
			DisplayOrder = 15,
			Children = {
				UI.Window(scope, {
					Title = "Customize Aura",
					Size = UDim2.fromOffset(960, bodyHeight + 52 + Theme.Space.L * 2),
					OnClose = context.Close,
					HeaderChildren = {
						UI.Image(scope, { Image = GEM_ICON, Size = UDim2.fromOffset(24, 24), LayoutOrder = 1 }),
						UI.Label(scope, {
							Name = "GemsAmount",
							Text = scope:Computed(function(use): string
								return Bind.formatNumber(tonumber(use(gems)) or 0)
							end),
							Variant = "BodyBold",
							-- Red while the purchase is out of reach.
							Color = scope:Computed(function(use): Color3
								return if use(canAfford) then Theme.Colors.Gems else Theme.Colors.Danger
							end),
							LayoutOrder = 2,
						}),
					},
					Children = {
						UI.Panel(scope, {
							Name = "Strip",
							Size = UDim2.new(1, 0, 0, STRIP_HEIGHT),
							Padding = Theme.Space.M,
							Children = {
								UI.Label(scope, {
									Name = "DevilFruit",
									Text = scope:Computed(function(use): string
										return tostring(use(fruitName))
									end),
									Variant = "Title",
									Scaled = true,
									TextXAlignment = Enum.TextXAlignment.Left,
									Size = UDim2.new(0.35, 0, 0, 36),
								}),
								UI.Label(scope, {
									Text = `Fruit slot {slot}`,
									Variant = "Small",
									TextXAlignment = Enum.TextXAlignment.Left,
									AnchorPoint = Vector2.new(0, 1),
									Position = UDim2.fromScale(0, 1),
									Size = UDim2.new(0.35, 0, 0, 20),
								}),
								UI.Stack(scope, {
									Name = "Pairs",
									Direction = "Horizontal",
									Gap = Theme.Space.XL,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									AnchorPoint = Vector2.new(0.5, 0.5),
									Position = UDim2.fromScale(0.5, 0.5),
									Children = {
										pair(scope, "Current", savedColor(1), savedColor(2), 1),
										UI.Label(scope, {
											Name = "Arrow",
											Text = ">",
											Variant = "Display",
											Color = Theme.Colors.Accent,
											LayoutOrder = 2,
										}),
										pair(scope, "New", primary, secondary, 3),
									},
								}),
							},
						}),

						editor(scope, "Primary Color", primary, {
							Name = "Frame1",
							Position = UDim2.fromOffset(0, editorY),
							Size = UDim2.new(0.5, -Theme.Space.M / 2, 0, EDITOR_HEIGHT),
						}),
						editor(scope, "Secondary Color", secondary, {
							Name = "Frame2",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, 0, 0, editorY),
							Size = UDim2.new(0.5, -Theme.Space.M / 2, 0, EDITOR_HEIGHT),
						}),

						scope:New("Frame")({
							Name = "Footer",
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.fromScale(0.5, 1),
							Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
							BackgroundTransparency = 1,
							[Fusion.Children] = {
								UI.Button(scope, {
									Name = "Buy",
									Icon = GEM_ICON,
									IconColor = WHITE,
									Text = scope:Computed(function(use): string
										return if use(buying) then "Buying..." else `Buy   {Bind.formatNumber(price)}`
									end),
									-- Only a hint: the server decides whether the gems are enough.
									Variant = scope:Computed(function(use): any
										return if use(canAfford) then "Primary" else "Secondary"
									end),
									Disabled = buying,
									AnchorPoint = Vector2.new(0.5, 0),
									Position = UDim2.fromScale(0.5, 0),
									Size = UDim2.fromOffset(300, FOOTER_HEIGHT),
									Visible = notConfirming,
									OnClick = function()
										confirming:set(true)
									end,
								}),
								UI.Label(scope, {
									Text = "Please confirm your purchase.",
									Variant = "BodyBold",
									TextXAlignment = Enum.TextXAlignment.Left,
									Size = UDim2.new(1, -(200 * 2 + Theme.Space.S * 2), 1, 0),
									Visible = confirming,
								}),
								UI.Button(scope, {
									Name = "Decline",
									Text = "Decline",
									Variant = "Secondary",
									AnchorPoint = Vector2.new(1, 0),
									Position = UDim2.new(1, -(200 + Theme.Space.S), 0, 0),
									Size = UDim2.fromOffset(200, FOOTER_HEIGHT),
									Visible = confirming,
									OnClick = function()
										confirming:set(false)
									end,
								}),
								UI.Button(scope, {
									Name = "Confirm",
									Text = "Confirm",
									Variant = "Success",
									AnchorPoint = Vector2.new(1, 0),
									Position = UDim2.fromScale(1, 0),
									Size = UDim2.fromOffset(200, FOOTER_HEIGHT),
									Visible = confirming,
									OnClick = buy,
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
