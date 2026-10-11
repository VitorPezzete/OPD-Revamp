--!strict
--[[
	The reeling minigame: ten targets, hit at least seven.

	The server starts it (difficulty + variant), keeps the score and ends it. This screen
	animates the targets on the timeline both sides share (FishingConfig.GetSchedule) and
	reports "I hit target #n" / "I clicked the water". The counter shown is optimistic;
	the catch is whatever the server counted.

	Variants
		Scatter  targets pop up everywhere, hit them before they vanish
		Center   one target in the middle, only hittable once its ring has closed
		Timed    same, anywhere on screen
		Arrows   gamepad: arrows glide to the centre lane, press their side (D-pad) once
		         they are past half way

	Every target and arrow is built once, in a scope of its own, and parented by hand; it
	goes when that scope is cleaned. They were rows of two state lists drawn with
	ForValues, and that is what broke the game: when a row left the list Fusion handed its
	slot to one of the rows that stayed, which was then built again from nothing. A target
	already on screen started over where it stood - ring wide open, as if it had just
	appeared - so the game looked like it kept putting targets in the same places, and an
	arrow jumped back to its end of the lane. Something that must be made exactly once and
	never rebuilt is not a list row.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local FishingConfig = require(ReplicatedStorage.Shared.Configs.FishingConfig)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local MINIGAME = FishingConfig.Minigame
local ARROW_IMAGE = "rbxassetid://135685790731603"

-- The water: lighter for the scattered variant, deep for the one-at-a-time ones. The
-- game's own colours, not the theme's: on the theme's dark panels the ring that tells
-- when to click could not be told from the water behind it.
local SHALLOW_COLOR = Color3.fromRGB(66, 189, 255)
local DEEP_COLOR = Color3.fromRGB(28, 39, 255)
local TARGET_COLOR = Color3.new(1, 1, 1)
local RING_COLOR = Color3.new(0, 0, 0)
local WATER_TRANSPARENCY = 0.2
local FADE = TweenInfo.new(1.5)
local MISS_FLASH = TweenInfo.new(0.25)

local CENTER = UDim2.fromScale(0.462, 0.424)
local ARROW_LEFT_X, ARROW_RIGHT_X, ARROW_CENTER_X = 0, 0.955, 0.477
local ARROW_WIDTH = 0.045
-- A target starts half see-through inside a ring three times its size.
local IDLE_TRANSPARENCY = 0.5
local RING_THICKNESS = 6

type Target = {
	Index: number,
	Position: UDim2,
	Color: Color3,
	RingColor: Color3,
	SpawnedAt: number,
	OpensIn: number,
	Lifetime: number,
}
type Arrow = { Index: number, Side: string, OpensAt: number, Lifetime: number }

local function without<T>(list: { T }, item: T): { T }
	local result: { T } = {}
	for _, other in list do
		if other ~= item then
			table.insert(result, other)
		end
	end
	return result
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local FishingService = Knit.GetService("FishingService")

		local random = Random.new()
		-- Bumped whenever a game starts or ends: delayed work of an older game sees it and stops.
		local run = 0
		local playing = false
		local misses = 0
		-- Targets and arrows still on screen and not yet judged.
		local live: { [any]: boolean } = {}
		-- Set to true to paint an arrow as missed (created by its row).
		local missed: { [Arrow]: Fusion.Value<boolean> } = {}

		local shown = scope:Value(false)
		local water = scope:Value(1)
		local waterColor = scope:Value(DEEP_COLOR)
		local hudShown = scope:Value(false)
		local laneShown = scope:Value(false)
		local difficultyText = scope:Value("")
		local points = scope:Value(0)
		local targetSize = scope:Value(UDim2.fromScale(0.075, 0.15))
		-- The scope each target / arrow on screen was built in (see the header).
		local rows: { [any]: Scope } = {}
		-- Arrows on screen, oldest first: the order the D-pad judges them in.
		local arrowQueue: { Arrow } = {}
		-- Where the rows are parented: created below, with the rest of the screen.
		local targetLayer: Frame
		local lane: Frame

		local function addRow<T>(item: T, parent: Instance, build: (rowScope: Scope, item: T) -> Instance)
			local rowScope: Scope = Fusion.scoped(Fusion)
			rows[item] = rowScope
			build(rowScope, item).Parent = parent
		end

		local function dropRow(item: any)
			local rowScope = rows[item]
			if rowScope then
				rows[item] = nil
				Fusion.doCleanup(rowScope)
			end
		end

		local function clear()
			table.clear(live)
			for item in table.clone(rows) do
				dropRow(item)
			end
			table.clear(arrowQueue)
		end

		table.insert(scope, function()
			run += 1
			playing = false
			clear()
		end)

		local function removeTarget(target: Target)
			live[target] = nil
			dropRow(target)
		end

		local function removeArrow(arrow: Arrow)
			live[arrow] = nil
			arrowQueue = without(arrowQueue, arrow)
			dropRow(arrow)
		end

		local function score(index: number)
			points:set(Fusion.peek(points) + 1)
			FishingService.Hit:Fire(index)
		end

		local function clickTarget(target: Target)
			if not live[target] then
				return
			end
			-- Too eager: the target is lost.
			if os.clock() - target.SpawnedAt >= target.OpensIn then
				score(target.Index)
			end
			removeTarget(target)
		end

		local function buildTarget(rowScope: Scope, target: Target): Instance
			-- 0 while the target sits still, then 1 as its ring closes on it.
			local goal = rowScope:Value(0)
			local closed = rowScope:Tween(goal, TweenInfo.new(target.Lifetime))
			task.delay(MINIGAME.Settle, function()
				if live[target] then
					goal:set(1)
				end
			end)
			local fade = rowScope:Computed(function(use): number
				return IDLE_TRANSPARENCY * (1 - use(closed))
			end)

			return rowScope:New("TextButton")({
				Name = "Target",
				AutoButtonColor = false,
				Selectable = false,
				Text = "",
				Position = target.Position,
				Size = targetSize,
				BackgroundColor3 = target.Color,
				BackgroundTransparency = fade,
				[Fusion.OnEvent("Activated")] = function()
					clickTarget(target)
				end,
				[Fusion.Children] = {
					rowScope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					rowScope:New("UIAspectRatioConstraint")({}),
					rowScope:New("Frame")({
						Name = "Ring",
						BackgroundTransparency = 1,
						Position = rowScope:Computed(function(use): UDim2
							local offset = use(closed) - 1
							return UDim2.fromScale(offset, offset)
						end),
						Size = rowScope:Computed(function(use): UDim2
							local size = 3 - 2 * use(closed)
							return UDim2.fromScale(size, size)
						end),
						[Fusion.Children] = {
							rowScope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
							rowScope:New("UIAspectRatioConstraint")({}),
							rowScope:New("UIStroke")({
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = target.RingColor,
								Thickness = RING_THICKNESS,
								Transparency = fade,
							}),
						},
					}),
				},
			})
		end

		local function buildArrow(rowScope: Scope, arrow: Arrow): Instance
			local left = arrow.Side == "Left"
			local x = rowScope:Value(if left then ARROW_LEFT_X else ARROW_RIGHT_X)
			local glide = rowScope:Tween(x, TweenInfo.new(arrow.Lifetime))
			task.delay(MINIGAME.ArrowSettle, function()
				if live[arrow] then
					x:set(ARROW_CENTER_X)
				end
			end)

			local flag = rowScope:Value(false)
			missed[arrow] = flag
			table.insert(rowScope, function()
				missed[arrow] = nil
			end)

			return rowScope:New("ImageLabel")({
				Name = "Arrow",
				BackgroundColor3 = Theme.Colors.Raised,
				BackgroundTransparency = IDLE_TRANSPARENCY,
				Image = ARROW_IMAGE,
				ImageColor3 = rowScope:Tween(
					rowScope:Computed(function(use): Color3
						return if use(flag) then Theme.Colors.Danger else Theme.Colors.Accent
					end),
					MISS_FLASH
				),
				ImageTransparency = 0.2,
				Rotation = if left then 0 else 180,
				Position = rowScope:Computed(function(use): UDim2
					return UDim2.fromScale(use(glide), 0)
				end),
				Size = UDim2.fromScale(ARROW_WIDTH, 1),
				[Fusion.Children] = {
					rowScope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Small) }),
				},
			})
		end

		local function spawnTarget(id: number, index: number, variant: string, schedule: FishingConfig.Schedule)
			if run ~= id then
				return
			end

			local color, ringColor, position = TARGET_COLOR, RING_COLOR, CENTER
			if variant == "Scatter" then
				-- Any hue but the blues of the water behind.
				local hue = random:NextInteger(0, 360)
				if hue >= 170 and hue <= 230 then
					hue = (hue + random:NextInteger(90, 300)) % 360
				end
				color = Color3.fromHSV(hue / 360, 1, 1)
				ringColor = color
				position = UDim2.fromScale(random:NextInteger(10, 85) / 100, random:NextInteger(10, 70) / 100)
			elseif variant ~= "Center" then
				position = UDim2.fromScale(random:NextInteger(10, 85) / 100, random:NextInteger(10, 60) / 100)
			end

			local target: Target = {
				Index = index,
				Position = position,
				Color = color,
				RingColor = ringColor,
				SpawnedAt = os.clock(),
				OpensIn = schedule.Opens[index] - schedule.Spawns[index],
				Lifetime = schedule.Lifetime,
			}
			live[target] = true
			addRow(target, targetLayer, buildTarget)

			task.delay(schedule.Ends[index] - schedule.Spawns[index], function()
				if live[target] then
					removeTarget(target)
				end
			end)
		end

		local function spawnArrow(id: number, index: number, schedule: FishingConfig.Schedule)
			if run ~= id then
				return
			end

			local arrow: Arrow = {
				Index = index,
				Side = if random:NextInteger(1, 2) == 1 then "Left" else "Right",
				OpensAt = os.clock() + schedule.Opens[index] - schedule.Spawns[index],
				Lifetime = schedule.Lifetime,
			}
			live[arrow] = true
			table.insert(arrowQueue, arrow)
			addRow(arrow, lane, buildArrow)

			task.delay(schedule.Ends[index] - schedule.Spawns[index], function()
				if live[arrow] then
					removeArrow(arrow)
				end
			end)
		end

		-- D-pad press: always judges the oldest arrow still coming from that side.
		local function pressSide(side: string)
			for _, arrow in arrowQueue do
				if arrow.Side ~= side or not live[arrow] then
					continue
				end

				if os.clock() < arrow.OpensAt then
					-- Too early: it turns red and is gone.
					live[arrow] = nil
					local flag = missed[arrow]
					if flag then
						flag:set(true)
					end
					task.delay(MISS_FLASH.Time, removeArrow, arrow)
				else
					score(arrow.Index)
					removeArrow(arrow)
				end
				return
			end
		end

		local function start(difficulty: unknown, variant: unknown)
			local schedule = if type(difficulty) == "string" and type(variant) == "string"
				then FishingConfig.GetSchedule(difficulty, variant)
				else nil
			if not schedule then
				return
			end

			run += 1
			local id = run
			clear()
			playing = true
			misses = 0
			points:set(0)

			targetSize:set(FishingConfig.Difficulties[difficulty :: string].ButtonSize)
			waterColor:set(if variant == "Scatter" then SHALLOW_COLOR else DEEP_COLOR)
			difficultyText:set(`Difficulty: {difficulty}`)
			hudShown:set(false)
			laneShown:set(variant == "Arrows")
			shown:set(true)
			water:set(WATER_TRANSPARENCY)

			task.delay(MINIGAME.Intro, function()
				if run ~= id then
					return
				end
				hudShown:set(true)

				for index = 1, MINIGAME.Targets do
					if variant == "Arrows" then
						task.delay(schedule.Spawns[index], spawnArrow, id, index, schedule)
					else
						task.delay(schedule.Spawns[index], spawnTarget, id, index, variant :: string, schedule)
					end
				end
			end)
		end

		local function finish(hits: unknown)
			if not playing then
				return
			end
			run += 1
			local id = run
			playing = false
			clear()

			if type(hits) == "number" and hits >= 0 then
				points:set(hits)
			end
			water:set(1)
			task.delay(FADE.Time, function()
				if run == id then
					shown:set(false)
					laneShown:set(false)
				end
			end)
		end

		local startConnection = FishingService.MinigameStarted:Connect(start)
		local endConnection = FishingService.MinigameEnded:Connect(finish)
		table.insert(scope, function()
			startConnection:Disconnect()
			endConnection:Disconnect()
		end)

		table.insert(scope, UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if not playing or processed or not Fusion.peek(laneShown) then
				return
			end
			if input.KeyCode == Enum.KeyCode.DPadLeft then
				pressSide("Left")
			elseif input.KeyCode == Enum.KeyCode.DPadRight then
				pressSide("Right")
			end
		end))

		-- The whole water is a button: clicking beside the targets costs a hit every few misses.
		local function clickWater()
			if not playing then
				return
			end
			FishingService.Miss:Fire()
			misses += 1
			if misses >= MINIGAME.MissesPerPenalty then
				misses = 0
				points:set(math.max(0, Fusion.peek(points) - 1))
			end
		end

		-- The two layers the rows are parented into (addRow).
		lane = scope:New("Frame")({
			Name = "Controller",
			ZIndex = 2,
			Position = UDim2.fromScale(0, 0.44),
			Size = UDim2.fromScale(1, 0.1),
			BackgroundColor3 = Theme.Colors.Sunken,
			BackgroundTransparency = 0.4,
			Visible = laneShown,
			[Fusion.Children] = {
				scope:New("Frame")({
					Name = "Zone",
					Position = UDim2.fromScale(0.3, 0),
					Size = UDim2.fromScale(0.4, 1),
					BackgroundColor3 = Theme.Colors.Primary,
					BackgroundTransparency = 0.6,
					[Fusion.Children] = {
						scope:New("UIStroke")({ Color = Theme.Colors.Accent, Thickness = 2 }),
					},
				}),
			},
		}) :: Frame
		targetLayer = scope:New("Frame")({
			Name = "Targets",
			ZIndex = 3,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}) :: Frame

		local screen = UI.Screen(scope, {
			Name = "Fishing",
			DisplayOrder = 8,
			IgnoreGuiInset = true,
			Children = {
				scope:New("Frame")({
					Name = "Frame",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = waterColor,
					BackgroundTransparency = scope:Tween(water, FADE),
					Visible = shown,
					[Fusion.Children] = {
						scope:New("TextButton")({
							Name = "Error",
							AutoButtonColor = false,
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),
							Text = "",
							[Fusion.OnEvent("Activated")] = clickWater,
						}),

						lane,
						targetLayer,

						UI.Panel(scope, {
							Name = "Score",
							ZIndex = 4,
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 0, 70),
							Size = UDim2.fromOffset(340, 96),
							Color = Theme.Colors.Background,
							Transparency = Theme.Transparency.Hud,
							Stroke = Theme.Colors.BorderStrong,
							Padding = Theme.Space.M,
							Visible = hudShown,
							Children = {
								UI.Label(scope, {
									Name = "Difficulty",
									Text = difficultyText,
									Variant = "Small",
									Color = Theme.Colors.Accent,
									Size = UDim2.new(1, 0, 0, 22),
								}),
								UI.Label(scope, {
									Name = "Count",
									Text = scope:Computed(function(use): string
										return `{use(points)}/{MINIGAME.Targets}`
									end),
									Variant = "Display",
									TextSize = Theme.TextSize.Title + 8,
									AnchorPoint = Vector2.new(0, 1),
									Position = UDim2.fromScale(0, 1),
									Size = UDim2.new(1, 0, 0, 44),
								}),
							},
						}),
					},
				}),
			},
		})
		-- The targets must sit over the water button whatever the tree order.
		screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		return screen
	end,
}
