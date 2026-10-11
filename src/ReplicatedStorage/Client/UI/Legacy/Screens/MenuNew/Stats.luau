--!strict
--[[
	Menu tab "Stats": name, the five skills with their exp bars, total level, both
	devil fruits with their affinities (the chart alone: no figures) and aura swatches, and the
	counters (Beri, Gems, Kills, Bounty, Fish, Sam's quest timer and compass tokens).

	The one tab still drawn by the old game's own layout, as it was: only the stats panel
	of the generated menu is built (Layouts.MenuNew.Frame.C is the old "Stats" button with
	the panel hanging off it), pinned to the size it had on a 1920x1080 screen and handed
	to the menu shell to dock, like the parts built with the Kit.

	Read-only: the only actions are the two aura swatches, which open the aura editor.

	The legacy tab was driven by seven LocalScripts (one per bar plus two for the panel)
	that each polled Workspace.UserData until it loaded and then fought over the same
	bar with different tweens. Everything here derives from the replicated data.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Style = require(ReplicatedStorage.Client.UI.Legacy.Style)
local PlaceManifest = require(ReplicatedStorage.Shared.Configs.PlaceManifest)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)

type Scope = Fusion.Scope<typeof(Fusion)>
type SkillName = DataTypes.SkillName

-- Key of this tab (PlaceManifest.MenuTabs, menu.Selected).
local TAB = "Stats"
-- The old "Stats" button of the generated menu, with the panel inside.
local LAYOUT = ReplicatedStorage.Client.UI.Legacy.Layouts.MenuNew.Frame.C
-- The panel as it measured on a 1920x1080 screen (2.8 x 16 of its button, itself 0.9 x
-- 0.15 of a column of 192 x 306.6), and the whole of it: its right half (the fruits and
-- the counters) is a child that hangs off the right edge of the left one.
local PANEL_SIZE = Vector2.new(484, 736)
local FULL_SIZE = Vector2.new(968, 736)
local AURA_SCREEN = "CustomizeAuras"
local SKILLS: { SkillName } = { "Defense", "Melee", "Sniper", "Sword", "Haki" }
local AFFINITY_SKILLS = { "Defense", "Melee", "Sniper", "Sword" }

local BAR_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local AFFINITY_TWEEN = TweenInfo.new(1.5, Enum.EasingStyle.Linear)

-- Counter label (under Frame/A) -> amount label and data path.
local COUNTERS = {
	{ Label = "Beri/BeriAmount", Path = "Economy.Beri" },
	{ Label = "Gems/GemsAmount", Path = "Economy.Gems" },
	{ Label = "Kills/KillsAmount", Path = "Combat.Kills" },
	{ Label = "Bounty/BountyAmount", Path = "Combat.Bounty" },
	{ Label = "Fish/FishAmount", Path = "Economy.Fish" },
}

local function formatTimer(seconds: number): string
	if seconds <= 0 then
		return "Ready!"
	end
	local minutes = math.floor(seconds / 60)
	local rest = seconds % 60
	return if minutes == 0 then `{rest}s` else `{minutes}m {rest}s`
end

-- "Skill: level" label with its exp bar; returns the level state for the total.
local function bindSkill(scope: Scope, panel: Instance, skill: SkillName): Fusion.Value<any>
	local level = Bind.data(scope, `Skills.{skill}.Level`, 0)
	local exp = Bind.data(scope, `Skills.{skill}.Exp`, 0)

	local label = Bind.find(panel, skill)
	local track = Bind.find(label, "Frame")
	local fill = Bind.find(track, "Frame")

	local ratio = scope:Computed(function(use)
		local requirement = StatConfig.GetExpRequirement(skill, tonumber(use(level)) or 0)
		return if requirement > 0 then math.clamp((tonumber(use(exp)) or 0) / requirement, 0, 1) else 0
	end)
	local shownRatio = scope:Tween(ratio, BAR_TWEEN)

	Bind.props(scope, label, {
		Text = scope:Computed(function(use)
			return `{skill}: {use(level)}`
		end),
	})
	Bind.props(scope, fill, {
		Size = scope:Computed(function(use)
			return UDim2.fromScale(use(shownRatio), 1)
		end),
	})

	-- Hovering the bar shows the exact progress, kept current while the mouse stays on it.
	local hovering = false
	local function showProgress()
		local percent = math.floor(Fusion.peek(ratio) * 10000) / 100
		Tooltip.show(`{percent}%`)
	end
	local function stopHover()
		if hovering then
			hovering = false
			Tooltip.hide()
		end
	end
	Bind.connect(scope, track.MouseEnter, function()
		hovering = true
		showProgress()
	end)
	Bind.connect(scope, track.MouseLeave, stopHover)
	scope:Observer(ratio):onChange(function()
		if hovering then
			showProgress()
		end
	end)
	table.insert(scope, stopHover)

	return level
end

-- Fruit name, affinity chart and aura swatches of one slot.
local function bindFruit(scope: Scope, info: Instance, slot: number, context: any, menu: any)
	local suffix = if slot == 1 then "" else "2"
	local chartName = if slot == 1 then "Affinities2a" else "Affinities2b"

	local fruit = Bind.data(scope, `DevilFruits.Slot{slot}`, { Name = FruitConfig.EmptyName, Color = "None" })
	local affinities = Bind.data(scope, `Affinities.DF{slot}`, {})

	-- The replicated value is read as it comes: anything but a fruit table is "no fruit".
	local fruitName = scope:Computed(function(use): string
		local current = use(fruit)
		return if type(current) == "table" and type(current.Name) == "string" then current.Name else FruitConfig.EmptyName
	end)
	local hasFruit = scope:Computed(function(use)
		return use(fruitName) ~= FruitConfig.EmptyName
	end)
	local colors = scope:Computed(function(use): { Color3 }?
		local current = use(fruit)
		local primary, secondary = FruitColor.Parse(tostring(type(current) == "table" and current.Color or "None"))
		return if primary and secondary then { primary, secondary } else nil
	end)

	local nameLabel = Bind.find(info, `DevilFruit{suffix}`)
	Bind.props(scope, nameLabel, { Text = fruitName })

	local chart = Bind.find(nameLabel, chartName)
	Bind.props(scope, chart, { Visible = hasFruit })
	for _, skill in AFFINITY_SKILLS do
		-- Affinities are multipliers from 1.0 to 2.0; the circle fills its quadrant at 2.0.
		local multiplier = scope:Computed(function(use): number
			local current = use(affinities)
			return math.clamp(tonumber(type(current) == "table" and current[skill]) or 1, 1, 2)
		end)
		local target = scope:Computed(function(use)
			return (use(multiplier) - 1) * 2
		end)
		local shown = scope:Tween(target, AFFINITY_TWEEN)
		local quarter = Bind.find(chart, skill)
		local circle = Bind.find(quarter, "Circle") :: ImageLabel
		Bind.props(scope, circle, {
			Size = scope:Computed(function(use)
				local size = use(shown)
				return UDim2.fromScale(size, size)
			end),
		})
	end

	-- Swatch "a" shows the primary aura color and opens the editor, "b" the secondary.
	for index, letter in { "a", "b" } do
		Bind.props(scope, Bind.find(info, `DFU{slot}{letter}`), {
			Visible = scope:Computed(function(use)
				return use(colors) ~= nil
			end),
			ImageColor3 = scope:Computed(function(use)
				local pair = use(colors)
				return if pair then pair[index] else Color3.new(1, 1, 1)
			end),
		})
	end

	local editButton = Bind.tryFind(info, `DFU{slot}a/CustomizeAuraButton`)
	if editButton and editButton:IsA("GuiButton") then
		Bind.click(scope, editButton, function()
			-- The editor takes the place of the stats panel.
			if Fusion.peek(menu.Selected) == TAB then
				menu.Close()
			end
			context.Open(AURA_SCREEN, { Slot = slot })
		end)
	end
end

return function(scope: Scope, context: any, menu: any): GuiObject?
	-- Not every place offers the tab (PlaceManifest.MenuTabs).
	if not PlaceManifest.Has("MenuTabs", TAB) then
		return nil
	end

	-- Only the panel is kept of the old button.
	local button: Instance = (require :: any)(LAYOUT)(scope)
	local panel = Bind.find(button, "Frame") :: GuiObject
	local holder = scope:New("Frame")({
		Name = "Stats",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(FULL_SIZE.X, FULL_SIZE.Y),
	})
	panel.Position = UDim2.fromOffset(0, 0)
	panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	panel.Visible = true
	panel.Parent = holder
	button:Destroy()
	-- In the middle of the screen.
	menu.Centre(holder :: any, FULL_SIZE)
	-- The old panel with text that can be read, as UIController does for a whole layout.
	Style.apply(panel)

	local info = Bind.find(panel, "A")
	local localPlayer = Players.LocalPlayer

	Bind.find(panel, "Nametag").Text = localPlayer.Name

	local levels: { Fusion.Value<any> } = {}
	for _, skill in SKILLS do
		table.insert(levels, bindSkill(scope, panel, skill))
	end
	Bind.props(scope, Bind.find(panel, "TotalLevel"), {
		Text = scope:Computed(function(use)
			local total = 0
			for _, level in levels do
				total += tonumber(use(level)) or 0
			end
			return `Total Level: {total}`
		end),
	})

	bindFruit(scope, info, 1, context, menu)
	bindFruit(scope, info, 2, context, menu)

	for _, counter in COUNTERS do
		local amount = Bind.data(scope, counter.Path, 0)
		Bind.props(scope, Bind.find(info, counter.Label), {
			-- The layout's amounts end with a space (they are right-aligned against the frame).
			Text = scope:Computed(function(use)
				local value = use(amount)
				return (if type(value) == "number" then Bind.formatNumber(value) else tostring(value)) .. " "
			end),
		})
	end

	-- CompassQuestService publishes the server time of Sam's next token (nil when full).
	local tokenAt = Bind.attribute(scope, localPlayer, "CompassTokenAt", nil)
	local samSeconds = scope:Value(0)
	local function refreshSam()
		local at = Fusion.peek(tokenAt)
		samSeconds:set(if type(at) == "number" then math.max(0, at - workspace:GetServerTimeNow()) else 0)
	end
	scope:Observer(tokenAt):onChange(refreshSam)
	refreshSam()
	local samTicker = task.spawn(function()
		while true do
			task.wait(1)
			-- Only worth recomputing while the stats tab is the one on screen.
			if Fusion.peek(menu.Selected) == TAB then
				refreshSam()
			end
		end
	end)
	table.insert(scope, function()
		task.cancel(samTicker)
	end)
	local tokens = Bind.data(scope, "CompassTokens.Current", 0)
	local tokenLimit = Bind.data(scope, "CompassTokens.Limit", 1)
	Bind.props(scope, Bind.find(info, "Sam/SamTimer"), {
		Text = scope:Computed(function(use)
			local seconds = math.max(0, math.floor(tonumber(use(samSeconds)) or 0))
			return `{formatTimer(seconds)} ({use(tokens)}/{use(tokenLimit)})`
		end),
	})

	return holder :: any
end
