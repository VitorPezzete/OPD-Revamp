--!strict
--[[
	Fruit storage: twelve slots for fruit items and, in a column beside them, the bound
	fruit (a Devil Fruit set aside after eating it).

	Everything shown comes from the replicated data (Storages, Bounds); a click only
	sends the slot number. Slot cooldowns are session state of the server: the screen
	asks for them when it opens and hears about new ones through a signal, then counts
	down by itself.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local FruitItemCodec = require(ReplicatedStorage.Shared.Util.FruitItemCodec)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local AffinityChart = require(ReplicatedStorage.Client.UI.Components.AffinityChart)

type Scope = Theme.Scope
type State<T> = Fusion.StateObject<T>
type Cooldown = { ReadyAt: number, Withdrawing: boolean }
-- Multiplier (1.0-2.0) per skill.
type Affinities = { [string]: number }
-- What a slot shows, whichever column it is in.
type SlotView = {
	Key: string,
	Order: number,
	Locked: State<boolean>,
	Title: State<string>,
	Filled: State<boolean>,
	-- nil when the slot is empty.
	Affinities: State<Affinities?>,
	-- { primary, secondary }, nil without an aura.
	Aura: State<{ Color3 }?>,
	ActionText: State<string>,
	ActionVariant: State<string>,
	ActionDisabled: State<boolean>,
	OnAction: () -> (),
	UnlockPrice: number,
	OnUnlock: () -> (),
}

local STORAGE = FruitEconomyConfig.Storage
local BOUND = FruitEconomyConfig.Bound
local SKILLS = FruitEconomyConfig.Skills

local GEM_ICON = "rbxassetid://1954296071"
-- The aura mark of a fruit, tinted with each of its two colours.
local AURA_ICON = "rbxassetid://607507441"
local UNTINTED = Color3.new(1, 1, 1)
local MAX_SCORE = 10
local CLOCK_STEP = 0.5

-- The same colours as the quarters of the chart.
local SKILL_COLORS: { [string]: Color3 } = {
	Defense = Theme.Colors.Success,
	Melee = Theme.Colors.Danger,
	Sniper = Theme.Colors.Warning,
	Sword = Theme.Colors.Gems,
}

local COLUMNS = 4
local SLOT_SIZE = Vector2.new(264, 224)
local SLOT_GAP = Theme.Space.M
-- The space between the storage grid and the bound column, on each side of the line.
local COLUMN_GAP = Theme.Space.L
local WINDOW_HEADER = 52
local HEADING_HEIGHT = 32
local FOOTER_HEIGHT = 26
local TITLE_HEIGHT = 24
local ACTION_HEIGHT = 36
local CHART_SIZE = 120
local AFFINITY_HEIGHT = 22
local AFFINITY_KEY = 10

-- Chart on the left, the four multipliers on the right; hidden while the slot is empty.
local function affinities(scope: Scope, multipliers: State<Affinities?>): Frame
	local rows: { any } = {}
	for index, skill in SKILLS do
		rows[index] = scope:New("Frame")({
			Name = skill,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, AFFINITY_HEIGHT),
			BackgroundTransparency = 1,
			[Fusion.Children] = {
				scope:New("Frame")({
					Name = "Key",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromOffset(AFFINITY_KEY, AFFINITY_KEY),
					BackgroundColor3 = SKILL_COLORS[skill],
					BorderSizePixel = 0,
				}),
				UI.Label(scope, {
					Text = skill,
					Variant = "Tiny",
					Color = Theme.Colors.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(AFFINITY_KEY + Theme.Space.XS + 2, 0),
					Size = UDim2.new(1, -(AFFINITY_KEY + Theme.Space.XS + 2), 1, 0),
				}),
				UI.Label(scope, {
					Name = "Value",
					Text = scope:Computed(function(use): string
						local current = use(multipliers)
						return if current then string.format("%.1f", current[skill] or 1) else ""
					end),
					Variant = "BodyBold",
					TextSize = Theme.TextSize.Small,
					Color = SKILL_COLORS[skill],
					TextXAlignment = Enum.TextXAlignment.Right,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0, 32, 1, 0),
				}),
			},
		})
	end

	return scope:New("Frame")({
		Name = "Affinities",
		Position = UDim2.fromOffset(0, TITLE_HEIGHT + Theme.Space.S),
		Size = UDim2.new(1, 0, 1, -(TITLE_HEIGHT + ACTION_HEIGHT + Theme.Space.S * 2)),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return use(multipliers) ~= nil
		end),
		[Fusion.Children] = {
			AffinityChart(scope, {
				Name = "Chart",
				Affinities = multipliers,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(CHART_SIZE, CHART_SIZE),
			}),
			UI.Stack(scope, {
				Name = "Values",
				Gap = Theme.Space.XS,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, CHART_SIZE + Theme.Space.M, 0.5, 0),
				Size = UDim2.new(1, -(CHART_SIZE + Theme.Space.M), 0, #SKILLS * AFFINITY_HEIGHT + (#SKILLS - 1) * Theme.Space.XS),
				Children = rows,
			}),
		},
	}) :: any
