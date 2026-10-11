--!strict
--[[
	Menu tab "Stats": the five skills with their exp bars and the total level, both devil
	fruits with their affinities (chart and figures) and aura colours, and the counters
	(Beri, Gems, Kills, Bounty, Fish, Sam's quest timer and compass tokens).

	Read-only: the only action is "Edit aura", which opens the aura editor in place of
	this tab. Everything derives from the replicated data.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local UI = require(ReplicatedStorage.Client.UI.Components)
local AffinityChart = require(ReplicatedStorage.Client.UI.Components.AffinityChart)

local Kit = require(script.Parent.Kit)

type Scope = Theme.Scope
type SkillName = DataTypes.SkillName

local peek = Fusion.peek

local AURA_SCREEN = "CustomizeAuras"
local SKILLS: { SkillName } = { "Defense", "Melee", "Sniper", "Sword", "Haki" }
local AFFINITY_SKILLS = { "Defense", "Melee", "Sniper", "Sword" }

local SKILL_COLORS: { [string]: Color3 } = {
	Defense = Theme.Colors.Success,
	Melee = Theme.Colors.Danger,
	Sniper = Theme.Colors.Warning,
	Sword = Theme.Colors.Gems,
	Haki = Theme.Colors.Haki,
}

local COUNTERS = {
	{ Label = "Beri", Path = "Economy.Beri", Color = Theme.Colors.Beri, Prefix = "$" },
	{ Label = "Gems", Path = "Economy.Gems", Color = Theme.Colors.Gems, Prefix = "" },
	{ Label = "Kills", Path = "Combat.Kills", Color = Theme.Colors.Text, Prefix = "" },
	{ Label = "Bounty", Path = "Combat.Bounty", Color = Theme.Colors.Text, Prefix = "" },
	{ Label = "Fish", Path = "Economy.Fish", Color = Theme.Colors.Text, Prefix = "" },
}

local WINDOW_SIZE = Vector2.new(820, 640)
local LEFT_WIDTH = 384
local COUNTERS_HEIGHT = 132
local SKILL_ROW_HEIGHT = 52
-- The affinity chart is square; the area under a fruit's name is about 177 high.
local CHART_SIZE = 150
local AFFINITY_ROW_HEIGHT = 26
local AFFINITY_KEY = 12

local function formatTimer(seconds: number): string
	if seconds <= 0 then
		return "Ready!"
	end
	local minutes = math.floor(seconds / 60)
	local rest = seconds % 60
	return if minutes == 0 then `{rest}s` else `{minutes}m {rest}s`
end

-- Name, level and exp bar of one skill; also returns the level state for the total.
local function skillRow(scope: Scope, skill: SkillName, order: number): (Instance, Fusion.Value<any>)
	local level = Bind.data(scope, `Skills.{skill}.Level`, 0)
	local exp = Bind.data(scope, `Skills.{skill}.Exp`, 0)

	local ratio = scope:Computed(function(use): number
		local requirement = StatConfig.GetExpRequirement(skill, tonumber(use(level)) or 0)
		return if requirement > 0 then math.clamp((tonumber(use(exp)) or 0) / requirement, 0, 1) else 0
	end)

	local bar = UI.ProgressBar(scope, {
		Name = "Exp",
		Value = ratio,
		Color = SKILL_COLORS[skill],
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 18),
	})

	-- Hovering the bar shows the exact progress, kept current while the mouse stays on it.
	local hovering = false
	local function showProgress()
		local percent = math.floor(peek(ratio) * 10000) / 100
		Tooltip.show(`{percent}%`)
	end
	local function stopHover()
		if hovering then
			hovering = false
			Tooltip.hide()
		end
	end
	Bind.connect(scope, bar.MouseEnter, function()
		hovering = true
		showProgress()
	end)
	Bind.connect(scope, bar.MouseLeave, stopHover)
	scope:Observer(ratio):onChange(function()
		if hovering then
			showProgress()
		end
	end)
	table.insert(scope, stopHover)

	local row = scope:New("Frame")({
		Name = skill,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, SKILL_ROW_HEIGHT),
		[Fusion.Children] = {
			UI.Label(scope, {
				Name = "Skill",
				Text = skill,
				Variant = "BodyBold",
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0.6, 0, 0, 26),
			}),
			UI.Label(scope, {
				Name = "Level",
				Variant = "BodyBold",
				Color = SKILL_COLORS[skill],
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.4, 0, 0, 26),
				Text = scope:Computed(function(use): string
					return `Level {use(level)}`
				end),
			}),
			bar,
		},
	})
	return row, level
end

