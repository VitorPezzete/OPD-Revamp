--!strict
--[[
	Mission tracker (legacy MissionGui): the current Expertise mission with its progress
	bar, shown while a mission is active, and the spinning badge that announces a new
	Expertise level.

	The old tracker: a see-through black box on the left edge with "Mission Objective",
	the mission's description and a bar with "progress / requirement" written over it. The
	three are a column now, with the same margin on every side. The badge is the old yellow
	seal at the top centre of the screen, the new level written on it.

	Everything is derived from the replicated data (Expertise.Mission and
	Skills.Expertise.Level); the legacy script rebuilt the text from five ValueObjects on
	every change.

	Place. With a mouse the tracker is near the left edge, as the old one, but a little
	higher: just above the charge bars, which the old one was drawn across. On a touch screen that is where the side menu's column stands
	(UI.Util.MenuSpace), and it would lie over the tracker: there the tracker goes to the
	top of the screen, just right of the column and its handle, and follows them when the
	column is put away. A menu window or screen takes that room on such a screen, so the
	tracker waits hidden while one is open instead of showing through from under it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ExpertiseConfig = require(ReplicatedStorage.Shared.Configs.ExpertiseConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local MenuSpace = require(ReplicatedStorage.Client.UI.Util.MenuSpace)

type Scope = Fusion.Scope<typeof(Fusion)>

local MISSION = "Expertise.Mission"
local NONE = "None"
local ELASTIC = TweenInfo.new(0.5, Enum.EasingStyle.Elastic)
local LINEAR = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
local BADGE_SPINS = 8

-- The old tracker on a 1920x1080 screen. Legacy.Screens.KOTH keeps clear of this width
-- on a touch screen (its TRACKER_WIDTH): keep them equal.
local SIZE = Vector2.new(308, 152)
-- With a mouse: the old box stood a tenth of its width in from the edge, a quarter of the
-- way down, its lower half across the charge bars (Legacy.Screens.ChargingMenu: at this
-- edge, 172 tall, their feet at mid-height). It is held by its bottom just above them;
-- that gui covers the top bar and this one does not, hence half of the bar's 58 pixels.
local MOUSE_ANCHOR = Vector2.new(0, 1)
local MOUSE_POSITION = UDim2.new(0, 30, 0.5, -(172 + 29 + Kit.Space.M))
-- Touch screens: design pixels kept from the left edge when no menu column stands there,
-- and from the top of the screen.
local EDGE_MARGIN = 16
local TOUCH_TOP = 8
local BOX_TRANSPARENCY = 0.7
local HEADER_HEIGHT = 26
local BAR_HEIGHT = 24
-- The blue the old game gave everything of the Expertise.
local BAR_COLOR = Color3.fromRGB(121, 164, 255)

-- The level-up seal: a fifth of the screen's height, its middle 15% of the way down.
local BADGE_SIZE = 204
local BADGE_IMAGE = "rbxassetid://8553470936"
local BADGE_COLOR = Color3.fromRGB(255, 255, 0)
-- The level fills the seal; nothing else on the screen is that large.
local LEVEL_SIZE = 96

local function playLevelUp(badge: ImageLabel, label: TextLabel, level: number)
	label.Text = tostring(level)
	task.wait(1)

	local function spin(info: TweenInfo, goal: { [string]: any })
		goal.Rotation = badge.Rotation + 90
		TweenService:Create(badge, info, goal):Play()
	end

	spin(ELASTIC, { ImageTransparency = 0, Size = UDim2.fromScale(1, 1) })
	TweenService:Create(label, ELASTIC, {
		TextStrokeTransparency = Kit.OutlineTransparency,
		TextTransparency = 0,
		Size = UDim2.fromScale(1, 1),
	}):Play()
	task.wait(0.5)

	for _ = 1, BADGE_SPINS do
		spin(LINEAR, {})
		task.wait(0.5)
	end

	spin(ELASTIC, { ImageTransparency = 1, Size = UDim2.fromScale(0, 0) })
	TweenService:Create(label, ELASTIC, { TextStrokeTransparency = 1, TextTransparency = 1, Size = UDim2.fromScale(0, 0) }):Play()
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local objective = Bind.data(scope, `{MISSION}.Objective`, NONE)
		local target = Bind.data(scope, `{MISSION}.ObjectiveTarget`, "")
		local difficulty = Bind.data(scope, `{MISSION}.Difficulty`, "")
		local progress = Bind.data(scope, `{MISSION}.Progress`, 0)
		local requirement = Bind.data(scope, `{MISSION}.Requirement`, 0)

		local active = scope:Computed(function(use): boolean
			local current = use(objective)
			return current ~= NONE and current ~= ""
		end)

		-- Beside the menu column where it stands on this edge (see "Place" above).
		local beside = MenuSpace.MidLeft
		local shown = if beside
			then scope:Computed(function(use): boolean
				return use(active) and not use(MenuSpace.Busy)
			end)
			else active

		local inner = SIZE.Y - 2 * Kit.Space.M
		local tracker = Kit.Well(scope, {
			Name = "Frame",
			Transparency = BOX_TRANSPARENCY,
			Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
			AnchorPoint = if beside then Vector2.zero else MOUSE_ANCHOR,
			Position = if beside
				then scope:Computed(function(use): UDim2
					return UDim2.fromOffset(math.max(EDGE_MARGIN, use(MenuSpace.Edge)), TOUCH_TOP)
				end)
				else MOUSE_POSITION,
			Visible = shown,
			Children = {
				Kit.Stack(scope, {
					Name = "Rows",
					Size = UDim2.fromScale(1, 1),
					Gap = Kit.Space.S,
					Padding = Kit.Space.M,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Children = {
						Kit.Label(scope, {
							Name = "Header",
							Text = "Mission Objective",
							TextSize = Kit.TextSize.Body,
							Fit = true,
							Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
							LayoutOrder = 1,
						}),
						Kit.Label(scope, {
							Name = "Description",
							Text = scope:Computed(function(use): string
								return ExpertiseConfig.DescribeMission(
									use(objective),
									use(difficulty),
									use(target),
									use(requirement)
								)
							end),
							TextSize = Kit.TextSize.Small,
							Bold = false,
							Fit = true,
							-- What the header, the bar and the gaps leave.
							Size = UDim2.new(1, 0, 0, inner - HEADER_HEIGHT - BAR_HEIGHT - 2 * Kit.Space.S),
							LayoutOrder = 2,
						}),
						Kit.Bar(scope, {
							Name = "Bar",
							Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
							Color = BAR_COLOR,
							LayoutOrder = 3,
							Value = scope:Computed(function(use): number
								local goal = use(requirement)
								return if goal > 0 then math.clamp(use(progress) / goal, 0, 1) else 0
							end),
							Text = scope:Computed(function(use): string
								return `{Bind.formatNumber(use(progress))} / {Bind.formatNumber(use(requirement))}`
							end),
						}),
					},
				}),
			},
		})
		if beside then
			-- Placed in design pixels from the column's own numbers: the scaler must not turn
			-- that into a share of the screen.
			tracker:SetAttribute("ScreenScale", false)
		end

		-- Expertise level-up badge. It grows out of its middle and shrinks back into it.
		local badge: ImageLabel = scope:New("ImageLabel")({
			Name = "Seal",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0, 0),
			Image = BADGE_IMAGE,
			ImageColor3 = BADGE_COLOR,
			ImageTransparency = 1,
		}) :: any
		local label = Kit.Label(scope, {
			Name = "Level",
			Text = "1",
			TextSize = LEVEL_SIZE,
			Fit = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0, 0),
			ZIndex = 2,
		})
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1

		-- Only real increases animate, not the first sync.
		local DataController = Knit.GetController("DataController")
		local known: number? = DataController:Get("Skills.Expertise.Level")
		local animation: thread? = nil
		local connection = DataController:Observe("Skills.Expertise.Level", function(level: number?)
			if type(level) ~= "number" then
				return
			end
			local previous = known
			known = level
			if previous and level > previous and not animation then
				animation = task.spawn(function()
					playLevelUp(badge, label, level)
					animation = nil
				end)
			end
		end)
		table.insert(scope, function()
			connection:Disconnect()
			-- The interface can be swapped in the middle of it: the badge is gone with the gui.
			if animation then
				task.cancel(animation)
				animation = nil
			end
		end)

		return Kit.Screen(scope, {
			Name = "MissionGui",
			-- Over the world, under the windows, like the rework's.
			DisplayOrder = 1,
			Children = {
				tracker,
				scope:New("Frame")({
					Name = "LevelUp",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.15),
					Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
					[Fusion.Children] = { badge, label },
				}),
			},
		})
	end,
}
