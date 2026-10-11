--!strict
--[[
	Challenges window: Levelling, Daily, Weekly and the repeatable challenges.

	Rows are built from ChallengeConfig; their state is derived from the replicated
	Challenges table with the same helpers the server uses to validate a claim. A click
	only fires ChallengeService.Claim with what is being claimed.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ChallengeConfig = require(ReplicatedStorage.Shared.Configs.ChallengeConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope
type State<T> = Fusion.StateObject<T>

type RowState = { Progress: number, Goal: number, Done: boolean }
type CompletionState = { Claimed: number, Total: number, Done: boolean }
type RewardView = { Icon: string, Color: Color3 }

local BERI: RewardView = { Icon = "rbxassetid://9859135533", Color = Theme.Colors.Beri }
local GEMS: RewardView = { Icon = "rbxassetid://1954296071", Color = Theme.Colors.Gems }
local TOKENS: RewardView = { Icon = "rbxassetid://9289714801", Color = Theme.Colors.Accent }

local TABS = {
	{ Key = "Level", Text = "Levelling" },
	{ Key = "Daily", Text = "Daily" },
	{ Key = "Weekly", Text = "Weekly" },
	{ Key = "General", Text = "Challenges" },
}
local DEFAULT_TAB = "Level"

local TAB_HEIGHT = 40
local ROW_HEIGHT = 78
local COMPLETION_HEIGHT = 96
local CLAIM_SIZE = UDim2.fromOffset(150, 44)
local REWARD_WIDTH = 150

local function rewardView(reward: ChallengeConfig.Reward): RewardView
	if reward.Gems then
		return GEMS
	end
	return if reward.CompassTokens then TOKENS else BERI
end

local function formatReward(reward: ChallengeConfig.Reward): string
	return Bind.formatNumber(reward.Beri or reward.Gems or reward.CompassTokens or 0)
end

-- Claim button of a row or completion panel; once done a green badge takes its place.
local function claim(
	scope: Scope,
	claimable: State<boolean>,
	done: State<boolean>,
	text: State<string>,
	doneText: string,
	onClaim: () -> ()
): Frame
	return scope:New("Frame")({
		Name = "ClaimHolder",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = CLAIM_SIZE,
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			UI.Button(scope, {
				Name = "Claim",
				Text = text,
				TextSize = Theme.TextSize.Small,
				Size = UDim2.fromScale(1, 1),
				Disabled = scope:Computed(function(use): boolean
					return not use(claimable)
				end),
				Visible = scope:Computed(function(use): boolean
					return not use(done)
				end),
				OnClick = function()
					if Fusion.peek(claimable) then
						onClaim()
					end
				end,
			}),
			UI.Badge(scope, {
				Name = "Done",
				Text = doneText,
				Color = Theme.Colors.Success,
				Soft = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Visible = done,
			}),
		},
	}) :: any
end

local function rewardLabel(scope: Scope, view: RewardView, text: Theme.UsedAs<string>): Frame
	return UI.Stack(scope, {
		Name = "Reward",
		Direction = "Horizontal",
		Gap = Theme.Space.XS,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(CLAIM_SIZE.X.Offset + Theme.Space.M), 0.5, 0),
		Size = UDim2.new(0, REWARD_WIDTH, 1, 0),
		Children = {
			UI.Image(scope, { Image = view.Icon, Size = UDim2.fromOffset(26, 26), LayoutOrder = 1 }),
			UI.Label(scope, { Text = text, Variant = "BodyBold", Color = view.Color, LayoutOrder = 2 }),
		},
	})
end

local function row(
	scope: Scope,
	order: number,
	text: Theme.UsedAs<string>,
	reward: RewardView,
	rewardText: Theme.UsedAs<string>,
	state: State<RowState>,
	doneText: string,
	onClaim: () -> ()
): Frame
	local done = scope:Computed(function(use): boolean
		return use(state).Done
	end)
	local claimable = scope:Computed(function(use): boolean
		local current = use(state)
		return not current.Done and current.Progress >= current.Goal
	end)
	local textWidth = -(CLAIM_SIZE.X.Offset + REWARD_WIDTH + Theme.Space.M * 2)

	return UI.Panel(scope, {
		Name = `Challenge_{order}`,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Color = Theme.Colors.Surface,
		Stroke = scope:Computed(function(use): Color3
			return if use(claimable) then Theme.Colors.BorderStrong else Theme.Colors.Border
		end),
		Padding = Theme.Space.M,
		Children = {
			UI.Label(scope, {
				Name = "Explanation",
				Text = text,
				Variant = "BodyBold",
				Scaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, textWidth, 0, 24),
			}),
			UI.ProgressBar(scope, {
				Name = "Progress",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, textWidth, 0, 20),
				Color = scope:Computed(function(use): Color3
					return if use(done) then Theme.Colors.Success else Theme.Colors.Primary
				end),
				Value = scope:Computed(function(use): number
					local current = use(state)
					return if current.Done then 1 else current.Progress / current.Goal
				end),
				Text = scope:Computed(function(use): string
					local current = use(state)
					return `{Bind.formatNumber(current.Progress)} / {Bind.formatNumber(current.Goal)}`
				end),
				TextSize = Theme.TextSize.Tiny,
			}),
			rewardLabel(scope, reward, rewardText),
			claim(scope, claimable, done, scope:Value("Claim"), doneText, onClaim),
		},
	})
