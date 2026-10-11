--!strict
--[[
	Menu tab "Customize": a small parchment with two plank buttons, docked beside the menu
	column, each opening a panel at the right edge of the screen (menu.Side), so that the
	character standing in the middle stays in view while it is being dressed.

	Clothes       a title, then one row per category: its name on a plank, then the
	              - / value / + steppers of the style and, where the category is coloured,
	              of the palette index; the skin dye button under the skin row.
	Accessories   a title, six slots in one column (D-F need a game pass) and the gems. A
	              slot is a row: its letter, its picture, its colour and the colour
	              stepper; a slot still locked shows "Game Pass" and a Buy button in place
	              of the colour. Clicking a picture turns the list into the accessory shop,
	              where an owned accessory is equipped into that slot and the others are
	              bought with gems. The small X on a picture takes off what the slot wears
	              (it stays owned).

		Customize(scope, context, menu): GuiObject     -- the chooser, for the shell to dock

	The two panels are the same width, with the same title and paddings; only one shows at
	a time. They live in the shell's full-screen frame (menu.Center), not in the docked
	chooser, so each owns its visibility: its button chosen and this tab open.

	There is no preview: as in the old menu, every change is applied to the real
	character by the server and the menu only mirrors the saved values. The client sends
	field names, slot letters and accessory names; prices, ownership and the game passes
	are the server's business.

	The screens of this group are opened from other tabs, by their parts: the two skin dye
	shops from the shop tab (MenuNew/Shop), the aura editor from the stats tab (MenuNew/Stats).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local AccessoryConfig = require(ReplicatedStorage.Shared.Configs.AccessoryConfig)
local AppearanceConfig = require(ReplicatedStorage.Shared.Configs.AppearanceConfig)
local AppearanceAssets = require(ReplicatedStorage.Shared.Util.AppearanceAssets)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)
local ColorButton = require(ReplicatedStorage.Client.UI.Legacy.Components.ColorButton)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local PlaceManifest = require(ReplicatedStorage.Shared.Configs.PlaceManifest)

type Scope = Fusion.Scope<typeof(Fusion)>

local peek = Fusion.peek

-- Key of this tab (PlaceManifest.MenuTabs), which is what menu.Selected holds.
local TAB_KEY = "Customize"
local SERVICES = { "AppearanceService", "MonetizationService" }
local CLOTHES = "Clothes"
local ACCESSORIES = "Accessories"

local WHITE = Color3.new(1, 1, 1)
-- What the dye button reads while no dye is owned.
local NO_DYE_TEXT = "None owned"

local EMPTY_SLOT_IMAGE = "rbxassetid://2009447558"
local GEM_ICON = "rbxassetid://1954296071"
local CONFIRM_ICON = "rbxassetid://1954825529"
local DECLINE_ICON = "rbxassetid://1954825535"

local SLOT_COLOR = Color3.fromRGB(153, 105, 96)
local GEMS_COLOR = Color3.fromRGB(85, 255, 255)
local COST_COLOR = Color3.fromRGB(74, 252, 255)
local COST_BACK = Color3.fromRGB(83, 45, 149)
local OWNED_COLOR = Color3.fromRGB(21, 255, 17)
local OWNED_BACK = Color3.fromRGB(103, 34, 200)
local ASK_BACK = Color3.fromRGB(248, 255, 111)

-- The parchment with the two buttons: the proportions of the menu column beside it.
local CHOOSER_BUTTON = Vector2.new(176, 36)
local CHOOSER_GAP = 6
local CHOOSER_PADDING = 8
local CHOOSER_SIZE = Vector2.new(
	CHOOSER_BUTTON.X + 2 * CHOOSER_PADDING,
	2 * CHOOSER_BUTTON.Y + CHOOSER_GAP + 2 * CHOOSER_PADDING
)

-- What the two side panels share.
local PANEL_WIDTH = 620
local PANEL_PADDING = 20
local INNER_WIDTH = PANEL_WIDTH - 2 * PANEL_PADDING
local TITLE_HEIGHT = 52
local SECTION_GAP = Kit.Space.S
local STEP_GAP = Kit.Space.XS

-- Clothes: name + two steppers fill the inner width.
local ROW_HEIGHT = 48
local STEPPER_WIDTH = 192
local STEP_BUTTON_WIDTH = 44
local NAME_WIDTH = INNER_WIDTH - 2 * (STEPPER_WIDTH + Kit.Space.M)
local CAPTION_HEIGHT = 22

-- Accessories: a slot row is letter, picture, then colour swatch + stepper (or the pass).
local GEMS_HEIGHT = 48
local SLOT_HEIGHT = 100
local SLOT_PADDING = Kit.Space.S
local SLOT_INNER = SLOT_HEIGHT - 2 * SLOT_PADDING
local LETTER_WIDTH = 56
local PICTURE_WIDTH = 132
local SIDE_WIDTH = INNER_WIDTH - 2 * SLOT_PADDING - LETTER_WIDTH - PICTURE_WIDTH - 2 * Kit.Space.S
local CONTROL_HEIGHT = 52
local COLOR_STEPPER_WIDTH = 228
local COLOR_STEP_WIDTH = 48
local SWATCH_WIDTH = SIDE_WIDTH - COLOR_STEPPER_WIDTH - Kit.Space.S
local PASS_BUY_WIDTH = 140
local REMOVE_SIZE = 28
-- Three cells across the panel, beside the scroll bar.
local SHOP_CELL = Vector2.new(176, 200)
local SHOP_PICTURE_HEIGHT = 150
local SHOP_NAME_HEIGHT = 32
local SHOP_STRIP_HEIGHT = 46

-- Row of the clothes panel -> Appearance field, top to bottom.
local ROWS: { { Text: string, Field: string? } } = {
	{ Text = "Hair", Field = "Hair" },
	{ Text = "Torso", Field = "Torso" },
	{ Text = "Arms", Field = "Arms" },
	{ Text = "Legs", Field = "Pants" },
	{ Text = "Face", Field = "Face" },
	{ Text = "Skin", Field = "SkinColor" },
	-- The dye is not a field to step through: its row holds the dye button.
	{ Text = "Skin Dye" },
	{ Text = "Hands", Field = "Gloves" },
	{ Text = "Feet", Field = "Feet" },
}

local function wrap(value: number, delta: number, limit: number): number
	return (value - 1 + delta) % limit + 1
end

return function(scope: Scope, _context: any, menu: any): GuiObject?
	-- No panel in a place that does not load what the buttons call.
	for _, service in SERVICES do
		if not PlaceManifest.Has("Services", service) then
			return nil
		end
	end

	local AppearanceService = Knit.GetService("AppearanceService")
	local MonetizationService = Knit.GetService("MonetizationService")

	-- Open sub-panel, slot being filled, whether the accessory shop covers the slots.
	local panel: Fusion.Value<string?> = scope:Value(nil :: string?)
	local selectedSlot = scope:Value("A")
	local shopOpen = scope:Value(false)

	local function togglePanel(name: string)
		shopOpen:set(false)
		panel:set(if peek(panel) == name then nil else name)
	end
	-- Leaving the tab folds everything, so it reopens on the two buttons.
	scope:Observer(menu.Selected):onChange(function()
		if peek(menu.Selected) ~= TAB_KEY then
			panel:set(nil)
			shopOpen:set(false)
		end
	end)

	-- A side panel shows while its button is chosen and this tab is the open one: it is
	-- not a child of the docked chooser, so leaving the tab does not take it away.
	local function showing(name: string): Fusion.StateObject<boolean>
		return scope:Computed(function(use): boolean
			return use(panel) == name and use(menu.Selected) == TAB_KEY
		end)
	end

	local function chooserButton(name: string, text: string, order: number): Instance
		return Kit.Button(scope, {
			Name = name,
			Text = text,
			TextSize = Kit.TextSize.Body,
			LayoutOrder = order,
			Size = UDim2.fromOffset(CHOOSER_BUTTON.X, CHOOSER_BUTTON.Y),
			Selected = scope:Computed(function(use): boolean
				return use(panel) == name
			end),
			OnClick = function()
				togglePanel(name)
			end,
		})
	end

	local chooser = Kit.Panel(scope, {
		Name = "Chooser",
		Size = UDim2.fromScale(1, 1),
		Padding = CHOOSER_PADDING,
		Children = Kit.Stack(scope, {
			Name = "Buttons",
			Gap = CHOOSER_GAP,
			Children = {
				chooserButton(CLOTHES, "Clothes", 1),
				chooserButton(ACCESSORIES, "Accessories", 2),
			},
		}),
	})

	-- The strip across the top of a side panel.
	local function titleBar(text: Fusion.UsedAs<string>, children: Fusion.Child?): Instance
		return Kit.Well(scope, {
			Name = "Title",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
			Children = {
				Kit.Label(scope, {
					Text = text,
					TextSize = Kit.TextSize.Heading,
					Size = UDim2.fromScale(1, 1),
				}),
				children,
			} :: { any },
		})
	end

	-- "-  value  +" in one line: what both panels step their numbers with.
	local function stepperRow(props: {
		Name: string,
		LayoutOrder: number,
		Size: Vector2,
		ButtonWidth: number,
		Text: Fusion.UsedAs<string>,
		OnStep: (delta: number) -> (),
	}): Instance
		return Kit.Stack(scope, {
			Name = props.Name,
			Direction = "Horizontal",
			Gap = STEP_GAP,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromOffset(props.Size.X, props.Size.Y),
			Children = {
				Kit.Button(scope, {
					Name = "Lower",
					Text = "-",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(props.ButtonWidth, props.Size.Y),
					OnClick = function()
						props.OnStep(-1)
					end,
				}),
				Kit.Well(scope, {
					Name = "Value",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(props.Size.X - 2 * (props.ButtonWidth + STEP_GAP), props.Size.Y),
					Children = Kit.Label(scope, {
						Size = UDim2.fromScale(1, 1),
						Fit = true,
						Text = props.Text,
					}),
				}),
				Kit.Button(scope, {
					Name = "Raise",
					Text = "+",
					LayoutOrder = 3,
					Size = UDim2.fromOffset(props.ButtonWidth, props.Size.Y),
					OnClick = function()
						props.OnStep(1)
					end,
				}),
			},
		})
	end

	---------------------------------------------------------------------------------
	-- Clothes

	-- The stepper of one Appearance field. nil for a field with nothing to step through.
	local function stepper(field: string, order: number): Instance?
		local limit = AppearanceConfig.GetLimit(field)
		if not limit then
			return nil
		end
		local value = Bind.data(scope, "Appearance." .. field, 1)

		return stepperRow({
			Name = field,
			LayoutOrder = order,
			Size = Vector2.new(STEPPER_WIDTH, ROW_HEIGHT),
			ButtonWidth = STEP_BUTTON_WIDTH,
			Text = scope:Computed(function(use): string
				return tostring(use(value))
			end),
			OnStep = function(delta: number)
				local current = peek(value)
				if type(current) == "number" then
					AppearanceService.Change:Fire(field, wrap(current, delta, limit))
				end
			end,
		})
	end

	-- The dye button shows the owned dye; clicking it wears the dye (picking a skin tone
	-- in the row above takes it off again).
	local dye = Bind.data(scope, "Appearance.SkinDye", "")
	local dyeName = scope:Computed(function(use): string
		return tostring(use(dye) or "")
	end)
	local dyeButton = ColorButton(scope, {
		Name = "SkinDye",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(STEPPER_WIDTH, ROW_HEIGHT),
		TextSize = Kit.TextSize.Body,
		Text = scope:Computed(function(use): string
			local name = use(dyeName)
			return if name ~= "" then name else NO_DYE_TEXT
		end),
		Color = scope:Computed(function(use): Color3
			local name = use(dyeName)
			return (if name ~= "" then AppearanceAssets.GetDye(name) else nil) or WHITE
		end),
		OnClick = function()
			AppearanceService.UseSkinDye:Fire()
		end,
	})

	local clothesRows: { Instance } = {
		titleBar("Clothes Customize"),
		-- What the two columns of steppers are.
		Kit.Stack(scope, {
			Name = "Captions",
			Direction = "Horizontal",
			Gap = Kit.Space.M,
			LayoutOrder = 2,
			Children = {
				scope:New("Frame")({
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(NAME_WIDTH, CAPTION_HEIGHT),
				}),
				Kit.Label(scope, {
					Text = "Style",
					TextSize = Kit.TextSize.Small,
					LayoutOrder = 2,
					Size = UDim2.fromOffset(STEPPER_WIDTH, CAPTION_HEIGHT),
				}),
				Kit.Label(scope, {
					Text = "Color",
					TextSize = Kit.TextSize.Small,
					LayoutOrder = 3,
					Size = UDim2.fromOffset(STEPPER_WIDTH, CAPTION_HEIGHT),
				}),
			},
		}),
	}
	for order, row in ROWS do
		local field = row.Field
		local category = if field then AppearanceConfig.Categories[field] else nil
		table.insert(
			clothesRows,
			Kit.Stack(scope, {
				Name = row.Text,
				Direction = "Horizontal",
				Gap = Kit.Space.M,
				LayoutOrder = order + 2,
				Children = {
					Kit.Panel(scope, {
						Name = "Name",
						Image = Kit.Images.Plank,
						Color = Kit.Colors.Plank,
						Transparency = 0.7,
						LayoutOrder = 1,
						Size = UDim2.fromOffset(NAME_WIDTH, ROW_HEIGHT),
						Children = Kit.Label(scope, {
							Text = row.Text,
							TextSize = Kit.TextSize.Button,
							Size = UDim2.fromScale(1, 1),
						}),
					}),
					if field then stepper(field, 2) else dyeButton,
					if field and category and category.Colored then stepper(field .. "_Color", 3) else nil,
				} :: { any },
			})
		)
	end

	local clothesSize = Vector2.new(
		PANEL_WIDTH,
		2 * PANEL_PADDING + TITLE_HEIGHT + CAPTION_HEIGHT + #ROWS * ROW_HEIGHT + (#ROWS + 1) * SECTION_GAP
	)
	local clothes = Kit.Panel(scope, {
		Name = "Clothes",
		Size = UDim2.fromOffset(clothesSize.X, clothesSize.Y),
		Padding = PANEL_PADDING,
		Visible = showing(CLOTHES),
		Children = Kit.Stack(scope, {
			Name = "Rows",
			Gap = SECTION_GAP,
			Size = UDim2.fromScale(1, 1),
			Children = clothesRows,
		}),
	})
	menu.Side(clothes, clothesSize)
	clothes.Parent = menu.Center

	---------------------------------------------------------------------------------
	-- Accessory slots

	-- The slot passes are Robux products: MonetizationService decides what is prompted
	-- (same entry point as the "Buy slot" buttons of the shop tab).
	local function promptSlotPass(pass: string)
		MonetizationService:Prompt(pass):catch(warn)
	end

	local function slotRow(slot: string, order: number): Instance
		local equipped = Bind.data(scope, `Appearance.ExtraSlots.{slot}`, "")
		local colorIndex = Bind.data(scope, `Appearance.ExtraSlots.{slot}_Color`, 1)
		local pass = AppearanceConfig.PremiumSlots[slot]
		local unlocked = if pass then Bind.data(scope, "GamePasses." .. pass, false) else scope:Value(true)

		local equippedName = scope:Computed(function(use): string
			local name = use(equipped)
			return if type(name) == "string" then name else ""
		end)
		local locked = scope:Computed(function(use): boolean
			return pass ~= nil and use(unlocked) ~= true
		end)

		local picture = Kit.Well(scope, {
			Name = "Picture",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(PICTURE_WIDTH, SLOT_INNER),
			Color = SLOT_COLOR,
			Transparency = 0.5,
			Children = {
				Kit.Image(scope, {
					Size = UDim2.fromScale(1, 1),
					ZIndex = 1,
					Image = scope:Computed(function(use): string
						local name = use(equippedName)
						local icon = if name ~= "" then AppearanceAssets.GetExtraIcon(name) else nil
						return icon or EMPTY_SLOT_IMAGE
					end),
				}),
				-- Opens the accessory shop for this slot; a slot still locked asks for its pass.
				Kit.Button(scope, {
					Name = "Button",
					Variant = "Ghost",
					Text = "",
					Size = UDim2.fromScale(1, 1),
					ZIndex = 2,
					OnClick = function()
						if pass and peek(unlocked) ~= true then
							promptSlotPass(pass)
							return
						end
						selectedSlot:set(slot)
						shopOpen:set(true)
					end,
				}),
				-- Takes off what the slot wears (it stays owned). Not on a slot still locked
				-- behind its game pass.
				Kit.Button(scope, {
					Name = "Remove",
					Text = "X",
					Variant = "Red",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -2, 0, 2),
					Size = UDim2.fromOffset(REMOVE_SIZE, REMOVE_SIZE),
					ZIndex = 3,
					Visible = scope:Computed(function(use): boolean
						return use(equippedName) ~= "" and use(unlocked) == true
					end),
					OnClick = function()
						AppearanceService.RemoveAccessory:Fire(slot)
					end,
				}),
			},
		})

		-- The colour the accessory is worn in, and the stepper through the palette.
		local controls = Kit.Stack(scope, {
			Name = "Controls",
			Direction = "Horizontal",
			Gap = Kit.Space.S,
			Size = UDim2.fromScale(1, 1),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Visible = scope:Computed(function(use): boolean
				return not use(locked)
			end),
			Children = {
				Kit.Well(scope, {
					Name = "ColorLabel",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(SWATCH_WIDTH, CONTROL_HEIGHT),
					Transparency = 0,
					Color = scope:Computed(function(use): Color3
						local index = use(colorIndex)
						return (if type(index) == "number" then AppearanceAssets.GetColor(index) else nil) or WHITE
					end),
					Children = Kit.Label(scope, {
						Text = "Color",
						TextSize = Kit.TextSize.Small,
						Size = UDim2.fromScale(1, 1),
					}),
				}),
				stepperRow({
					Name = "Color",
					LayoutOrder = 2,
					Size = Vector2.new(COLOR_STEPPER_WIDTH, CONTROL_HEIGHT),
					ButtonWidth = COLOR_STEP_WIDTH,
					Text = scope:Computed(function(use): string
						return tostring(use(colorIndex))
					end),
					OnStep = function(delta: number)
						local current = peek(colorIndex)
						if peek(equippedName) ~= "" and type(current) == "number" then
							AppearanceService.SetAccessoryColor:Fire(slot, wrap(current, delta, AppearanceConfig.ColorCount))
						end
					end,
				}),
			},
		})

		return Kit.Well(scope, {
			Name = `Slot{slot}`,
			LayoutOrder = order,
			Size = UDim2.fromOffset(INNER_WIDTH, SLOT_HEIGHT),
			Padding = SLOT_PADDING,
			Children = Kit.Stack(scope, {
				Direction = "Horizontal",
				Gap = Kit.Space.S,
				Size = UDim2.fromScale(1, 1),
				Children = {
					Kit.Well(scope, {
						Name = "SlotName",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(LETTER_WIDTH, SLOT_INNER),
						Transparency = 0.65,
						Children = Kit.Label(scope, {
							Text = slot,
							TextSize = Kit.TextSize.Title,
							Size = UDim2.fromScale(1, 1),
						}),
					}),
					picture,
					scope:New("Frame")({
						Name = "Side",
						BackgroundTransparency = 1,
						LayoutOrder = 3,
						Size = UDim2.fromOffset(SIDE_WIDTH, SLOT_INNER),
						[Fusion.Children] = {
							controls,
							-- In place of the colour while the pass is not owned.
							if pass
								then Kit.Stack(scope, {
									Name = "BuyGamepass",
									Direction = "Horizontal",
									Gap = Kit.Space.S,
									Size = UDim2.fromScale(1, 1),
									VerticalAlignment = Enum.VerticalAlignment.Center,
									Visible = locked,
									Children = {
										Kit.Well(scope, {
											Name = "Notice",
											LayoutOrder = 1,
											Size = UDim2.fromOffset(SIDE_WIDTH - PASS_BUY_WIDTH - Kit.Space.S, CONTROL_HEIGHT),
											Children = Kit.Label(scope, {
												Text = "Game Pass",
												TextSize = Kit.TextSize.Body,
												Fit = true,
												Size = UDim2.fromScale(1, 1),
											}),
										}),
										Kit.Button(scope, {
											Name = "Buy",
											Text = "Buy",
											Variant = "Green",
											LayoutOrder = 2,
											Size = UDim2.fromOffset(PASS_BUY_WIDTH, CONTROL_HEIGHT),
											OnClick = function()
												promptSlotPass(pass)
											end,
										}),
									},
								})
								else nil,
						} :: { any },
					}),
				},
			}),
		})
	end

	local slotRows: { Instance } = {}
	for index, slot in AccessoryConfig.Slots do
		table.insert(slotRows, slotRow(slot, index))
	end

	---------------------------------------------------------------------------------
	-- Accessory shop: one cell per purchasable accessory.

	local owned = Bind.data(scope, "Appearance.OwnedAccessories", {})

	local function shopCell(name: string, order: number): Instance
		local isOwned = scope:Computed(function(use): boolean
			local set = use(owned)
			return type(set) == "table" and set[name] == true
		end)
		local confirming = scope:Value(false)

		local strip = UDim2.new(1, 0, 0, SHOP_STRIP_HEIGHT)
		local stripPosition = UDim2.new(0, 0, 1, -SHOP_STRIP_HEIGHT)
		local askWidth = math.floor(SHOP_CELL.X / 3)

		return Kit.Well(scope, {
			Name = name,
			LayoutOrder = order,
			Children = {
				Kit.Image(scope, {
					Image = AppearanceAssets.GetExtraIcon(name) or EMPTY_SLOT_IMAGE,
					Size = UDim2.new(1, 0, 0, SHOP_PICTURE_HEIGHT),
					ZIndex = 1,
				}),
				Kit.Well(scope, {
					Name = "Label",
					Position = UDim2.fromOffset(0, SHOP_PICTURE_HEIGHT - SHOP_NAME_HEIGHT),
					Size = UDim2.new(1, 0, 0, SHOP_NAME_HEIGHT),
					Transparency = 0.5,
					ZIndex = 2,
					Children = Kit.Label(scope, {
						Text = name,
						TextSize = Kit.TextSize.Small,
						Fit = true,
						Size = UDim2.fromScale(1, 1),
					}),
				}),
				-- The picture equips an accessory already owned into the slot being filled.
				Kit.Button(scope, {
					Name = "Equip",
					Variant = "Ghost",
					Text = "",
					Size = UDim2.new(1, 0, 0, SHOP_PICTURE_HEIGHT),
					ZIndex = 3,
					OnClick = function()
						if peek(isOwned) then
							AppearanceService.EquipAccessory:Fire(peek(selectedSlot), name)
							shopOpen:set(false)
						end
					end,
				}),

				-- The strip under the picture: the price, which asks for confirmation in
				-- place before buying, or "Owned".
				Kit.Well(scope, {
					Name = "Cost",
					Position = stripPosition,
					Size = strip,
					Color = COST_BACK,
					Transparency = 0,
					Visible = scope:Computed(function(use): boolean
						return not use(isOwned) and not use(confirming)
					end),
					Children = {
						Kit.Stack(scope, {
							Direction = "Horizontal",
							Gap = Kit.Space.XS,
							Padding = Kit.Space.XS,
							Size = UDim2.fromScale(1, 1),
							HorizontalAlignment = Enum.HorizontalAlignment.Right,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Children = {
								Kit.Label(scope, {
									Text = Bind.formatNumber(AccessoryConfig.Prices[name]),
									Color = COST_COLOR,
									LayoutOrder = 1,
								}),
								Kit.Image(scope, {
									Image = GEM_ICON,
									LayoutOrder = 2,
									Size = UDim2.fromOffset(SHOP_STRIP_HEIGHT - 12, SHOP_STRIP_HEIGHT - 12),
								}),
							},
						}),
						Kit.Button(scope, {
							Name = "Buy",
							Variant = "Ghost",
							Text = "",
							Size = UDim2.fromScale(1, 1),
							ZIndex = 2,
							OnClick = function()
								if not peek(isOwned) and not peek(confirming) then
									confirming:set(true)
								end
							end,
						}),
					},
				}),
				Kit.Stack(scope, {
					Name = "Ask",
					Direction = "Horizontal",
					Position = stripPosition,
					Size = strip,
					Visible = scope:Computed(function(use): boolean
						return not use(isOwned) and use(confirming)
					end),
					Children = {
						Kit.Button(scope, {
							Name = "Confirm",
							Variant = "Green",
							Text = "",
							LayoutOrder = 1,
							Size = UDim2.fromOffset(askWidth, SHOP_STRIP_HEIGHT),
							OnClick = function()
								confirming:set(false)
								AppearanceService:BuyAccessory(name):catch(warn)
							end,
							Children = Kit.Image(scope, {
								Image = CONFIRM_ICON,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromOffset(SHOP_STRIP_HEIGHT - 12, SHOP_STRIP_HEIGHT - 12),
								ZIndex = 3,
							}),
						}),
						Kit.Well(scope, {
							Name = "Question",
							LayoutOrder = 2,
							Size = UDim2.fromOffset(SHOP_CELL.X - 2 * askWidth, SHOP_STRIP_HEIGHT),
							Color = ASK_BACK,
							Transparency = 0,
							Children = Kit.Label(scope, {
								Text = "Buy?",
								TextSize = Kit.TextSize.Small,
								Outline = false,
								Size = UDim2.fromScale(1, 1),
							}),
						}),
						Kit.Button(scope, {
							Name = "Decline",
							Variant = "Red",
							Text = "",
							LayoutOrder = 3,
							Size = UDim2.fromOffset(askWidth, SHOP_STRIP_HEIGHT),
							OnClick = function()
								confirming:set(false)
							end,
							Children = Kit.Image(scope, {
								Image = DECLINE_ICON,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromOffset(SHOP_STRIP_HEIGHT - 12, SHOP_STRIP_HEIGHT - 12),
								ZIndex = 3,
							}),
						}),
					},
				}),
				Kit.Well(scope, {
					Name = "Owned",
					Position = stripPosition,
					Size = strip,
					Color = OWNED_BACK,
					Transparency = 0,
					Visible = isOwned,
					Children = Kit.Label(scope, {
						Text = "Owned",
						Color = OWNED_COLOR,
						Size = UDim2.fromScale(1, 1),
					}),
				}),
			},
		})
	end

	local names = {}
	for name in AccessoryConfig.Prices do
		table.insert(names, name)
	end
	table.sort(names)
	local shopCells: { Instance } = {}
	for order, name in names do
		table.insert(shopCells, shopCell(name, order))
	end

	---------------------------------------------------------------------------------
	-- The accessories panel: title, the slots or the shop, the gems.

	local gems = Bind.data(scope, AppearanceConfig.AccessoryCurrency, 0)
	local slotCount = #AccessoryConfig.Slots
	local bodyHeight = slotCount * SLOT_HEIGHT + math.max(slotCount - 1, 0) * SECTION_GAP
	local accessoriesSize = Vector2.new(
		PANEL_WIDTH,
		2 * PANEL_PADDING + TITLE_HEIGHT + bodyHeight + GEMS_HEIGHT + 2 * SECTION_GAP
	)

	local accessories = Kit.Panel(scope, {
		Name = "Accessories",
		Image = Kit.Images.Sheet,
		Size = UDim2.fromOffset(accessoriesSize.X, accessoriesSize.Y),
		Padding = PANEL_PADDING,
		Visible = showing(ACCESSORIES),
		Children = Kit.Stack(scope, {
			Size = UDim2.fromScale(1, 1),
			Gap = SECTION_GAP,
			Children = {
				titleBar(
					scope:Computed(function(use): string
						return if use(shopOpen) then "Accessory Shop" else "Accessory Customize"
					end),
					-- Back from the shop to the slots.
					Kit.Button(scope, {
						Name = "Close",
						Text = "X",
						Variant = "Red",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -Kit.Space.S, 0.5, 0),
						Size = UDim2.fromOffset(TITLE_HEIGHT - 2 * Kit.Space.S, TITLE_HEIGHT - 2 * Kit.Space.S),
						Visible = shopOpen,
						OnClick = function()
							shopOpen:set(false)
						end,
					})
				),
				scope:New("Frame")({
					Name = "Body",
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, bodyHeight),
					[Fusion.Children] = {
						Kit.Stack(scope, {
							Name = "Slots",
							Gap = SECTION_GAP,
							Size = UDim2.fromScale(1, 1),
							Visible = scope:Computed(function(use): boolean
								return not use(shopOpen)
							end),
							Children = slotRows,
						}),
						Kit.Scroll(scope, {
							Name = "Shop",
							CellSize = SHOP_CELL,
							Gap = Kit.Space.S,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Visible = shopOpen,
							Children = shopCells,
						}),
					},
				}),
				Kit.Well(scope, {
					Name = "Gems",
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 0, GEMS_HEIGHT),
					Children = Kit.Stack(scope, {
						Direction = "Horizontal",
						Gap = Kit.Space.S,
						Padding = Kit.Space.S,
						Size = UDim2.fromScale(1, 1),
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Children = {
							Kit.Label(scope, {
								Name = "Amount",
								TextSize = Kit.TextSize.Heading,
								Color = GEMS_COLOR,
								LayoutOrder = 1,
								Text = scope:Computed(function(use): string
									return Bind.formatNumber(tonumber(use(gems)) or 0)
								end),
							}),
							Kit.Image(scope, {
								Image = GEM_ICON,
								LayoutOrder = 2,
								Size = UDim2.fromOffset(GEMS_HEIGHT - 2 * Kit.Space.S, GEMS_HEIGHT - 2 * Kit.Space.S),
							}),
						},
					}),
				}),
			},
		}),
	})
	menu.Side(accessories, accessoriesSize)
	accessories.Parent = menu.Center

	-- What the shell docks: the chooser alone. The two panels are in menu.Center, whose
	-- own closer gives them the gamepad's B.
	local container = scope:New("Frame")({
		Name = "Customize",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(CHOOSER_SIZE.X, CHOOSER_SIZE.Y),
		[Fusion.Children] = { chooser },
	}) :: Frame
	-- The gamepad's B closes the tab from anywhere inside it, as it closes a window.
	Closers.register(scope, container, menu.Close)
	return container
end
