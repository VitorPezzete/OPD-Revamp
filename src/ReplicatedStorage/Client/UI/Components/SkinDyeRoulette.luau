--!strict
--[[
	The skin dye roulette, shared by the two shops (SkinDyeShop: Beri, common colours;
	SkinDyeShopAll: gems, every colour). Returns a screen module for UIController.

		return SkinDyeRoulette({ Name = "SkinDyeShop", Title = "Skin Dye Shop", Rare = false })

	Same behaviour as the legacy Client.Modules.SkinDyeSpin: a strip of seven cells behind
	a window five cells wide slides left one cell at a time; the cell that left the window
	is recycled at the far end with a new random colour. While idle it crawls. A paid spin
	runs SPIN_STEPS steps, slowing down, and the cell recycled at WINNER_STEP - the one
	that ends in the marked centre cell - gets the colour the server rolled.

	The server has already charged and stored the result when the roulette starts; the
	animation is only the reveal. Closing the shop mid-roulette loses nothing: the next
	time it opens, the pending result is offered again.

	Here the strip is state: `offset` (in cells) is how far it has slid, and every cell has
	a slot (its place on the strip, in cells) and a dye name.
	Not part of Components/init: require it by its path.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local AppearanceConfig = require(ReplicatedStorage.Shared.Configs.AppearanceConfig)
local AppearanceAssets = require(ReplicatedStorage.Shared.Util.AppearanceAssets)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

local Button = require(script.Parent.Button)
local Label = require(script.Parent.Label)
local Panel = require(script.Parent.Panel)
local Screen = require(script.Parent.Screen)
local Window = require(script.Parent.Window)

type Scope = Theme.Scope

export type Options = {
	Name: string,
	Title: string,
	Rare: boolean,
}

type Cell = { Slot: Fusion.Value<number>, Dye: Fusion.Value<string?> }

local CELL_COUNT = 7
local VISIBLE_CELLS = 5
local IDLE_STEP_SECONDS = 0.5
local SPIN_STEPS = 70
local WINNER_STEP = 66
-- { last step using this duration, seconds per step }
local SPIN_PACE = { { 40, 0.075 }, { 50, 0.2 }, { 60, 0.45 }, { SPIN_STEPS, 1 } }

local CELL_SIZE = 150
local CELL_GAP = Theme.Space.S
local STRIP_WIDTH = CELL_SIZE * VISIBLE_CELLS
local MARKER_SIZE = 18
local ACTION_HEIGHT = 96
local GEM_ICON = "rbxassetid://1954296071"

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function getStepSeconds(step: number): number
	for _, pace in SPIN_PACE do
		if step <= pace[1] then
			return pace[2]
		end
	end
	return 1
end

local function dyeColor(name: string?): Color3
	return if name then AppearanceAssets.GetDye(name) or WHITE else WHITE
end

-- Black on light dyes, white on dark ones.
local function readableOn(color: Color3): Color3
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if luminance > 0.6 then BLACK else WHITE
end

local function mount(options: Options, scope: Scope, context: any)
	local AppearanceService = Knit.GetService("AppearanceService")
	local tier = if options.Rare then AppearanceConfig.SkinDye.Rare else AppearanceConfig.SkinDye.Common
	local dyeNames = AppearanceAssets.GetDyeNames(tier.Pool)

	local balance = Bind.data(scope :: any, tier.Currency, 0)
	local busy = scope:Value(false)
	local result: Fusion.Value<string?> = scope:Value(nil :: string?)
	local offset = scope:Value(0)

	local function randomDye(): string?
		return dyeNames[math.random(1, math.max(#dyeNames, 1))]
	end

	local cells: { Cell } = table.create(CELL_COUNT)
	for index = 1, CELL_COUNT do
		cells[index] = { Slot = scope:Value(index - 1), Dye = scope:Value(randomDye()) }
	end

	-- Every run of the strip (idle crawl or spin) holds the token it started with and
	-- stops as soon as another run, or the closing screen, takes it.
	local token = 0
	local closed = false

	local function reset()
		offset:set(0)
		for index, cell in cells do
			cell.Slot:set(index - 1)
		end
	end

	-- Slides one cell, then recycles the cell that left. Returns false when interrupted.
	local function step(run: number, count: number, seconds: number, winner: string?): boolean
		local elapsed = 0
		while elapsed < seconds do
			elapsed += RunService.RenderStepped:Wait()
			if run ~= token then
				return false
			end
			offset:set(count - 1 + math.min(elapsed / seconds, 1))
		end

		local cell = cells[(count - 1) % CELL_COUNT + 1]
		cell.Slot:set(count + CELL_COUNT - 1)
		cell.Dye:set(winner or randomDye())
		return true
	end

	local function interrupt(): number
		token += 1
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
		if Fusion.peek(busy) or Fusion.peek(result) then
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

	table.insert(scope, function()
		closed = true
		interrupt()
	end)

	local hasResult = scope:Computed(function(use): boolean
		return use(result) ~= nil
	end)
	local resultColor = scope:Computed(function(use): Color3
		return dyeColor(use(result))
	end)
	-- The price is only a hint here: the server charges (or refuses) the spin.
	local cannotSpin = scope:Computed(function(use): boolean
		return use(busy) or use(result) ~= nil or (tonumber(use(balance)) or 0) < tier.Price
	end)

	local cellFrames: { any } = {}
	for index, cell in cells do
		local color = scope:Computed(function(use): Color3
			return dyeColor(use(cell.Dye))
		end)
		cellFrames[index] = scope:New("Frame")({
			Name = `Cell{index}`,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(CELL_SIZE, CELL_SIZE),
			Position = scope:Computed(function(use): UDim2
				return UDim2.fromOffset(use(cell.Slot) * CELL_SIZE, 0)
			end),
			[Fusion.Children] = {
				scope:New("Frame")({
					Name = "Swatch",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -CELL_GAP, 1, -CELL_GAP),
					BackgroundColor3 = color,
					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Medium) }),
						scope:New("UIStroke")({ Color = Theme.Colors.Border, Thickness = 1.5 }),
						Label(scope, {
							Name = "Label",
							Text = scope:Computed(function(use): string
								return use(cell.Dye) or ""
							end),
							Variant = "BodyBold",
							TextSize = Theme.TextSize.Small,
							Color = scope:Computed(function(use): Color3
								return readableOn(use(color))
							end),
							Scaled = true,
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.new(0.5, 0, 1, -Theme.Space.S),
							Size = UDim2.new(1, -Theme.Space.M, 0, 36),
						}),
					},
				}),
			},
		})
	end

	local function marker(atBottom: boolean): Frame
		return scope:New("Frame")({
			Name = "Arrow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, if atBottom then 1 else 0),
			Size = UDim2.fromOffset(MARKER_SIZE, MARKER_SIZE),
			Rotation = 45,
			BackgroundColor3 = Theme.Colors.Accent,
			ZIndex = 4,
			[Fusion.Children] = {
				scope:New("UIStroke")({ Color = Theme.Colors.Background, Thickness = 2 }),
			},
		}) :: any
	end

	local balanceText = scope:Computed(function(use): string
		local amount = Bind.formatNumber(tonumber(use(balance)) or 0)
		return if options.Rare then `Gems: {amount}` else `$ {amount}`
	end)

	local bodyHeight = CELL_SIZE + MARKER_SIZE + Theme.Space.L + ACTION_HEIGHT

	-- A spin paid for in a previous visit and never answered.
	task.spawn(function()
		local fetched, pendingDye = AppearanceService:GetPendingSkinDye():await()
		local pending: string? = if fetched and type(pendingDye) == "string" then pendingDye else nil
		if pending and not closed and not Fusion.peek(busy) and not Fusion.peek(result) then
			result:set(pending)
		end
	end)

	idle()

	return Screen(scope, {
		Name = options.Name,
		Children = Window(scope, {
			Title = options.Title,
			Subtitle = balanceText,
			Size = UDim2.fromOffset(STRIP_WIDTH + Theme.Space.L * 2, 52 + Theme.Space.L * 2 + bodyHeight),
			OnClose = function()
				context.Close()
			end,
			Children = {
				scope:New("Frame")({
					Name = "Roulette",
					Position = UDim2.fromOffset(0, MARKER_SIZE / 2),
					Size = UDim2.fromOffset(STRIP_WIDTH, CELL_SIZE),
					BackgroundTransparency = 1,
					[Fusion.Children] = {
						Panel(scope, {
							Name = "Scroller",
							Size = UDim2.fromScale(1, 1),
							Color = Theme.Colors.Sunken,
							ClipsDescendants = true,
							Gradient = false,
							Children = scope:New("Frame")({
								Name = "Main",
								BackgroundTransparency = 1,
								Size = UDim2.fromOffset(CELL_SIZE, CELL_SIZE),
								Position = scope:Computed(function(use): UDim2
									return UDim2.fromOffset(-use(offset) * CELL_SIZE, 0)
								end),
								[Fusion.Children] = cellFrames,
							}),
						}),
						-- The winner stops here: the middle of the five visible cells.
						scope:New("Frame")({
							Name = "Winner",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromOffset(CELL_SIZE, CELL_SIZE),
							BackgroundTransparency = 1,
							ZIndex = 3,
							[Fusion.Children] = {
								scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Medium) }),
								scope:New("UIStroke")({ Color = Theme.Colors.Accent, Thickness = 3 }),
								marker(false),
								marker(true),
							},
						}),
					},
				}),

				scope:New("Frame")({
					Name = "Actions",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, ACTION_HEIGHT),
					BackgroundTransparency = 1,
					[Fusion.Children] = {
						scope:New("Frame")({
							Name = "Spin",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Visible = scope:Computed(function(use): boolean
								return not use(hasResult)
							end),
							[Fusion.Children] = {
								Button(scope, {
									Name = "SpinButton",
									Text = scope:Computed(function(use): string
										local price = Bind.formatNumber(tier.Price)
										if use(busy) then
											return "Spinning..."
										end
										return if options.Rare then `Spin  {price}` else `Spin  ${price}`
									end),
									Icon = if options.Rare then GEM_ICON else nil,
									IconColor = WHITE,
									TextSize = Theme.TextSize.Heading,
									Disabled = cannotSpin,
									AnchorPoint = Vector2.new(0.5, 0.5),
									Position = UDim2.fromScale(0.5, 0.5),
									Size = UDim2.fromOffset(300, 60),
									OnClick = function()
										task.spawn(spin)
									end,
								}),
							},
						}),
						Panel(scope, {
							Name = "Display",
							Size = UDim2.fromScale(1, 1),
							Padding = Theme.Space.M,
							Visible = hasResult,
							Children = {
								scope:New("Frame")({
									Name = "Panel",
									Size = UDim2.fromScale(1, 1),
									SizeConstraint = Enum.SizeConstraint.RelativeYY,
									BackgroundColor3 = resultColor,
									[Fusion.Children] = {
										scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Small) }),
										scope:New("UIStroke")({ Color = Theme.Colors.Accent, Thickness = 2 }),
									},
								}),
								Label(scope, {
									Name = "Caption",
									Text = "You rolled",
									Variant = "Small",
									TextXAlignment = Enum.TextXAlignment.Left,
									Position = UDim2.fromOffset(ACTION_HEIGHT, 4),
									Size = UDim2.new(1, -(ACTION_HEIGHT + 340), 0, 20),
								}),
								Label(scope, {
									Name = "Label",
									Text = scope:Computed(function(use): string
										return use(result) or ""
									end),
									Variant = "Heading",
									Scaled = true,
									TextXAlignment = Enum.TextXAlignment.Left,
									Position = UDim2.fromOffset(ACTION_HEIGHT, 28),
									Size = UDim2.new(1, -(ACTION_HEIGHT + 340), 0, 36),
								}),
								Button(scope, {
									Name = "Decline",
									Text = "Decline",
									Variant = "Secondary",
									AnchorPoint = Vector2.new(1, 0.5),
									Position = UDim2.new(1, -(160 + Theme.Space.S), 0.5, 0),
									Size = UDim2.fromOffset(160, 48),
									OnClick = function()
										answer(false)
									end,
								}),
								Button(scope, {
									Name = "Accept",
									Text = "Accept",
									Variant = "Success",
									AnchorPoint = Vector2.new(1, 0.5),
									Position = UDim2.fromScale(1, 0.5),
									Size = UDim2.fromOffset(160, 48),
									OnClick = function()
										answer(true)
									end,
								}),
							},
						}),
					},
				}),
			},
		}),
	})
end

return function(options: Options)
	return {
		Mount = function(scope: Scope, _gui: any, context: any)
			return mount(options, scope, context)
		end,
	}
end
