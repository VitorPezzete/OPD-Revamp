--!strict
--[[
	Affinity Diviner (AffinityMerchant): reroll the affinities of an eaten fruit.

	The old window, centred: a grey box holding a darker one, "Affinity Diviner" across
	the top, the diviner's words at the left with their < > buttons, her portrait at the
	right over the Skip Spin button, the affinity chart(s) in the middle over the two
	reroll buttons, and the Beri and Gems balances at the bottom.

	One chart per fruit: four quarter circles (Defense, Melee, Sniper, Sword) that grow
	with the affinity over faint rings, each with its figure and its padlock in the free
	corner. Padlocks keep an affinity (each one doubles the price, at most three); the
	two buttons pay with Beri or Gems. The client sends the fruit slot, the currency and
	the locks; the result arrives as replicated data once the server's spin is over, and
	the circles grow back to the new values.

	There is no close button, as in the old game and the rework: walking away closes it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local ColorButton = require(ReplicatedStorage.Client.UI.Legacy.Components.ColorButton)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local peek = Fusion.peek

local AFFINITY = FruitEconomyConfig.Affinity
local SKILLS = FruitEconomyConfig.Skills
local EMPTY = "None"

local CIRCLE = "rbxassetid://3018668598"
local LOCK = "rbxassetid://5332501773"
local PORTRAIT = "rbxassetid://3019683242"

local OUTER_COLOR = Color3.fromRGB(167, 167, 167)
local BERI_COLOR = Color3.fromRGB(0, 255, 0)
local GEMS_COLOR = Color3.fromRGB(112, 255, 246)

type Quarter = {
	-- The corner of the quarter that is the centre of the chart (its anchor in the chart).
	Corner: Vector2,
	Color: Color3,
	-- The paler shade of the rings and of the padlock.
	Pale: Color3,
}
local QUARTERS: { [string]: Quarter } = {
	Defense = { Corner = Vector2.new(1, 1), Color = Color3.fromRGB(0, 255, 0), Pale = Color3.fromRGB(155, 255, 155) },
	Melee = { Corner = Vector2.new(0, 1), Color = Color3.fromRGB(255, 127, 0), Pale = Color3.fromRGB(255, 178, 105) },
	Sniper = { Corner = Vector2.new(1, 0), Color = Color3.fromRGB(255, 255, 0), Pale = Color3.fromRGB(255, 255, 105) },
	Sword = { Corner = Vector2.new(0, 0), Color = Color3.fromRGB(0, 255, 255), Pale = Color3.fromRGB(105, 255, 255) },
}
-- Rings drawn inside the full circle of a quarter, each a tenth smaller than the last.
local RINGS = 9
local RING_TRANSPARENCY = 0.9

local LOCKED_TRANSPARENCY = 0
local UNLOCKED_TRANSPARENCY = 0.7
-- Share of a quarter its padlock takes, and its figure next to it.
local LOCK_SHARE = 0.4
local FIGURE_SIZE = UDim2.fromScale(0.4, 0.2)
-- Affinities go from 1.0 (empty quarter) to 2.0; 2.0 fills twice the quarter's frame.
local AFFINITY_BASE = 1
local AFFINITY_TO_SCALE = 2
-- The buttons come back a little after the server's spin, or at once when skipping.
local SPIN_LOCK_SECONDS = AFFINITY.SpinSeconds + 1
local SKIP_LOCK_SECONDS = 0.5
local SHRINK_TWEEN = TweenInfo.new(AFFINITY.SpinSeconds, Enum.EasingStyle.Linear)
local GROW_TWEEN = TweenInfo.new(1.5, Enum.EasingStyle.Linear)
local SKIP_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Linear)
local BALANCE_TWEEN = TweenInfo.new(3, Enum.EasingStyle.Linear)

local FRUITLESS_LINES = {
	"Welcome to the Pyramid of Divinity, fruitless one.",
	"You walk without the fruit's power. Return to me when it is yours.",
}
local LINES = {
	"I welcome you to the Pyramid of Divinity.",
	"You have passed the Pyramid's trial, and so I offer you my services.",
	"This temple holds the power to rechannel a Devil Fruit's affinities.",
	"If you wish to know more about affinities, then please allow me to tell you.",
	"All Devil Fruits have a special affinity towards specific types of combat.",
	"A user's capabilities hold a special strength over how a Devil Fruit's power is expressed.",
	"Your strength brings forth a Devil Fruit's power, but did you know that each has its own will?",
	"A Devil Fruit is not a dead thing to be eaten.",
	"You have consumed it. A living being. It lies within you, now.",
	"I will help you to attune yourself to a new willpower. A willpower that you have never noticed.",
	"Even now, in this moment, you are forcing your will upon it. Controlling it. Its power.",
	"Would you give your full power to your master? Not likely.",
	"So you must change.",
	"You may never be fully attuned to your devil's will, but with my help you may get closer.",
	"But, be careful that it does not consume you as your will blends with its own.",
}
-- With a single fruit she stops after the third line.
local SINGLE_FRUIT_LINES = 3

-- The charts: which fruit slot each one edits, how many fruits show it, and its width
-- (one fruit has the middle to itself, two share it).
local BLOCKS = {
	{ Name = "Affinities", FruitSlot = 1, FruitCount = 1, Chart = 300 },
	{ Name = "Affinities2a", FruitSlot = 1, FruitCount = 2, Chart = 260 },
	{ Name = "Affinities2b", FruitSlot = 2, FruitCount = 2, Chart = 260 },
}

local OUTER_SIZE = Vector2.new(1380, 716)
local OUTER_MARGIN = Kit.Space.XL
local INNER_PADDING = Kit.Space.XL
local TITLE_HEIGHT = 60
local SIDE_WIDTH = 290
local DIALOGUE_HEIGHT = 380
local ARROW_SIZE = Vector2.new(120, 52)
local PORTRAIT_SIZE = 290
local NAME_HEIGHT = 36
local SKIP_HEIGHT = 48
local CAPTION_HEIGHT = 30
local REROLL_HEIGHT = 46
local BALANCE_SIZE = Vector2.new(500, 40)

return {
	Merchants = { AFFINITY.Merchant },

	Mount = function(scope: Scope, _gui: any, context: any)
		local AffinityService = Knit.GetService("AffinityService")
		local MonetizationService = Knit.GetService("MonetizationService")

		local alive = true
		table.insert(scope, function()
			alive = false
		end)

		local beri = Bind.data(scope, "Economy.Beri", 0)
		local gems = Bind.data(scope, "Economy.Gems", 0)
		local firstFruit = Bind.data(scope, "DevilFruits.Slot1.Name", EMPTY)
		local secondFruit = Bind.data(scope, "DevilFruits.Slot2.Name", EMPTY)
		local ownsSkip = Bind.data(scope, "GamePasses.SkipSpin", false)
		local affinities = Bind.data(scope, "Affinities", {})

		local wantsSkip = scope:Value(false)
		local skipping = scope:Computed(function(use): boolean
			return use(wantsSkip) and use(ownsSkip) == true
		end)
		-- One spin at a time, whichever block started it.
		local spinning = scope:Value(false)

		local fruitCount = scope:Computed(function(use): number
			if use(secondFruit) ~= EMPTY then
				return 2
			end
			return if use(firstFruit) ~= EMPTY then 1 else 0
		end)

		---------------------------------------------------------------------------------
		-- Dialogue

		local stage = scope:Value(1)
		local lines = scope:Computed(function(use): { string }
			return if use(fruitCount) == 0 then FRUITLESS_LINES else LINES
		end)
		local lastStage = scope:Computed(function(use): number
			local count = use(fruitCount)
			return if count == 0 then #FRUITLESS_LINES elseif count == 1 then SINGLE_FRUIT_LINES else #LINES
		end)

		local dialogue = Kit.Stack(scope, {
			Name = "Dialogue",
			Gap = Kit.Space.M,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Children = {
				Kit.Well(scope, {
					Name = "Dia",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(SIDE_WIDTH, DIALOGUE_HEIGHT),
					Transparency = 0.7,
					Padding = Kit.Space.M,
					Children = Kit.Label(scope, {
						Wrapped = true,
						TextYAlignment = Enum.TextYAlignment.Top,
						Size = UDim2.fromScale(1, 1),
						Text = scope:Computed(function(use): string
							local all = use(lines)
							return all[math.min(use(stage), #all)]
						end),
					}),
				}),
				-- A fixed row, so that the remaining arrow does not jump when the other goes.
				scope:New("Frame")({
					Name = "Arrows",
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromOffset(SIDE_WIDTH, ARROW_SIZE.Y),
					[Children] = {
						Kit.Button(scope, {
							Name = "Back",
							Text = "<",
							Variant = "Blue",
							Size = UDim2.fromOffset(ARROW_SIZE.X, ARROW_SIZE.Y),
							Visible = scope:Computed(function(use): boolean
								return use(stage) > 1
							end),
							OnClick = function()
								stage:set(math.max(1, peek(stage) - 1))
							end,
						}),
						Kit.Button(scope, {
							Name = "Forward",
							Text = ">",
							Variant = "Blue",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.fromOffset(ARROW_SIZE.X, ARROW_SIZE.Y),
							Visible = scope:Computed(function(use): boolean
								return use(stage) < use(lastStage)
							end),
							OnClick = function()
								stage:set(math.min(peek(lastStage), peek(stage) + 1))
							end,
						}),
					},
				}),
			},
		})

		---------------------------------------------------------------------------------
		-- The diviner and the skip button

		local diviner = Kit.Stack(scope, {
			Name = "Diviner",
			Gap = Kit.Space.S,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Children = {
				Kit.Label(scope, {
					Name = "LabelName",
					Text = "Lucy",
					TextSize = Kit.TextSize.Heading,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(PORTRAIT_SIZE, NAME_HEIGHT),
				}),
				Kit.Image(scope, {
					Name = "Portrait",
					Image = PORTRAIT,
					LayoutOrder = 2,
					Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE),
				}),
				Kit.Button(scope, {
					Name = "Skip",
					Variant = "Blue",
					LayoutOrder = 3,
					Size = UDim2.fromOffset(PORTRAIT_SIZE, SKIP_HEIGHT),
					-- Without a fruit there is nothing to spin.
					Visible = scope:Computed(function(use): boolean
						return use(fruitCount) > 0
					end),
					Text = scope:Computed(function(use): string
						return if use(skipping) then "Skip Spin: On" else "Skip Spin: Off"
					end),
					Selected = skipping,
					OnClick = function()
						if peek(ownsSkip) == true then
							wantsSkip:set(not peek(wantsSkip))
						else
							wantsSkip:set(true)
							MonetizationService:PromptPass("SkipSpin"):catch(warn)
						end
					end,
				}),
			},
		})

		---------------------------------------------------------------------------------
		-- Charts

		local function block(entry: typeof(BLOCKS[1]), order: number): Instance
			local locks: Fusion.Value<{ [string]: boolean }> = scope:Value({})
			-- True while this block's own circles are shrinking.
			local rolling = scope:Value(false)

			local lockCount = scope:Computed(function(use): number
				local count = 0
				for _, skill in SKILLS do
					if use(locks)[skill] then
						count += 1
					end
				end
				return count
			end)

			local tweenInfo = scope:Computed(function(use): TweenInfo
				if use(rolling) then
					return SHRINK_TWEEN
				end
				return if use(skipping) then SKIP_TWEEN else GROW_TWEEN
			end)

			local quarters: { Instance } = {}
			for _, skill in SKILLS do
				local look = QUARTERS[skill]
				if not look then
					warn(`[UI] affinity "{skill}" has no quarter in the legacy chart`)
					continue
				end
				local corner = look.Corner
				-- The corner away from the centre of the chart, where the padlock goes; the
				-- figure stands next to it, towards the centre.
				local free = Vector2.new(1 - corner.X, 1 - corner.Y)
				local inward = if free.Y < 0.5 then LOCK_SHARE else -LOCK_SHARE

				-- An affinity that is not locked runs down to 1.0 while the spin lasts, then
				-- up to its new value.
				local target = scope:Computed(function(use): number
					if use(rolling) and not use(locks)[skill] then
						return AFFINITY_BASE
					end
					local all = use(affinities)
					local saved = if type(all) == "table" then all[`DF{entry.FruitSlot}`] else nil
					local value = if type(saved) == "table" and type(saved[skill]) == "number"
						then saved[skill]
						else AFFINITY_BASE
					return math.clamp(value, AFFINITY_BASE, AFFINITY_BASE + 1)
				end)
				local value = scope:Tween(target, tweenInfo)

				local rings: { Instance } = {}
				for ring = 1, RINGS do
					local share = 1 - ring / (RINGS + 1)
					table.insert(
						rings,
						Kit.Image(scope, {
							Name = "BackgroundCircle",
							Image = CIRCLE,
							Color = look.Pale,
							Transparency = RING_TRANSPARENCY,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(share, share),
						})
					)
				end

				table.insert(
					quarters,
					scope:New("Frame")({
						Name = skill,
						BackgroundTransparency = 1,
						ClipsDescendants = true,
						AnchorPoint = corner,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.5, 0.5),
						[Children] = {
							-- The full circle (twice the quarter) around the centre of the chart.
							Kit.Image(scope, {
								Name = "BackgroundCircle",
								Image = CIRCLE,
								Color = look.Pale,
								Transparency = RING_TRANSPARENCY,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(corner.X, corner.Y),
								Size = UDim2.fromScale(2, 2),
								ZIndex = 1,
								Children = rings,
							}),
							Kit.Image(scope, {
								Name = "Circle",
								Image = CIRCLE,
								Color = look.Color,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(corner.X, corner.Y),
								ZIndex = 2,
								Size = scope:Computed(function(use): UDim2
									local scale = (use(value) - AFFINITY_BASE) * AFFINITY_TO_SCALE
									return UDim2.fromScale(scale, scale)
								end),
							}),
							scope:New("ImageButton")({
								Name = "Lock",
								BackgroundTransparency = 1,
								AnchorPoint = free,
								Position = UDim2.fromScale(free.X, free.Y),
								Size = UDim2.fromScale(LOCK_SHARE, LOCK_SHARE),
								ZIndex = 3,
								Image = LOCK,
								ImageColor3 = look.Pale,
								ImageTransparency = scope:Computed(function(use): number
									return if use(locks)[skill] then LOCKED_TRANSPARENCY else UNLOCKED_TRANSPARENCY
								end),
								[Fusion.OnEvent("Activated")] = function()
									local nextLocks = table.clone(peek(locks))
									if nextLocks[skill] then
										nextLocks[skill] = nil
									elseif peek(lockCount) < AFFINITY.MaxLocks then
										nextLocks[skill] = true
									end
									locks:set(nextLocks)
								end,
							}),
							Kit.Label(scope, {
								Name = "Figure",
								TextSize = Kit.TextSize.Small,
								Fit = true,
								AnchorPoint = free,
								Position = UDim2.fromScale(free.X, free.Y + inward),
								Size = FIGURE_SIZE,
								ZIndex = 4,
								-- The one figure that keeps its decimal: an affinity runs from 1.0 to 2.0.
								Text = scope:Computed(function(use): string
									return string.format("%.1f", use(value))
								end),
							}),
						},
					})
				)
			end

			local function reroll(name: string, currency: "Beri" | "Gems", balance: Fusion.Value<any>, color: Color3?, rerollOrder: number): Instance
				local cost = scope:Computed(function(use): number
					return FruitEconomyConfig.GetRerollCost(currency, use(lockCount))
				end)
				local props = {
					Name = name,
					LayoutOrder = rerollOrder,
					Size = UDim2.new(0.8, 0, 0, REROLL_HEIGHT),
					Visible = scope:Computed(function(use): boolean
						return not use(spinning)
					end),
					Text = scope:Computed(function(use): string
						local amount = Bind.formatNumber(use(cost))
						return if currency == "Gems" then `{amount} Gems` else `${amount}`
					end),
					-- Greyed only: the server decides whether the spin is paid for.
					Disabled = scope:Computed(function(use): boolean
						return (tonumber(use(balance)) or 0) < use(cost)
					end),
					OnClick = function()
						if peek(spinning) or (tonumber(peek(balance)) or 0) < peek(cost) then
							return
						end

						local skip = peek(skipping)
						spinning:set(true)
						AffinityService:Reroll(entry.FruitSlot, currency, peek(locks), skip)
							:andThen(function(started: boolean)
								if not started then
									spinning:set(false)
									return
								end
								rolling:set(not skip)
								task.delay(if skip then SKIP_LOCK_SECONDS else SPIN_LOCK_SECONDS, function()
									-- The screen may have closed during the spin.
									if alive then
										rolling:set(false)
										spinning:set(false)
									end
								end)
							end)
							:catch(function()
								spinning:set(false)
							end)
					end,
				}
				if color then
					local colored: any = props
					colored.Color = color
					return ColorButton(scope, colored)
				end
				local flat: any = props
				flat.Variant = "Blue"
				return Kit.Button(scope, flat)
			end

			-- Which fruit the block edits and, once a padlock is closed, how many are.
			local fruitName = if entry.FruitSlot == 1 then firstFruit else secondFruit

			return Kit.Stack(scope, {
				Name = entry.Name,
				LayoutOrder = order,
				Gap = Kit.Space.S,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Size = UDim2.fromOffset(entry.Chart, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible = scope:Computed(function(use): boolean
					return use(fruitCount) == entry.FruitCount
				end),
				Children = {
					Kit.Label(scope, {
						Name = "Caption",
						Fit = true,
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, CAPTION_HEIGHT),
						Text = scope:Computed(function(use): string
							local count = use(lockCount)
							local name = tostring(use(fruitName))
							return if count == 0 then name else `{name} - {count} of {AFFINITY.MaxLocks} locks used`
						end),
					}),
					scope:New("Frame")({
						Name = "Chart",
						BackgroundTransparency = 1,
						LayoutOrder = 2,
						Size = UDim2.fromOffset(entry.Chart, entry.Chart),
						[Children] = quarters,
					}),
					reroll("Reroll1", "Beri", beri, nil, 3),
					reroll("Reroll2", "Gems", gems, GEMS_COLOR, 4),
				},
			})
		end

		local blocks: { Instance } = {}
		for order, entry in BLOCKS do
			table.insert(blocks, block(entry, order))
		end

		---------------------------------------------------------------------------------
		-- Balances roll towards their new value, as the old labels did.

		local shownBeri = scope:Tween(beri, BALANCE_TWEEN)
		local shownGems = scope:Tween(gems, BALANCE_TWEEN)

		local function balance(name: string, color: Color3, text: Fusion.StateObject<string>, order: number): Instance
			return Kit.Well(scope, {
				Name = name,
				LayoutOrder = order,
				Size = UDim2.fromOffset(BALANCE_SIZE.X, BALANCE_SIZE.Y),
				Transparency = 0.8,
				Children = Kit.Label(scope, {
					Text = text,
					Color = color,
					Fit = true,
					Size = UDim2.fromScale(1, 1),
				}),
			})
		end

		local balancesHeight = 2 * BALANCE_SIZE.Y + Kit.Space.S
		local inner = Kit.Well(scope, {
			Name = "Frame",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -2 * OUTER_MARGIN, 1, -2 * OUTER_MARGIN),
			Transparency = 0.5,
			Padding = INNER_PADDING,
			Children = {
				Kit.Label(scope, {
					Name = "Shop",
					Text = "Affinity Diviner",
					TextSize = Kit.TextSize.Title,
					Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
				}),
				dialogue,
				diviner,
				Kit.Stack(scope, {
					Name = "Charts",
					Direction = "Horizontal",
					Gap = Kit.Space.XL * 2,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					-- From the top: a chart must not move when its buttons go for the spin.
					VerticalAlignment = Enum.VerticalAlignment.Top,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, TITLE_HEIGHT),
					Size = UDim2.new(1, -2 * (SIDE_WIDTH + Kit.Space.XL), 1, -(TITLE_HEIGHT + balancesHeight + Kit.Space.M)),
					Children = blocks,
				}),
				Kit.Stack(scope, {
					Name = "Balances",
					Gap = Kit.Space.S,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.5, 1),
					Size = UDim2.fromOffset(BALANCE_SIZE.X, balancesHeight),
					Children = {
						balance(
							"Cash",
							BERI_COLOR,
							scope:Computed(function(use): string
								return `${Bind.formatNumber(math.floor(use(shownBeri)))}`
							end),
							1
						),
						balance(
							"Gems",
							GEMS_COLOR,
							scope:Computed(function(use): string
								return `{Bind.formatNumber(math.floor(use(shownGems)))} Gems`
							end),
							2
						),
					},
				}),
			},
		})

		MerchantDialogue.closeOnMove(scope, context.Close)

		return Kit.Screen(scope, {
			Name = "AffinityUI",
			-- Named "Window" for the gamepad: the selection on open. Nothing is registered
			-- to close it: walking away does.
			Children = Kit.Panel(scope, {
				Name = "Window",
				Image = "",
				Color = OUTER_COLOR,
				Transparency = 0.5,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(OUTER_SIZE.X, OUTER_SIZE.Y),
				Children = inner,
			}),
		})
	end,
}
