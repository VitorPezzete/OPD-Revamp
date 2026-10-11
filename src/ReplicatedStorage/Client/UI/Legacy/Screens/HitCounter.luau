--!strict
--[[
	Combo counter of the legacy interface: the number of hits landed and their total
	damage, with a thin bar under them that runs out in three seconds. Every new hit refills
	the bar; when it empties the counter fades and resets. A hit landing during the fade
	brings it back and keeps the count.

	It stands where the old one did (left of the character, a little below mid-height), the
	same size, built in code: the two lines and the bar are a stack, so they are centred on
	each other.

	The server only sends hits to players who enabled Settings.Hit_Counter (HitCounterService).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

local COMBO_WINDOW = 3
local FADE = TweenInfo.new(0.25)

-- The old counter on a 1920x1080 screen.
local SIZE = Vector2.new(300, 142)
local POSITION = UDim2.fromScale(0.2035, 0.5568)
local LINE_HEIGHT = 52
local BAR_SIZE = Vector2.new(260, 8)
-- Larger than a title: the old digits filled their box, and the counter is read mid-fight.
local DIGIT_SIZE = 44
local BAR_FULL_COLOR = Color3.fromRGB(255, 255, 255)
local BAR_EMPTY_COLOR = Color3.fromRGB(255, 0, 0)

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local HitCounterService = Knit.GetService("HitCounterService")

		local shown = scope:Value(false)
		local hits = scope:Value(0)
		local total = scope:Value(0)
		-- Share of the combo window left, eased like the old bar's tween (quad out).
		local remaining = scope:Value(0)

		local fade = scope:Tween(
			scope:Computed(function(use): number
				return if use(shown) then 0 else 1
			end),
			FADE
		)

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

			-- A hit during the fade-out brings the counter back with its count (the legacy
			-- one kept counting on invisible text).
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

		return Kit.Screen(scope, {
			Name = "HitCounter",
			Children = {
				Kit.Stack(scope, {
					Name = "DmgCounterFrame",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = POSITION,
					Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
					Gap = Kit.Space.XS,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					-- The ScreenGui stays enabled (the UIController owns that flag).
					Visible = scope:Computed(function(use): boolean
						return use(fade) < 1
					end),
					Children = {
						Kit.Label(scope, {
							Name = "Hits",
							Text = scope:Computed(function(use): string
								return `Hits: {use(hits)}x`
							end),
							TextSize = DIGIT_SIZE,
							Fit = true,
							Size = UDim2.new(1, 0, 0, LINE_HEIGHT),
							Transparency = fade,
							LayoutOrder = 1,
						}),
						Kit.Label(scope, {
							Name = "Dmg",
							Text = scope:Computed(function(use): string
								return Bind.formatNumber(use(total))
							end),
							TextSize = DIGIT_SIZE,
							Fit = true,
							Size = UDim2.new(1, 0, 0, LINE_HEIGHT),
							Transparency = fade,
							LayoutOrder = 2,
						}),
						scope:New("Frame")({
							Name = "TimeBarFrame",
							BackgroundTransparency = 1,
							Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y),
							LayoutOrder = 3,
							[Fusion.Children] = {
								-- Drains towards its middle, from white to red, as the old one did.
								scope:New("Frame")({
									Name = "Fill",
									AnchorPoint = Vector2.new(0.5, 0.5),
									Position = UDim2.fromScale(0.5, 0.5),
									BorderSizePixel = 0,
									Size = scope:Computed(function(use): UDim2
										return UDim2.fromScale(use(remaining), 1)
									end),
									BackgroundColor3 = scope:Computed(function(use): Color3
										return BAR_EMPTY_COLOR:Lerp(BAR_FULL_COLOR, use(remaining))
									end),
									BackgroundTransparency = fade,
									[Fusion.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }) },
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
