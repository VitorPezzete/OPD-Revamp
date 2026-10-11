--!strict
--[[
	Fruit storage (menu tab G): twelve slots for fruit items and, on a second page, the
	bound fruits.

	The old plank board, as two windows of the same size. Storage: the slots in two rows
	of six, each a column of its button (Store / Take / the countdown), the fruit's name,
	its affinity chart and its aura swatch; a locked slot shows its price and UNLOCK in
	the same cell. The arrow at the right opens the bound page: three larger slots, the
	arrow back at the left, the warning about the character reset under them. Both carry
	the gems the unlocks are paid with and the close button in their title row.

	Everything shown comes from the replicated data (Storages, Bounds); a click only
	sends the slot number. Slot cooldowns are session state of the server: the screen
	asks for them when it opens and hears about new ones through a signal, then counts
	down by itself.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local FruitItemCodec = require(ReplicatedStorage.Shared.Util.FruitItemCodec)
local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>
type Cooldown = { ReadyAt: number, Withdrawing: boolean }

local STORAGE = FruitEconomyConfig.Storage
local BOUND = FruitEconomyConfig.Bound
local SKILLS = FruitEconomyConfig.Skills

local STORE_COLOR = Color3.fromRGB(255, 255, 92)
local TAKE_COLOR = Color3.fromRGB(92, 255, 92)
local BUSY_COLOR = Color3.fromRGB(100, 100, 100)
local BIND_COLOR = Color3.fromRGB(136, 89, 255)
local UNBIND_COLOR = Color3.fromRGB(92, 43, 255)
local SLOT_EDGE = Color3.fromRGB(53, 114, 255)
local LOCKED_COLOR = Color3.fromRGB(37, 45, 90)
local BOUND_LOCKED_COLOR = Color3.fromRGB(91, 35, 204)
local GEMS_COLOR = Color3.fromRGB(126, 255, 255)
local GEM_IMAGE = "rbxassetid://1954296071"
-- The round picture of the charts' backdrop and of the aura swatches, and the disc of
-- a chart's quarters.
local ROUND_IMAGE = "rbxassetid://607507441"
local DISC_IMAGE = "rbxassetid://3018668598"

-- A full affinity (score 10) fills its quarter: the disc is twice the quarter's frame.
local SCORE_TO_SCALE = 1 / 5
local MAX_SCORE = 10
local CLOCK_STEP = 0.5

local BOUND_TITLE = "Bound Devil Fruits"
local BOUND_WARNING = "* Binding or unbinding a bound Devil Fruit will reset your character!"
local BOUND_NOTE = "Bound slots: set an eaten Devil Fruit aside and swap it back in later."

-- Each quarter of a chart: the corner that touches the middle, and its colour.
local QUARTERS: { [string]: { Centre: Vector2, Color: Color3 } } = {
	Defense = { Centre = Vector2.new(1, 1), Color = Color3.fromRGB(0, 255, 0) },
	Melee = { Centre = Vector2.new(0, 1), Color = Color3.fromRGB(255, 127, 0) },
	Sniper = { Centre = Vector2.new(1, 0), Color = Color3.fromRGB(255, 255, 0) },
	Sword = { Centre = Vector2.new(0, 0), Color = Color3.fromRGB(0, 255, 255) },
}
local RINGS = 10

-- Design pixels.
local WINDOW_SIZE = UDim2.fromOffset(1040, 740)
local GEMS_WIDTH = 220
local ARROW_SIZE = Vector2.new(64, 160)
local COLUMNS = 6
local CELL_GAP = Kit.Space.M
local CELL_PADDING = Kit.Space.S
local ROW_GAP = 6
-- A storage slot and a bound slot are the same column at two sizes.
type Measures = {
	Width: number,
	Button: number,
	Name: number,
	NameSize: number,
	Aura: number,
	UnlockButton: number,
	Gem: number,
}
local SMALL: Measures = {
	Width = 140,
	Button = 40,
	Name = 28,
	NameSize = Kit.TextSize.Small,
	Aura = 60,
	UnlockButton = 44,
	Gem = 56,
}
local LARGE: Measures = {
	Width = 240,
	Button = 48,
	Name = 34,
	NameSize = Kit.TextSize.Body,
	Aura = 88,
	UnlockButton = 52,
	Gem = 96,
}

local function inner(measures: Measures): number
	return measures.Width - 2 * CELL_PADDING
end

local function cellHeight(measures: Measures): number
	-- The chart is as wide as the column.
	return 2 * CELL_PADDING + measures.Button + measures.Name + inner(measures) + measures.Aura + 3 * ROW_GAP
end

local function corner(scope: Scope, radius: number): Instance
	return scope:New("UICorner")({ CornerRadius = UDim.new(0, radius) })
end

-- A button in a colour of its own (the yellow Store, the purple Bind...): no Kit variant
-- has them, so the Kit's bare button lies on a tinted box.
local function tintButton(
	scope: Scope,
	props: Kit.Layout & { Color: Fusion.UsedAs<Color3>, Text: Fusion.UsedAs<string>, OnClick: () -> () }
): Instance
	return Kit.Well(scope, {
		Name = props.Name or "Button",
		LayoutOrder = props.LayoutOrder,
		Size = props.Size,
		Color = props.Color,
		Transparency = 0,
		Children = {
			corner(scope, 10),
			Kit.Button(scope, {
				Variant = "Ghost",
				Text = props.Text,
				Size = UDim2.fromScale(1, 1),
				OnClick = props.OnClick,
			}),
		},
	})
end

-- The four affinity quarters; `scores` maps a skill to 0-10, nil hides the chart.
local function chart(scope: Scope, scores: any, size: number, layoutOrder: number): Instance
	local quarters: { any } = {}
	for _, skill in SKILLS do
		local quarter = QUARTERS[skill]
		if not quarter then
			continue
		end
		local centre = UDim2.fromScale(quarter.Centre.X, quarter.Centre.Y)
		local faint = quarter.Color:Lerp(Color3.new(1, 1, 1), 0.4)
		local pieces: { any } = {}
		-- Ten faint discs, one per step of the score, darken towards the middle.
		for ring = 1, RINGS do
			local scale = 2 * ring / RINGS
			table.insert(
				pieces,
				Kit.Image(scope, {
					Name = "BackgroundCircle",
					Image = DISC_IMAGE,
					Color = faint,
					Transparency = 0.9,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = centre,
					Size = UDim2.fromScale(scale, scale),
				})
			)
		end
		table.insert(
			pieces,
			Kit.Image(scope, {
				Name = "Circle",
				Image = DISC_IMAGE,
				Color = quarter.Color,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = centre,
				ZIndex = 2,
				Size = scope:Computed(function(use): UDim2
					local current = use(scores)
					local score = if current then tonumber(current[skill]) or 0 else 0
					local scale = math.clamp(score, 0, MAX_SCORE) * SCORE_TO_SCALE
					return UDim2.fromScale(scale, scale)
				end),
			})
		)
		table.insert(
			quarters,
			scope:New("Frame")({
				Name = skill,
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				AnchorPoint = quarter.Centre,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.5, 0.5),
				ZIndex = 2,
				[Fusion.Children] = pieces,
			})
		)
	end

	return scope:New("Frame")({
		Name = "Affinities",
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Visible = scope:Computed(function(use): boolean
			return use(scores) ~= nil
		end),
		[Fusion.Children] = {
			Kit.Image(scope, {
				Name = "Backdrop",
				Image = ROUND_IMAGE,
				Color = Color3.new(0, 0, 0),
				Transparency = 0.4,
				Size = UDim2.fromScale(1, 1),
			}),
			-- The quarters stop short of the backdrop's rim.
			scope:New("Frame")({
				Name = "Quarters",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.87, 0.87),
				[Fusion.Children] = quarters,
			}),
		},
	})
