--!strict
--[[
	Affinity Diviner (AffinityMerchant): reroll the affinities of an eaten fruit.

	One block per eaten fruit: the round affinity chart of the Stats tab in the middle,
	and in each corner the affinity of that quarter with its padlock. Padlocks keep an
	affinity (each one doubles the price, at most three); the two buttons pay with Beri or
	Gems. The client sends the fruit slot, the currency and the locks; the result arrives
	as replicated data once the server's spin is over, and the chart grows back to the new
	values.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local AffinityChart = require(ReplicatedStorage.Client.UI.Components.AffinityChart)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Dialogue = require(ReplicatedStorage.Client.UI.Components.Dialogue)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local AFFINITY = FruitEconomyConfig.Affinity
local SKILLS = FruitEconomyConfig.Skills
local EMPTY = "None"

local PORTRAIT = "rbxassetid://3019683242"
local LOCK = "rbxassetid://5332501773"

-- One colour per affinity, the same as its quarter of the chart.
local SKILL_COLORS: { [string]: Color3 } = {
	Defense = Theme.Colors.Success,
	Melee = Theme.Colors.Danger,
	Sniper = Theme.Colors.Warning,
	Sword = Theme.Colors.Gems,
}

-- Affinities go from 1.0 (empty quarter) to 2.0 (full quarter).
local AFFINITY_BASE = 1
-- Corner of the block each affinity is written in: the corner of its quarter of the chart.
local CORNERS: { [string]: Vector2 } = {
	Defense = Vector2.new(0, 0),
	Melee = Vector2.new(1, 0),
	Sniper = Vector2.new(0, 1),
	Sword = Vector2.new(1, 1),
}
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

local BLOCK_SIZE = UDim2.fromOffset(462, 378)
local CHART_SIZE = 204
local CORNER_SIZE = Vector2.new(104, 96)
local LOCK_SIZE = 40
local BUTTON_HEIGHT = 48
local TOOLBAR_HEIGHT = 40

return {
	Merchants = { AFFINITY.Merchant },

	Mount = function(scope: Scope, _gui: any, context: any)
		local AffinityService = Knit.GetService("AffinityService")
		local MonetizationService = Knit.GetService("MonetizationService")

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

		local alive = true
		table.insert(scope, function()
			alive = false
		end)

		local fruitCount = scope:Computed(function(use): number
			if use(secondFruit) ~= EMPTY then
				return 2
			end
			return if use(firstFruit) ~= EMPTY then 1 else 0
		end)

		-- Dialogue.
		local stage = scope:Value(1)
		local lines = scope:Computed(function(use): { string }
			return if use(fruitCount) == 0 then FRUITLESS_LINES else LINES
		end)
		local lastStage = scope:Computed(function(use): number
			local count = use(fruitCount)
			return if count == 0 then #FRUITLESS_LINES elseif count == 1 then SINGLE_FRUIT_LINES else #LINES
		end)

		-- Balances roll towards their new value.
		local shownBeri = scope:Tween(beri, BALANCE_TWEEN)
		local shownGems = scope:Tween(gems, BALANCE_TWEEN)

		local function block(fruitSlot: number, fruitName: Fusion.Value<any>, minimumFruits: number): Instance
			local locks: Fusion.Value<{ [string]: boolean }> = scope:Value({})
			-- True while this block's own gauges are shrinking.
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

			-- What the chart shows: an affinity that is not locked runs down to 1.0 while the
			-- spin lasts, then up to its new value.
			local shown: { [string]: Fusion.StateObject<number> } = {}
			local corners: { any } = {}
			for _, skill in SKILLS do
				local color = SKILL_COLORS[skill] or Theme.Colors.Accent
				local corner = CORNERS[skill] or Vector2.zero
				local locked = scope:Computed(function(use): boolean
					return use(locks)[skill] == true
				end)
				local target = scope:Computed(function(use): number
					if use(rolling) and not use(locked) then
						return AFFINITY_BASE
					end
					local saved = use(affinities)[`DF{fruitSlot}`]
					local value = if saved and type(saved[skill]) == "number" then saved[skill] else AFFINITY_BASE
					return math.clamp(value, AFFINITY_BASE, AFFINITY_BASE + 1)
				end)
				local value = scope:Tween(target, tweenInfo)
				shown[skill] = value

				table.insert(
					corners,
					scope:New("Frame")({
						Name = skill,
						AnchorPoint = corner,
						Position = UDim2.fromScale(corner.X, corner.Y),
						Size = UDim2.fromOffset(CORNER_SIZE.X, CORNER_SIZE.Y),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							UI.Label(scope, {
								Name = "Title",
								Text = skill,
								Variant = "BodyBold",
								Color = color,
								Size = UDim2.new(1, 0, 0, 24),
							}),
							UI.Label(scope, {
								Name = "Value",
								-- The one figure that keeps its decimal: an affinity runs from 1.0 to 2.0.
								Text = scope:Computed(function(use): string
									return string.format("%.1f", use(value))
								end),
								Variant = "Small",
								Color = Theme.Colors.Text,
								Position = UDim2.fromOffset(0, 24),
								Size = UDim2.new(1, 0, 0, 22),
							}),
							UI.Button(scope, {
								Name = "Lock",
								Icon = LOCK,
								IconColor = scope:Computed(function(use): Color3
									return if use(locked) then color else Theme.Colors.TextDim
								end),
								Variant = "Secondary",
								Selected = locked,
								AnchorPoint = Vector2.new(0.5, 1),
								Position = UDim2.fromScale(0.5, 1),
								Size = UDim2.fromOffset(LOCK_SIZE, LOCK_SIZE),
								OnClick = function()
									local nextLocks = table.clone(Fusion.peek(locks))
									if nextLocks[skill] then
										nextLocks[skill] = nil
									elseif Fusion.peek(lockCount) < AFFINITY.MaxLocks then
										nextLocks[skill] = true
									end
									locks:set(nextLocks)
								end,
							}),
						},
					})
				)
			end
			local chartValues = scope:Computed(function(use): { [string]: number }
				local values: { [string]: number } = {}
				for skill, value in shown do
					values[skill] = use(value)
				end
				return values
			end)

			local function reroll(name: string, currency: "Beri" | "Gems", balance: Fusion.Value<any>, right: boolean): Instance
				local cost = scope:Computed(function(use): number
					return FruitEconomyConfig.GetRerollCost(currency, use(lockCount))
				end)
				return UI.Button(scope, {
					Name = name,
					Text = scope:Computed(function(use): string
						local amount = Bind.formatNumber(use(cost))
						return if currency == "Gems" then `{amount} Gems` else `${amount}`
					end),
					Variant = "Secondary",
					TextColor = if currency == "Gems" then Theme.Colors.Gems else Theme.Colors.Beri,
					-- Greyed out only: the server decides whether the spin is paid for.
					Disabled = scope:Computed(function(use): boolean
						return use(spinning) or use(balance) < use(cost)
					end),
					AnchorPoint = Vector2.new(if right then 1 else 0, 1),
					Position = UDim2.fromScale(if right then 1 else 0, 1),
					Size = UDim2.new(0.5, -Theme.Space.S / 2, 0, BUTTON_HEIGHT),
					OnClick = function()
						if Fusion.peek(spinning) then
							return
						end

						local skip = Fusion.peek(skipping)
						spinning:set(true)
						AffinityService:Reroll(fruitSlot, currency, Fusion.peek(locks), skip)
							:andThen(function(started: boolean)
								if not started then
									spinning:set(false)
									return
								end
								rolling:set(not skip)
								task.delay(if skip then SKIP_LOCK_SECONDS else SPIN_LOCK_SECONDS, function()
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
				})
			end

			return UI.Panel(scope, {
				Name = `Affinities{fruitSlot}`,
				Size = BLOCK_SIZE,
				Padding = Theme.Space.M,
				LayoutOrder = fruitSlot,
				Visible = scope:Computed(function(use): boolean
					return use(fruitCount) >= minimumFruits
				end),
				Children = {
					UI.Label(scope, {
						Name = "Fruit",
						Text = scope:Computed(function(use): string
							return tostring(use(fruitName))
						end),
						Variant = "Heading",
						Scaled = true,
						Size = UDim2.new(1, 0, 0, 28),
					}),
					UI.Label(scope, {
						Name = "Hint",
						Text = scope:Computed(function(use): string
							local count = use(lockCount)
							return if count == 0
								then "Lock an affinity to keep it. Each lock doubles the price."
								else `{count} of {AFFINITY.MaxLocks} locks used`
						end),
						Variant = "Tiny",
						Position = UDim2.fromOffset(0, 30),
						Size = UDim2.new(1, 0, 0, 18),
					}),
					scope:New("Frame")({
						Name = "Affinities",
						Position = UDim2.fromOffset(0, 60),
						Size = UDim2.new(1, 0, 1, -(60 + BUTTON_HEIGHT + Theme.Space.M)),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							AffinityChart(scope, {
								Affinities = chartValues,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromOffset(CHART_SIZE, CHART_SIZE),
							}),
							corners,
						} :: { any },
					}),
					reroll("Reroll1", "Beri", beri, false),
					reroll("Reroll2", "Gems", gems, true),
				},
			})
		end

		MerchantDialogue.closeOnMove(scope, context.Close)

		return UI.Screen(scope, {
			Name = "AffinityUI",
			DisplayOrder = 10,
			Children = {
				Dialogue(scope, {
					Title = "Affinity Diviner",
					Subtitle = scope:Computed(function(use): string
						local cash = Bind.formatNumber(use(shownBeri))
						local gemCount = Bind.formatNumber(use(shownGems))
						return `${cash}   {gemCount} Gems`
					end),
					Speaker = "Lucy",
					Portrait = PORTRAIT,
					Text = scope:Computed(function(use): string
						local all = use(lines)
						return all[math.min(use(stage), #all)]
					end),
					Size = scope:Computed(function(use): UDim2
						-- Without a fruit there is nothing below the dialogue.
						return if use(fruitCount) == 0 then UDim2.fromOffset(980, 300) else UDim2.fromOffset(980, 700)
					end),
					Actions = {
						UI.Button(scope, {
							Name = "Back",
							Text = "<",
							Variant = "Secondary",
							Size = UDim2.fromOffset(44, 40),
							LayoutOrder = 1,
							Disabled = scope:Computed(function(use): boolean
								return use(stage) <= 1
							end),
							OnClick = function()
								stage:set(math.max(1, Fusion.peek(stage) - 1))
							end,
						}),
						UI.Button(scope, {
							Name = "Forward",
							Text = ">",
							Variant = "Secondary",
							Size = UDim2.fromOffset(44, 40),
							LayoutOrder = 2,
							Disabled = scope:Computed(function(use): boolean
								return use(stage) >= use(lastStage)
							end),
							OnClick = function()
								stage:set(math.min(Fusion.peek(lastStage), Fusion.peek(stage) + 1))
							end,
						}),
					},
					Children = {
						scope:New("Frame")({
							Name = "Reroll",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Visible = scope:Computed(function(use): boolean
								return use(fruitCount) > 0
							end),
							[Fusion.Children] = {
								UI.Button(scope, {
									Name = "Skip",
									Text = scope:Computed(function(use): string
										return if use(skipping) then "Skip Spin: On" else "Skip Spin: Off"
									end),
									Variant = "Secondary",
									Selected = skipping,
									TextSize = Theme.TextSize.Small,
									Size = UDim2.fromOffset(200, TOOLBAR_HEIGHT),
									OnClick = function()
										if Fusion.peek(ownsSkip) == true then
											wantsSkip:set(not Fusion.peek(wantsSkip))
										else
											wantsSkip:set(true)
											MonetizationService:PromptPass("SkipSpin"):catch(warn)
										end
									end,
								}),
								UI.Stack(scope, {
									Name = "Blocks",
									Direction = "Horizontal",
									Gap = Theme.Space.L,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									Position = UDim2.fromOffset(0, TOOLBAR_HEIGHT + Theme.Space.M),
									Size = UDim2.new(1, 0, 1, -(TOOLBAR_HEIGHT + Theme.Space.M)),
									Children = {
										block(1, firstFruit, 1),
										block(2, secondFruit, 2),
									},
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
