--!strict
--[[
	Combo counter: number of hits landed and their total damage (the real damage of each
	hit, HitCounterService), with a bar that runs out in three seconds. Every new hit refills the bar; when it empties the counter, bar included,
	fades out gradually and resets.
	A hit landing during the fade brings it back and keeps the count.

	The server only sends hits to players who enabled Settings.Hit_Counter (HitCounterService).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Numerals = require(ReplicatedStorage.Client.UI.Util.Numerals)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local COMBO_WINDOW = 3
local FADE = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- The texts are drawn over the world: a thin dark edge keeps them readable.
local TEXT_OUTLINE = 1
local TEXT_OUTLINE_TRANSPARENCY = 0.45

local WIDTH = 300
local HEIGHT = 130
local BAR_SIZE = UDim2.fromOffset(220, 8)

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local HitCounterService = Knit.GetService("HitCounterService")

		local shown = scope:Value(false)
		local hits = scope:Value(0)
		local total = scope:Value(0)
		-- Share of the combo window left, eased like the bar that drains (1 -> 0).
		local remaining = scope:Value(0)

		local fade = scope:Tween(
			scope:Computed(function(use): number
				return if use(shown) then 0 else 1
			end),
			FADE
		)

		local outlineFade = scope:Computed(function(use): number
			return 1 - (1 - use(fade)) * (1 - TEXT_OUTLINE_TRANSPARENCY)
		end)
		-- The trough of the bar leaves with the rest of the counter.
		local barFade = scope:Computed(function(use): number
			return 1 - (1 - Theme.Transparency.Hud) * (1 - use(fade))
		end)

		local lastHit = 0
		local stepping: RBXScriptConnection? = nil

		local function stop()
			if stepping then
				stepping:Disconnect()
				stepping = nil
			end
		end

		-- Runs only while a combo is on screen.
		local function step()
			local elapsed = os.clock() - lastHit
			if elapsed < COMBO_WINDOW then
				local left = 1 - elapsed / COMBO_WINDOW
				remaining:set(left * left)
			elseif elapsed < COMBO_WINDOW + FADE.Time then
				remaining:set(0)
				shown:set(false)
			else
				stop()
				hits:set(0)
				total:set(0)
			end
		end

		Bind.connect(scope, HitCounterService.Hit, function(damage: number)
			if type(damage) ~= "number" or damage ~= damage then
				return
			end

			lastHit = os.clock()
			hits:set(Fusion.peek(hits) + 1)
			total:set(Fusion.peek(total) + damage)
			remaining:set(1)
			shown:set(true)
			if not stepping then
				stepping = RunService.Heartbeat:Connect(step)
			end
		end)
		table.insert(scope, stop)

		return UI.Screen(scope, {
			Name = "HitCounter",
			Children = {
				scope:New("Frame")({
					Name = "Combo",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.2, 0.56),
					Size = UDim2.fromOffset(WIDTH, HEIGHT),
					BackgroundTransparency = 1,
					Visible = scope:Computed(function(use): boolean
						return use(fade) < 1
					end),
					[Fusion.Children] = {
						UI.Stack(scope, {
							Name = "Rows",
							Size = UDim2.fromScale(1, 1),
							Gap = Theme.Space.XS,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Children = {
								UI.Label(scope, {
									Name = "Hits",
									Text = scope:Computed(function(use): string
										local count = use(hits)
										return `{count} {if count == 1 then "HIT" else "HITS"}`
									end),
									Variant = "Display",
									Font = Numerals.Font,
									Color = Theme.Colors.White,
									Outline = true,
									OutlineColor = Theme.Colors.Black,
									OutlineThickness = TEXT_OUTLINE,
									OutlineTransparency = outlineFade,
									Transparency = fade,
									LayoutOrder = 1,
								}),
								UI.Label(scope, {
									Name = "Damage",
									Text = scope:Computed(function(use): string
										return `{Bind.formatNumber(use(total))} damage`
									end),
									Variant = "Heading",
									Font = Numerals.Font,
									Color = Theme.Colors.White,
									Outline = true,
									OutlineColor = Theme.Colors.Black,
									OutlineThickness = TEXT_OUTLINE,
									OutlineTransparency = outlineFade,
									Transparency = fade,
									LayoutOrder = 2,
								}),
								UI.ProgressBar(scope, {
									Name = "TimeBar",
									Value = remaining,
									-- Runs from white to red as the window closes.
									Color = scope:Computed(function(use): Color3
										return Theme.Colors.Danger:Lerp(Theme.Colors.White, use(remaining))
									end),
									TrackColor = Theme.Colors.Black,
									StrokeColor = Theme.Colors.Black,
									Size = BAR_SIZE,
									Radius = Theme.Radius.Pill,
									Animated = false,
									Transparency = barFade,
									Fade = fade,
									LayoutOrder = 3,
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