end

local function auraMarks(scope: Scope, aura: State<{ Color3 }?>): Frame
	local marks: { any } = {}
	for index = 1, 2 do
		marks[index] = UI.Image(scope, {
			Name = `Aura{index}`,
			Image = AURA_ICON,
			LayoutOrder = index,
			Size = UDim2.fromOffset(22, 22),
			Color = scope:Computed(function(use): Color3
				local colors = use(aura)
				return if colors then colors[index] else UNTINTED
			end),
		})
	end
	return UI.Stack(scope, {
		Name = "Aura",
		Direction = "Horizontal",
		Gap = Theme.Space.XS,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Visible = scope:Computed(function(use): boolean
			return use(aura) ~= nil
		end),
		Children = marks,
	})
end

-- Unlock -> Confirm / Cancel, shown instead of the slot content while it is locked.
local function lockedContent(scope: Scope, view: SlotView, gems: State<number>): Frame
	local asking = scope:Value(false)
	local notAsking = scope:Computed(function(use): boolean
		return not use(asking)
	end)

	return scope:New("Frame")({
		Name = "Locked",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = view.Locked,
		[Fusion.Children] = {
			UI.Label(scope, {
				Text = "Locked",
				Variant = "BodyBold",
				Color = Theme.Colors.TextMuted,
				Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
			}),
			UI.Stack(scope, {
				Name = "Price",
				Direction = "Horizontal",
				Gap = Theme.Space.XS,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, -6),
				Children = {
					UI.Image(scope, { Image = GEM_ICON, Size = UDim2.fromOffset(28, 28), LayoutOrder = 1 }),
					UI.Label(scope, {
						Text = Bind.formatNumber(view.UnlockPrice),
						Variant = "Heading",
						Color = Theme.Colors.Gems,
						LayoutOrder = 2,
					}),
				},
			}),
			UI.Button(scope, {
				Name = "Unlock",
				Text = "Unlock",
				-- Only a hint: the server decides whether the gems are enough.
				Variant = scope:Computed(function(use): any
					return if use(gems) >= view.UnlockPrice then "Primary" else "Secondary"
				end),
				TextSize = Theme.TextSize.Small,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, ACTION_HEIGHT),
				Visible = notAsking,
				OnClick = function()
					asking:set(true)
				end,
			}),
			UI.Button(scope, {
				Name = "Decline",
				Text = "Cancel",
				Variant = "Secondary",
				TextSize = Theme.TextSize.Small,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(0.5, -Theme.Space.XS, 0, ACTION_HEIGHT),
				Visible = asking,
				OnClick = function()
					asking:set(false)
				end,
			}),
			UI.Button(scope, {
				Name = "Confirm",
				Text = "Confirm",
				Variant = "Success",
				TextSize = Theme.TextSize.Small,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.new(0.5, -Theme.Space.XS, 0, ACTION_HEIGHT),
				Visible = asking,
				OnClick = function()
					asking:set(false)
					view.OnUnlock()
				end,
			}),
		},
	}) :: any
