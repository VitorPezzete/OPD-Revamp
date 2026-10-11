--!strict
--[[
	Sam (QuestMerchant): compass tokens.

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
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Dialogue = require(ReplicatedStorage.Client.UI.Components.Dialogue)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local TOKENS = FruitEconomyConfig.Tokens

local PORTRAIT = "rbxassetid://82448030606682"
local COMPASS_ICON = "rbxassetid://73573763689554"
local GEM_ICON = "rbxassetid://1954296071"
local GREETING =
	"There's nothing like a sunny day in paradise! Except maybe this treasure map I found. Give me some time to look it over and maybe I'll point you in the right direction."
local UPGRADE_TEXT =
	"Increase your storage capacity and keep getting Compass Tokens until you reach the limit! Would you like to increase your capacity?"

local EMPTY_TRANSPARENCY = 0.7
local ICON = 64
local BUTTON_HEIGHT = 52
-- Game art keeps its own colours.
local UNTINTED = Color3.new(1, 1, 1)

-- Published by PrivateServerService (covers Roblox private servers and code servers).
local function isPrivate(): boolean
	return Workspace:GetAttribute("PrivateServer") == true
end

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
		local private = isPrivate()

		-- Tokens the claim buttons would spend in this kind of server.
		local usable = scope:Computed(function(use): number
			return if isPrivate() then use(vipTokens) else use(current)
		end)
		local hasTokens = scope:Computed(function(use): boolean
			return use(usable) > 0
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

		local function claim(amount: number)
			if Fusion.peek(usable) > 0 then
				CompassQuestService:Claim(amount):catch(warn)
				if not isPrivate() then
					context.Close()
				end
			else
				MonetizationService:Prompt(`Claim{amount}`):catch(warn)
			end
		end

		local claimButtons: { any } = {}
		for index, amount in TOKENS.ClaimAmounts do
			table.insert(
				claimButtons,
				UI.Button(scope, {
					Name = `Claim{amount}`,
					Text = scope:Computed(function(use): string
						return if use(hasTokens) then `Claim {amount}` else `Buy {amount}`
					end),
					Variant = scope:Computed(function(use): any
						return if use(hasTokens) then "Primary" else "Secondary"
					end),
					Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
					LayoutOrder = index,
					OnClick = function()
						claim(amount)
					end,
				})
			)
		end

		MerchantDialogue.closeOnMove(scope, context.Close)

		local textLeft = ICON + Theme.Space.M
		local notAsking = scope:Computed(function(use): boolean
			return not use(askingUpgrade)
		end)

		return UI.Screen(scope, {
			Name = "QuestDF",
			DisplayOrder = 10,
			Children = {
				Dialogue(scope, {
					Title = "Quest Man From Quest Land",
					Speaker = "Sam",
					Portrait = PORTRAIT,
					Text = GREETING,
					Size = UDim2.fromOffset(820, 540),
					Children = {
						UI.Panel(scope, {
							Name = "Tokens",
							Size = UDim2.new(0.56, -Theme.Space.S, 1, 0),
							Padding = Theme.Space.M,
							Visible = notAsking,
							Children = {
								UI.Image(scope, {
									Name = "CompassButton",
									Image = COMPASS_ICON,
									Size = UDim2.fromOffset(ICON, ICON),
									Transparency = scope:Computed(function(use): number
										return if use(hasTokens) then 0 else EMPTY_TRANSPARENCY
									end),
								}),
								UI.Label(scope, {
									Name = "TopLabel",
									Text = scope:Computed(function(use): string
										return if isPrivate()
											then `VIP Compass Tokens: {use(vipTokens)}`
											else `Compass Tokens: {use(current)}/{use(limit)}`
									end),
									Variant = "Heading",
									Scaled = true,
									TextXAlignment = Enum.TextXAlignment.Left,
									Position = UDim2.fromOffset(textLeft, 0),
									Size = UDim2.new(1, -textLeft, 0, 30),
								}),
								UI.Label(scope, {
									Name = "LowerLabel",
									Text = "A token will be available in:",
									Variant = "Small",
									TextXAlignment = Enum.TextXAlignment.Left,
									Position = UDim2.fromOffset(textLeft, 34),
									Size = UDim2.new(1, -textLeft, 0, 20),
								}),
								UI.Label(scope, {
									Name = "TimeRemaining",
									Text = scope:Computed(function(use): string
										if isPrivate() then
											return "???"
										elseif use(current) >= use(limit) then
											return "Full"
										end
										return formatWait(math.max(0, math.ceil(use(readyAt) - use(now))))
									end),
									Variant = "Title",
									Color = Theme.Colors.Accent,
									TextXAlignment = Enum.TextXAlignment.Left,
									Position = UDim2.fromOffset(textLeft, 56),
									Size = UDim2.new(1, -textLeft, 0, 34),
								}),
								-- Private servers: every VIPRushGoal claimed compasses add a golden one.
								scope:New("Frame")({
									Name = "GoldenCompassFrame",
									AnchorPoint = Vector2.new(0, 1),
									Position = UDim2.fromScale(0, 1),
									Size = UDim2.new(1, 0, 0, 56),
									BackgroundTransparency = 1,
									Visible = private,
									[Fusion.Children] = {
										UI.Label(scope, {
											Name = "Title",
											Text = "Golden Compass Progress",
											Variant = "Small",
											TextXAlignment = Enum.TextXAlignment.Left,
											Size = UDim2.new(1, 0, 0, 22),
										}),
										UI.ProgressBar(scope, {
											Name = "Progress",
											Value = scope:Computed(function(use): number
												return use(vipRush) / TOKENS.VIPRushGoal
											end),
											Text = scope:Computed(function(use): string
												return `{use(vipRush)} / {TOKENS.VIPRushGoal}`
											end),
											Color = Theme.Colors.Beri,
											AnchorPoint = Vector2.new(0, 1),
											Position = UDim2.fromScale(0, 1),
											Size = UDim2.new(1, 0, 0, 26),
										}),
									},
								}),
							},
						}),

						scope:New("Frame")({
							Name = "Actions",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.new(0.44, -Theme.Space.S, 1, 0),
							BackgroundTransparency = 1,
							Visible = notAsking,
							[Fusion.Children] = {
								UI.Stack(scope, {
									Name = "Claims",
									Size = UDim2.fromScale(1, 0),
									AutomaticSize = Enum.AutomaticSize.Y,
									Gap = Theme.Space.S,
									Children = claimButtons,
								}),
								UI.Button(scope, {
									Name = "Prompt",
									Text = scope:Computed(function(use): string
										return `Upgrade capacity  {use(cost)}`
									end),
									Icon = GEM_ICON,
									IconColor = UNTINTED,
									Variant = "Secondary",
									TextColor = Theme.Colors.Gems,
									AnchorPoint = Vector2.new(0, 1),
									Position = UDim2.fromScale(0, 1),
									Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
									OnClick = function()
										askingUpgrade:set(true)
									end,
								}),
							},
						}),

						UI.Panel(scope, {
							Name = "CapacityUpgrade",
							Size = UDim2.fromScale(1, 1),
							Padding = Theme.Space.L,
							Stroke = Theme.Colors.BorderStrong,
							Visible = askingUpgrade,
							Children = {
								UI.Label(scope, {
									Name = "BodyText",
									Text = UPGRADE_TEXT,
									Variant = "Muted",
									Wrapped = true,
									Size = UDim2.new(1, 0, 1, -(BUTTON_HEIGHT + 44 + Theme.Space.M * 2)),
								}),
								UI.Stack(scope, {
									Name = "Cost",
									Direction = "Horizontal",
									Gap = Theme.Space.S,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									AnchorPoint = Vector2.new(0.5, 1),
									Position = UDim2.new(0.5, 0, 1, -(BUTTON_HEIGHT + Theme.Space.M)),
									Children = {
										UI.Image(scope, {
											Name = "Gem",
											Image = GEM_ICON,
											Size = UDim2.fromOffset(32, 32),
											LayoutOrder = 1,
										}),
										UI.Label(scope, {
											Name = "Amount",
											Text = cost,
											Variant = "Title",
											Color = Theme.Colors.Gems,
											LayoutOrder = 2,
										}),
									},
								}),
								UI.Button(scope, {
									Name = "Decline",
									Text = "Decline",
									Variant = "Secondary",
									AnchorPoint = Vector2.new(0, 1),
									Position = UDim2.fromScale(0, 1),
									Size = UDim2.new(0.5, -Theme.Space.S / 2, 0, BUTTON_HEIGHT),
									OnClick = function()
										askingUpgrade:set(false)
									end,
								}),
								-- The dialog stays up so several levels can be bought in a row.
								UI.Button(scope, {
									Name = "Confirm",
									Text = "Confirm",
									Disabled = upgrading,
									AnchorPoint = Vector2.new(1, 1),
									Position = UDim2.fromScale(1, 1),
									Size = UDim2.new(0.5, -Theme.Space.S / 2, 0, BUTTON_HEIGHT),
									OnClick = function()
										upgrading:set(true)
										CompassCapacityService:UpgradeCapacity():catch(warn):finally(function()
											upgrading:set(false)
										end)
									end,
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
