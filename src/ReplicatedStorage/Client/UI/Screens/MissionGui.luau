--!strict
--[[
	Mission tracker: the current Expertise mission with its progress bar, shown while a
	mission is active, and the spinning badge that announces a new Expertise level.

	Everything is derived from the replicated data (Expertise.Mission and
	Skills.Expertise.Level).

	Place. With a mouse the tracker hangs on the left edge, a quarter of the way down. On
	a touch screen that is where the side menu's column stands (UI.Util.MenuSpace), and it
	would lie over the tracker: there the tracker goes to the top of the screen, just
	right of the column and its handle, and follows them when the column is put away. A
	menu window or screen takes that room on such a screen, so the tracker waits hidden
	while one is open instead of showing through from under it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local ExpertiseConfig = require(ReplicatedStorage.Shared.Configs.ExpertiseConfig)
local MenuSpace = require(ReplicatedStorage.Client.UI.Util.MenuSpace)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local MISSION = "Expertise.Mission"
local LEVEL = "Skills.Expertise.Level"
local NONE = "None"

local BADGE_IMAGE = "rbxassetid://8553470936"
-- Seconds between the level changing and the badge appearing.
local BADGE_DELAY = 1
local BADGE_QUARTER_TURNS = 10
local BADGE_TURN_SECONDS = 0.5
local BADGE_TURN = TweenInfo.new(BADGE_TURN_SECONDS, Enum.EasingStyle.Linear)
local BADGE_FADE = TweenInfo.new(0.35)
-- Under-damped: the badge bounces in, as the old elastic tween did.
local BADGE_SPRING_SPEED = 18
local BADGE_SPRING_DAMPING = 0.5

local TRACKER_SIZE = UDim2.fromOffset(400, 132)
local BADGE_SIZE = UDim2.fromOffset(220, 220)
local EDGE_MARGIN = 16
-- Touch screens: narrower, so that on a phone it stays left of the middle of the screen
-- beside the menu column, and this far under the top bar.
local TOUCH_TRACKER_SIZE = UDim2.fromOffset(340, 132)
local TOUCH_TOP = 8

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local DataController = Knit.GetController("DataController")

		local objective = Bind.data(scope, `{MISSION}.Objective`, NONE)
		local target = Bind.data(scope, `{MISSION}.ObjectiveTarget`, "")
		local difficulty = Bind.data(scope, `{MISSION}.Difficulty`, "")
		local progress = Bind.data(scope, `{MISSION}.Progress`, 0)
		local requirement = Bind.data(scope, `{MISSION}.Requirement`, 0)

		local active = scope:Computed(function(use): boolean
			local current = use(objective)
			return current ~= NONE and current ~= ""
		end)

		-- Expertise level-up badge. Only real increases animate, not the first sync.
		local badgeShown = scope:Value(false)
		local badgeLevel = scope:Value(0)
		local badgeTurns = scope:Value(0)
		local badgeFade = scope:Tween(
			scope:Computed(function(use): number
				return if use(badgeShown) then 0 else 1
			end),
			BADGE_FADE
		)

		local animation: thread? = nil
		local function playLevelUp(level: number)
			animation = task.spawn(function()
				badgeLevel:set(level)
				task.wait(BADGE_DELAY)
				badgeShown:set(true)
				for _ = 1, BADGE_QUARTER_TURNS do
					badgeTurns:set(Fusion.peek(badgeTurns) + 1)
					task.wait(BADGE_TURN_SECONDS)
				end
				badgeShown:set(false)
				animation = nil
			end)
		end

		local known: number? = DataController:Get(LEVEL)
		local connection = DataController:Observe(LEVEL, function(level: number?)
			if type(level) ~= "number" then
				return
			end
			local previous = known
			known = level
			if previous and level > previous and not animation then
				playLevelUp(level)
			end
		end)
		table.insert(scope, function()
			connection:Disconnect()
			if animation then
				task.cancel(animation)
				animation = nil
			end
		end)

		-- Beside the menu column where it stands on this edge (see "Place" above).
		local beside = MenuSpace.MidLeft

		local tracker = UI.Panel(scope, {
			Name = "Tracker",
			Position = if beside
				then scope:Computed(function(use): UDim2
					return UDim2.fromOffset(math.max(EDGE_MARGIN, use(MenuSpace.Edge)), TOUCH_TOP)
				end)
				else UDim2.new(0, EDGE_MARGIN, 0.26, 0),
			Size = if beside then TOUCH_TRACKER_SIZE else TRACKER_SIZE,
			Color = Theme.Colors.Background,
			Transparency = Theme.Transparency.Hud,
			Padding = Theme.Space.M,
			Visible = if beside
				then scope:Computed(function(use): boolean
					return use(active) and not use(MenuSpace.Busy)
				end)
				else active,
			Children = {
				UI.Stack(scope, {
					Name = "Rows",
					Size = UDim2.fromScale(1, 1),
					Gap = Theme.Space.S,
					Children = {
						UI.Label(scope, {
							Name = "Header",
							Text = "MISSION OBJECTIVE",
							Variant = "Tiny",
							Font = Theme.Fonts.Heading,
							Color = Theme.Colors.Accent,
							LayoutOrder = 1,
						}),
						UI.Label(scope, {
							Name = "Description",
							Text = scope:Computed(function(use): string
								return ExpertiseConfig.DescribeMission(
									use(objective),
									use(difficulty),
									use(target),
									use(requirement)
								)
							end),
							Variant = "Body",
							Scaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Top,
							Size = UDim2.new(1, 0, 0, 46),
							LayoutOrder = 2,
						}),
						UI.ProgressBar(scope, {
							Name = "Bar",
							Value = scope:Computed(function(use): number
								local goal = use(requirement)
								return if goal > 0 then use(progress) / goal else 0
							end),
							Text = scope:Computed(function(use): string
								return `{Bind.formatNumber(use(progress))} / {Bind.formatNumber(use(requirement))}`
							end),
							Size = UDim2.new(1, 0, 0, 22),
							LayoutOrder = 3,
						}),
					},
				}),
			},
		})
		if beside then
			-- Placed in design pixels from the column's own numbers, like the menu's dock:
			-- the scaler must not turn that into a share of the screen.
			tracker:SetAttribute("ScreenScale", false)
		end

		return UI.Screen(scope, {
			Name = "MissionGui",
			DisplayOrder = 1,
			Children = {
				tracker,

				scope:New("Frame")({
					Name = "LevelUp",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.15),
					Size = BADGE_SIZE,
					BackgroundTransparency = 1,
					Visible = scope:Computed(function(use): boolean
						return use(badgeFade) < 1
					end),
					[Fusion.Children] = {
						UI.Image(scope, {
							Name = "Badge",
							Image = BADGE_IMAGE,
							Color = Theme.Colors.Primary,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = scope:Spring(
								scope:Computed(function(use): UDim2
									return if use(badgeShown) then UDim2.fromScale(1, 1) else UDim2.fromScale(0, 0)
								end),
								BADGE_SPRING_SPEED,
								BADGE_SPRING_DAMPING
							),
							Rotation = scope:Tween(
								scope:Computed(function(use): number
									return use(badgeTurns) * 90
								end),
								BADGE_TURN
							),
							Transparency = badgeFade,
						}),
						UI.Label(scope, {
							Name = "Level",
							Text = scope:Computed(function(use): string
								return tostring(use(badgeLevel))
							end),
							Variant = "Display",
							Outline = true,
							Transparency = badgeFade,
							Size = UDim2.fromScale(1, 1),
							ZIndex = 2,
						}),
					},
				}),
			},
		})
	end,
}
