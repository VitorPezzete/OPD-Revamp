--!strict
--[[
	Menu tab "Customize": two pages.

	Clothes       one row per category with a stepper for the style and, where the
	              category is coloured, one for the palette index (with its swatch); the
	              skin dye row.
	Accessories   six slots (D-F need a game pass), each with its colour stepper; clicking
	              a slot opens the accessory picker, where an owned accessory is equipped
	              into that slot and the others are bought with gems (confirmed in place).
	              Accessories are shown as turning 3D previews (ModelPreview); in the
	              picker only the hovered card turns. An accessory without a model keeps
	              its flat icon.

	There is no preview of the character: every change is applied to the real character by
	the server and the tab only mirrors the saved values. The client sends field names, slot letters and
	accessory names; prices, ownership and the game passes are the server's business.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local AccessoryConfig = require(ReplicatedStorage.Shared.Configs.AccessoryConfig)
local AppearanceAssets = require(ReplicatedStorage.Shared.Util.AppearanceAssets)
local AppearanceConfig = require(ReplicatedStorage.Shared.Configs.AppearanceConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local ModelPreview = require(ReplicatedStorage.Client.UI.Components.ModelPreview)

local Kit = require(script.Parent.Kit)

type Scope = Theme.Scope

local peek = Fusion.peek

local CLOTHES = "Clothes"
local ACCESSORIES = "Accessories"

-- Narrow, so that the character in the middle of the screen stays in view while it is edited.
local WINDOW_SIZE = Vector2.new(540, 660)
local TABS_HEIGHT = 40
local SLOT_COLUMNS = 3
local SHOP_CELL = Vector2.new(124, 156)

-- Rows of the clothes page, in order. "Dye" is the skin dye row.
local ROWS: { { Field: string, Label: string } } = {
	{ Field = "Hair", Label = "Hair" },
	{ Field = "Torso", Label = "Torso" },
	{ Field = "Arms", Label = "Arms" },
	{ Field = "Pants", Label = "Legs" },
	{ Field = "Face", Label = "Face" },
	{ Field = "SkinColor", Label = "Skin" },
	{ Field = "Dye", Label = "Skin dye" },
	{ Field = "Gloves", Label = "Hands" },
	{ Field = "Feet", Label = "Feet" },
}

local function wrap(value: number, delta: number, limit: number): number
	return (value - 1 + delta) % limit + 1
end

local function paletteColor(index: any): Color3
	return (if type(index) == "number" then AppearanceAssets.GetColor(index) else nil) or Theme.Colors.Sunken
end

local function skinColor(index: any): Color3
	return (if type(index) == "number" then AppearanceAssets.GetSkin(index) else nil) or Theme.Colors.Sunken
end

-- The accessory to preview in 3D; nil when there is nothing to draw (the card keeps its icon).
local function accessoryModel(name: string): Instance?
	if name == "" then
		return nil
	end
	local extra = AppearanceAssets.GetExtra(name)
	if extra and (extra:IsA("BasePart") or extra:FindFirstChildWhichIsA("BasePart", true)) then
		return extra
	end
	return nil
end

-- Icon of an accessory, only when it has no model to preview.
local function accessoryIcon(name: string, model: Instance?): string
	if name == "" or model then
		return ""
	end
	return AppearanceAssets.GetExtraIcon(name) or ""
end

return function(scope: Scope, _context: any, menu: any): Instance
	local AppearanceService = Knit.GetService("AppearanceService")
	local MonetizationService = Knit.GetService("MonetizationService")

	local page = scope:Value(CLOTHES)
	-- Slot being filled, and whether the accessory picker covers the slots.
	local selectedSlot = scope:Value("A")
	local shopOpen = scope:Value(false)
	local gems = Bind.data(scope, AppearanceConfig.AccessoryCurrency, 0)

	-- The slot passes are Robux products: MonetizationService decides what is prompted
	-- (same entry point as the "Buy slot" buttons of the shop tab).
	local function promptSlotPass(pass: string)
		Kit.send(MonetizationService:Prompt(pass))
	end

	---------------------------------------------------------------------------------
	-- Clothes

	local function fieldStepper(pageScope: Scope, field: string, caption: string, order: number, swatch: ((index: any) -> Color3)?)
		local limit = AppearanceConfig.GetLimit(field)
		if not limit then
			return nil
		end
		local value = Bind.data(pageScope, "Appearance." .. field, 1)

		return UI.Stack(pageScope, {
			Name = field,
			Direction = "Horizontal",
			Gap = Theme.Space.S,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			LayoutOrder = order,
			Children = {
				UI.Label(pageScope, { Text = caption, Variant = "Tiny", LayoutOrder = 1 }),
				Kit.Stepper(pageScope, {
					LayoutOrder = 2,
					Text = pageScope:Computed(function(use): string
						return tostring(use(value))
					end),
					OnStep = function(delta: number)
						local current = peek(value)
						if type(current) == "number" then
							AppearanceService.Change:Fire(field, wrap(current, delta, limit))
						end
					end,
					Children = if swatch
						then Kit.Swatch(
							pageScope,
							pageScope:Computed(function(use): Color3
								return swatch(use(value))
							end),
							3
						)
						else nil,
				}),
			},
		})
	end

	-- The dye row shows the owned dye; the button wears it (picking a skin tone in the row
	-- above takes it off again).
	local function dyeRow(pageScope: Scope, order: number): Instance
		local dye = Bind.data(pageScope, "Appearance.SkinDye", "")
		local dyeName = pageScope:Computed(function(use): string
			return tostring(use(dye) or "")
		end)

		return Kit.Row(pageScope, {
			Label = "Skin dye",
			LayoutOrder = order,
			Hint = pageScope:Computed(function(use): string
				local name = use(dyeName)
				return if name ~= "" then name else "None owned"
			end),
			Children = {
				Kit.Swatch(
					pageScope,
					pageScope:Computed(function(use): Color3
						local name = use(dyeName)
						return (if name ~= "" then AppearanceAssets.GetDye(name) else nil) or Theme.Colors.Sunken
					end),
					1
				),
				UI.Button(pageScope, {
					Name = "UseDye",
					Text = "Wear dye",
					Variant = "Secondary",
					TextSize = Theme.TextSize.Small,
					Size = UDim2.fromOffset(120, 32),
					LayoutOrder = 2,
					OnClick = function()
						AppearanceService.UseSkinDye:Fire()
					end,
				}),
			},
		})
	end

	local function clothesPage(pageScope: Scope): Instance
		local rows: { Instance } = {}
		for order, row in ROWS do
			if row.Field == "Dye" then
				table.insert(rows, dyeRow(pageScope, order))
				continue
			end

			local category = AppearanceConfig.Categories[row.Field]
			table.insert(
				rows,
				Kit.Row(pageScope, {
					Label = row.Label,
					LayoutOrder = order,
					Height = 48,
					Children = {
						fieldStepper(pageScope, row.Field, "Style", 1, if row.Field == "SkinColor" then skinColor else nil),
						if category and category.Colored
							then fieldStepper(pageScope, row.Field .. "_Color", "Color", 2, paletteColor)
							else nil,
					} :: { any },
				})
			)
		end

		return UI.Scroll(pageScope, { Name = "Clothes", Children = rows })
	end

	---------------------------------------------------------------------------------
	-- Accessory slots

	local function slotPanel(pageScope: Scope, slot: string, order: number): Instance
		local equipped = Bind.data(pageScope, `Appearance.ExtraSlots.{slot}`, "")
		local colorIndex = Bind.data(pageScope, `Appearance.ExtraSlots.{slot}_Color`, 1)
		local pass = AppearanceConfig.PremiumSlots[slot]
		local unlocked = if pass then Bind.data(pageScope, "GamePasses." .. pass, false) else pageScope:Value(true)

		local equippedName = pageScope:Computed(function(use): string
			local name = use(equipped)
			return if type(name) == "string" then name else ""
		end)
		local locked = pageScope:Computed(function(use): boolean
			return use(unlocked) ~= true
		end)
		local equippedModel = pageScope:Computed(function(use): Instance?
			return accessoryModel(use(equippedName))
		end)

		return UI.Panel(pageScope, {
			Name = "Slot" .. slot,
			LayoutOrder = order,
			Padding = Theme.Space.M,
			Children = {
				UI.Label(pageScope, {
					Name = "SlotName",
					Text = "Slot " .. slot,
					Variant = "Heading",
					Color = Theme.Colors.Accent,
					Size = UDim2.new(1, 0, 0, 26),
				}),
				UI.Card(pageScope, {
					Name = "Accessory",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 34),
					Size = UDim2.fromOffset(132, 140),
					Title = pageScope:Computed(function(use): string
						local name = use(equippedName)
						return if name ~= "" then name else "Empty"
					end),
					Image = pageScope:Computed(function(use): string
						return accessoryIcon(use(equippedName), use(equippedModel))
					end),
					OnClick = function()
						if pass and peek(unlocked) ~= true then
							promptSlotPass(pass)
							return
						end
						selectedSlot:set(slot)
						shopOpen:set(true)
					end,
					-- The six slots turn slowly; the "+" of an empty slot sits over the well.
					Children = {
						ModelPreview(pageScope, {
							Name = "Preview",
							Source = equippedModel,
							ZIndex = 1,
						}),
						UI.Label(pageScope, {
							Name = "Plus",
							Text = "+",
							Variant = "Display",
							Color = Theme.Colors.TextDim,
							Size = UDim2.fromScale(1, 1),
							ZIndex = 2,
							Visible = pageScope:Computed(function(use): boolean
								return use(equippedName) == ""
							end),
						}),
					},
				}),
				-- Takes off what the slot wears (it stays owned).
				UI.Button(pageScope, {
					Name = "Remove",
					Text = "X",
					Variant = "Ghost",
					TextSize = Theme.TextSize.Small,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(26, 26),
					ZIndex = 4,
					Visible = pageScope:Computed(function(use): boolean
						return use(equippedName) ~= "" and not use(locked)
					end),
					OnClick = function()
						AppearanceService.RemoveAccessory:Fire(slot)
					end,
				}),
				pageScope:New("Frame")({
					Name = "Color",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.5, 1),
					Size = UDim2.new(1, 0, 0, 34),
					[Fusion.Children] = {
						pageScope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Kit.Stepper(pageScope, {
							Text = pageScope:Computed(function(use): string
								return tostring(use(colorIndex))
							end),
							OnStep = function(delta: number)
								local current = peek(colorIndex)
								if peek(equippedName) ~= "" and type(current) == "number" then
									AppearanceService.SetAccessoryColor:Fire(
										slot,
										wrap(current, delta, AppearanceConfig.ColorCount)
									)
								end
							end,
							Children = Kit.Swatch(
								pageScope,
								pageScope:Computed(function(use): Color3
									return paletteColor(use(colorIndex))
								end),
								3
							),
						}),
					},
				}),
				if pass
					then UI.Panel(pageScope, {
						Name = "Locked",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 34),
						Size = UDim2.fromOffset(132, 140),
						Color = Theme.Colors.Sunken,
						Transparency = 0.15,
						ZIndex = 5,
						Visible = locked,
						Children = {
							UI.Label(pageScope, {
								Text = "Game pass",
								Variant = "Small",
								AnchorPoint = Vector2.new(0.5, 0),
								Position = UDim2.new(0.5, 0, 0, Theme.Space.L),
								ZIndex = 6,
							}),
							UI.Button(pageScope, {
								Name = "Buy",
								Text = "Unlock",
								TextSize = Theme.TextSize.Small,
								AnchorPoint = Vector2.new(0.5, 1),
								Position = UDim2.new(0.5, 0, 1, -Theme.Space.M),
								Size = UDim2.fromOffset(104, 34),
								ZIndex = 6,
								OnClick = function()
									promptSlotPass(pass)
								end,
							}),
						},
					})
					else nil,
			} :: { any },
		})
	end

	local function slotsPage(pageScope: Scope): Instance
		local panels: { any } = {}
		for order, slot in AccessoryConfig.Slots do
			table.insert(panels, slotPanel(pageScope, slot, order))
		end

		local gap = Theme.Space.M
		return pageScope:New("Frame")({
			Name = "Slots",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			[Fusion.Children] = {
				pageScope:New("UIGridLayout")({
					CellSize = UDim2.new(1 / SLOT_COLUMNS, -gap, 0, 244),
					CellPadding = UDim2.fromOffset(gap, gap),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				panels,
			} :: { any },
		})
	end

	---------------------------------------------------------------------------------
	-- Accessory picker: one card per purchasable accessory.

	local function shopPage(pageScope: Scope): Instance
		local owned = Bind.data(pageScope, "Appearance.OwnedAccessories", {})
		-- Accessory waiting for its purchase to be confirmed.
		local confirming: Fusion.Value<string?> = pageScope:Value(nil :: string?)

		local names: { string } = {}
		for name in AccessoryConfig.Prices do
			table.insert(names, name)
		end
		table.sort(names)

		local cards: { Instance } = {}
		for order, name in names do
			local isOwned = pageScope:Computed(function(use): boolean
				local set = use(owned)
				return type(set) == "table" and set[name] == true
			end)
			local asking = pageScope:Computed(function(use): boolean
				return use(confirming) == name and not use(isOwned)
			end)
			-- Dozens of cards: only the one under the mouse turns.
			local hovered = pageScope:Value(false)
			local model = accessoryModel(name)

			table.insert(
				cards,
				UI.Card(pageScope, {
					Name = name,
					LayoutOrder = order,
					Title = name,
					Caption = pageScope:Computed(function(use): string
						return if use(isOwned)
							then "Owned"
							else `{Bind.formatNumber(AccessoryConfig.Prices[name])} gems`
					end),
					CaptionColor = pageScope:Computed(function(use): Color3
						return if use(isOwned) then Theme.Colors.Success else Theme.Colors.Gems
					end),
					Image = accessoryIcon(name, model),
					Selected = asking,
					OnClick = function()
						if peek(isOwned) then
							AppearanceService.EquipAccessory:Fire(peek(selectedSlot), name)
							shopOpen:set(false)
						else
							confirming:set(if peek(confirming) == name then nil else name)
						end
					end,
					OnHover = function(hovering: boolean)
						hovered:set(hovering)
					end,
					Children = {
						if model
							then ModelPreview(pageScope, {
								Name = "Preview",
								Source = model,
								Spin = hovered,
								ZIndex = 1,
							})
							else nil,
						-- Buying is confirmed in place, over the picture.
						pageScope:New("Frame")({
							Name = "Confirm",
							BackgroundColor3 = Theme.Colors.Sunken,
							BackgroundTransparency = 0.2,
							Size = UDim2.fromScale(1, 1),
							ZIndex = 2,
							Visible = asking,
							[Fusion.Children] = {
								pageScope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Small) }),
								UI.Button(pageScope, {
									Name = "Confirm",
									Text = "Buy",
									Variant = "Success",
									TextSize = Theme.TextSize.Small,
									AnchorPoint = Vector2.new(0.5, 0),
									Position = UDim2.new(0.5, 0, 0, Theme.Space.S),
									Size = UDim2.new(1, -Theme.Space.S * 2, 0.5, -Theme.Space.S * 1.5),
									OnClick = function()
										confirming:set(nil)
										Kit.send(AppearanceService:BuyAccessory(name))
									end,
								}),
								UI.Button(pageScope, {
									Name = "Decline",
									Text = "Cancel",
									Variant = "Secondary",
									TextSize = Theme.TextSize.Small,
									AnchorPoint = Vector2.new(0.5, 1),
									Position = UDim2.new(0.5, 0, 1, -Theme.Space.S),
									Size = UDim2.new(1, -Theme.Space.S * 2, 0.5, -Theme.Space.S * 1.5),
									OnClick = function()
										confirming:set(nil)
									end,
								}),
							},
						}),
					} :: { any },
				})
			)
		end

		local barHeight = 40
		return pageScope:New("Frame")({
			Name = "AccessoryShop",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			[Fusion.Children] = {
				UI.Button(pageScope, {
					Name = "Close",
					Text = "Back",
					Variant = "Secondary",
					TextSize = Theme.TextSize.Small,
					Size = UDim2.fromOffset(96, barHeight - 4),
					OnClick = function()
						shopOpen:set(false)
					end,
				}),
				UI.Label(pageScope, {
					Name = "Title",
					Text = pageScope:Computed(function(use): string
						return `Accessory for slot {use(selectedSlot)}: click an owned one to wear it`
					end),
					Variant = "Muted",
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(96 + Theme.Space.M, 0),
					Size = UDim2.new(1, -(96 + Theme.Space.M), 0, barHeight - 4),
				}),
				UI.Scroll(pageScope, {
					Name = "List",
					Position = UDim2.fromOffset(0, barHeight + Theme.Space.S),
					Size = UDim2.new(1, 0, 1, -(barHeight + Theme.Space.S)),
					CellSize = SHOP_CELL,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Children = cards,
				}),
			},
		})
	end

	---------------------------------------------------------------------------------

	local content = scope:Computed(function(use, pageScope: Scope): Instance
		if use(page) == CLOTHES then
			return clothesPage(pageScope)
		elseif use(shopOpen) then
			return shopPage(pageScope)
		end
		return slotsPage(pageScope)
	end)

	return UI.Window(scope, {
		Name = "Customize",
		Title = "Customize",
		Subtitle = scope:Computed(function(use): string
			return `{Bind.formatNumber(tonumber(use(gems)) or 0)} gems`
		end),
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		AnchorPoint = Kit.WindowAnchor,
		Position = Kit.WindowPosition,
		OnClose = menu.Close,
		Children = {
			UI.Tabs(scope, {
				Tabs = { { Key = CLOTHES, Text = "Clothes" }, { Key = ACCESSORIES, Text = "Accessories" } },
				Selected = page,
				TabSize = UDim2.fromOffset(160, TABS_HEIGHT),
				-- Changing page folds the picker, so Accessories reopens on the slots.
				OnSelect = function()
					shopOpen:set(false)
				end,
			}),
			scope:New("Frame")({
				Name = "Page",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, TABS_HEIGHT + Theme.Space.M),
				Size = UDim2.new(1, 0, 1, -(TABS_HEIGHT + Theme.Space.M)),
				[Fusion.Children] = content,
			}),
		},
	})
end
