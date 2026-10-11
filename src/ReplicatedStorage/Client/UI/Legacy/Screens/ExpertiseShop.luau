--!strict
--[[
	The Expert: takes a mission for one Expertise Task token and sells token capacity.
	The mission itself is rolled by the server; this screen only sends the two intents.
	Like every legacy merchant window, it closes as soon as the character walks away.

	The old red rounded board with its thick dark edge: the task count under the title,
	what the Expert says in the dark box with the mission button under it, his portrait on
	the right with the "Upgrade?" tag below it. The capacity confirmation is the blue card
	that comes up over the portrait.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ExpertiseConfig = require(ReplicatedStorage.Shared.Configs.ExpertiseConfig)
local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

local BOARD_COLOR = Color3.fromRGB(255, 0, 0)
local EDGE_COLOR = Color3.fromRGB(34, 34, 34)
local CARD_COLOR = Color3.fromRGB(101, 134, 255)
local GEMS_COLOR = Color3.fromRGB(0, 255, 255)
local PORTRAIT_IMAGE = "rbxassetid://8551734334"
local OPTION_IMAGE = "rbxassetid://138044594632644"
local GEM_IMAGE = "rbxassetid://1954296071"
local UPGRADE_TEXT = "Increase your storage capacity and keep getting Expertise Tasks until you reach the limit! "
	.. "Would you like to increase your capacity?"

-- Design pixels. The old board took 0.7 of the screen each way, less its margin.
local WINDOW_SIZE = Vector2.new(1200, 640)
local EDGE = 15
local TITLE_HEIGHT = 56
local TOP_LABEL_HEIGHT = 32
local SIDE_WIDTH = 340
local NAME_HEIGHT = 36
local PORTRAIT_SIZE = 238
local OPTION_SIZE = 150
local BUTTON_SIZE = Vector2.new(360, 56)
local CARD_SIZE = 400
local CARD_BUTTON = Vector2.new(138, 48)
local GEM_SIZE = 32

-- A gem at each end of whatever shows a price in gems.
local function gems(scope: Scope): { Instance }
	return {
		Kit.Image(scope, {
			Name = "GemLeft",
			Image = GEM_IMAGE,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, Kit.Space.XS, 0.5, 0),
			Size = UDim2.fromOffset(GEM_SIZE, GEM_SIZE),
			ZIndex = 3,
		}),
		Kit.Image(scope, {
			Name = "GemRight",
			Image = GEM_IMAGE,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -Kit.Space.XS, 0.5, 0),
			Size = UDim2.fromOffset(GEM_SIZE, GEM_SIZE),
			ZIndex = 3,
		}),
	}
end

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

