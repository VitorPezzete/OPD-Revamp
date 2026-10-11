--!strict
--[[
	King of the Hill scoreboard, top centre: both team scores and the time left, shown
	only to the players of a running match.

	The match is a world event (WorldEventService / Modules.WorldEvents.KOTH); this screen
	renders its Score signal: (eventName, { Red, Blue, TimeLeft }?) where nil hides the board.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope
type Score = { Red: number, Blue: number, TimeLeft: number }

local EVENT_NAME = "KOTH"

-- Under the health / haki bars.
local TOP_OFFSET = 116
local BOARD_SIZE = Vector2.new(460, 68)
local TEAM_WIDTH = 130

-- The two teams, in the theme's blue and red.
local BLUE = Theme.Colors.Shield
local RED = Theme.Colors.Danger

local function team(scope: Scope, name: string, title: string, color: Color3, points: Fusion.UsedAs<string>, side: number): Instance
	return UI.Panel(scope, {
		Name = name,
		AnchorPoint = Vector2.new(side, 0),
		Position = UDim2.fromScale(side, 0),
		Size = UDim2.new(0, TEAM_WIDTH, 1, 0),
		Color = Theme.Colors.Raised,
		Stroke = color,
		Radius = Theme.Radius.Small,
		Children = {
			UI.Label(scope, {
				Name = "Title",
				Text = title,
				Variant = "Tiny",
				Font = Theme.Fonts.Heading,
				Color = color,
				Position = UDim2.fromOffset(0, 4),
				Size = UDim2.new(1, 0, 0, 16),
			}),
			UI.Label(scope, {
				Name = "Points",
				Text = points,
				Variant = "Title",
				Position = UDim2.fromOffset(0, 18),
				Size = UDim2.new(1, 0, 1, -20),
			}),
		},
	})
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local score: Fusion.Value<Score?> = scope:Value(nil :: Score?)

		local service = Knit.GetService("WorldEventService")
		local connection = service.Score:Connect(function(eventName: unknown, payload: unknown)
			if eventName ~= EVENT_NAME then
				return
			end
			if type(payload) ~= "table" then
				score:set(nil)
				return
			end
			local data = payload :: { [string]: any }
			score:set({
				Red = tonumber(data.Red) or 0,
				Blue = tonumber(data.Blue) or 0,
				TimeLeft = tonumber(data.TimeLeft) or 0,
			})
		end)
		table.insert(scope, function()
			connection:Disconnect()
		end)

		local function points(key: "Red" | "Blue"): Fusion.UsedAs<string>
			return scope:Computed(function(use): string
				local current = use(score)
				return if current then tostring(current[key]) else ""
			end)
		end

		return UI.Screen(scope, {
			Name = "KOTH",
			DisplayOrder = 3,
			Children = {
				UI.Panel(scope, {
					Name = "Board",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, TOP_OFFSET),
					Size = UDim2.fromOffset(BOARD_SIZE.X, BOARD_SIZE.Y),
					Color = Theme.Colors.Background,
					Transparency = Theme.Transparency.Hud,
					Padding = Theme.Space.S,
					Visible = scope:Computed(function(use): boolean
						return use(score) ~= nil
					end),
					Children = {
						team(scope, "BlueTeam", "BLUE", BLUE, points("Blue"), 0),
						scope:New("Frame")({
							Name = "Time",
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.fromScale(0.5, 0),
							Size = UDim2.new(1, -(TEAM_WIDTH + Theme.Space.S) * 2, 1, 0),
							BackgroundTransparency = 1,
							[Fusion.Children] = {
								UI.Label(scope, {
									Name = "Title",
									Text = "KING OF THE HILL",
									Variant = "Tiny",
									Font = Theme.Fonts.Heading,
									Color = Theme.Colors.Accent,
									Position = UDim2.fromOffset(0, 4),
									Size = UDim2.new(1, 0, 0, 16),
								}),
								UI.Label(scope, {
									Name = "TimeLeft",
									Text = scope:Computed(function(use): string
										local current = use(score)
										local timeLeft = if current then math.max(0, math.floor(current.TimeLeft)) else 0
										return string.format("%02d:%02d", timeLeft // 60, timeLeft % 60)
									end),
									Variant = "Title",
									Font = Theme.Fonts.Mono,
									Position = UDim2.fromOffset(0, 18),
									Size = UDim2.new(1, 0, 1, -20),
								}),
							},
						}),
						team(scope, "RedTeam", "RED", RED, points("Red"), 1),
					},
				}),
			},
		})
	end,
}