end

local function completion(
	scope: Scope,
	title: Theme.UsedAs<string>,
	rewardText: string,
	state: State<CompletionState>,
	onClaim: () -> ()
): Frame
	local ratio = scope:Computed(function(use): number
		local current = use(state)
		return if current.Total > 0 then current.Claimed / current.Total else 0
	end)
	local done = scope:Computed(function(use): boolean
		return use(state).Done
	end)
	local claimable = scope:Computed(function(use): boolean
		return not use(state).Done and use(ratio) >= 1
	end)
	local textWidth = -(CLAIM_SIZE.X.Offset + REWARD_WIDTH + Theme.Space.M * 2)

	return UI.Panel(scope, {
		Name = "Completion",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, COMPLETION_HEIGHT),
		Color = Theme.Colors.Raised,
		Stroke = Theme.Colors.BorderStrong,
		Padding = Theme.Space.M,
		Children = {
			UI.Label(scope, {
				Name = "Title",
				Text = title,
				Variant = "Heading",
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, textWidth, 0, 28),
			}),
			UI.ProgressBar(scope, {
				Name = "Progress",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, textWidth, 0, 24),
				Color = Theme.Colors.Gems,
				Value = scope:Computed(function(use): number
					return if use(done) then 1 else use(ratio)
				end),
				Text = scope:Computed(function(use): string
					return `{math.floor((if use(done) then 1 else use(ratio)) * 100)}%`
				end),
			}),
			rewardLabel(scope, GEMS, rewardText),
			claim(
				scope,
				claimable,
				done,
				scope:Computed(function(use): string
					return if use(claimable) then "Claim" else "100% needed"
				end),
				"Complete",
				onClaim
			),
		},
	})
end

-- One tab: its rows in a scrolling list and, for the tabs that have one, the completion panel.
local function page(scope: Scope, key: string, selected: State<string>, rows: { any }, footer: Frame?): Frame
	local listHeight = if footer then -(COMPLETION_HEIGHT + Theme.Space.M) else 0

	return scope:New("Frame")({
		Name = key,
		Position = UDim2.fromOffset(0, TAB_HEIGHT + Theme.Space.M),
		Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + Theme.Space.M)),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return use(selected) == key
		end),
		[Fusion.Children] = {
			UI.Scroll(scope, {
				Size = UDim2.new(1, 0, 1, listHeight),
				Gap = Theme.Space.S,
				Children = rows,
			}),
			footer,
		} :: { any },
	}) :: any