end

-- The two aura colours as a disc in a ring; `colors` is { Color3, Color3 } or nil.
local function aura(scope: Scope, colors: any, size: number, layoutOrder: number): Instance
	local function color(index: number)
		return scope:Computed(function(use): Color3
			local current = use(colors)
			return if current then current[index] else Color3.new(1, 1, 1)
		end)
	end
	return scope:New("Frame")({
		Name = "Aura",
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Visible = scope:Computed(function(use): boolean
			return use(colors) ~= nil
		end),
		[Fusion.Children] = {
			Kit.Image(scope, {
				Name = "DFU2",
				Image = ROUND_IMAGE,
				Color = color(2),
				Size = UDim2.fromScale(1, 1),
			}),
			Kit.Image(scope, {
				Name = "DFU1",
				Image = ROUND_IMAGE,
				Color = color(1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.87, 0.87),
				ZIndex = 2,
			}),
		},
	})
end

type SlotProps = {
	Name: string,
	LayoutOrder: number,
	Measures: Measures,
	Unlocked: Fusion.UsedAs<boolean>,
	-- The open slot.
	Title: Fusion.UsedAs<string>,
	Scores: any,
	Colors: any,
	ButtonText: Fusion.UsedAs<string>,
	ButtonColor: Fusion.UsedAs<Color3>,
	OnClick: () -> (),
	-- The locked slot: Unlock -> Confirm / Decline.
	LockedColor: Color3,
	LockedTransparency: number,
	Price: number,
	Gems: any,
	OnUnlock: () -> (),
}

