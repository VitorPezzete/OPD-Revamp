--!strict
--[[
	Builds the screen module of a "slot" shop: the old game's merchant windows where a
	flat coloured board holds a row of slots, each a picture that buys the item with its
	name and its price written under it (Shop2, ShopSniper, ShopFlail, ShopDrinks,
	BoatShop, ...).

		return ShopScreen.new({
			Title = "Sword Shop",
			Merchants = { "SwordMerchant" },
			Color = Color3.fromRGB(221, 139, 71),          -- the board
			Border = Color3.fromRGB(255, 226, 0),
			Icon = "rbxassetid://133293265",               -- every slot's picture, or
			Icons = { Dagger = "rbxassetid://..." },       -- one per item
		})

	The window is built with the Kit: the board (named "Window", so the gamepad is given
	the selection when it opens), the title with the player's Beri at its right, a grid of
	uniform cells (picture, name, price, requirement) and the "Walk away to close" line.

	Names and prices are printed from ShopConfig (the old GUIs carried their own copy of
	the prices). A click only sends the merchant and item names; ShopService decides
	everything. A purchase that goes through closes the shop, and so does walking away.

	Variants: by default the whole catalogue is listed. A shop whose list depends on what
	the player owns (the boat shops only show the Galleon to owners of a Sturdy Rod) lists
	its variants; the first one whose conditions hold is shown.

	The helpers (closeOnMove, getMerchantName, buy, priceText, firstButton, focus, Hint,
	Balance) are also used by the legacy merchant screens that are not plain catalogues.
]]
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ShopConfig = require(ReplicatedStorage.Shared.Configs.ShopConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Variant = {
	-- Item names in slot order; nil = the whole catalogue of the merchant.
	Items: { string }?,
	-- Shown only while the player owns / does not own this item (data.Items).
	RequiresItem: string?,
	HiddenWithItem: string?,
}

export type Options = {
	Title: string,
	Merchants: { string },
	-- The flat colour of the board and of its border (each old shop had its own).
	Color: Color3,
	Border: Color3?,
	-- The picture of the slots: one for all, or one per item name.
	Icon: string?,
	Icons: { [string]: string }?,
	-- The tint behind a slot's picture (black by default) and how much of it shows.
	SlotColor: Color3?,
	SlotTransparency: number?,
	-- What the merchant says, in a box at the right of the slots.
	Dialogue: string?,
	Variants: { Variant }?,
}

-- Colours of the old slot labels (Cash) and of a gems price.
local CASH_COLOR = Color3.fromRGB(50, 255, 50)
local GEMS_COLOR = Color3.fromRGB(85, 255, 255)
local DEFAULT_BORDER = Color3.fromRGB(27, 42, 53)
local BOARD_TRANSPARENCY = 0.2
local BORDER_THICKNESS = 3
-- The picture of a slot that sells nothing (disabled catalogue).
local DISABLED_TRANSPARENCY = 0.6

local PADDING = Kit.Space.XL
local HEADER_HEIGHT = 56
local HINT_HEIGHT = 24
-- The old board was half of a 1920x1080 screen wide.
local MIN_WIDTH = 960
local MAX_COLUMNS = 5
local CELL_WIDTH = 208
local NAME_HEIGHT = 32
local PRICE_HEIGHT = 30
local REQUIREMENT_HEIGHT = 22
local CELL_GAP = Kit.Space.L
local BALANCE_WIDTH = 240

local DEFAULT_VARIANTS: { Variant } = { {} }

local ShopScreen = {}

ShopScreen.HINT = "Walk away to close"
ShopScreen.DISABLED_HINT = "Nothing is for sale right now. Walk away to close"
ShopScreen.HINT_HEIGHT = HINT_HEIGHT
ShopScreen.CASH_COLOR = CASH_COLOR
ShopScreen.GEMS_COLOR = GEMS_COLOR

-- Merchant windows have no close button: walking away (or dying) closes them.
function ShopScreen.closeOnMove(scope: Scope, context: any)
	MerchantDialogue.closeOnMove(scope, function()
		context.Close()
	end)
end

-- The merchant model that opened the screen, or the screen's first merchant.
function ShopScreen.getMerchantName(context: any, merchants: { string }): string
	local args = context.Args
	local merchant = if type(args) == "table" then args.Merchant else nil
	if typeof(merchant) == "Instance" and ShopConfig.Merchants[merchant.Name] then
		return merchant.Name
	end
	return merchants[1]
end

-- Sends the purchase; `onDone(success)` runs when the server has answered.
function ShopScreen.buy(merchantName: string, itemName: string, onDone: ((success: boolean) -> ())?)
	Knit.GetService("ShopService")
		:Buy(merchantName, itemName)
		:andThen(function(success: boolean)
			if onDone then
				onDone(success == true)
			end
		end)
		:catch(function(problem: any)
			warn(`[Shop] purchase failed: {problem}`)
			if onDone then
				onDone(false)
			end
		end)
end

-- "1.000" / "100 Gems", and the colour of that currency. Beri prices stay bare numbers,
-- as the Cash labels of the old shops were.
function ShopScreen.priceText(price: number, currency: string?): (string, Color3)
	if currency == "Gems" then
		return `{Bind.formatNumber(price)} Gems`, GEMS_COLOR
	end
	return Bind.formatNumber(price), CASH_COLOR
end

-- Whether the object and every GuiObject between it and `root` (included) are visible.
local function isShown(object: Instance, root: Instance): boolean
	local current: Instance? = object
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current == root then
			break
		end
		current = current.Parent
	end
	return true
end

-- Top-most, then left-most button that can be selected inside `root`.
function ShopScreen.firstButton(root: Instance): GuiButton?
	local best: GuiButton? = nil
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") and descendant.Selectable and isShown(descendant, root) then
			if not best then
				best = descendant
			else
				local a, b = descendant.AbsolutePosition, best.AbsolutePosition
				if a.Y < b.Y - 1 or (math.abs(a.Y - b.Y) <= 1 and a.X < b.X) then
					best = descendant
				end
			end
		end
	end
	return best
end

--[[
	Gives the gamepad selection to the first button of `root` while the gamepad is in use.
	NavigationController does it when a screen holding a "Window" opens; a screen calls
	this after it swapped the page it shows (the selection would be left on a button that
	is no longer there), or when it has no window at all.
]]
function ShopScreen.focus(scope: Scope, root: Instance)
	local InputController = Knit.GetController("InputController")
	if not InputController:IsUsingGamepad() then
		return
	end
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		-- The gui is parented after Mount returns and laid out on the next frame.
		RunService.Heartbeat:Wait()
		if not alive or not root:IsDescendantOf(game) or not InputController:IsUsingGamepad() then
			return
		end
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(root) and isShown(selected, root) then
			return
		end
		local button = ShopScreen.firstButton(root)
		if button then
			GuiService.SelectedObject = button
		end
	end)
