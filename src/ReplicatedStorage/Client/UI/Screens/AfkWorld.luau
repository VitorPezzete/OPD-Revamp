--!strict
--[[
	AFK place only: the whole screen. A black cover over the (empty) world and over every
	other piece of the interface, with what the player has earned so far, the time left
	until the next roll and the way back to the main game.

	Nothing is counted here. The amounts are the replicated data (data.AFK_World, filled
	by AfkWorldService and paid out by the AFK NPC of the main place); the countdown runs
	to the server time AfkWorldService published on the Player. The only request is
	Return, which carries nothing.

	The legacy screen counted 60 s from the last event it received, whatever the server
	was doing, and teleported back by itself.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local AfkStateConfig = require(ReplicatedStorage.Shared.Configs.AfkStateConfig)
local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

-- { row name, label, data.AFK_World field, colour of the amount }
local REWARDS: { { any } } = {
	{ "BeriReward", "Beri", "Beri", Theme.Colors.Beri },
	{ "GemsReward", "Gems", "Gems", Theme.Colors.Gems },
	{ "CompassReward", "Compass", "Compass", Theme.Colors.Text },
	{ "SilverReward", "Silver Compass", "SilverCompass", Theme.Colors.Text },
	{ "GoldenReward", "Golden Compass", "GoldenCompass", Theme.Colors.Warning },
}

local ATTRIBUTES = AfkStateConfig.Attributes
-- Above every screen of the game (the highest is 101); the loading screen (1000) fades
-- out over it.
local DISPLAY_ORDER = 500
-- How often the countdown looks at the clock: the text only changes once a second.
local CLOCK_INTERVAL = 0.25
-- "Teleporting..." gives up after this long and the button can be pressed again.
local RETURN_TIMEOUT = 15

local WIDTH = 520
local TIMER_HEIGHT = 64
local TITLE_HEIGHT = 44
local ROW_HEIGHT = 46
local ROW_GAP = Theme.Space.XS
local BUTTON_HEIGHT = 56
local EDGE = 64

local localPlayer = Players.LocalPlayer

return {
	-- Mounted in the AFK place only; elsewhere nothing ever opens it.
	Persistent = PlaceConfig.Role == "AFK",

	Mount = function(scope: Scope, _gui: any, _context: any)
		local nextRoll = Bind.attribute(scope, localPlayer, ATTRIBUTES.NextRoll, 0)
		-- Whole seconds until the next roll; -1 while the server has not announced one.
		local remaining = scope:Value(-1)
		local returning = scope:Value(false)

		-- The game's own player list is not loaded in this place, and the engine's would
		-- draw over the cover. SetCoreGuiEnabled errors until the core scripts are up.
		task.spawn(function()
			for _ = 1, 20 do
				if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false) then
					break
				end
				task.wait(0.5)
			end
		end)

		local alive = true
		table.insert(scope, function()
			alive = false
		end)
		task.spawn(function()
			while alive do
				local target = Fusion.peek(nextRoll)
				if type(target) == "number" and target > 0 then
					remaining:set(math.max(0, math.ceil(target - Workspace:GetServerTimeNow())))
				else
					remaining:set(-1)
				end
				task.wait(CLOCK_INTERVAL)
			end
		end)

		local function askToReturn()
			if Fusion.peek(returning) then
				return
			end
			returning:set(true)

			local function release()
				if alive then
					returning:set(false)
				end
			end
			Knit.GetService("AfkWorldService")
				:Return()
				:andThen(function(accepted: boolean)
					-- Refused (rate limit, Studio): the button comes back at once.
					if not accepted then
						release()
						return
					end
					-- Accepted: the place changes under the screen; this only covers a
					-- teleport that never happens.
					task.delay(RETURN_TIMEOUT, release)
				end)
				:catch(release)
		end

		local rows: { any } = {}
		for index, reward in REWARDS do
			local amount = Bind.data(scope, `AFK_World.{reward[3]}`, 0)
			rows[index] = UI.Panel(scope, {
				Name = reward[1],
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				Color = Theme.Colors.Raised,
				Padding = Theme.Space.M,
				Children = {
					UI.Label(scope, {
						Name = "Title",
						Text = reward[2],
						Variant = "Body",
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.fromScale(0.6, 1),
					}),
					UI.Label(scope, {
						Name = "Amount",
						Text = scope:Computed(function(use): string
							local saved = use(amount)
							return Bind.formatNumber(if type(saved) == "number" then saved else 0)
						end),
						Variant = "BodyBold",
						Color = reward[4],
						TextXAlignment = Enum.TextXAlignment.Right,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromScale(0.4, 1),
					}),
				},
			})
		end

		local listHeight = #REWARDS * ROW_HEIGHT + (#REWARDS - 1) * ROW_GAP
		local listTop = TITLE_HEIGHT + Theme.Space.M
		local panelHeight = Theme.Space.L * 2 + listTop + listHeight

		return UI.Screen(scope, {
			Name = "AfkWorld",
			DisplayOrder = DISPLAY_ORDER,
			IgnoreGuiInset = true,
			Children = {
				scope:New("Frame")({
					Name = "Cover",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.Colors.Black,
					BorderSizePixel = 0,
					-- Swallows every click meant for what lies under it.
					Active = true,
					[Fusion.Children] = {
						UI.Panel(scope, {
							Name = "RewardTime",
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 0, EDGE),
							Size = UDim2.fromOffset(WIDTH, TIMER_HEIGHT),
							Children = {
								UI.Label(scope, {
									Name = "Countdown",
									Text = scope:Computed(function(use): string
										local seconds = use(remaining)
										if seconds < 0 then
											return "Next Reward In --:--"
										end
										return string.format("Next Reward In %02d:%02d", seconds // 60, seconds % 60)
									end),
									Variant = "Heading",
									Size = UDim2.fromScale(1, 1),
								}),
							},
						}),

						UI.Panel(scope, {
							Name = "Rewards",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromOffset(WIDTH, panelHeight),
							Padding = Theme.Space.L,
							Children = {
								UI.Label(scope, {
									Name = "Title",
									Text = "Rewards",
									Variant = "Title",
									Color = Theme.Colors.Accent,
									Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
								}),
								UI.Stack(scope, {
									Name = "List",
									Position = UDim2.fromOffset(0, listTop),
									Size = UDim2.new(1, 0, 0, listHeight),
									Gap = ROW_GAP,
									Children = rows,
								}),
							},
						}),

						UI.Button(scope, {
							Name = "Return",
							-- The main brown of the palette, as the panels: the dark default read as a different colour.
							Variant = "Secondary",
							Text = scope:Computed(function(use): string
								return if use(returning) then "Teleporting..." else "Return To The Main Game"
							end),
							Disabled = returning,
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.new(0.5, 0, 1, -EDGE),
							Size = UDim2.fromOffset(WIDTH, BUTTON_HEIGHT),
							OnClick = askToReturn,
						}),
					},
				}),
			},
		})
	end,
}
