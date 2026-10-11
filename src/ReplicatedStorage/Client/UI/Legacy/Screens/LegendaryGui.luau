--!strict
--[[
	The Legendary Mode offer shown at the altar (legacy LegendaryGui / ClientVoidGui):
	the screen goes dark under two sheets of black smoke, "TO KNOW EVERYTHING / YOU MUST
	GIVE UP EVERYTHING" appears word by word, then ACCEPT (green) and DECLINE (red).

	Opened by WorldEventController (AltarService.Offer) with UIController:Open("LegendaryGui").
	ACCEPT only sends the request: StatResetService checks everything and performs the
	transition.

	Timings are the legacy ones: each word gains 0.05 opacity per step; the steps are
	0.05 s apart, 0.2 s for the last word of each sentence.

	The old words were black, in a staircase down the left of the screen, two of them on
	top of each other; they are the Kit's white lettering now, one sentence per line in
	the middle of the screen.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

-- Over every window, like the rework's.
local DISPLAY_ORDER = 40
local SMOKE = "rbxassetid://1838921133"
local SMOKE_FADE = TweenInfo.new(2, Enum.EasingStyle.Linear)
local FADE_STEPS = 20
local FAST_STEP = 0.05
local SLOW_STEP = 0.2
local START_DELAY = 1

-- The only text of the interface meant to fill the screen: twice the Kit's largest.
local WORD_SIZE = Kit.TextSize.Title * 2
local LINE_HEIGHT = WORD_SIZE + Kit.Space.XL
-- The sentences stand around this share of the screen's height, the answers below.
local WORDS_Y = 0.4
local BUTTONS_Y = 0.7
-- The old buttons: a fifth of the screen wide, their centres 30% of it apart.
local BUTTON_SIZE = UDim2.fromOffset(300, 80)
local BUTTON_GAP = 276
local BUTTON_TINT = Color3.fromRGB(162, 0, 255)
local BUTTON_TINT_TRANSPARENCY = 0.9

type Word = { Text: string, Line: number, Seconds: number, Pause: number }

-- Seconds: the fade of the word; Pause: the wait after it.
local WORDS: { Word } = {
	{ Text = "TO", Line = 1, Seconds = FAST_STEP * FADE_STEPS, Pause = 0 },
	{ Text = "KNOW", Line = 1, Seconds = FAST_STEP * FADE_STEPS, Pause = 0 },
	{ Text = "EVERYTHING", Line = 1, Seconds = SLOW_STEP * FADE_STEPS, Pause = 2 },
	{ Text = "YOU", Line = 2, Seconds = FAST_STEP * FADE_STEPS, Pause = 0 },
	{ Text = "MUST", Line = 2, Seconds = FAST_STEP * FADE_STEPS, Pause = 0 },
	{ Text = "GIVE", Line = 2, Seconds = FAST_STEP * FADE_STEPS, Pause = 0 },
	{ Text = "UP", Line = 2, Seconds = FAST_STEP * FADE_STEPS, Pause = 0 },
	{ Text = "EVERYTHING", Line = 2, Seconds = SLOW_STEP * FADE_STEPS, Pause = 3 },
}

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		-- 1: hidden, 0: shown.
		local darkness = scope:Value(1)
		local asking = scope:Value(false)
		local answered = scope:Value(false)

		local goals: { Fusion.Value<number> } = {}
		local lines: { { Instance } } = { {}, {} }
		for index, word in WORDS do
			local goal = scope:Value(1)
			goals[index] = goal
			table.insert(
				lines[word.Line],
				Kit.Label(scope, {
					Name = word.Text,
					Text = word.Text,
					TextSize = WORD_SIZE,
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
				goals[index]:set(0)
				-- Not a wait on the tween: it never ends if the screen closes mid-fade.
				task.wait(word.Seconds + word.Pause)
			end
			if alive then
				asking:set(true)
			end
		end)

		local smoke = scope:Tween(darkness, SMOKE_FADE)

		local function sheet(name: string, rotation: number): Instance
			local image = Kit.Image(scope, {
				Name = name,
				Image = SMOKE,
				Color = Color3.new(0, 0, 0),
				Transparency = smoke,
				ScaleType = Enum.ScaleType.Stretch,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1.25),
			})
			image.Rotation = rotation
			return image
		end

		local function sentence(line: number, offset: number): Instance
			return Kit.Stack(scope, {
				Name = `Line{line}`,
				Direction = "Horizontal",
				Gap = Kit.Space.XL,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, WORDS_Y, offset),
				Children = lines[line],
			})
		end

		-- The faint purple the old buttons had behind their text.
		local function tint(): Instance
			return scope:New("Frame")({
				Name = "Tint",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = BUTTON_TINT,
				BackgroundTransparency = BUTTON_TINT_TRANSPARENCY,
				BorderSizePixel = 0,
				ZIndex = 0,
			})
		end

		return Kit.Screen(scope, {
			Name = "LegendaryGui",
			DisplayOrder = DISPLAY_ORDER,
			IgnoreGuiInset = true,
			Children = {
				sheet("F1", 0),
				sheet("F2", 180),

				sentence(1, -LINE_HEIGHT / 2),
				sentence(2, LINE_HEIGHT / 2),

				Kit.Stack(scope, {
					Name = "Answer",
					Direction = "Horizontal",
					Gap = BUTTON_GAP,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, BUTTONS_Y),
					Visible = asking,
					Children = {
						Kit.Button(scope, {
							Name = "Accept",
							Text = "ACCEPT",
							Variant = "Ghost",
							TextSize = Kit.TextSize.Title,
							TextColor = Kit.Colors.Good,
							Size = BUTTON_SIZE,
							LayoutOrder = 1,
							OnClick = function()
								if Fusion.peek(answered) then
									return
								end
								answered:set(true)
								-- Refusals are explained by the server through the usual notifications.
								Knit.GetService("StatResetService"):EnterLegendaryMode():catch(warn)
								context.Close()
							end,
							Children = tint(),
						}),
						Kit.Button(scope, {
							Name = "Decline",
							Text = "DECLINE",
							Variant = "Ghost",
							TextSize = Kit.TextSize.Title,
							TextColor = Kit.Colors.Bad,
							Size = BUTTON_SIZE,
							LayoutOrder = 2,
							OnClick = function()
								if not Fusion.peek(answered) then
									context.Close()
								end
							end,
							Children = tint(),
						}),
					},
				}),
			},
		})
	end,
}
