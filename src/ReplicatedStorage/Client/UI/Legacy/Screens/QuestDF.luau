--!strict
--[[
	Sam (QuestMerchant): compass tokens.

	The old wide purple dialogue window, "Quest Man From Quest Land" across the top, in
	three columns: what Sam says at the left; the tokens, the compass, the two claim
	buttons and the wait for the next token in the middle; Sam at the right with his
	"Upgrade?" bubble, and under him the Golden Compass gauge of private servers. The
	capacity upgrade asks its question on the blue card that opens over the right half.
	(The old window was wider than the screen; this one fits it.)

	Public servers show the tokens earned over time and the wait for the next one; the
	private server owner sees the bought VIP tokens and the Golden Compass progress
	instead. Claim trades tokens for compasses; with none left the same buttons open the
	purchase prompt. The capacity upgrade is CompassCapacityService.

	The countdown is computed here from the time the server published
	(player attribute), not ticked by the server.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.Configs.InventoryConfig)
local DialogueBox = require(ReplicatedStorage.Client.UI.Legacy.Components.DialogueBox)
local GemPrice = require(ReplicatedStorage.Client.UI.Legacy.Components.GemPrice)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)

type Scope = Fusion.Scope<typeof(Fusion)>

local TOKENS = FruitEconomyConfig.Tokens
-- Published by PrivateServerService (covers Roblox private servers and code servers).
local function isPrivate(): boolean
	return Workspace:GetAttribute("PrivateServer") == true
end
local EMPTY_TRANSPARENCY = 0.7
local DISPLAY_ORDER = 10

local WINDOW_COLOR = Color3.fromRGB(119, 30, 221)
local CARD_COLOR = Color3.fromRGB(101, 134, 255)
local GOLDEN_COLOR = Color3.fromRGB(255, 238, 0)
local PORTRAIT = "rbxassetid://82448030606682"
local BUBBLE = "rbxassetid://138044594632644"
local COMPASS = "rbxassetid://73573763689554"

local SAM_LINE =
	"There's nothing like a sunny day in paradise! Except maybe this treasure map I found. Give me some time to look it over and maybe I'll point you in the right direction."
local UPGRADE_TEXT =
	"Increase your storage capacity and keep getting Compass Tokens until you reach the limit! Would you like to increase your capacity?"

local WINDOW_SIZE = Vector2.new(1560, 700)
local SIDE_WIDTH = 450
local CENTRE_WIDTH = 520
local COMPASS_SIDE = 200
local CLAIM_SIZE = UDim2.fromOffset(180, 56)
local TIME_SIZE = UDim2.fromOffset(240, 40)
local BUBBLE_SIDE = 190
local PORTRAIT_SIDE = 240
local PROMPT_SIZE = UDim2.fromOffset(150, 44)
local PROMPT_GEM = 26
local GOLDEN_SIZE = UDim2.fromOffset(SIDE_WIDTH - 2 * Kit.Space.XL, 26)
-- Covers Sam's column and stops short of the claim buttons.
local CARD_SIZE = Vector2.new(540, 440)
local CARD_BUTTON_SIZE = UDim2.fromOffset(220, 56)
local CARD_GEM = 40

local function formatWait(seconds: number): string
	local minutes = seconds // 60
	return if minutes == 0 then `{seconds % 60}s` else `{minutes}m {seconds % 60}s`
end

