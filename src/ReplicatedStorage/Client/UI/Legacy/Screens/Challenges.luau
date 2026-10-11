--!strict
--[[
	Challenges window (menu tab H): Levelling, Daily, Weekly and the repeatable challenges.

	The legacy controller was 1,500 lines of one hand-written function per row. Rows are
	now bound in loops from ChallengeConfig; their state is derived from the replicated
	Challenges table with the same helpers the server uses to validate a claim. A click
	only fires ChallengeService.Claim with what is being claimed.

	The layout carries one row per challenge the old game had. The lists are ChallengeConfig's
	now: a challenge without a row gets a copy of the list's last one, placed one step
	further down, and a row without a challenge is hidden. What a row or a completion panel
	pays (amount and currency icon) comes from the config too, not from the drawing.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ChallengeConfig = require(ReplicatedStorage.Shared.Configs.ChallengeConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local GamepadWindow = require(ReplicatedStorage.Client.UI.Legacy.Components.GamepadWindow)

type Scope = Fusion.Scope<typeof(Fusion)>
type Computed<T> = Fusion.StateObject<T>

type RowState = { Progress: number, Goal: number, Done: boolean }
type CompletionState = { Claimed: number, Total: number, Done: boolean }

local CLAIMABLE_COLOR = Color3.fromRGB(60, 151, 221)
local LOCKED_COLOR = Color3.fromRGB(83, 110, 143)
local DONE_COLOR = Color3.fromRGB(108, 220, 89)
local TAB_SELECTED_COLOR = Color3.fromRGB(147, 104, 89)
local TAB_IDLE_COLOR = Color3.fromRGB(113, 79, 68)

local SPIN = TweenInfo.new(24, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)

-- Currency icons of a row's prize (the layout's own art).
local BERI_ICON = "rbxassetid://9859135533"
local GEMS_ICON = "rbxassetid://1954296071"
local TOKENS_ICON = "rbxassetid://9289714801"

local ROW_PREFIX = "Challenge_"
-- The line under the gem of the levelling panel: which stage the four goals belong to.
-- Shares of the completion panel, between its gem and its progress bar.
local STAGE_POSITION = UDim2.fromScale(0.5, 0.63)
local STAGE_SIZE = UDim2.fromScale(0.9, 0.06)

-- Tab button -> the frame it shows.
local TABS = {
	Button = "LevelUpFrame",
	Button1 = "DailyFrame",
	Button2 = "WeeklyFrame",
	Button4 = "ChallengesFrame",
}
local DEFAULT_TAB = "Button"

local function formatReward(reward: ChallengeConfig.Reward): string
	return Bind.formatNumber(reward.Beri or reward.Gems or reward.CompassTokens or 0)
end

local function rewardIcon(reward: ChallengeConfig.Reward): string
	if reward.Gems then
		return GEMS_ICON
	end
	return if reward.CompassTokens then TOKENS_ICON else BERI_ICON
end

--[[
	The rows of a list for `count` challenges: the layout's rows by index, copies of the
	last one for the challenges it has none for (one step further down each, the step
	being the distance between its first two rows), and every row beyond `count` hidden.
	Empty when the list has no row to copy.
]]
local function prepareRows(scope: Scope, list: Instance, count: number): { Instance }
	local existing: { [number]: GuiObject } = {}
	local highest = 0
	for _, child in list:GetChildren() do
		local index = tonumber(string.match(child.Name, "^" .. ROW_PREFIX .. "(%d+)$"))
		if index and child:IsA("GuiObject") then
			existing[index] = child
			highest = math.max(highest, index)
			if index > count then
				child.Visible = false
			end
		end
	end

	local rows: { Instance } = {}
	local last = existing[highest]
	if not last then
		return rows
	end
	local first, second = existing[1], existing[2]
	local step = if first and second then second.Position.Y.Scale - first.Position.Y.Scale else last.Size.Y.Scale * 1.5

	for index = 1, count do
		local row = existing[index]
		if not row then
			local copy = last:Clone()
			copy.Name = ROW_PREFIX .. index
			copy.Position = UDim2.new(
				last.Position.X.Scale,
				last.Position.X.Offset,
				last.Position.Y.Scale + step * (index - highest),
				last.Position.Y.Offset
			)
			copy.Parent = list
			table.insert(scope, copy)
			row = copy
		end
		rows[index] = row
	end
	return rows
end

-- What a row pays: the amount and the icon of its currency.
local function setPrize(row: Instance, reward: ChallengeConfig.Reward)
	local prize = Bind.find(row, "PrizeFrame")
	Bind.find(prize, "TextLabel").Text = formatReward(reward)
	local icon = prize:FindFirstChildOfClass("ImageLabel")
	if icon then
		icon.Image = rewardIcon(reward)
	end
end

-- Claim button shared by rows and completion panels: blue when claimable, green when done.
local function bindClaim(
	scope: Scope,
	holder: Instance,
	claimable: Computed<boolean>,
	done: Computed<boolean>,
	text: Computed<string>,
	onClaim: () -> ()
)
	local button = Bind.find(holder, "Claim") :: GuiButton
	Bind.props(scope, button, {
		BackgroundColor3 = scope:Computed(function(use)
			if use(done) then
				return DONE_COLOR
			end
			return if use(claimable) then CLAIMABLE_COLOR else LOCKED_COLOR
		end),
		AutoButtonColor = claimable,
	})
	Bind.props(scope, Bind.find(button, "TextLabel"), {
		Text = text,
		TextTransparency = scope:Computed(function(use)
			return if use(done) or use(claimable) then 0 else 0.5
		end),
	})
	Bind.props(scope, Bind.find(holder, "DarkFrame"), {
		BackgroundTransparency = scope:Computed(function(use)
			return if use(done) then 0.3 else 1
		end),
	})
	Bind.click(scope, button, function()
		if Fusion.peek(claimable) then
			onClaim()
		end
	end)
end

local function bindRow(scope: Scope, row: Instance, state: Computed<RowState>, doneText: string, onClaim: () -> ())
	local claimable = scope:Computed(function(use)
		local current = use(state)
		return not current.Done and current.Progress >= current.Goal
	end)
	local done = scope:Computed(function(use)
		return use(state).Done
	end)

	Bind.props(scope, Bind.find(row, "Progress/Bar"), {
		Size = scope:Computed(function(use)
			local current = use(state)
			-- A claimed challenge stays full, whatever its counter was reset to.
			local ratio = if current.Done then 1 else current.Progress / math.max(current.Goal, 1)
			return UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		end),
	})
	Bind.props(scope, Bind.find(row, "Progress/LabelProgress"), {
		Text = scope:Computed(function(use)
			local current = use(state)
			return `{Bind.formatNumber(current.Progress)}/{Bind.formatNumber(current.Goal)}`
		end),
	})
	bindClaim(scope, row, claimable, done, scope:Computed(function(use)
		return if use(done) then doneText else "Claim"
	end), onClaim)
end

local function bindCompletion(
	scope: Scope,
	panel: Instance,
	reward: ChallengeConfig.Reward,
	state: Computed<CompletionState>,
	onClaim: () -> ()
)
	local ratio = scope:Computed(function(use)
		local current = use(state)
		return if current.Total > 0 then current.Claimed / current.Total else 0
	end)
	local claimable = scope:Computed(function(use)
		return not use(state).Done and use(ratio) >= 1
	end)
	local done = scope:Computed(function(use)
		return use(state).Done
	end)
	-- Once claimed the panel stays full, whatever the rows were reset to.
	local shown = scope:Computed(function(use)
		return if use(done) then 1 else math.clamp(use(ratio), 0, 1)
	end)

	-- What the panel pays is the config's figure, not the one drawn in the layout.
	local header = Bind.tryFind(panel, "Header")
	if header and reward.Gems then
		header.Text = `Gems x{Bind.formatNumber(reward.Gems)}`
	end

	Bind.props(scope, Bind.find(panel, "Progress/Bar"), {
		Size = scope:Computed(function(use)
			return UDim2.fromScale(use(shown), 1)
		end),
	})
	Bind.props(scope, Bind.find(panel, "Progress/LabelProgress"), {
		Text = scope:Computed(function(use)
			return `{math.floor(use(shown) * 100)}%`
		end),
	})
	bindClaim(scope, panel, claimable, done, scope:Computed(function(use)
		if use(done) then
			return "Complete"
		end
		return if use(claimable) then "Claim" else "100% Completion"
	end), onClaim)

	local effect = Bind.tryFind(panel, "Effect")
	if effect then
		local tween = TweenService:Create(effect, SPIN, { Rotation = effect.Rotation + 360 })
		tween:Play()
		table.insert(scope, function()
			tween:Cancel()
		end)
	end
end

return {
	Layout = "Challenges",

	Mount = function(scope: Scope, gui: ScreenGui, context: any)
		local ChallengeService = Knit.GetService("ChallengeService")
		local window = Bind.find(gui, "Frame") :: GuiObject
		local content = Bind.find(window, "Frame")
		window.Visible = true
		-- The layout has no close button (the menu's Challenges button toggles the
		-- window); for the gamepad it is a window all the same: the selection on open, B
		-- closes it.
		GamepadWindow.mark(scope, gui, context.Close)

		for _, descendant in gui:GetDescendants() do
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
				descendant.Font = Enum.Font.ArimoBold
			end
		end

		local challenges = Bind.data(scope, "Challenges", {})
		local melee = Bind.data(scope, "Skills.Melee.Level", 0)
		local defense = Bind.data(scope, "Skills.Defense.Level", 0)

		local selected = scope:Value(DEFAULT_TAB)
		for buttonName, frameName in TABS do
			local button = Bind.find(window, buttonName) :: GuiButton
			Bind.props(scope, button, {
				BackgroundColor3 = scope:Computed(function(use)
					return if use(selected) == buttonName then TAB_SELECTED_COLOR else TAB_IDLE_COLOR
				end),
			})
			Bind.props(scope, Bind.find(content, frameName), {
				Visible = scope:Computed(function(use)
					return use(selected) == buttonName
				end),
			})
			Bind.click(scope, button, function()
				selected:set(buttonName)
			end)
		end
		local monthly = Bind.tryFind(content, "MonthlyFrame")
		if monthly then
			monthly.Visible = false
		end

		-- Daily / weekly.
		for _, period in ChallengeConfig.Periods do
			local frame = Bind.find(content, period .. "Frame")
			local tasks = ChallengeConfig.GetTasks(period) :: { ChallengeConfig.Task }
			local rows = prepareRows(scope, Bind.find(frame, "ScrollingFrame"), #tasks)
			for index, task in tasks do
				local row = rows[index]
				if not row then
					continue
				end
				Bind.find(row, "Progress/LabelExplanation").Text = task.Text
				setPrize(row, task.Reward)

				local state = scope:Computed(function(use): RowState
					local progress, goal, done = ChallengeConfig.GetPeriodic(use(challenges), period, index)
					return { Progress = progress, Goal = goal, Done = done }
				end)
				bindRow(scope, row, state, "Completed", function()
					ChallengeService.Claim:Fire(period, index)
				end)
			end

			local completion = scope:Computed(function(use): CompletionState
				local claimed, total, done = ChallengeConfig.GetCompletion(use(challenges), period)
				return { Claimed = claimed, Total = total, Done = done }
			end)
			local panel = Bind.find(frame, "CompletionFrame")
			bindCompletion(scope, panel, ChallengeConfig.Completion[period], completion, function()
				ChallengeService.Claim:Fire(period, "All")
			end)
		end

		-- Repeatable challenges: never "done", claiming starts them over.
		local generalFrame = Bind.find(content, "ChallengesFrame")
		local generalRows = prepareRows(scope, Bind.find(generalFrame, "ScrollingFrame"), #ChallengeConfig.General)
		for index, task in ChallengeConfig.General do
			local row = generalRows[index]
			if not row then
				continue
			end
			Bind.find(row, "Progress/LabelExplanation").Text = task.Text
			setPrize(row, task.Reward)

			local state = scope:Computed(function(use): RowState
				local progress, goal = ChallengeConfig.GetGeneral(use(challenges), index)
				return { Progress = progress, Goal = goal, Done = false }
			end)
			bindRow(scope, row, state, "Completed", function()
				ChallengeService.Claim:Fire("General", index)
			end)
		end

		-- Levelling.
		local levelFrame = Bind.find(content, "LevelUpFrame")
		local stage = scope:Computed(function(use): number
			return ChallengeConfig.GetStage(use(challenges))
		end)
		local prize = scope:Computed(function(use)
			return Bind.formatNumber(ChallengeConfig.GoalBeriPerStage * use(stage))
		end)
		local levelRows = prepareRows(scope, Bind.find(levelFrame, "ScrollingFrame"), #ChallengeConfig.LevelGoals)
		for index, goal in ChallengeConfig.LevelGoals do
			local row = levelRows[index]
			if not row then
				continue
			end
			Bind.props(scope, Bind.find(row, "Progress/LabelExplanation"), {
				Text = scope:Computed(function(use)
					return ChallengeConfig.DescribeLevelGoal(use(challenges), goal)
				end),
			})
			-- A levelling goal always pays Beri.
			setPrize(row, { Beri = 0 })
			Bind.props(scope, Bind.find(row, "PrizeFrame/TextLabel"), { Text = prize })

			local state = scope:Computed(function(use): RowState
				local progress, target, done = ChallengeConfig.GetLevelGoal(
					use(challenges),
					goal,
					tonumber(use(melee)) or 0,
					tonumber(use(defense)) or 0
				)
				return { Progress = progress, Goal = target, Done = done }
			end)
			bindRow(scope, row, state, "Complete", function()
				ChallengeService.Claim:Fire("Level", index)
			end)
		end

		local levelCompletion = scope:Computed(function(use): CompletionState
			local claimed, total, done = ChallengeConfig.GetLevelCompletion(use(challenges))
			return { Claimed = claimed, Total = total, Done = done }
		end)
		local levelPanel = Bind.find(levelFrame, "CompletionFrame")
		bindCompletion(scope, levelPanel, { Gems = ChallengeConfig.StageGems }, levelCompletion, function()
			ChallengeService.Claim:Fire("Level", "All")
		end)

		-- Which stage the four goals belong to: a copy of the panel's header, smaller.
		local header = Bind.tryFind(levelPanel, "Header")
		if header and header:IsA("TextLabel") then
			local stageLabel = header:Clone()
			stageLabel.Name = "Stage"
			stageLabel.Position = STAGE_POSITION
			stageLabel.Size = STAGE_SIZE
			stageLabel.Parent = levelPanel
			table.insert(scope, stageLabel)
			Bind.props(scope, stageLabel, {
				Text = scope:Computed(function(use)
					return `Stage {use(stage)} of {#ChallengeConfig.LevelStages}`
				end),
			})
		end
	end,
}
