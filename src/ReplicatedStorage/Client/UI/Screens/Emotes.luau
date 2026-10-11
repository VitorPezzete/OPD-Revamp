--!strict
--[[
	The emote wheel: the free emotes and the unlockable ones. Opened by the menu or while
	the Emotes hotkey is held (EmoteController).

	The buttons only pick an animation; starting / stopping it is EmoteController's job.
	An unlockable emote that is not owned (data.Emotes) is shown disabled.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local EmoteConfig = require(ReplicatedStorage.Shared.Configs.EmoteConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

-- Names of EmoteConfig.Free, in the same order. Table Kick was hidden in the legacy wheel.
local FREE_NAMES = { "Jittery", "Thinking", "Admire", "Relax", "Pushups", "Praise", "Table Kick", "Dab", "T-Pose" }
local HIDDEN_FREE = { ["Table Kick"] = true }
-- Names of CB_Mark1 .. CB_Mark16.
local MARK_NAMES = {
	"Dance",
	"Kicks",
	"Meditate",
	"Regal",
	"Face Palm",
	"Bow",
	"Yawn",
	"Hand Stand",
	"Standing Sleep",
	"Kamehameha",
	"Cross Arms",
	"Clapping",
	"Kicking Back",
	"Kneel",
	"Torture Dance",
	"Floating",
}
-- Meditate was never sold: everyone has it.
local FREE_MARK = "CB_Mark3"

local COLUMNS = 3
local CELL = Vector2.new(164, 42)
local GAP = Theme.Space.S
local HEADING_HEIGHT = 24
local HINT_HEIGHT = 20

local function gridHeight(count: number): number
	local rows = math.ceil(count / COLUMNS)
	return rows * CELL.Y + math.max(rows - 1, 0) * GAP
end

local function grid(scope: Scope, name: string, order: number, buttons: { any }): Frame
	return scope:New("Frame")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, gridHeight(#buttons)),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("UIGridLayout")({
				CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
				CellPadding = UDim2.fromOffset(GAP, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			buttons,
		} :: { any },
	}) :: any
end

local function heading(scope: Scope, text: string, order: number): TextLabel
	return UI.Label(scope, {
		Text = text,
		Variant = "BodyBold",
		Color = Theme.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, HEADING_HEIGHT),
		LayoutOrder = order,
	})
end

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local EmoteController = Knit.GetController("EmoteController")
		local owned = Bind.data(scope, "Emotes", {})

		local freeButtons: { any } = {}
		for index, name in FREE_NAMES do
			local animationId = EmoteConfig.Free[index]
			if animationId and not HIDDEN_FREE[name] then
				table.insert(
					freeButtons,
					UI.Button(scope, {
						Name = name,
						Text = name,
						Variant = "Secondary",
						TextSize = Theme.TextSize.Small,
						LayoutOrder = index,
						OnClick = function()
							EmoteController:Play(animationId)
						end,
					})
				)
			end
		end

		local markButtons: { any } = {}
		for index, name in MARK_NAMES do
			local markName = `CB_Mark{index}`
			table.insert(
				markButtons,
				UI.Button(scope, {
					Name = markName,
					Text = name,
					Variant = "Secondary",
					TextSize = Theme.TextSize.Small,
					LayoutOrder = index,
					Disabled = scope:Computed(function(use): boolean
						local emotes = use(owned)
						return markName ~= FREE_MARK and not (type(emotes) == "table" and emotes[markName] == true)
					end),
					OnClick = function()
						EmoteController:PlayMark(markName)
					end,
				})
			)
		end

		local width = COLUMNS * CELL.X + (COLUMNS - 1) * GAP
		local height = HEADING_HEIGHT * 2
			+ gridHeight(#freeButtons)
			+ gridHeight(#markButtons)
			+ HINT_HEIGHT
			+ Theme.Space.M * 4

		return UI.Screen(scope, {
			Name = "Emotes",
			DisplayOrder = 10,
			Children = {
				UI.Window(scope, {
					Title = "Emotes",
					-- At the right, so the character stays in view while it emotes.
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -60, 0.5, 0),
					Size = UDim2.fromOffset(width + Theme.Space.L * 2, height + 52 + Theme.Space.L * 2),
					OnClose = context.Close,
					Children = {
						UI.Stack(scope, {
							Size = UDim2.fromScale(1, 1),
							Gap = Theme.Space.M,
							Children = {
								heading(scope, "Basic", 1),
								grid(scope, "Free", 2, freeButtons),
								heading(scope, "Unlockable", 3),
								grid(scope, "Marks", 4, markButtons),
								UI.Label(scope, {
									Name = "Hint",
									Text = "Locked emotes are sold by the Emote Merchant.",
									Variant = "Tiny",
									TextXAlignment = Enum.TextXAlignment.Left,
									Size = UDim2.new(1, 0, 0, HINT_HEIGHT),
									LayoutOrder = 5,
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