end

local function slotPanel(scope: Scope, view: SlotView, gems: State<number>): Frame
	local unlocked = scope:Computed(function(use): boolean
		return not use(view.Locked)
	end)

	return UI.Panel(scope, {
		Name = `Slot{view.Key}`,
		LayoutOrder = view.Order,
		Size = UDim2.fromOffset(SLOT_SIZE.X, SLOT_SIZE.Y),
		Color = Theme.Colors.Surface,
		Stroke = scope:Computed(function(use): Color3
			return if use(view.Filled) then Theme.Colors.BorderStrong else Theme.Colors.Border
		end),
		Padding = Theme.Space.M,
		Children = {
			lockedContent(scope, view, gems),
			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = unlocked,
				[Fusion.Children] = {
					UI.Label(scope, {
						Name = "Fruit",
						Text = view.Title,
						Variant = "BodyBold",
						Color = scope:Computed(function(use): Color3
							return if use(view.Filled) then Theme.Colors.Text else Theme.Colors.TextDim
						end),
						Scaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.new(1, -56, 0, TITLE_HEIGHT),
					}),
					auraMarks(scope, view.Aura),
					affinities(scope, view.Affinities),
					UI.Button(scope, {
						Name = "Action",
						Text = view.ActionText,
						Variant = view.ActionVariant :: any,
						Disabled = view.ActionDisabled,
						TextSize = Theme.TextSize.Small,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, ACTION_HEIGHT),
						OnClick = view.OnAction,
					}),
				},
			}),
		},
	})
end

local function heading(scope: Scope, text: string, order: number?): TextLabel
	return UI.Label(scope, {
		Name = "Heading",
		Text = text,
		Variant = "Heading",
		Color = Theme.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, HEADING_HEIGHT),
	})