-- One cell of a page: the slot itself, or its price while it is locked.
local function slotCell(scope: Scope, props: SlotProps): Instance
	local measures = props.Measures
	local width = inner(measures)
	local asking = scope:Value(false)
	local notAsking = scope:Computed(function(use): boolean
		return not use(asking)
	end)

	return scope:New("Frame")({
		Name = props.Name,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(measures.Width, cellHeight(measures)),
		[Fusion.Children] = {
			Kit.Well(scope, {
				Name = "Slot",
				Size = UDim2.fromScale(1, 1),
				Visible = props.Unlocked,
				Children = {
					corner(scope, 12),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = SLOT_EDGE,
						Thickness = 3,
						Transparency = 0.5,
					}),
					Kit.Stack(scope, {
						Gap = ROW_GAP,
						Padding = CELL_PADDING,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Size = UDim2.fromScale(1, 1),
						Children = {
							tintButton(scope, {
								LayoutOrder = 1,
								Size = UDim2.fromOffset(width, measures.Button),
								Color = props.ButtonColor,
								Text = props.ButtonText,
								OnClick = props.OnClick,
							}),
							Kit.Label(scope, {
								Name = "DevilFruit",
								LayoutOrder = 2,
								Text = props.Title,
								TextSize = measures.NameSize,
								Fit = true,
								Size = UDim2.fromOffset(width, measures.Name),
							}),
							chart(scope, props.Scores, width, 3),
							aura(scope, props.Colors, measures.Aura, 4),
						},
					}),
				},
			}),

			Kit.Well(scope, {
				Name = "Unlock",
				Color = props.LockedColor,
				Transparency = props.LockedTransparency,
				Padding = CELL_PADDING,
				Size = UDim2.fromScale(1, 1),
				Visible = scope:Computed(function(use): boolean
					return not use(props.Unlocked)
				end),
				Children = {
					corner(scope, 12),
					Kit.Button(scope, {
						Name = "Unlock",
						Text = "UNLOCK",
						-- Only a hint: the server decides whether the gems are enough.
						Variant = scope:Computed(function(use): Kit.Variant
							return if (tonumber(use(props.Gems)) or 0) >= props.Price then "Blue" else "Grey"
						end),
						Size = UDim2.new(1, 0, 0, measures.UnlockButton),
						Visible = notAsking,
						OnClick = function()
							asking:set(true)
						end,
					}),
					Kit.Button(scope, {
						Name = "Decline",
						Text = "DECLINE",
						Variant = "Red",
						Size = UDim2.new(1, 0, 0, measures.UnlockButton),
						Visible = asking,
						OnClick = function()
							asking:set(false)
						end,
					}),
					Kit.Stack(scope, {
						Name = "Price",
						Gap = Kit.Space.XS,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.new(1, 0, 0, measures.Gem + Kit.TextSize.Heading + Kit.Space.M),
						Children = {
							Kit.Label(scope, {
								LayoutOrder = 1,
								Text = Bind.formatNumber(props.Price),
								Color = GEMS_COLOR,
								TextSize = Kit.TextSize.Heading,
								Fit = true,
								Size = UDim2.new(1, 0, 0, Kit.TextSize.Heading + Kit.Space.S),
							}),
							Kit.Image(scope, {
								LayoutOrder = 2,
								Image = GEM_IMAGE,
								Size = UDim2.fromOffset(measures.Gem, measures.Gem),
							}),
						},
					}),
					Kit.Button(scope, {
						Name = "Confirm",
						Text = "CONFIRM",
						Variant = "Green",
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, measures.UnlockButton),
						Visible = asking,
						OnClick = function()
							asking:set(false)
							props.OnUnlock()
						end,
					}),
				},
			}),
		},
	})
