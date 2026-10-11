--!strict
--[[
	The Expert: takes a mission for one Expertise Task token and sells token capacity.
	The mission itself is rolled by the server; this screen only sends the two intents.
	Like every merchant window, it closes as soon as the character walks away.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ExpertiseConfig = require(ReplicatedStorage.Shared.Configs.ExpertiseConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local MerchantSpeech = require(ReplicatedStorage.Client.UI.Components.MerchantSpeech)
local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

type Scope = Theme.Scope

local PORTRAIT = "rbxassetid://8551734334"
local GEM_ICON = "rbxassetid://1954296071"
local UPGRADE_TEXT =
	"Increase your storage capacity and keep getting Expertise Tasks until you reach the limit! Would you like to increase your capacity?"

local LINES = {
	NoTokens = {
		"I don't have any new assignments for you yet. Come back later.",
		"No new jobs have come in. Hang around a while. Maybe something will pop up soon.",
		"I'm getting word of a new assignment. It's not ready yet. But, we're going to need you when we're ready.",
	},
	Available = {
		"You're here for an assignment? Good. There's work to be done. Don't return until it is done.",
		"I have a job for you. Some things that need to get done. You're the one to do it.",
		"You look like you could use a little practice. Why not take on a little job for me?",
	},
	Running = {
		"You're on the job. Get back to it. Unless it's proving to be too much for you to handle?",
		"You're on the job. There's more work to be done. Why stop now?",
		"You're on the job. I might have something new in soon. Keep up the hussle.",
	},
}

local SPEECH_HEIGHT = 140
local ACTIONS_HEIGHT = 132
local BUTTON_HEIGHT = 50
local HINT_HEIGHT = 22
local GAP = Theme.Space.M

return {
	Merchants = { ExpertiseConfig.Merchant },

	Mount = function(scope: Scope, _gui: any, context: any)
		local ExpertiseService = Knit.GetService("ExpertiseService")

		local tokens = Bind.data(scope :: any, "ExpertiseTokens.Current", 0)
		local limit = Bind.data(scope :: any, "ExpertiseTokens.Limit", 1)
		local objective = Bind.data(scope :: any, "Expertise.Mission.Objective", "None")
		local upgradeOpen = scope:Value(false)

		local state = scope:Computed(function(use): string
			if (tonumber(use(tokens)) or 0) <= 0 then
				return "NoTokens"
			end
			local current = use(objective)
			return if current == "None" or current == "" then "Available" else "Running"
		end)
		local cost = scope:Computed(function(use): number?
			return ExpertiseConfig.GetTokenUpgradeCost(tonumber(use(limit)) or 1)
		end)
		local costText = scope:Computed(function(use): string
			local current = use(cost)
			return if current then Bind.formatNumber(current) else "Max"
		end)
		-- The confirmation only exists while there is something left to buy.
		local confirming = scope:Computed(function(use): boolean
			return use(upgradeOpen) and use(cost) ~= nil
		end)
		local choosing = scope:Computed(function(use): boolean
			return not use(confirming)
		end)

		ShopWindow.closeOnMove(scope, context)

		local bodyHeight = SPEECH_HEIGHT + GAP + ACTIONS_HEIGHT + Theme.Space.S + HINT_HEIGHT

		return UI.Screen(scope, {
			Name = "ExpertiseShop",
			Children = UI.Window(scope, {
				Title = "Mission Assignment",
				Subtitle = scope:Computed(function(use): string
					return `Expertise Tasks: {use(tokens)}/{use(limit)}`
				end),
				Size = UDim2.fromOffset(700, 52 + Theme.Space.L * 2 + bodyHeight),
				Children = {
					MerchantSpeech(scope, {
						Portrait = PORTRAIT,
						Speaker = "The Expert",
						-- A new line is picked whenever the situation changes, not on every token tick.
						Text = scope:Computed(function(use): string
							local lines = (LINES :: any)[use(state)]
							return lines[math.random(1, #lines)]
						end),
						Height = SPEECH_HEIGHT,
					}),

					scope:New("Frame")({
						Name = "Actions",
						Position = UDim2.fromOffset(0, SPEECH_HEIGHT + GAP),
						Size = UDim2.new(1, 0, 0, ACTIONS_HEIGHT),
						BackgroundTransparency = 1,
						Visible = choosing,
						[Fusion.Children] = {
							UI.Button(scope, {
								Name = "Accept",
								Text = scope:Computed(function(use): string
									local current = use(state)
									if current == "Available" then
										return "Accept Mission"
									elseif current == "Running" then
										return "New Mission"
									end
									return "Close"
								end),
								Variant = scope:Computed(function(use): any
									return if use(state) == "NoTokens" then "Secondary" else "Primary"
								end),
								TextSize = Theme.TextSize.Heading,
								Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT + 10),
								OnClick = function()
									if Fusion.peek(state) ~= "NoTokens" then
										ExpertiseService.AcceptMission:Fire()
									end
									context.Close()
								end,
							}),
							UI.Label(scope, {
								Name = "UpgradeLabel",
								Text = "Upgrade task capacity?",
								Variant = "Muted",
								TextXAlignment = Enum.TextXAlignment.Left,
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.new(1, -220, 0, BUTTON_HEIGHT),
							}),
							UI.Button(scope, {
								Name = "Prompt",
								Text = costText,
								Icon = GEM_ICON,
								TextColor = Theme.Colors.Gems,
								Variant = "Secondary",
								Disabled = scope:Computed(function(use): boolean
									return use(cost) == nil
								end),
								AnchorPoint = Vector2.new(1, 1),
								Position = UDim2.fromScale(1, 1),
								Size = UDim2.fromOffset(200, BUTTON_HEIGHT),
								OnClick = function()
									upgradeOpen:set(true)
								end,
							}),
						},
					}),

					UI.Panel(scope, {
						Name = "CapacityUpgrade",
						Position = UDim2.fromOffset(0, SPEECH_HEIGHT + GAP),
						Size = UDim2.new(1, 0, 0, ACTIONS_HEIGHT),
						Padding = Theme.Space.M,
						Visible = confirming,
						Children = {
							UI.Label(scope, {
								Name = "BodyText",
								Text = UPGRADE_TEXT,
								Variant = "Small",
								Wrapped = true,
								Scaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								Size = UDim2.new(1, 0, 1, -(BUTTON_HEIGHT - 6 + Theme.Space.S)),
							}),
							UI.Badge(scope, {
								Name = "Cost",
								Text = scope:Computed(function(use): string
									return `{use(costText)} Gems`
								end),
								Color = Theme.Colors.Gems,
								Soft = true,
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.new(0, 0, 1, -8),
							}),
							UI.Button(scope, {
								Name = "Decline",
								Text = "Decline",
								Variant = "Secondary",
								AnchorPoint = Vector2.new(1, 1),
								Position = UDim2.new(1, -(150 + Theme.Space.S), 1, 0),
								Size = UDim2.fromOffset(150, BUTTON_HEIGHT - 6),
								OnClick = function()
									upgradeOpen:set(false)
								end,
							}),
							UI.Button(scope, {
								Name = "Confirm",
								Text = "Confirm",
								Variant = "Success",
								AnchorPoint = Vector2.new(1, 1),
								Position = UDim2.fromScale(1, 1),
								Size = UDim2.fromOffset(150, BUTTON_HEIGHT - 6),
								OnClick = function()
									ExpertiseService.UpgradeTokens:Fire()
								end,
							}),
						},
					}),

					UI.Label(scope, {
						Name = "Hint",
						Text = ShopWindow.HINT,
						Variant = "Tiny",
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.fromScale(0.5, 1),
						Size = UDim2.new(1, 0, 0, HINT_HEIGHT),
					}),
				},
			}),
		})
	end,
}
