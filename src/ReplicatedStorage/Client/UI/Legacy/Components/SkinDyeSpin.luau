--!strict
--[[
	The skin dye roulette, shared by the two shops (SkinDyeShop: Beri, common colours, the
	blue board; SkinDyeShopAll: gems, every colour, the red board). Returns a screen
	definition for UIController.

	The old window, rebuilt with the Kit: a flat board with its title bar and close
	picture, the strip of colours between two arrows, the spin button under it (Accept and
	Decline take its place while a result waits) and the balance at the bottom. The colour
	that was rolled is shown on the round panel over the strip.

	A strip of seven cells slides left one cell at a time; the cell that left the window
	is recycled at the far end with a new random colour. While idle it crawls. A paid spin
	runs SPIN_STEPS steps, slowing down, and the cell recycled at WINNER_STEP - the one
	that ends under the arrows - gets the colour the server rolled.

	The server has already charged and stored the result when the roulette starts; the
	animation is only the reveal. Closing the shop mid-roulette loses nothing: the next
	time it opens, the pending result is offered again.

	The legacy twin of UI.Components.SkinDyeRoulette: same requests, same states. The
	price on the spin button and the balance are written from AppearanceConfig and the
	profile.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local AppearanceConfig = require(ReplicatedStorage.Shared.Configs.AppearanceConfig)
local AppearanceAssets = require(ReplicatedStorage.Shared.Util.AppearanceAssets)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local ShopScreen = require(script.Parent.ShopScreen)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Options = {
	Rare: boolean,
}

local CELL_COUNT = 7
local SHOWN_CELLS = 5
local IDLE_STEP_SECONDS = 0.5
local SPIN_STEPS = 70
local WINNER_STEP = 66
-- { last step using this duration, seconds per step }
local SPIN_PACE = { { 40, 0.075 }, { 50, 0.2 }, { 60, 0.45 }, { SPIN_STEPS, 1 } }

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(27, 42, 53)
local STRIP_COLOR = Color3.fromRGB(63, 75, 90)
local GEMS_COLOR = Color3.fromRGB(0, 255, 255)
local CASH_COLOR = Color3.fromRGB(0, 255, 0)

local CLOSE_IMAGE = "rbxassetid://1954825535"
local ARROW_DOWN = "rbxassetid://3274907844"
local ARROW_UP = "rbxassetid://3274907966"
local GEM_IMAGE = "rbxassetid://1954296071"
local ROUND_IMAGE = "rbxassetid://3277364109"

local LOOKS = {
	Common = {
		Title = "Skin Dye Shop",
		Board = Color3.fromRGB(157, 188, 255),
		Header = Color3.fromRGB(91, 135, 238),
	},
	Rare = {
		Title = "Rare Skin Dye Shop",
		Board = Color3.fromRGB(255, 138, 138),
		Header = Color3.fromRGB(189, 52, 52),
	},
}

-- Design pixels. The old board was half the screen wide and a fifth of it tall.
local WIDTH = 960
local HEADER_HEIGHT = 56
local CELL = 150
local ARROW = 32
local STRIP_BORDER = 5
local BUTTON_HEIGHT = 52
local BALANCE_HEIGHT = 30
local STRIP_Y = HEADER_HEIGHT + Kit.Space.M + ARROW + Kit.Space.XS
local BUTTONS_Y = STRIP_Y + CELL + Kit.Space.XS + ARROW + Kit.Space.M
local BALANCE_Y = BUTTONS_Y + BUTTON_HEIGHT + Kit.Space.S
local HEIGHT = BALANCE_Y + BALANCE_HEIGHT + Kit.Space.M
-- The round panel covers the strip and its arrows, and stops short of the buttons.
local DISPLAY = CELL + 2 * (ARROW + Kit.Space.XS) + Kit.Space.M

local function getStepSeconds(step: number): number
	for _, pace in SPIN_PACE do
		if step <= pace[1] then
			return pace[2]
		end
	end
	return 1
end

local function mount(options: Options, scope: Scope, context: any): ScreenGui
	local AppearanceService = Knit.GetService("AppearanceService")
	local tier = if options.Rare then AppearanceConfig.SkinDye.Rare else AppearanceConfig.SkinDye.Common
	local look = if options.Rare then LOOKS.Rare else LOOKS.Common
	local dyeNames = AppearanceAssets.GetDyeNames(tier.Pool)

	local balance = Bind.data(scope, tier.Currency, 0)
	local busy = scope:Value(false)
	local result: Fusion.Value<string?> = scope:Value(nil :: string?)

	-- Every run of the strip (idle crawl or spin) holds the token it started with and
	-- stops as soon as another run, or the closing screen, takes it.
	local token = 0
	local tween: Tween? = nil
	local closed = false

	local cellColors: { Fusion.Value<Color3> } = table.create(CELL_COUNT)
	local cellNames: { Fusion.Value<string> } = table.create(CELL_COUNT)
	local cells: { Frame } = table.create(CELL_COUNT)
	for index = 1, CELL_COUNT do
		cellColors[index] = scope:Value(WHITE)
		cellNames[index] = scope:Value("")
		cells[index] = scope:New("Frame")({
			Name = `Frame{index}`,
			BackgroundColor3 = cellColors[index],
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(CELL * (index - 1), 0),
			Size = UDim2.fromOffset(CELL, CELL),
			[Fusion.Children] = {
				Kit.Label(scope, {
					Text = cellNames[index],
					TextSize = Kit.TextSize.Body,
					Fit = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -Kit.Space.M, 1, -Kit.Space.M),
				}),
			},
		}) :: any
	end

	local strip: Frame = scope:New("Frame")({
		Name = "Main",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(CELL * CELL_COUNT, CELL),
		[Fusion.Children] = cells,
	}) :: any

	local function paint(index: number, name: string?)
		local dye = name or dyeNames[math.random(1, math.max(#dyeNames, 1))]
		cellColors[index]:set(if dye then AppearanceAssets.GetDye(dye) or WHITE else WHITE)
		cellNames[index]:set(dye or "")
	end

	local function reset()
		strip.Position = UDim2.fromOffset(0, 0)
		for index, cell in cells do
			cell.Position = UDim2.fromOffset(CELL * (index - 1), 0)
		end
	end

	-- Slides one cell, then recycles the cell that left. Returns false when interrupted.
	local function step(run: number, count: number, seconds: number, winner: string?): boolean
		local slide = TweenService:Create(strip, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
			Position = UDim2.fromOffset(-CELL * count, 0),
		})
		tween = slide
		slide:Play()
		slide.Completed:Wait()
		if run ~= token then
			return false
		end

		local index = (count - 1) % CELL_COUNT + 1
		cells[index].Position = UDim2.fromOffset(CELL * (count + CELL_COUNT - 1), 0)
		paint(index, winner)
		return true
	end

	local function interrupt(): number
		token += 1
		if tween then
			tween:Cancel()
			tween = nil
		end
		return token
	end

	local function idle()
		local run = interrupt()
		reset()
		task.spawn(function()
			local count = 0
			while run == token do
				count += 1
				step(run, count, IDLE_STEP_SECONDS, nil)
			end
		end)
	end

	local function spin()
		-- The price is only a hint here: the server charges (or refuses) the spin.
		if Fusion.peek(busy) or Fusion.peek(result) or (tonumber(Fusion.peek(balance)) or 0) < tier.Price then
			return
		end
		busy:set(true)

		local spun, spunDye = AppearanceService:SpinSkinDye(options.Rare):await()
		local dye: string? = if spun and type(spunDye) == "string" then spunDye else nil
		if closed then
			return
		elseif not dye then
			busy:set(false)
			return
		end

		local run = interrupt()
		reset()
		for count = 1, SPIN_STEPS do
			if not step(run, count, getStepSeconds(count), if count == WINNER_STEP then dye else nil) then
				return
			end
		end
		busy:set(false)
		result:set(dye)
	end

	local function answer(accepted: boolean)
		if not Fusion.peek(result) then
			return
		end
		if accepted then
			AppearanceService.AcceptSkinDye:Fire()
		else
			AppearanceService.DeclineSkinDye:Fire()
		end
		result:set(nil)
		idle()
	end

	local function close()
		context.Close()
	end

	local hasResult = scope:Computed(function(use): boolean
		return use(result) ~= nil
	end)
	local canSpin = scope:Computed(function(use): boolean
		return not use(busy) and (tonumber(use(balance)) or 0) >= tier.Price
	end)
	local price = Bind.formatNumber(tier.Price)

	local function arrow(image: string, y: number): Instance
		return Kit.Image(scope, {
			Name = "Arrow",
			Image = image,
			Color = STRIP_COLOR,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.fromOffset(ARROW, ARROW),
		})
	end

	local window = ShopScreen.Board(scope, {
		Color = look.Board,
		Transparency = 0,
		Padding = 0,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Children = {
			Kit.Panel(scope, {
				Name = "Header",
				Image = "",
				Color = look.Header,
				Transparency = 0,
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
				Children = {
					Kit.Label(scope, {
						Name = "Title",
						Text = look.Title,
						TextSize = Kit.TextSize.Title,
						Fit = true,
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.fromScale(0.5, 0),
						Size = UDim2.new(1, -2 * (HEADER_HEIGHT + Kit.Space.S), 1, 0),
					}),
					-- The old close picture, on the bar's own colour.
					Kit.Button(scope, {
						Name = "Close",
						Variant = "Ghost",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(HEADER_HEIGHT, HEADER_HEIGHT),
						OnClick = close,
						Children = {
							Kit.Image(scope, { Image = CLOSE_IMAGE, Size = UDim2.fromScale(1, 1) }),
						},
					}),
				},
			}),

			arrow(ARROW_DOWN, STRIP_Y - Kit.Space.XS - ARROW),
			scope:New("Frame")({
				Name = "Scroller",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, STRIP_Y),
				Size = UDim2.fromOffset(CELL * SHOWN_CELLS, CELL),
				BackgroundColor3 = STRIP_COLOR,
				BorderSizePixel = 0,
				[Fusion.Children] = {
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						LineJoinMode = Enum.LineJoinMode.Miter,
						Color = DARK,
						Thickness = STRIP_BORDER,
					}),
					-- The stroke would be clipped with the cells: they get a frame of their own.
					scope:New("Frame")({
						Name = "Clip",
						BackgroundTransparency = 1,
						ClipsDescendants = true,
						Size = UDim2.fromScale(1, 1),
						[Fusion.Children] = { strip },
					}),
				},
			}),
			arrow(ARROW_UP, STRIP_Y + CELL + Kit.Space.XS),

			-- The colour that was rolled, over the strip, until it is answered.
			scope:New("Frame")({
				Name = "Display",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, STRIP_Y + CELL / 2),
				Size = UDim2.fromOffset(DISPLAY, DISPLAY),
				Visible = hasResult,
				ZIndex = 2,
				[Fusion.Children] = {
					Kit.Image(scope, {
						Name = "Background",
						Image = ROUND_IMAGE,
						Color = DARK,
						Size = UDim2.fromScale(1, 1),
					}),
					Kit.Image(scope, {
						Name = "Panel",
						Image = ROUND_IMAGE,
						Color = scope:Computed(function(use): Color3
							local dye = use(result)
							return if dye then AppearanceAssets.GetDye(dye) or WHITE else WHITE
						end),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, -2 * STRIP_BORDER, 1, -2 * STRIP_BORDER),
						Children = {
							Kit.Label(scope, {
								Text = scope:Computed(function(use): string
									return use(result) or ""
								end),
								TextSize = Kit.TextSize.Heading,
								Fit = true,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.8, 0.5),
							}),
						},
					}),
				},
			}),

			Kit.Button(scope, {
				Name = "SpinButton",
				-- Grey while it would do nothing: mid-spin, or without the price.
				Variant = scope:Computed(function(use): Kit.Variant
					return if use(canSpin) then "Blue" else "Grey"
				end),
				Text = scope:Computed(function(use): string
					if use(busy) then
						return "Spinning..."
					end
					-- The gem button carries its gem pictures: only the Beri one needs the sign.
					return if options.Rare then price else `${price}`
				end),
				TextColor = if options.Rare then GEMS_COLOR else nil,
				TextSize = Kit.TextSize.Heading,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, BUTTONS_Y),
				Size = UDim2.fromOffset(280, BUTTON_HEIGHT),
				-- Accept / Decline take its place while a result waits for an answer.
				Visible = scope:Computed(function(use): boolean
					return use(result) == nil
				end),
				OnClick = function()
					task.spawn(spin)
				end,
				Children = if options.Rare
					then {
						Kit.Image(scope, {
							Name = "GemLeft",
							Image = GEM_IMAGE,
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0, Kit.Space.S, 0.5, 0),
							Size = UDim2.fromOffset(BUTTON_HEIGHT - Kit.Space.S, BUTTON_HEIGHT - Kit.Space.S),
							ZIndex = 3,
						}),
						Kit.Image(scope, {
							Name = "GemRight",
							Image = GEM_IMAGE,
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -Kit.Space.S, 0.5, 0),
							Size = UDim2.fromOffset(BUTTON_HEIGHT - Kit.Space.S, BUTTON_HEIGHT - Kit.Space.S),
							ZIndex = 3,
						}),
					}
					else nil,
			}),
			Kit.Button(scope, {
				Name = "Accept",
				Text = "Accept",
				Variant = "Green",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.25, 0, 0, BUTTONS_Y),
				Size = UDim2.fromOffset(180, BUTTON_HEIGHT),
				Visible = hasResult,
				OnClick = function()
					answer(true)
				end,
			}),
			Kit.Button(scope, {
				Name = "Decline",
				Text = "Decline",
				Variant = "Red",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.75, 0, 0, BUTTONS_Y),
				Size = UDim2.fromOffset(180, BUTTON_HEIGHT),
				Visible = hasResult,
				OnClick = function()
					answer(false)
				end,
			}),

			-- "$ 12.345" in the Beri shop, "Gems: 12" in the gem shop.
			Kit.Label(scope, {
				Name = if options.Rare then "CurrentGems" else "Cash",
				Text = scope:Computed(function(use): string
					local amount = Bind.formatNumber(tonumber(use(balance)) or 0)
					return if options.Rare then `Gems: {amount}` else `$ {amount}`
				end),
				Color = if options.Rare then GEMS_COLOR else CASH_COLOR,
				TextSize = Kit.TextSize.Body,
				Fit = true,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, BALANCE_Y),
				Size = UDim2.new(0.5, 0, 0, BALANCE_HEIGHT),
			}),
		},
	})

	-- The gamepad's B closes it like the close button (NavigationController).
	Closers.register(scope, window, close)
	-- The buttons under the selection change when a result arrives or is answered.
	scope:Observer(hasResult):onChange(function()
		ShopScreen.focus(scope, window)
	end)

	table.insert(scope, function()
		closed = true
		interrupt()
	end)

	for index = 1, CELL_COUNT do
		paint(index, nil)
	end
	idle()

	-- A spin paid for in a previous visit and never answered.
	task.spawn(function()
		local fetched, pendingDye = AppearanceService:GetPendingSkinDye():await()
		local pending: string? = if fetched and type(pendingDye) == "string" then pendingDye else nil
		if pending and not closed and not Fusion.peek(busy) and not Fusion.peek(result) then
			result:set(pending)
		end
	end)

	return Kit.Screen(scope, {
		Name = context.Name,
		Children = { window },
	})
end

return function(options: Options)
	return {
		Mount = function(scope: Scope, _gui: any, context: any): ScreenGui
			return mount(options, scope, context)
		end,
	}
end