end

return {
	Mount = function(scope: Scope, _gui: any, context: any): ScreenGui
		local FruitStorageService = Knit.GetService("FruitStorageService")

		local showBound = scope:Value(false)

		local gems = Bind.data(scope, "Economy.Gems", 0)
		local storages = Bind.data(scope, "Storages", {})
		local bounds = Bind.data(scope, "Bounds", {})

		local cooldowns: Fusion.Value<{ [number]: Cooldown }> = scope:Value({})
		local clock = scope:Value(os.clock())
		-- Bind / Unbind resets the character: one request at a time.
		local binding = scope:Value(false)
		local mounted = true
		table.insert(scope, function()
			mounted = false
		end)

		local function close()
			context.Close()
		end

		local function setCooldown(slot: number, seconds: number, withdrawing: boolean)
			local nextCooldowns = table.clone(Fusion.peek(cooldowns))
			nextCooldowns[slot] = { ReadyAt = os.clock() + seconds, Withdrawing = withdrawing }
			cooldowns:set(nextCooldowns)
		end

		local cooldownConnection = FruitStorageService.Cooldown:Connect(setCooldown)
		table.insert(scope, function()
			cooldownConnection:Disconnect()
		end)
		FruitStorageService:GetCooldowns()
			:andThen(function(remaining: { [string]: number })
				if type(remaining) ~= "table" then
					return
				end
				for key, seconds in remaining do
					local slot = tonumber(key)
					if slot and not Fusion.peek(cooldowns)[slot] then
						setCooldown(slot, seconds, false)
					end
				end
			end)
			:catch(warn)

		-- The countdown labels follow this clock; it only runs while the screen is open.
		local ticking = true
		table.insert(scope, function()
			ticking = false
		end)
		task.spawn(function()
			while ticking do
				task.wait(CLOCK_STEP)
				clock:set(os.clock())
			end
		end)

		local storageCells: { any } = {}
		for slot = 1, STORAGE.SlotCount do
			local key = tostring(slot)

			local unlocked = scope:Computed(function(use): boolean
				local stored = use(storages)[key]
				return stored ~= nil and stored.Unlocked == true
			end)
			local item = scope:Computed(function(use)
				local stored = use(storages)[key]
				return if stored then FruitItemCodec.DecodeItem(stored.Item) else nil
			end)
			-- Seconds left, rounded up; 0 when the slot is ready.
			local remaining = scope:Computed(function(use): number
				local cooldown = use(cooldowns)[slot]
				return if cooldown then math.max(0, math.ceil(cooldown.ReadyAt - use(clock))) else 0
			end)

			table.insert(
				storageCells,
				slotCell(scope, {
					Name = `Storage{slot}`,
					LayoutOrder = slot,
					Measures = SMALL,
					Unlocked = unlocked,
					Title = scope:Computed(function(use): string
						local current = use(item)
						return if current then `{current.FruitName} Fruit` else "Empty"
					end),
					Scores = scope:Computed(function(use)
						local current = use(item)
						return if current then current.Scores else nil
					end),
					Colors = scope:Computed(function(use)
						local current = use(item)
						local fruit = current and current.HasAura and FruitConfig.Fruits[current.FruitName]
						return if fruit then fruit.DefaultColors else nil
					end),
					ButtonColor = scope:Computed(function(use): Color3
						if use(remaining) > 0 then
							return BUSY_COLOR
						end
						return if use(item) then TAKE_COLOR else STORE_COLOR
					end),
					ButtonText = scope:Computed(function(use): string
						local seconds = use(remaining)
						if seconds <= 0 then
							return if use(item) then "Take" else "Store"
						end

						-- A withdrawal spends its first seconds "processing" before the fruit arrives.
						local cooldown = use(cooldowns)[slot]
						local processing = seconds - (STORAGE.CooldownSeconds - STORAGE.WithdrawSeconds)
						if cooldown and cooldown.Withdrawing and processing > 0 then
							return if processing > STORAGE.WithdrawSeconds - 2
								then "Processing"
								else string.rep(".", processing)
						end
						return tostring(seconds)
					end),
					OnClick = function()
						if Fusion.peek(remaining) > 0 then
							return
						end
						if Fusion.peek(item) then
							FruitStorageService:Withdraw(slot):catch(warn)
						else
							FruitStorageService:Store(slot):catch(warn)
						end
					end,
					LockedColor = LOCKED_COLOR,
					LockedTransparency = 0.7,
					Price = STORAGE.UnlockGems,
					Gems = gems,
					OnUnlock = function()
						FruitStorageService:Unlock(slot):catch(warn)
					end,
				})
			)
		end

		local boundCells: { any } = {}
		for slot = 1, BOUND.SlotCount do
			local key = tostring(slot)

			local unlocked = scope:Computed(function(use): boolean
				local bound = use(bounds)[key]
				return bound ~= nil and bound.Unlocked == true
			end)
			local fruit = scope:Computed(function(use)
				local bound = use(bounds)[key]
				return if bound then FruitItemCodec.DecodeBound(bound.Fruit) else nil
			end)

			table.insert(
				boundCells,
				slotCell(scope, {
					Name = `BoundFruit{slot}`,
					LayoutOrder = slot,
					Measures = LARGE,
					Unlocked = unlocked,
					Title = scope:Computed(function(use): string
						local current = use(fruit)
						return if current then current.FruitName else "Empty"
					end),
					Scores = scope:Computed(function(use)
						local current = use(fruit)
						if not current then
							return nil
						end
						-- Bound fruits keep multipliers (1.0-2.0); the circles take scores (0-10).
						local scores = {}
						for _, skill in SKILLS do
							local multiplier = tonumber((current.Affinities :: any)[skill]) or 1
							scores[skill] = (math.clamp(multiplier, 1, 2) - 1) * MAX_SCORE
						end
						return scores
					end),
					Colors = scope:Computed(function(use)
						local current = use(fruit)
						local primary, secondary = FruitColor.Parse(if current then current.Color else "None")
						return if primary and secondary then { primary, secondary } else nil
					end),
					ButtonColor = scope:Computed(function(use): Color3
						if use(binding) then
							return BUSY_COLOR
						end
						return if use(fruit) then UNBIND_COLOR else BIND_COLOR
					end),
					ButtonText = scope:Computed(function(use): string
						return if use(fruit) then "Unbind" else "Bind"
					end),
					OnClick = function()
						if Fusion.peek(binding) then
							return
						end
						binding:set(true)
						FruitStorageService:Bind(slot):catch(warn)
						task.delay(BOUND.DebounceSeconds, function()
							if mounted then
								binding:set(false)
							end
						end)
					end,
					LockedColor = BOUND_LOCKED_COLOR,
					LockedTransparency = 0.5,
					Price = BOUND.UnlockGems,
					Gems = gems,
					OnUnlock = function()
						FruitStorageService:UnlockBound(slot):catch(warn)
					end,
				})
			)
		end

		-- On both pages: the gems the unlocks are paid with, beside the close button.
		local function balance(): Instance
			return Kit.Label(scope, {
				Name = "Gems",
				Text = scope:Computed(function(use): string
					return `Gems: {Bind.formatNumber(tonumber(use(gems)) or 0)}`
				end),
				Color = GEMS_COLOR,
				TextSize = Kit.TextSize.Body,
				Fit = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.fromOffset(GEMS_WIDTH, 36),
			})
		end

		local storagePage: Instance
		local boundPage: Instance

		local storageRows = math.ceil(STORAGE.SlotCount / COLUMNS)
		local storageGrid = Vector2.new(
			COLUMNS * SMALL.Width + (COLUMNS - 1) * CELL_GAP,
			storageRows * cellHeight(SMALL) + (storageRows - 1) * CELL_GAP
		)

		storagePage = Kit.Window(scope, {
			Title = "Devil Fruit Storage",
			Image = Kit.Images.Plank,
			Size = WINDOW_SIZE,
			OnClose = close,
			HeaderChildren = balance(),
			Visible = scope:Computed(function(use): boolean
				return not use(showBound)
			end),
			Children = {
				scope:New("Frame")({
					Name = "Slots",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromOffset(storageGrid.X, storageGrid.Y),
					[Fusion.Children] = {
						scope:New("UIGridLayout")({
							CellSize = UDim2.fromOffset(SMALL.Width, cellHeight(SMALL)),
							CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
							FillDirectionMaxCells = COLUMNS,
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						storageCells,
					} :: { any },
				}),
				-- The old game kept the bound page shut until the first Marine Raid; nothing
				-- asks for that any more (the server does not, nor does the rework's window).
				Kit.Button(scope, {
					Name = "SwitchTabRight",
					Text = ">",
					Variant = "Blue",
					TextSize = Kit.TextSize.Title,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromOffset(ARROW_SIZE.X, ARROW_SIZE.Y),
					OnClick = function()
						showBound:set(true)
						ShopScreen.focus(scope, boundPage)
					end,
				}),
			},
		})

		local notesHeight = 2 * 26 + Kit.Space.XS
		boundPage = Kit.Window(scope, {
			Title = BOUND_TITLE,
			Image = Kit.Images.Plank,
			Size = WINDOW_SIZE,
			OnClose = close,
			HeaderChildren = balance(),
			Visible = showBound,
			Children = {
				Kit.Button(scope, {
					Name = "SwitchTabLeft",
					Text = "<",
					Variant = "Blue",
					TextSize = Kit.TextSize.Title,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromOffset(ARROW_SIZE.X, ARROW_SIZE.Y),
					OnClick = function()
						showBound:set(false)
						ShopScreen.focus(scope, storagePage)
					end,
				}),
				-- The row of slots, centred in what the notes leave of the page.
				Kit.Stack(scope, {
					Name = "Slots",
					Direction = "Horizontal",
					Gap = Kit.Space.L,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Size = UDim2.new(1, 0, 1, -(notesHeight + Kit.Space.M)),
					Children = boundCells,
				}),
				Kit.Stack(scope, {
					Name = "Notes",
					Gap = Kit.Space.XS,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, notesHeight),
					Children = {
						Kit.Label(scope, {
							Name = "TextLabel2",
							LayoutOrder = 1,
							Text = BOUND_WARNING,
							TextSize = Kit.TextSize.Small,
							Fit = true,
							Size = UDim2.new(1, 0, 0, 26),
						}),
						Kit.Label(scope, {
							Name = "Explanation",
							LayoutOrder = 2,
							Text = BOUND_NOTE,
							TextSize = Kit.TextSize.Small,
							Fit = true,
							Size = UDim2.new(1, 0, 0, 26),
						}),
					},
				}),
			},
		})

		return Kit.Screen(scope, {
			Name = context.Name,
			-- Above the menu, as the rework's window is.
			DisplayOrder = 10,
			Children = { storagePage, boundPage },
		})
	end,
}