end

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local ChallengeService = Knit.GetService("ChallengeService")

		local challenges = Bind.data(scope, "Challenges", {})
		local melee = Bind.data(scope, "Skills.Melee.Level", 0)
		local defense = Bind.data(scope, "Skills.Defense.Level", 0)
		local selected = scope:Value(DEFAULT_TAB)

		local pages: { any } = {}

		-- Levelling.
		local stage = scope:Computed(function(use): number
			return ChallengeConfig.GetStage(use(challenges))
		end)
		local levelPrize = scope:Computed(function(use): string
			return Bind.formatNumber(ChallengeConfig.GoalBeriPerStage * use(stage))
		end)
		local levelRows: { any } = {}
		for index, goal in ChallengeConfig.LevelGoals do
			levelRows[index] = row(
				scope,
				index,
				scope:Computed(function(use): string
					return ChallengeConfig.DescribeLevelGoal(use(challenges), goal)
				end),
				BERI,
				levelPrize,
				scope:Computed(function(use): RowState
					local progress, target, done =
						ChallengeConfig.GetLevelGoal(use(challenges), goal, use(melee), use(defense))
					return { Progress = progress, Goal = target, Done = done }
				end),
				"Complete",
				function()
					ChallengeService.Claim:Fire("Level", index)
				end
			)
		end
		table.insert(
			pages,
			page(
				scope,
				"Level",
				selected,
				levelRows,
				completion(
					scope,
					scope:Computed(function(use): string
						return `Stage {use(stage)} of {#ChallengeConfig.LevelStages}`
					end),
					Bind.formatNumber(ChallengeConfig.StageGems),
					scope:Computed(function(use): CompletionState
						local claimed, total, done = ChallengeConfig.GetLevelCompletion(use(challenges))
						return { Claimed = claimed, Total = total, Done = done }
					end),
					function()
						ChallengeService.Claim:Fire("Level", "All")
					end
				)
			)
		)

		-- Daily / weekly.
		for _, period in ChallengeConfig.Periods do
			local rows: { any } = {}
			for index, definition in ChallengeConfig.GetTasks(period) :: { ChallengeConfig.Task } do
				rows[index] = row(
					scope,
					index,
					definition.Text,
					rewardView(definition.Reward),
					formatReward(definition.Reward),
					scope:Computed(function(use): RowState
						local progress, goal, done = ChallengeConfig.GetPeriodic(use(challenges), period, index)
						return { Progress = progress, Goal = goal, Done = done }
					end),
					"Completed",
					function()
						ChallengeService.Claim:Fire(period, index)
					end
				)
			end
			table.insert(
				pages,
				page(
					scope,
					period,
					selected,
					rows,
					completion(
						scope,
						`{period} completion`,
						formatReward(ChallengeConfig.Completion[period]),
						scope:Computed(function(use): CompletionState
							local claimed, total, done = ChallengeConfig.GetCompletion(use(challenges), period)
							return { Claimed = claimed, Total = total, Done = done }
						end),
						function()
							ChallengeService.Claim:Fire(period, "All")
						end
					)
				)
			)
		end

		-- Repeatable challenges: never "done", claiming starts them over.
		local generalRows: { any } = {}
		for index, definition in ChallengeConfig.General do
			generalRows[index] = row(
				scope,
				index,
				definition.Text,
				rewardView(definition.Reward),
				formatReward(definition.Reward),
				scope:Computed(function(use): RowState
					local progress, goal = ChallengeConfig.GetGeneral(use(challenges), index)
					return { Progress = progress, Goal = goal, Done = false }
				end),
				"Completed",
				function()
					ChallengeService.Claim:Fire("General", index)
				end
			)
		end
		table.insert(pages, page(scope, "General", selected, generalRows, nil))

		return UI.Screen(scope, {
			Name = "Challenges",
			DisplayOrder = 10,
			Children = {
				UI.Window(scope, {
					Title = "Challenges",
					Size = UDim2.fromOffset(1000, 700),
					OnClose = context.Close,
					Children = {
						UI.Tabs(scope, {
							Tabs = TABS :: any,
							Selected = selected,
							TabSize = UDim2.fromOffset(160, TAB_HEIGHT),
						}),
						pages,
					},
				}),
			},
		})
	end,
}
