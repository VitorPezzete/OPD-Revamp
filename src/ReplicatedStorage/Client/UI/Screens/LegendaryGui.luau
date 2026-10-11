--!strict
--[[
	The Legendary Mode offer shown at the altar: "TO KNOW EVERYTHING / YOU MUST GIVE UP
	EVERYTHING", revealed word by word while the screen darkens, then ACCEPT / DECLINE.

	Opened by WorldEventController (AltarService.Offer) with UIController:Open("LegendaryGui").
	ACCEPT only sends the request: StatResetService checks everything and performs the
	transition.

	Timings are the legacy ones: a word takes 1 s to appear, 4 s for the last word of each
	sentence, with a pause after each sentence.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

-- The smoke that closes in from both sides (game art, tinted with the backdrop colour).
local SMOKE = "rbxassetid://1838921133"
local SMOKE_FADE = TweenInfo.new(2, Enum.EasingStyle.Linear)
local SHADE_TRANSPARENCY = 0.35

local FAST = 1
local SLOW = 4
local START_DELAY = 1

type Word = { Text: string, Line: number, Seconds: number, Pause: number }

local WORDS: { Word } = {
	{ Text = "TO", Line = 1, Seconds = FAST, Pause = 0 },
	{ Text = "KNOW", Line = 1, Seconds = FAST, Pause = 0 },
	{ Text = "EVERYTHING", Line = 1, Seconds = SLOW, Pause = 2 },
	{ Text = "YOU", Line = 2, Seconds = FAST, Pause = 0 },
	{ Text = "MUST", Line = 2, Seconds = FAST, Pause = 0 },
	{ Text = "GIVE", Line = 2, Seconds = FAST, Pause = 0 },
	{ Text = "UP", Line = 2, Seconds = FAST, Pause = 0 },
	{ Text = "EVERYTHING", Line = 2, Seconds = SLOW, Pause = 3 },
}

local LINE_HEIGHT = 64
local BUTTON_SIZE = UDim2.fromOffset(220, 56)

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		-- 1 = hidden, 0 = shown; each one is followed by a tween.
		local darkness = scope:Value(1)
		local wordGoals: { Fusion.Value<number> } = {}
		local asking = scope:Value(false)
		local answered = scope:Value(false)

		local lines: { { any } } = { {}, {} }
		for index, word in WORDS do
			local goal = scope:Value(1)
			wordGoals[index] = goal
			table.insert(
				lines[word.Line],
				UI.Label(scope, {
					Name = word.Text,
					Text = word.Text,
					Variant = "Display",
					LayoutOrder = index,
					Transparency = scope:Tween(goal, TweenInfo.new(word.Seconds, Enum.EasingStyle.Linear)),
				})
			)
		end

		local alive = true
		table.insert(scope, function()
			alive = false
		end)

		task.spawn(function()
			darkness:set(0)
			task.wait(START_DELAY)
			for index, word in WORDS do
				if not alive then
					return
				end
				wordGoals[index]:set(0)
				task.wait(word.Seconds + word.Pause)
			end
			if alive then
				asking:set(true)
			end
		end)

		local smoke = scope:Tween(darkness, SMOKE_FADE)
		local shade = scope:Computed(function(use): number
			return 1 - (1 - use(smoke)) * (1 - SHADE_TRANSPARENCY)
		end)

		local function sentence(line: number, offset: number): Instance
			return UI.Stack(scope, {
				Name = `Line{line}`,
				Direction = "Horizontal",
				Gap = Theme.Space.L,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, offset),
				Children = lines[line],
			})
		end

		return UI.Screen(scope, {
			Name = "LegendaryGui",
			DisplayOrder = 40,
			IgnoreGuiInset = true,
			Children = {
				UI.Backdrop(scope, { Transparency = shade }),
				UI.Image(scope, {
					Name = "F1",
					Image = SMOKE,
					Color = Theme.Colors.Backdrop,
					Transparency = smoke,
					ScaleType = Enum.ScaleType.Stretch,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1.25),
				}),
				UI.Image(scope, {
					Name = "F2",
					Image = SMOKE,
					Color = Theme.Colors.Backdrop,
					Transparency = smoke,
					ScaleType = Enum.ScaleType.Stretch,
					Rotation = 180,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1.25),
				}),

				sentence(1, -LINE_HEIGHT),
				sentence(2, 0),

				UI.Stack(scope, {
					Name = "Answer",
					Direction = "Horizontal",
					Gap = Theme.Space.XL,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0.5, LINE_HEIGHT + Theme.Space.XL),
					Visible = asking,
					Children = {
						UI.Button(scope, {
							Name = "Decline",
							Text = "DECLINE",
							Variant = "Secondary",
							TextSize = Theme.TextSize.Heading,
							Size = BUTTON_SIZE,
							LayoutOrder = 1,
							Disabled = answered,
							OnClick = function()
								context.Close()
							end,
						}),
						UI.Button(scope, {
							Name = "Accept",
							Text = "ACCEPT",
							TextSize = Theme.TextSize.Heading,
							Size = BUTTON_SIZE,
							LayoutOrder = 2,
							Disabled = answered,
							OnClick = function()
								if Fusion.peek(answered) then
									return
								end
								answered:set(true)
								-- Refusals are explained by the server through the usual notifications.
								Knit.GetService("StatResetService"):EnterLegendaryMode():catch(warn)
								context.Close()
							end,
						}),
					},
				}),
			},
		})
	end,
}
