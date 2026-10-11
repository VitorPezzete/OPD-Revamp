--!strict
--[[
	King of the Hill scoreboard: both team scores and the time left, shown only to the
	players of a running match.

	The old board: three burnt-edged sheets in a row at the top centre of the screen, the
	blue team's score on the left, the red team's on the right, each on a tinted plate, and
	the taller one between them with the time left. The three are a row now: the same
	width each, centred on one line.

	The match is a world event (WorldEventService / Modules.WorldEvents.KOTH); this screen
	renders its Score signal: (eventName, { Red, Blue, TimeLeft }?) where nil hides the board.
	The legacy client hid it on a (0, 0, 0) update, which also hid a real 0 - 0 at time up.

	Place. With a mouse the board is where the old one was: top centre, a third of the
	screen wide. On a touch screen the mission tracker stands at the top too, right of the
	side menu's column (Legacy.Screens.MissionGui, UI.Util.MenuSpace), and a board that wide
	would lie over it on a phone: there the board is as wide as the rework's and is kept
	right of the tracker's room whenever the middle of the screen is not.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local MenuSpace = require(ReplicatedStorage.Client.UI.Util.MenuSpace)
local ScreenScale = require(ReplicatedStorage.Client.UI.Util.ScreenScale)

type Scope = Fusion.Scope<typeof(Fusion)>
type Score = { Red: number, Blue: number, TimeLeft: number }

local EVENT_NAME = "KOTH"
-- Over the world, under the windows, like the rework's.
local DISPLAY_ORDER = 3

-- The old board on a 1920x1080 screen: its middle 17% of the way down.
local CELL_WIDTH = 220
local CELL_GAP = Kit.Space.XS
local BOARD_SIZE = Vector2.new(3 * CELL_WIDTH + 2 * CELL_GAP, 100)
local BOARD_POSITION = UDim2.fromScale(0.5, 0.1731)
local BOARD_TOP = 126
-- The score sheets are shorter than the clock's.
local SCORE_HEIGHT = 82
-- The plate inside a sheet.
local PLATE_INSET = 6
local BLUE = Color3.fromRGB(0, 85, 255)
local RED = Color3.fromRGB(255, 0, 0)
-- Larger than a title: the scores are read from across a fight.
local SCORE_SIZE = 44

-- Touch screens, in design pixels. The board's width there (the rework's).
local TOUCH_WIDTH = 460
-- What the mission tracker takes of the top of a touch screen, as Legacy.Screens.MissionGui
-- places it: this far from the left edge when no menu column stands there, and this wide.
-- Keep them equal to that screen.
local TRACKER_MARGIN = 16
local TRACKER_WIDTH = 308
local TRACKER_GAP = 12

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

		-- A sheet with a tinted plate and a text on it.
		local function cell(props: {
			Name: string,
			Height: number,
			Color: Color3,
			Transparency: number,
			Text: Fusion.UsedAs<string>,
			TextSize: number,
			Order: number,
		}): Instance
			return Kit.Panel(scope, {
				Name = props.Name,
				Image = Kit.Images.Sheet,
				Size = UDim2.fromOffset(CELL_WIDTH, props.Height),
				LayoutOrder = props.Order,
				Children = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.05, 0) }),
					scope:New("UIStroke")({ Thickness = 1, Color = Kit.Colors.Outline }),
					Kit.Well(scope, {
						Name = "Plate",
						Color = props.Color,
						Transparency = props.Transparency,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, -2 * PLATE_INSET, 1, -2 * PLATE_INSET),
						Children = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.05, 0) }),
							scope:New("UIStroke")({ Thickness = 1, Color = Kit.Colors.Outline }),
							Kit.Label(scope, {
								Name = "Text",
								Text = props.Text,
								TextSize = props.TextSize,
								Fit = true,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.new(1, -2 * Kit.Space.S, 1, -Kit.Space.S),
							}),
						},
					}),
				},
			})
		end

		local touch = MenuSpace.MidLeft
		-- On a touch screen the whole board is drawn smaller, proportions kept.
		local shrink = if touch then math.min(1, TOUCH_WIDTH / BOARD_SIZE.X) else 1

		local board = Kit.Stack(scope, {
			Name = "Frame",
			Direction = "Horizontal",
			Gap = CELL_GAP,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			AnchorPoint = if touch then Vector2.zero else Vector2.new(0.5, 0.5),
			Position = BOARD_POSITION,
			Size = UDim2.fromOffset(BOARD_SIZE.X, BOARD_SIZE.Y),
			Visible = scope:Computed(function(use): boolean
				return use(score) ~= nil
			end),
			Children = {
				if touch then scope:New("UIScale")({ Name = "TouchShrink", Scale = shrink }) else nil,
				cell({
					Name = "BlueTeam",
					Height = SCORE_HEIGHT,
					Color = BLUE,
					Transparency = 0.5,
					TextSize = SCORE_SIZE,
					Order = 1,
					Text = scope:Computed(function(use): string
						local current = use(score)
						return if current then tostring(current.Blue) else ""
					end),
				}),
				cell({
					Name = "Clock",
					Height = BOARD_SIZE.Y,
					Color = Kit.Colors.Sunken,
					Transparency = 0.5,
					TextSize = Kit.TextSize.Heading,
					Order = 2,
					Text = scope:Computed(function(use): string
						local current = use(score)
						local timeLeft = if current then math.max(0, math.floor(current.TimeLeft)) else 0
						return string.format("TimeLeft: %02d:%02d", timeLeft // 60, timeLeft % 60)
					end),
				}),
				cell({
					Name = "RedTeam",
					Height = SCORE_HEIGHT,
					Color = RED,
					Transparency = 0.5,
					TextSize = SCORE_SIZE,
					Order = 3,
					Text = scope:Computed(function(use): string
						local current = use(score)
						return if current then tostring(current.Red) else ""
					end),
				}),
			} :: { any },
		})

		local gui = Kit.Screen(scope, {
			Name = "KOTH",
			DisplayOrder = DISPLAY_ORDER,
			Children = { board },
		})
		-- Inside the notch of a phone, as the old gui.
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

		if touch then
			--[[
				Placed in design pixels from the tracker's own numbers: the scaler must not
				turn that into a share of the screen.
			]]
			local width = BOARD_SIZE.X * shrink
			board:SetAttribute("ScreenScale", false)

			-- Width of the gui in real pixels; the gui's UIScale makes design pixels of it.
			local guiWidth = scope:Value(gui.AbsoluteSize.X)
			table.insert(
				scope,
				gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					guiWidth:set(gui.AbsoluteSize.X)
				end)
			)
			scope:Hydrate(board)({
				Position = scope:Computed(function(use): UDim2
					local available = use(guiWidth) / math.max(use(ScreenScale.Factor), 0.01)
					local centred = (available - width) / 2
					local clear = math.max(TRACKER_MARGIN, use(MenuSpace.Edge)) + TRACKER_WIDTH + TRACKER_GAP
					-- Never off the right edge, even where both cannot fit side by side.
					local left = math.max(0, math.min(math.max(centred, clear), available - width))
					return UDim2.fromOffset(math.round(left), BOARD_TOP)
				end),
			})
		end

		return gui
	end,
}