-- Fruit name, aura colours and affinities of one slot.
local function fruitPanel(scope: Scope, slot: number, context: any, menu: any): Instance
	local fruit = Bind.data(scope, `DevilFruits.Slot{slot}`, { Name = FruitConfig.EmptyName, Color = "None" })
	local affinities = Bind.data(scope, `Affinities.DF{slot}`, {})

	local hasFruit = scope:Computed(function(use): boolean
		local current = use(fruit)
		return type(current) == "table" and current.Name ~= FruitConfig.EmptyName
	end)
	local colors = scope:Computed(function(use): { Color3 }?
		local current = use(fruit)
		local primary, secondary = FruitColor.Parse(tostring(type(current) == "table" and current.Color or "None"))
		return if primary and secondary then { primary, secondary } else nil
	end)
	local hasAura = scope:Computed(function(use): boolean
		return use(colors) ~= nil
	end)

	local function swatch(index: number): Instance
		return Kit.Swatch(
			scope,
			scope:Computed(function(use): Color3
				local pair = use(colors)
				return if pair then pair[index] else Theme.Colors.Sunken
			end),
			index,
			hasAura
		)
	end

	-- Affinities are multipliers from 1.0 to 2.0: drawn by the chart, written beside it.
	local multipliers = scope:Computed(function(use): { [string]: number }
		local current = use(affinities)
		local result: { [string]: number } = {}
		for _, skill in AFFINITY_SKILLS do
			result[skill] = math.clamp(tonumber(type(current) == "table" and current[skill]) or 1, 1, 2)
		end
		return result
	end)

	local affinityRows: { Instance } = {}
	for order, skill in AFFINITY_SKILLS do
		table.insert(
			affinityRows,
			scope:New("Frame")({
				Name = skill,
				BackgroundTransparency = 1,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, AFFINITY_ROW_HEIGHT),
				[Fusion.Children] = {
					-- The key of the skill's quarter in the chart.
					scope:New("Frame")({
						Name = "Key",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromOffset(AFFINITY_KEY, AFFINITY_KEY),
						BackgroundColor3 = SKILL_COLORS[skill],
						BorderSizePixel = 0,
					}),
					UI.Label(scope, {
						Text = skill,
						Variant = "Small",
						TextXAlignment = Enum.TextXAlignment.Left,
						Position = UDim2.fromOffset(AFFINITY_KEY + Theme.Space.S, 0),
						Size = UDim2.new(1, -(AFFINITY_KEY + Theme.Space.S), 1, 0),
					}),
					UI.Label(scope, {
						Name = "Value",
						Variant = "BodyBold",
						Color = SKILL_COLORS[skill],
						TextXAlignment = Enum.TextXAlignment.Right,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(0, 40, 1, 0),
						Text = scope:Computed(function(use): string
							-- The one figure that keeps its decimal: an affinity runs from 1.0 to 2.0.
							return string.format("%.1f", use(multipliers)[skill])
						end),
					}),
				},
			})
		)
	end

	local headerHeight = 34
	return UI.Panel(scope, {
		Name = "DevilFruit" .. slot,
		LayoutOrder = slot,
		Size = UDim2.new(1, 0, 0.5, -Theme.Space.S / 2),
		Color = Theme.Colors.Raised,
		Padding = Theme.Space.M,
		Children = {
			UI.Label(scope, {
				Name = "Name",
				Variant = "Heading",
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0.5, 0, 0, headerHeight),
				Scaled = true,
				Text = scope:Computed(function(use): string
					local current = use(fruit)
					local name = if type(current) == "table" then current.Name else FruitConfig.EmptyName
					return if name == FruitConfig.EmptyName then `Slot {slot}: no fruit` else tostring(name)
				end),
			}),
			UI.Stack(scope, {
				Name = "Aura",
				Direction = "Horizontal",
				Gap = Theme.Space.S,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.5, 0, 0, headerHeight),
				Children = {
					swatch(1),
					swatch(2),
					UI.Button(scope, {
						Name = "CustomizeAuraButton",
						Text = "Edit aura",
						Variant = "Secondary",
						TextSize = Theme.TextSize.Small,
						Size = UDim2.fromOffset(104, 30),
						LayoutOrder = 3,
						Visible = hasAura,
						OnClick = function()
							-- The editor takes the place of the stats window.
							menu.Close()
							context.Open(AURA_SCREEN, { Slot = slot })
						end,
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Affinities",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, headerHeight + Theme.Space.S),
				Size = UDim2.new(1, 0, 1, -(headerHeight + Theme.Space.S)),
				Visible = hasFruit,
				[Fusion.Children] = {
					AffinityChart(scope, {
						Name = "Chart",
						Affinities = multipliers,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromOffset(CHART_SIZE, CHART_SIZE),
					}),
					UI.Stack(scope, {
						Name = "Values",
						Gap = Theme.Space.S,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, CHART_SIZE + Theme.Space.L, 0.5, 0),
						Size = UDim2.new(1, -(CHART_SIZE + Theme.Space.L), 0, 16 + #AFFINITY_SKILLS * (AFFINITY_ROW_HEIGHT + Theme.Space.S)),
						Children = {
							UI.Label(scope, {
								Text = "Affinities",
								Variant = "Tiny",
								TextXAlignment = Enum.TextXAlignment.Left,
								Size = UDim2.new(1, 0, 0, 16),
								LayoutOrder = 0,
							}),
							affinityRows,
						} :: { any },
					}),
				} :: { any },
			}),
		},
	})
end

local function counterCell(scope: Scope, label: string, text: Theme.UsedAs<string>, color: Color3, order: number): Instance
	return scope:New("Frame")({
		Name = label,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		[Fusion.Children] = {
			UI.Label(scope, {
				Text = label,
				Variant = "Tiny",
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 16),
			}),
			UI.Label(scope, {
				Name = "Amount",
				Text = text,
				Variant = "BodyBold",
				Color = color,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(0, 18),
				Size = UDim2.new(1, 0, 0, 24),
				Scaled = true,
			}),
		},
	})