end

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local FruitStorageService = Knit.GetService("FruitStorageService")

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

		-- The countdowns follow this clock; it only runs while the screen is open.
		local elapsed = 0
		table.insert(
			scope,
			RunService.Heartbeat:Connect(function(delta: number)
				elapsed += delta
				if elapsed >= CLOCK_STEP then
					elapsed = 0
					clock:set(os.clock())
				end
			end)
		)

		local storageSlots: { any } = {}
		for slot = 1, STORAGE.SlotCount do
			local key = tostring(slot)
			local item = scope:Computed(function(use): FruitItemCodec.StoredItem?
				local stored = use(storages)[key]
				return if stored then FruitItemCodec.DecodeItem(stored.Item) else nil
			end)
			-- Seconds left, rounded up; 0 when the slot is ready.
			local remaining = scope:Computed(function(use): number
				local cooldown = use(cooldowns)[slot]
				return if cooldown then math.max(0, math.ceil(cooldown.ReadyAt - use(clock))) else 0
			end)

			local view: SlotView = {
				Key = key,
				Order = slot,
				Locked = scope:Computed(function(use): boolean
					local stored = use(storages)[key]
					return not (stored ~= nil and stored.Unlocked == true)
				end),
				Title = scope:Computed(function(use): string
					local current = use(item)
					return if current then `{current.FruitName} Fruit` else "Empty"
				end),
				Filled = scope:Computed(function(use): boolean
					return use(item) ~= nil
				end),
				Affinities = scope:Computed(function(use): Affinities?
					local current = use(item)
					if not current then
						return nil
					end
					-- Stored items keep scores (0-10); a score stands for 1 + score / 10.
					local multipliers: Affinities = {}
					for _, skill in SKILLS do
						local score = tonumber((current.Scores :: any)[skill]) or 0
						multipliers[skill] = 1 + math.clamp(score, 0, MAX_SCORE) / MAX_SCORE
					end
					return multipliers
				end),
				Aura = scope:Computed(function(use): { Color3 }?
					local current = use(item)
					local fruit = if current and current.HasAura then FruitConfig.Fruits[current.FruitName] else nil
					return if fruit then fruit.DefaultColors else nil
				end),
				ActionText = scope:Computed(function(use): string
					local seconds = use(remaining)
					if seconds <= 0 then
						return if use(item) then "Take" else "Store held fruit"
					end

					-- A withdrawal spends its first seconds "processing" before the fruit arrives.
					local cooldown = use(cooldowns)[slot]
					local processing = seconds - (STORAGE.CooldownSeconds - STORAGE.WithdrawSeconds)
					if cooldown and cooldown.Withdrawing and processing > 0 then
						return `Processing {string.rep(".", 1 + processing % 3)}`
					end
					return `Ready in {seconds}s`
				end),
				ActionVariant = scope:Computed(function(use): string
					return if use(item) then "Success" else "Primary"
				end),
				ActionDisabled = scope:Computed(function(use): boolean
					return use(remaining) > 0
				end),
				OnAction = function()
					if Fusion.peek(remaining) > 0 then
						return
					end
					if Fusion.peek(item) then
						FruitStorageService:Withdraw(slot):catch(warn)
					else
						FruitStorageService:Store(slot):catch(warn)
					end
				end,
				UnlockPrice = STORAGE.UnlockGems,
				OnUnlock = function()
					FruitStorageService:Unlock(slot):catch(warn)
				end,
			}
			storageSlots[slot] = slotPanel(scope, view, gems)
		end

		local boundSlots: { any } = {}
		for slot = 1, BOUND.SlotCount do
			local key = tostring(slot)
			local fruit = scope:Computed(function(use): FruitItemCodec.BoundFruit?
				local bound = use(bounds)[key]
				return if bound then FruitItemCodec.DecodeBound(bound.Fruit) else nil
			end)

			local view: SlotView = {
				Key = key,
				Order = slot,
				Locked = scope:Computed(function(use): boolean
					local bound = use(bounds)[key]
					return not (bound ~= nil and bound.Unlocked == true)
				end),
				Title = scope:Computed(function(use): string
					local current = use(fruit)
					return if current then current.FruitName else "Empty"
				end),
				Filled = scope:Computed(function(use): boolean
					return use(fruit) ~= nil
				end),
				Affinities = scope:Computed(function(use): Affinities?
					local current = use(fruit)
					if not current then
						return nil
					end
					-- Bound fruits keep the multipliers themselves.
					local multipliers: Affinities = {}
					for _, skill in SKILLS do
						local multiplier = tonumber((current.Affinities :: any)[skill]) or 1
						multipliers[skill] = math.clamp(multiplier, 1, 2)
					end
					return multipliers
				end),
				Aura = scope:Computed(function(use): { Color3 }?
					local current = use(fruit)
					local primary, secondary = FruitColor.Parse(if current then current.Color else "None")
					return if primary and secondary then { primary, secondary } else nil
				end),
				ActionText = scope:Computed(function(use): string
					return if use(fruit) then "Unbind" else "Bind eaten fruit"
				end),
				ActionVariant = scope:Computed(function(use): string
					return if use(fruit) then "Danger" else "Primary"
				end),
				ActionDisabled = binding,
				OnAction = function()
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
				UnlockPrice = BOUND.UnlockGems,
				OnUnlock = function()
					FruitStorageService:UnlockBound(slot):catch(warn)
				end,
			}
			boundSlots[slot] = slotPanel(scope, view, gems)
		end

		-- Storage grid | line | bound column, both under a heading.
		local rows = math.ceil(STORAGE.SlotCount / COLUMNS)
		local gridWidth = COLUMNS * SLOT_SIZE.X + (COLUMNS - 1) * SLOT_GAP
		local gridHeight = rows * SLOT_SIZE.Y + (rows - 1) * SLOT_GAP
		local boundX = gridWidth + COLUMN_GAP * 2 + 1
		local bodyWidth = boundX + SLOT_SIZE.X
		-- Both columns: a heading over a stack of slots (three rows of storage, three bound slots).
		local columnHeight = HEADING_HEIGHT + SLOT_GAP + gridHeight
		local bodyHeight = columnHeight + SLOT_GAP + FOOTER_HEIGHT

		return UI.Screen(scope, {
			Name = "Storage",
			DisplayOrder = 10,
			Children = {
				UI.Window(scope, {
					Title = "Devil Fruit Storage",
					Size = UDim2.fromOffset(
						bodyWidth + Theme.Space.L * 2,
						bodyHeight + WINDOW_HEADER + Theme.Space.L * 2
					),
					OnClose = context.Close,
					HeaderChildren = {
						UI.Image(scope, { Image = GEM_ICON, Size = UDim2.fromOffset(24, 24), LayoutOrder = 1 }),
						UI.Label(scope, {
							Name = "Gems",
							Text = scope:Computed(function(use): string
								return Bind.formatNumber(tonumber(use(gems)) or 0)
							end),
							Variant = "BodyBold",
							Color = Theme.Colors.Gems,
							LayoutOrder = 2,
						}),
					},
					Children = {
						scope:New("Frame")({
							Name = "StorageColumn",
							Size = UDim2.fromOffset(gridWidth, columnHeight),
							BackgroundTransparency = 1,
							[Fusion.Children] = {
								heading(scope, "Storage"),
								scope:New("Frame")({
									Name = "Slots",
									Position = UDim2.fromOffset(0, HEADING_HEIGHT + SLOT_GAP),
									Size = UDim2.new(1, 0, 0, gridHeight),
									BackgroundTransparency = 1,
									[Fusion.Children] = {
										scope:New("UIGridLayout")({
											CellSize = UDim2.fromOffset(SLOT_SIZE.X, SLOT_SIZE.Y),
											CellPadding = UDim2.fromOffset(SLOT_GAP, SLOT_GAP),
											SortOrder = Enum.SortOrder.LayoutOrder,
										}),
										storageSlots,
									} :: { any },
								}),
							},
						}),

						UI.Divider(scope, {
							Vertical = true,
							Position = UDim2.fromOffset(gridWidth + COLUMN_GAP, 0),
							Size = UDim2.fromOffset(1, columnHeight),
						}),

						UI.Stack(scope, {
							Name = "BoundColumn",
							Gap = SLOT_GAP,
							Position = UDim2.fromOffset(boundX, 0),
							Size = UDim2.fromOffset(SLOT_SIZE.X, columnHeight),
							Children = {
								heading(scope, "Devil Fruit Bound", 1),
								UI.Stack(scope, {
									Name = "Slots",
									Gap = SLOT_GAP,
									LayoutOrder = 2,
									Children = boundSlots,
								}),
							},
						}),

						-- What the bound slots are for, under both columns.
						scope:New("Frame")({
							Name = "Footer",
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
							BackgroundTransparency = 1,
							[Fusion.Children] = {
								UI.Label(scope, {
									Name = "Explanation",
									Text = "Bound slots: set an eaten Devil Fruit aside and swap it back in later.",
									Variant = "Small",
									TextXAlignment = Enum.TextXAlignment.Left,
									Size = UDim2.fromScale(0.5, 1),
								}),
								UI.Label(scope, {
									Name = "Warning",
									Text = "Binding or unbinding a Devil Fruit resets your character!",
									Variant = "Small",
									Color = Theme.Colors.Warning,
									TextXAlignment = Enum.TextXAlignment.Right,
									AnchorPoint = Vector2.new(1, 0),
									Position = UDim2.fromScale(1, 0),
									Size = UDim2.fromScale(0.5, 1),
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