end

-- The "Walk away to close" line of every merchant window: a row for the bottom of it.
function ShopScreen.Hint(scope: Scope, props: (Kit.Layout & { Text: Fusion.UsedAs<string>? })?): TextLabel
	local given: any = props or {}
	return Kit.Label(scope, {
		Name = given.Name or "Hint",
		Text = given.Text or ShopScreen.HINT,
		TextSize = Kit.TextSize.Small,
		Fit = true,
		Size = given.Size or UDim2.new(1, 0, 0, HINT_HEIGHT),
		Position = given.Position,
		AnchorPoint = given.AnchorPoint,
		LayoutOrder = given.LayoutOrder,
		Visible = given.Visible,
		ZIndex = given.ZIndex,
	})
end

-- The player's Beri, written the way the old Cash labels were.
function ShopScreen.Balance(scope: Scope, props: Kit.Layout?): TextLabel
	local given: any = props or {}
	local beri = Bind.data(scope, "Economy.Beri", 0)
	return Kit.Label(scope, {
		Name = given.Name or "Balance",
		Text = scope:Computed(function(use): string
			return `$ {Bind.formatNumber(tonumber(use(beri)) or 0)}`
		end),
		Color = CASH_COLOR,
		TextSize = Kit.TextSize.Body,
		Fit = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = given.Size or UDim2.fromOffset(BALANCE_WIDTH, 32),
		Position = given.Position,
		AnchorPoint = given.AnchorPoint,
		LayoutOrder = given.LayoutOrder,
		Visible = given.Visible,
		ZIndex = given.ZIndex,
	})
end

-- The same two, hung on a frame that was built elsewhere: the hint right under it, the
-- balance in its top right corner.
function ShopScreen.addHint(scope: Scope, frame: GuiObject, text: string?): TextLabel
	local hint = ShopScreen.Hint(scope, {
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		ZIndex = frame.ZIndex + 1,
	})
	hint.Parent = frame
	return hint
end

function ShopScreen.addBalance(scope: Scope, frame: GuiObject): TextLabel
	local balance = ShopScreen.Balance(scope, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Kit.Space.M, 0, Kit.Space.S),
		ZIndex = frame.ZIndex + 1,
	})
	balance.Parent = frame
	return balance
end