end

return function(scope: Scope, context: any, menu: any): Instance
	local localPlayer = Players.LocalPlayer

	---------------------------------------------------------------------------------
	-- Skills

	local levels: { Fusion.Value<any> } = {}
	local skillRows: { Instance } = {}
	for order, skill in SKILLS do
		local row, level = skillRow(scope, skill, order)
		table.insert(skillRows, row)
		table.insert(levels, level)
	end
	table.insert(
		skillRows,
		UI.Label(scope, {
			Name = "TotalLevel",
			Variant = "BodyBold",
			Color = Theme.Colors.Accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = #SKILLS + 1,
			Size = UDim2.new(1, 0, 0, 28),
			Text = scope:Computed(function(use): string
				local total = 0
				for _, level in levels do
					total += tonumber(use(level)) or 0
				end
				return `Total Level: {total}`
			end),
		})
	)

	---------------------------------------------------------------------------------
	-- Counters

	local cells: { Instance } = {}
	for order, counter in COUNTERS do
		local amount = Bind.data(scope, counter.Path, 0)
		table.insert(
			cells,
			counterCell(
				scope,
				counter.Label,
				scope:Computed(function(use): string
					local value = use(amount)
					return counter.Prefix .. (if type(value) == "number" then Bind.formatNumber(value) else tostring(value))
				end),
				counter.Color,
				order
			)
		)
	end

	-- CompassQuestService publishes the server time of Sam's next token (nil when full).
	local tokenAt = Bind.attribute(scope, localPlayer, "CompassTokenAt", nil)
	local samSeconds = scope:Value(0)
	local function refreshSam()
		local at = peek(tokenAt)
		samSeconds:set(if type(at) == "number" then math.max(0, at - workspace:GetServerTimeNow()) else 0)
	end
	scope:Observer(tokenAt):onChange(refreshSam)
	refreshSam()
	-- Ticks only while the tab is open: the thread dies with the scope.
	local samTicker = task.spawn(function()
		while true do
			task.wait(1)
			refreshSam()
		end
	end)
	table.insert(scope, function()
		task.cancel(samTicker)
	end)
	local tokens = Bind.data(scope, "CompassTokens.Current", 0)
	local tokenLimit = Bind.data(scope, "CompassTokens.Limit", 1)
	table.insert(
		cells,
		counterCell(
			scope,
			"Sam's quest",
			scope:Computed(function(use): string
				local seconds = math.max(0, math.floor(tonumber(use(samSeconds)) or 0))
				return `{formatTimer(seconds)} ({use(tokens)}/{use(tokenLimit)})`
			end),
			Theme.Colors.Text,
			#COUNTERS + 1
		)
	)

	---------------------------------------------------------------------------------

	local gap = Theme.Space.M
	return UI.Window(scope, {
		Name = "Stats",
		Title = "Stats",
		Subtitle = localPlayer.Name,
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		AnchorPoint = Kit.WindowAnchor,
		Position = Kit.WindowPosition,
		OnClose = menu.Close,
		Children = {
			Kit.Section(scope, {
				Name = "Skills",
				Title = "Skills",
				Size = UDim2.new(0, LEFT_WIDTH, 1, -(COUNTERS_HEIGHT + gap)),
				Children = UI.Stack(scope, {
					Gap = Theme.Space.S,
					Size = UDim2.fromScale(1, 1),
					Children = skillRows,
				}),
			}),
			UI.Panel(scope, {
				Name = "Counters",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromOffset(LEFT_WIDTH, COUNTERS_HEIGHT),
				Padding = Theme.Space.M,
				Children = {
					scope:New("UIGridLayout")({
						CellSize = UDim2.new(1 / 3, -Theme.Space.S, 0, 46),
						CellPadding = UDim2.fromOffset(Theme.Space.S, Theme.Space.S),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					cells,
				} :: { any },
			}),
			Kit.Section(scope, {
				Name = "DevilFruits",
				Title = "Devil Fruits",
				Position = UDim2.fromOffset(LEFT_WIDTH + gap, 0),
				Size = UDim2.new(1, -(LEFT_WIDTH + gap), 1, 0),
				Children = UI.Stack(scope, {
					Gap = Theme.Space.S,
					Size = UDim2.fromScale(1, 1),
					Children = {
						fruitPanel(scope, 1, context, menu),
						fruitPanel(scope, 2, context, menu),
					},
				}),
			}),
		},
	})
end
