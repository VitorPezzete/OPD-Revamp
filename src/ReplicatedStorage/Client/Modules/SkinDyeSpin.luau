--!strict
--[[
	The skin dye roulette, shared by the two shops (SkinDyeShop: Beri, common colours;
	SkinDyeShopAll: gems, every colour). Returns a screen definition for UIController.

	A strip of seven cells slides left one cell at a time; the cell that left the window
	is recycled at the far end with a new random colour. While idle it crawls. A paid spin
	runs SPIN_STEPS steps, slowing down, and the cell recycled at WINNER_STEP - the one
	that ends under the arrows - gets the colour the server rolled.

	The server has already charged and stored the result when the roulette starts; the
	animation is only the reveal. Closing the shop mid-roulette loses nothing: the next
	time it opens, the pending result is offered again.

	Geometry comes from the layout: the window (Scroller) is five cells wide, the strip
	(Main) and every cell are squares as tall as the window. A cell is therefore one strip
	width apart from the next, and one step moves the strip a fifth of the window.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local AppearanceConfig = require(ReplicatedStorage.Shared.Configs.AppearanceConfig)
local AppearanceAssets = require(ReplicatedStorage.Shared.Util.AppearanceAssets)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Options = {
	Layout: string,
	Rare: boolean,
}

local CELL_COUNT = 7
-- Strip positions are relative to the window, cell positions to the strip.
local STEP = 0.2
local CELL_SPACING = 1
local IDLE_STEP_SECONDS = 0.5
local SPIN_STEPS = 70
local WINNER_STEP = 66
-- { last step using this duration, seconds per step }
local SPIN_PACE = { { 40, 0.075 }, { 50, 0.2 }, { 60, 0.45 }, { SPIN_STEPS, 1 } }

local WHITE = Color3.new(1, 1, 1)

local function getStepSeconds(step: number): number
	for _, pace in SPIN_PACE do
		if step <= pace[1] then
			return pace[2]
		end
	end
	return 1
end

local function mount(options: Options, scope: Scope, gui: ScreenGui, context: any)
	local AppearanceService = Knit.GetService("AppearanceService")
	local tier = if options.Rare then AppearanceConfig.SkinDye.Rare else AppearanceConfig.SkinDye.Common
	local dyeNames = AppearanceAssets.GetDyeNames(tier.Pool)

	local frame = Bind.find(gui, "Frame")
	local strip = Bind.find(frame, "Scroller/Main")
	local cells = table.create(CELL_COUNT)
	for index = 1, CELL_COUNT do
		cells[index] = Bind.find(strip, `Frame{index}`)
	end
	frame.Visible = true

	local balance = Bind.data(scope, tier.Currency, 0)
	local busy = scope:Value(false)
	local result: Fusion.Value<string?> = scope:Value(nil :: string?)

	-- Every run of the strip (idle crawl or spin) holds the token it started with and
	-- stops as soon as another run, or the closing screen, takes it.
	local token = 0
	local tween: Tween? = nil
	local closed = false

	local function paint(cell: any, name: string?)
		local dye = name or dyeNames[math.random(1, math.max(#dyeNames, 1))]
		cell.BackgroundColor3 = if dye then AppearanceAssets.GetDye(dye) or WHITE else WHITE
		cell.Label.Text = dye or ""
	end

	local function reset()
		strip.Position = UDim2.fromScale(0, 0.5)
		for index, cell in cells do
			cell.Position = UDim2.fromScale(CELL_SPACING * (index - 1), 0.5)
		end
	end

	-- Slides one cell, then recycles the cell that left. Returns false when interrupted.
	local function step(run: number, count: number, seconds: number, winner: string?): boolean
		local slide = TweenService:Create(strip, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
			Position = UDim2.fromScale(-STEP * count, 0.5),
		})
		tween = slide
		slide:Play()
		slide.Completed:Wait()
		if run ~= token then
			return false
		end

		local cell = cells[(count - 1) % CELL_COUNT + 1]
		cell.Position = UDim2.fromScale(CELL_SPACING * (count + CELL_COUNT - 1), 0.5)
		paint(cell, winner)
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
		if Fusion.peek(busy) or Fusion.peek(result) or Fusion.peek(balance) < tier.Price then
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

	local hasResult = scope:Computed(function(use)
		return use(result) ~= nil
	end)
	local display = Bind.find(frame, "Display")
	Bind.props(scope, display, { Visible = hasResult })
	Bind.props(scope, Bind.find(display, "Panel"), {
		ImageColor3 = scope:Computed(function(use)
			local dye = use(result)
			return if dye then AppearanceAssets.GetDye(dye) or WHITE else WHITE
		end),
	})
	Bind.props(scope, Bind.find(display, "Panel/Label"), {
		Text = scope:Computed(function(use)
			return use(result) or ""
		end),
	})

	local accept = Bind.find(frame, "Accept")
	local decline = Bind.find(frame, "Decline")
	Bind.props(scope, accept, { Visible = hasResult })
	Bind.props(scope, decline, { Visible = hasResult })
	Bind.click(scope, accept, function()
		answer(true)
	end)
	Bind.click(scope, decline, function()
		answer(false)
	end)

	-- "$ 12345" in the Beri shop, "Gems: 12" in the gem shop.
	local cash = Bind.tryFind(frame, "Cash")
	if cash then
		Bind.props(scope, cash, {
			Text = scope:Computed(function(use)
				return `$ {use(balance)}`
			end),
		})
	end
	local gems = Bind.tryFind(frame, "CurrentGems")
	if gems then
		Bind.props(scope, gems, {
			Text = scope:Computed(function(use)
				return `Gems: {use(balance)}`
			end),
		})
	end

	Bind.click(scope, Bind.find(frame, "SpinButton"), function()
		task.spawn(spin)
	end)
	Bind.click(scope, Bind.find(frame, "Header/Close"), function()
		context.Close()
	end)

	table.insert(scope, function()
		closed = true
		interrupt()
	end)

	for _, cell in cells do
		paint(cell, nil)
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
end

return function(options: Options)
	return {
		Layout = options.Layout,
		Mount = function(scope: Scope, gui: ScreenGui, context: any)
			mount(options, scope, gui, context)
		end,
	}
end