return {
	Merchants = TOKENS.QuestMerchants,
	-- On a phone the engine's tool bar would be drawn over this window (UIController).
	HidesHotbar = true,

	Mount = function(scope: Scope, _gui: any, context: any)
		local CompassQuestService = Knit.GetService("CompassQuestService")
		local CompassCapacityService = Knit.GetService("CompassCapacityService")
		local MonetizationService = Knit.GetService("MonetizationService")

		local current = Bind.data(scope, "CompassTokens.Current", 0)
		local limit = Bind.data(scope, "CompassTokens.Limit", 1)
		local vipTokens = Bind.data(scope, "CompassTokens.VIPBonus", 0)
		local vipRush = Bind.data(scope, "Shop.VIPRush", 0)
		local readyAt = Bind.attribute(scope, Players.LocalPlayer, TOKENS.ReadyAttribute, 0)
		local now = scope:Value(Workspace:GetServerTimeNow())
		local askingUpgrade = scope:Value(false)
		local upgrading = scope:Value(false)

		-- Tokens the claim buttons would spend in this kind of server.
		local usable = scope:Computed(function(use): number
			return if isPrivate() then use(vipTokens) else use(current)
		end)

		local ticking = true
		table.insert(scope, function()
			ticking = false
		end)
		task.spawn(function()
			while ticking do
				task.wait(1)
				if ticking then
					now:set(Workspace:GetServerTimeNow())
				end
			end
		end)

		local cost = scope:Computed(function(use): string
			return tostring(InventoryConfig.GetCompassCapacityCost(use(limit)))
		end)

		local claimButtons: { Instance } = {}
		for index, amount in TOKENS.ClaimAmounts do
			table.insert(
				claimButtons,
				Kit.Button(scope, {
					Name = `Claim{amount}`,
					Variant = "Blue",
					Size = CLAIM_SIZE,
					LayoutOrder = index,
					Text = scope:Computed(function(use): string
						return if use(usable) > 0 then `Claim {amount}` else `Buy {amount}`
					end),
					OnClick = function()
						if Fusion.peek(usable) > 0 then
							CompassQuestService:Claim(amount):catch(warn)
							if not isPrivate() then
								context.Close()
							end
						else
							MonetizationService:Prompt(`Claim{amount}`):catch(warn)
						end
					end,
				})
			)
		end

		local function gem(side: number, anchor: Vector2, position: UDim2): Instance
			return Kit.Image(scope, {
				Name = "Gem",
				Image = GemPrice.Icon,
				AnchorPoint = anchor,
				Position = position,
				Size = UDim2.fromOffset(side, side),
				ZIndex = 3,
			})
		end

		local function upgrade()
			-- One request at a time: the next level is priced from the answer.
			if Fusion.peek(upgrading) then
				return
			end
			upgrading:set(true)
			CompassCapacityService:UpgradeCapacity():catch(warn):finally(function()
				upgrading:set(false)
			end)
		end

		-- Closes when the player walks away, dies or has no character.
		MerchantDialogue.closeOnMove(scope, context.Close)

		return Kit.Screen(scope, {
			Name = "QuestDF",
			DisplayOrder = DISPLAY_ORDER,
			Children = {
				-- A window for the gamepad; like the rework's dialogue it has no close button.
				DialogueBox.new(scope, {
					Title = "Quest Man From Quest Land",
					Color = WINDOW_COLOR,
					InnerColor = WINDOW_COLOR,
					Size = WINDOW_SIZE,
					Children = {
						DialogueBox.speech(scope, {
							Text = SAM_LINE,
							Size = UDim2.new(0, SIDE_WIDTH, 1, 0),
						}),

						Kit.Stack(scope, {
							Name = "Tokens",
							Gap = Kit.Space.M,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Children = {
								Kit.Label(scope, {
									Name = "TopLabel",
									Text = scope:Computed(function(use): string
										return if isPrivate()
											then `VIP Compass Tokens: {use(vipTokens)}`
											else `Compass Tokens: {use(current)}/{use(limit)}`
									end),
									TextSize = Kit.TextSize.Heading,
									Fit = true,
									Size = UDim2.fromOffset(CENTRE_WIDTH, 36),
									LayoutOrder = 1,
								}),
								-- Faded while there is no token to spend.
								Kit.Image(scope, {
									Name = "CompassButton",
									Image = COMPASS,
									Size = UDim2.fromOffset(COMPASS_SIDE, COMPASS_SIDE),
									LayoutOrder = 2,
									Transparency = scope:Computed(function(use): number
										return if use(usable) > 0 then 0 else EMPTY_TRANSPARENCY
									end),
								}),
								Kit.Stack(scope, {
									Name = "Claim",
									Direction = "Horizontal",
									Gap = Kit.Space.L,
									LayoutOrder = 3,
									Children = claimButtons,
								}),
								Kit.Label(scope, {
									Name = "LowerLabel",
									Text = "A token will be available in:",
									TextSize = Kit.TextSize.Small,
									Size = UDim2.fromOffset(CENTRE_WIDTH, 24),
									LayoutOrder = 4,
								}),
								Kit.Well(scope, {
									Name = "TimeRemaining",
									Transparency = 0.9,
									Color = Color3.new(1, 1, 1),
									Size = TIME_SIZE,
									LayoutOrder = 5,
									Children = {
										Kit.Label(scope, {
											Text = scope:Computed(function(use): string
												if isPrivate() then
													return "???"
												elseif use(current) >= use(limit) then
													return "Full"
												end
												return formatWait(math.max(0, math.ceil(use(readyAt) - use(now))))
											end),
											TextSize = Kit.TextSize.Heading,
											Size = UDim2.fromScale(1, 1),
										}),
									},
								}),
							},
						}),

						Kit.Stack(scope, {
							Name = "Sam",
							Gap = Kit.Space.L,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(1, -SIDE_WIDTH / 2, 0.5, 0),
							Children = {
								Kit.Stack(scope, {
									Name = "Row",
									Direction = "Horizontal",
									Gap = Kit.Space.S,
									LayoutOrder = 1,
									Children = {
										-- The bubble by his head: the price of the next token slot.
										Kit.Image(scope, {
											Name = "Option",
											Image = BUBBLE,
											Size = UDim2.fromOffset(BUBBLE_SIDE, BUBBLE_SIDE),
											LayoutOrder = 1,
											Children = {
												Kit.Label(scope, {
													Name = "Label",
													Text = "Upgrade?",
													-- Dark on the bubble, as it was.
													Outline = false,
													Fit = true,
													AnchorPoint = Vector2.new(0.5, 0.5),
													Position = UDim2.fromScale(0.5, 0.42),
													Size = UDim2.new(0.8, 0, 0, 32),
												}),
												Kit.Button(scope, {
													Name = "Prompt",
													Text = cost,
													Variant = "Blue",
													TextColor = GemPrice.Color,
													AnchorPoint = Vector2.new(0.5, 0.5),
													Position = UDim2.fromScale(0.5, 0.8),
													Size = PROMPT_SIZE,
													OnClick = function()
														askingUpgrade:set(true)
													end,
													Children = {
														gem(PROMPT_GEM, Vector2.new(0, 0.5), UDim2.new(0, Kit.Space.XS, 0.5, 0)),
														gem(PROMPT_GEM, Vector2.new(1, 0.5), UDim2.new(1, -Kit.Space.XS, 0.5, 0)),
													},
												}),
											},
										}),
										DialogueBox.portrait(scope, {
											Image = PORTRAIT,
											Speaker = "Sam",
											Side = PORTRAIT_SIDE,
											LayoutOrder = 2,
										}),
									},
								}),

								-- Private servers: every VIPRushGoal claimed compasses add a golden one.
								Kit.Stack(scope, {
									Name = "GoldenCompassFrame",
									Gap = Kit.Space.XS,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									LayoutOrder = 2,
									Visible = isPrivate(),
									Children = {
										Kit.Label(scope, {
											Name = "Title",
											Text = "Golden Compass Progress",
											TextSize = Kit.TextSize.Small,
											Color = GOLDEN_COLOR,
											LayoutOrder = 1,
										}),
										Kit.Bar(scope, {
											Name = "Progress",
											Size = GOLDEN_SIZE,
											Color = GOLDEN_COLOR,
											LayoutOrder = 2,
											Value = scope:Computed(function(use): number
												return use(vipRush) / TOKENS.VIPRushGoal
											end),
											Text = scope:Computed(function(use): string
												return `{use(vipRush)} / {TOKENS.VIPRushGoal}`
											end),
										}),
									},
								}),
							},
						}),

						-- The dialog stays up so several levels can be bought in a row, as before.
						Kit.Panel(scope, {
							Name = "CapacityUpgrade",
							Image = "",
							Color = CARD_COLOR,
							Transparency = 0.02,
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.fromScale(1, 0.5),
							Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
							ZIndex = 5,
							Visible = askingUpgrade,
							Children = {
								scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
								-- Clicks stop at the card instead of reaching the bubble under it.
								scope:New("TextButton")({
									Name = "Shield",
									Size = UDim2.fromScale(1, 1),
									BackgroundTransparency = 1,
									Text = "",
									AutoButtonColor = false,
									Selectable = false,
									ZIndex = 0,
								}),
								Kit.Stack(scope, {
									Name = "Rows",
									Gap = Kit.Space.L,
									Padding = Kit.Space.XL,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									Size = UDim2.fromScale(1, 1),
									Children = {
										Kit.Label(scope, {
											Name = "BodyText",
											Text = UPGRADE_TEXT,
											TextSize = Kit.TextSize.Heading,
											Fit = true,
											Size = UDim2.new(1, 0, 0, 190),
											LayoutOrder = 1,
										}),
										Kit.Stack(scope, {
											Name = "Cost",
											Direction = "Horizontal",
											Gap = Kit.Space.M,
											VerticalAlignment = Enum.VerticalAlignment.Center,
											LayoutOrder = 2,
											Children = {
												Kit.Image(scope, {
													Image = GemPrice.Icon,
													Size = UDim2.fromOffset(CARD_GEM, CARD_GEM),
													LayoutOrder = 1,
												}),
												Kit.Label(scope, {
													Name = "Cost",
													Text = cost,
													TextSize = Kit.TextSize.Title,
													Color = GemPrice.Color,
													LayoutOrder = 2,
												}),
												Kit.Image(scope, {
													Image = GemPrice.Icon,
													Size = UDim2.fromOffset(CARD_GEM, CARD_GEM),
													LayoutOrder = 3,
												}),
											},
										}),
										Kit.Stack(scope, {
											Name = "Buttons",
											Direction = "Horizontal",
											Gap = Kit.Space.XL,
											LayoutOrder = 3,
											Children = {
												Kit.Button(scope, {
													Name = "Confirm",
													Text = "CONFIRM",
													Variant = "Green",
													Size = CARD_BUTTON_SIZE,
													LayoutOrder = 1,
													-- Greyed out while the server is answering.
													Disabled = upgrading,
													OnClick = upgrade,
												}),
												Kit.Button(scope, {
													Name = "Decline",
													Text = "DECLINE",
													Variant = "Red",
													Size = CARD_BUTTON_SIZE,
													LayoutOrder = 2,
													OnClick = function()
														askingUpgrade:set(false)
													end,
												}),
											},
										}),
									},
								}),
							} :: { any },
						}),
					},
				}),
			},
		})
	end,
}