return {
	Merchants = { ExpertiseConfig.Merchant },

	Mount = function(scope: Scope, _gui: any, context: any): ScreenGui
		local ExpertiseService = Knit.GetService("ExpertiseService")

		local tokens = Bind.data(scope, "ExpertiseTokens.Current", 0)
		local limit = Bind.data(scope, "ExpertiseTokens.Limit", 1)
		local objective = Bind.data(scope, "Expertise.Mission.Objective", "None")

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
		local upgradeOpen = scope:Value(false)

		local window: ImageLabel
		local upgrade: ImageLabel

		upgrade = Kit.Panel(scope, {
			Name = "CapacityUpgrade",
			Image = "",
			Color = CARD_COLOR,
			Transparency = 0.02,
			Padding = Kit.Space.XL,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(1, 0, 0, CARD_SIZE),
			ZIndex = 5,
			Visible = scope:Computed(function(use): boolean
				-- The confirmation only exists while there is something left to buy.
				return use(upgradeOpen) and use(cost) ~= nil
			end),
			Children = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0.1, 0) }),
				Kit.Label(scope, {
					Name = "BodyText",
					Text = UPGRADE_TEXT,
					TextSize = Kit.TextSize.Body,
					Fit = true,
					Size = UDim2.new(1, 0, 1, -(GEM_SIZE + CARD_BUTTON.Y + 3 * Kit.Space.L)),
				}),
				Kit.Label(scope, {
					Name = "Cost",
					Text = costText,
					Color = GEMS_COLOR,
					TextSize = Kit.TextSize.Heading,
					Fit = true,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -(CARD_BUTTON.Y + Kit.Space.L)),
					Size = UDim2.new(0.7, 0, 0, GEM_SIZE + Kit.Space.S),
					Children = gems(scope),
				}),
				Kit.Button(scope, {
					Name = "Confirm",
					Text = "CONFIRM",
					Variant = "Green",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.fromOffset(CARD_BUTTON.X, CARD_BUTTON.Y),
					OnClick = function()
						ExpertiseService.UpgradeTokens:Fire()
					end,
				}),
				Kit.Button(scope, {
					Name = "Decline",
					Text = "DECLINE",
					Variant = "Red",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.fromScale(1, 1),
					Size = UDim2.fromOffset(CARD_BUTTON.X, CARD_BUTTON.Y),
					OnClick = function()
						upgradeOpen:set(false)
						ShopScreen.focus(scope, window)
					end,
				}),
			},
		})
		-- The card lies over the "Upgrade?" tag: a click on it must not reach the tag.
		upgrade.Active = true

		local contentTop = TITLE_HEIGHT + TOP_LABEL_HEIGHT + Kit.Space.M
		local footer = Kit.Space.S + ShopScreen.HINT_HEIGHT
		local leftWidth = -(SIDE_WIDTH + Kit.Space.XL)

		window = Kit.Panel(scope, {
			Name = "Window",
			Image = "",
			Color = BOARD_COLOR,
			Transparency = 0.5,
			Padding = Kit.Space.XL,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
			Children = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0.1, 0) }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = EDGE_COLOR,
					Thickness = EDGE,
					Transparency = 0.5,
				}),

				Kit.Label(scope, {
					Name = "Shop",
					Text = "Mission Assignment",
					TextSize = Kit.TextSize.Title,
					Fit = true,
					Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
				}),
				Kit.Label(scope, {
					Name = "TopLabel",
					Text = scope:Computed(function(use): string
						return `Expertise Tasks: {use(tokens)}/{use(limit)}`
					end),
					TextSize = Kit.TextSize.Heading,
					Fit = true,
					Position = UDim2.fromOffset(0, TITLE_HEIGHT),
					Size = UDim2.new(1, 0, 0, TOP_LABEL_HEIGHT),
				}),

				Kit.Well(scope, {
					Name = "Dia",
					Transparency = 0.5,
					Padding = Kit.Space.L,
					Position = UDim2.fromOffset(0, contentTop),
					Size = UDim2.new(1, leftWidth, 1, -(contentTop + footer + BUTTON_SIZE.Y + Kit.Space.L)),
					Children = {
						Kit.Label(scope, {
							-- A new line is picked whenever the situation changes, not on every token tick.
							Text = scope:Computed(function(use): string
								local lines = (LINES :: any)[use(state)]
								return lines[math.random(1, #lines)]
							end),
							TextSize = Kit.TextSize.Title,
							Fit = true,
							Size = UDim2.fromScale(1, 1),
						}),
					},
				}),
				-- Centred under the dialogue box, not under the whole board.
				scope:New("Frame")({
					Name = "Actions",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, -footer),
					Size = UDim2.new(1, leftWidth, 0, BUTTON_SIZE.Y),
					[Fusion.Children] = {
						Kit.Button(scope, {
							Name = "Accept",
							Variant = "Blue",
							Text = scope:Computed(function(use): string
								local current = use(state)
								if current == "Available" then
									return "Accept Mission"
								elseif current == "Running" then
									return "New Mission"
								end
								-- Nothing to take: the button only closes the window.
								return "Close"
							end),
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.fromScale(0.5, 0),
							Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y),
							OnClick = function()
								if Fusion.peek(state) ~= "NoTokens" then
									ExpertiseService.AcceptMission:Fire()
								end
								context.Close()
							end,
						}),
					},
				}),

				scope:New("Frame")({
					Name = "Expert",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, contentTop),
					Size = UDim2.new(0, SIDE_WIDTH, 1, -(contentTop + footer)),
					[Fusion.Children] = {
						Kit.Stack(scope, {
							Gap = Kit.Space.S,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Size = UDim2.fromScale(1, 1),
							Children = {
								Kit.Label(scope, {
									Name = "Label",
									LayoutOrder = 1,
									Text = "The Expert",
									TextSize = Kit.TextSize.Heading,
									Size = UDim2.new(1, 0, 0, NAME_HEIGHT),
								}),
								Kit.Image(scope, {
									Name = "Portrait",
									LayoutOrder = 2,
									Image = PORTRAIT_IMAGE,
									Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE),
								}),
								Kit.Panel(scope, {
									Name = "Option",
									LayoutOrder = 3,
									Image = OPTION_IMAGE,
									Size = UDim2.fromOffset(OPTION_SIZE, OPTION_SIZE),
									Children = {
										Kit.Label(scope, {
											Name = "Label",
											Text = "Upgrade?",
											TextSize = Kit.TextSize.Small,
											Fit = true,
											AnchorPoint = Vector2.new(0.5, 0.5),
											Position = UDim2.fromScale(0.5, 0.42),
											Size = UDim2.new(1, -Kit.Space.M, 0, 30),
										}),
										Kit.Button(scope, {
											Name = "Prompt",
											-- Grey once the capacity is at its maximum.
											Variant = scope:Computed(function(use): Kit.Variant
												return if use(cost) ~= nil then "Blue" else "Grey"
											end),
											Text = costText,
											TextColor = GEMS_COLOR,
											TextSize = Kit.TextSize.Small,
											AnchorPoint = Vector2.new(0.5, 0.5),
											Position = UDim2.fromScale(0.5, 0.8),
											Size = UDim2.new(1, -Kit.Space.S, 0, GEM_SIZE + Kit.Space.XS),
											OnClick = function()
												if Fusion.peek(cost) ~= nil then
													upgradeOpen:set(true)
													ShopScreen.focus(scope, upgrade)
												end
											end,
											Children = gems(scope),
										}),
									},
								}),
							},
						}),
						upgrade,
					},
				}),

				ShopScreen.Hint(scope, {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
				}),
			},
		})

		ShopScreen.closeOnMove(scope, context)

		return Kit.Screen(scope, {
			Name = context.Name,
			Children = { window },
		})
	end,
}