--[[
	The board of a merchant window: a flat colour with a border, named "Window". The old
	shops were not parchments but plain coloured frames, each merchant its own colour.
]]
function ShopScreen.Board(
	scope: Scope,
	props: Kit.Layout & {
		Color: Color3,
		Border: Color3?,
		-- 0.2 by default: the world showed through the old shops.
		Transparency: number?,
		Padding: number?,
		Children: Fusion.Child?,
	}
): ImageLabel
	return Kit.Panel(scope, {
		Name = props.Name or "Window",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size,
		Visible = props.Visible,
		ZIndex = props.ZIndex,
		Image = "",
		Color = props.Color,
		Transparency = props.Transparency or BOARD_TRANSPARENCY,
		Padding = props.Padding or PADDING,
		Children = {
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Miter,
				Color = props.Border or DEFAULT_BORDER,
				Thickness = BORDER_THICKNESS,
			}),
			props.Children,
		} :: { any },
	})
end

local function requirementText(item: ShopConfig.Item): string?
	if item.Requirement then
		return `Requires {item.Requirement.Skill} level {item.Requirement.Level}`
	elseif item.RequiresItem then
		return `Requires {item.RequiresItem}`
	end
	return nil
end

local function catalogueNames(merchantName: string): { string }
	local names = {}
	local catalogue = ShopConfig.Merchants[merchantName]
	for _, item in if catalogue then catalogue.Items else {} do
		table.insert(names, item.Name)
	end
	return names
end

function ShopScreen.new(options: Options)
	return {
		Merchants = options.Merchants,

		Mount = function(scope: Scope, _gui: any, context: any): ScreenGui
			local merchantName = ShopScreen.getMerchantName(context, options.Merchants)
			local catalogue = ShopConfig.Merchants[merchantName]
			-- The server refuses a disabled catalogue anyway; the slots only say so.
			local disabled = catalogue ~= nil and catalogue.Disabled == true
			local ownedItems = Bind.data(scope, "Items", {})
			local busy = false
			local closed = false
			table.insert(scope, function()
				closed = true
			end)

			local function buy(itemName: string)
				if busy or disabled then
					return
				end
				busy = true
				ShopScreen.buy(merchantName, itemName, function(success: boolean)
					if closed then
						return
					end
					busy = false
					if success then
						context.Close()
					end
				end)
			end

			local variants = options.Variants or DEFAULT_VARIANTS
			local allNames = catalogueNames(merchantName)

			-- The items of the first variant whose conditions hold.
			local shownNames = scope:Computed(function(use): { string }
				local owned = use(ownedItems)
				if type(owned) ~= "table" then
					owned = {}
				end
				for _, variant in variants do
					if variant.RequiresItem and owned[variant.RequiresItem] ~= true then
						continue
					end
					if variant.HiddenWithItem and owned[variant.HiddenWithItem] == true then
						continue
					end
					return variant.Items or allNames
				end
				return {}
			end)

			-- The window is sized once, for the longest list it can show: it would jump
			-- under the player's cursor otherwise.
			local mostItems = 1
			for _, variant in variants do
				mostItems = math.max(mostItems, #(variant.Items or allNames))
			end
			local hasRequirement = false
			for _, item in if catalogue then catalogue.Items else {} do
				if requirementText(item) then
					hasRequirement = true
				end
			end

			local columns = math.min(mostItems, MAX_COLUMNS)
			local rows = math.ceil(mostItems / columns)
			local cellHeight = CELL_WIDTH
				+ Kit.Space.XS
				+ NAME_HEIGHT
				+ PRICE_HEIGHT
				+ (if hasRequirement then REQUIREMENT_HEIGHT else 0)
			local gridWidth = columns * CELL_WIDTH + (columns - 1) * CELL_GAP
			local gridHeight = rows * cellHeight + (rows - 1) * CELL_GAP
			local innerWidth = math.max(MIN_WIDTH - 2 * PADDING, gridWidth)
			-- A merchant's line takes what the slots leave; it is dropped when they leave nothing.
			local dialogueWidth = innerWidth - gridWidth - CELL_GAP
			local dialogue = if options.Dialogue and dialogueWidth >= CELL_WIDTH then options.Dialogue else nil

			local function cell(cellScope: Scope, index: number, itemName: string): Instance?
				local item = ShopConfig.Find(merchantName, itemName)
				if not item then
					return nil
				end
				local priceText, priceColor = ShopScreen.priceText(item.Price, item.Currency)
				local icon = (options.Icons and options.Icons[item.Name]) or options.Icon or ""
				return Kit.Stack(cellScope, {
					Name = item.Name,
					LayoutOrder = index,
					Size = UDim2.fromOffset(CELL_WIDTH, cellHeight),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Children = {
						Kit.Well(cellScope, {
							Name = "Slot",
							LayoutOrder = 1,
							Size = UDim2.fromOffset(CELL_WIDTH, CELL_WIDTH),
							Color = options.SlotColor,
							Transparency = options.SlotTransparency or 0.2,
							Children = {
								Kit.Button(cellScope, {
									Name = "Buy",
									Variant = "Ghost",
									Size = UDim2.fromScale(1, 1),
									Disabled = disabled,
									OnClick = function()
										buy(item.Name)
									end,
									Children = {
										Kit.Image(cellScope, {
											Name = "Icon",
											Image = icon,
											Size = UDim2.fromScale(1, 1),
											Transparency = if disabled then DISABLED_TRANSPARENCY else 0,
										}),
									},
								}),
							},
						}),
						-- A breath between the picture and the name.
						cellScope:New("Frame")({
							Name = "Gap",
							LayoutOrder = 2,
							BackgroundTransparency = 1,
							Size = UDim2.new(1, 0, 0, Kit.Space.XS),
						}),
						Kit.Label(cellScope, {
							Name = "Label",
							LayoutOrder = 3,
							Text = item.Name,
							TextSize = Kit.TextSize.Body,
							Fit = true,
							Size = UDim2.new(1, 0, 0, NAME_HEIGHT),
						}),
						Kit.Label(cellScope, {
							Name = "Cash",
							LayoutOrder = 4,
							Text = priceText,
							Color = priceColor,
							TextSize = Kit.TextSize.Body,
							Fit = true,
							Size = UDim2.new(1, 0, 0, PRICE_HEIGHT),
						}),
						if hasRequirement
							then Kit.Label(cellScope, {
								Name = "Requirement",
								LayoutOrder = 5,
								Text = requirementText(item) or "",
								Color = Kit.Colors.Gold,
								TextSize = Kit.TextSize.Tiny,
								Fit = true,
								Size = UDim2.new(1, 0, 0, REQUIREMENT_HEIGHT),
							})
							else nil,
					} :: { any },
				})
			end

			local grid = scope:New("Frame")({
				Name = "Slots",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(gridWidth, gridHeight),
				[Fusion.Children] = {
					scope:New("UIGridLayout")({
						CellSize = UDim2.fromOffset(CELL_WIDTH, cellHeight),
						CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
						FillDirectionMaxCells = columns,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					scope:ForPairs(shownNames, function(_, cellScope: Scope, index: number, itemName: string)
						return index, cell(cellScope, index, itemName)
					end),
				} :: { any },
			})

			local window = ShopScreen.Board(scope, {
				Color = options.Color,
				Border = options.Border,
				Size = UDim2.fromOffset(
					innerWidth + 2 * PADDING,
					2 * PADDING + HEADER_HEIGHT + gridHeight + Kit.Space.M + HINT_HEIGHT
				),
				Children = {
					Kit.Label(scope, {
						Name = "Shop",
						Text = options.Title,
						TextSize = Kit.TextSize.Title,
						Fit = true,
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.fromScale(0.5, 0),
						Size = UDim2.new(1, -2 * (BALANCE_WIDTH + Kit.Space.M), 0, HEADER_HEIGHT - Kit.Space.M),
					}),
					ShopScreen.Balance(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(BALANCE_WIDTH, HEADER_HEIGHT - Kit.Space.M),
					}),
					Kit.Stack(scope, {
						Name = "Content",
						Direction = "Horizontal",
						Gap = CELL_GAP,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Position = UDim2.fromOffset(0, HEADER_HEIGHT),
						Size = UDim2.new(1, 0, 0, gridHeight),
						Children = {
							grid,
							if dialogue
								then Kit.Well(scope, {
									Name = "Dia",
									LayoutOrder = 2,
									-- As tall as the pictures, so the box lines up with the slot beside it.
									Size = UDim2.fromOffset(dialogueWidth, CELL_WIDTH),
									Color = Kit.Colors.Box,
									Transparency = 0.6,
									Padding = Kit.Space.L,
									Children = {
										Kit.Label(scope, {
											Text = dialogue,
											TextSize = Kit.TextSize.Heading,
											Fit = true,
											Size = UDim2.fromScale(1, 1),
										}),
									},
								})
								else nil,
						} :: { any },
					}),
					ShopScreen.Hint(scope, {
						Text = if disabled then ShopScreen.DISABLED_HINT else nil,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
					}),
				},
			})

			ShopScreen.closeOnMove(scope, context)

			return Kit.Screen(scope, {
				Name = context.Name,
				Children = { window },
			})
		end,
	}
end

return ShopScreen
