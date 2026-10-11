--!strict
--[[
	The reeling minigame (legacy Fishing gui): ten targets, hit at least seven.

	The old look: the whole screen turns to blue water, the difficulty on a strip at the
	top centre with the count under it, and square targets, each with a large ring that
	closes on it. The gamepad's variant has a lane across the middle of the screen with a
	light zone in its centre, and arrows gliding into it from both ends.

	Targets and arrows are a fixed number of design pixels now (the old ones were a share
	of the screen's width, squashed by an aspect constraint), measured from their middle:
	the centre target is in the centre whatever its size, and both arrows end on the same
	spot.

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

	Targets are hit with the mouse or a finger. Not ported: the "Bait" button (flashed for
	a frame, nothing listened to it) and the DragTemplate / fourth variant (its spawn
	function never existed).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FishingConfig = require(ReplicatedStorage.Shared.Configs.FishingConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local ScreenScale = require(ReplicatedStorage.Client.UI.Util.ScreenScale)

type Scope = Fusion.Scope<typeof(Fusion)>

local MINIGAME = FishingConfig.Minigame
local SHALLOW_COLOR = Color3.fromRGB(66, 189, 255)
local DEEP_COLOR = Color3.fromRGB(28, 39, 255)
local MISS_COLOR = Color3.fromRGB(255, 0, 0)
local WATER_TRANSPARENCY = 0.2
local FADE = TweenInfo.new(1.5)
local MISS_FLASH = TweenInfo.new(0.25)
-- Over the HUD and the touch controls, under the windows, like the rework's.
local DISPLAY_ORDER = 8

-- Design pixels of a 1920x1080 screen.
local DIFFICULTY_SIZE = Vector2.new(384, 64)
local DIFFICULTY_COLOR = Color3.fromRGB(25, 40, 255)
local COUNT_SIZE = Vector2.new(192, 48)
local COUNT_COLOR = Color3.fromRGB(34, 38, 255)
-- Targets are placed by their middle, as a share of the screen: clear of the strips at
-- the top and of the touch controls at the bottom, as the old ranges were.
local CENTER = UDim2.fromScale(0.5, 0.5)
local SCATTER_X, SCATTER_Y = NumberRange.new(14, 89), NumberRange.new(20, 77)
local TIMED_Y = NumberRange.new(20, 67)
local TARGET_CORNER = 8
local TARGET_COLOR = Color3.fromRGB(150, 150, 150)
local RING_THICKNESS = 6
-- The ring starts three times as large as its target.
local RING_OPEN_POSITION, RING_OPEN_SIZE = UDim2.fromScale(-1, -1), UDim2.fromScale(3, 3)
local RING_CLOSED_POSITION, RING_CLOSED_SIZE = UDim2.fromScale(0, 0), UDim2.fromScale(1, 1)

local LANE_HEIGHT = 100
local LANE_POSITION = UDim2.fromScale(0, 0.44)
local LANE_COLOR = Color3.fromRGB(73, 76, 255)
local ARROW = "rbxassetid://135685790731603"
local ARROW_COLOR = Color3.fromRGB(39, 143, 255)
local ARROW_SIZE = Vector2.new(88, LANE_HEIGHT)
local ARROW_LEFT = UDim2.new(0, ARROW_SIZE.X / 2, 0.5, 0)
local ARROW_RIGHT = UDim2.new(1, -ARROW_SIZE.X / 2, 0.5, 0)
local ARROW_CENTER = UDim2.fromScale(0.5, 0.5)

type Arrow = { Button: GuiObject, Index: number, Side: string, OpensAt: number }

-- A target with its ring, as open as it starts. Built and destroyed by the game itself.
local function newTarget(size: number): (TextButton, Frame, UIStroke)
	local target = Instance.new("TextButton")
	target.Name = "Target"
	target.AnchorPoint = Vector2.new(0.5, 0.5)
	target.Size = UDim2.fromOffset(size, size)
	target.BackgroundColor3 = TARGET_COLOR
	target.BackgroundTransparency = 0.5
	target.BorderSizePixel = 0
	target.Text = ""
	-- Hit with a pointer or a finger; never the gamepad's selection.
	target.Selectable = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, TARGET_CORNER)
	corner.Parent = target

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.Position = RING_OPEN_POSITION
	ring.Size = RING_OPEN_SIZE
	ring.Parent = target

	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0, TARGET_CORNER)
	ringCorner.Parent = ring

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = RING_THICKNESS
	stroke.Transparency = 0.5
	stroke.Parent = ring

	return target, ring, stroke
end

-- Judged with the D-pad: the picture itself takes neither clicks nor the selection.
local function newArrow(left: boolean): ImageLabel
	local arrow = Instance.new("ImageLabel")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = if left then ARROW_LEFT else ARROW_RIGHT
	arrow.Size = UDim2.fromOffset(ARROW_SIZE.X, ARROW_SIZE.Y)
	arrow.Rotation = if left then 0 else 180
	arrow.BackgroundColor3 = Kit.Colors.Box
	arrow.BackgroundTransparency = 0.5
	arrow.BorderSizePixel = 0
	arrow.Image = ARROW
	arrow.ImageColor3 = ARROW_COLOR
	arrow.ImageTransparency = 0.5
	arrow.ZIndex = 2
	return arrow
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local FishingService = Knit.GetService("FishingService")

		local difficultyText = scope:Value("")
		local countText = scope:Value("")
		-- The strips come in after the intro; the lane only in the gamepad's variant.
		local stripsShown = scope:Value(false)
		local laneShown = scope:Value(false)

		local random = Random.new()
		-- Bumped whenever a game starts or ends: delayed work of an older game sees it and stops.
		local run = 0
		local playing = false
		local points = 0
		local misses = 0
		local targetSize = 0
		local live: { [Instance]: boolean } = {}
		local arrows: { Arrow } = {}

		-- The interface can be swapped in the middle of a game: whatever was scheduled for
		-- it sees another run and stops, instead of working on a gui that is gone.
		table.insert(scope, function()
			run += 1
			playing = false
			table.clear(live)
			table.clear(arrows)
		end)

		local function showCount()
			countText:set(`{points}/{MINIGAME.Targets}`)
		end

		local function strip(name: string, size: Vector2, color: Color3, transparency: number, text: any, textSize: number, order: number): Instance
			return Kit.Well(scope, {
				Name = name,
				Color = color,
				Transparency = transparency,
				Size = UDim2.fromOffset(size.X, size.Y),
				LayoutOrder = order,
				Children = {
					Kit.Label(scope, {
						Text = text,
						TextSize = textSize,
						Fit = true,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, -2 * Kit.Space.M, 1, -Kit.Space.S),
					}),
				},
			})
		end

		local lane: Frame = scope:New("Frame")({
			Name = "Controller",
			BackgroundColor3 = LANE_COLOR,
			BorderSizePixel = 0,
			Position = LANE_POSITION,
			Size = UDim2.new(1, 0, 0, LANE_HEIGHT),
			Visible = laneShown,
			[Fusion.Children] = {
				-- Where an arrow counts.
				scope:New("Frame")({
					Name = "Zone",
					BackgroundColor3 = Kit.Colors.Box,
					BackgroundTransparency = 0.2,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.3, 0),
					Size = UDim2.fromScale(0.4, 1),
				}),
			},
		}) :: any

		local water: Frame = scope:New("Frame")({
			Name = "Frame",
			BackgroundColor3 = DEEP_COLOR,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			[Fusion.Children] = {
				-- The whole water is a button: clicking beside the targets costs a hit every
				-- few misses.
				scope:New("TextButton")({
					Name = "Error",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = "",
					Selectable = false,
					AutoButtonColor = false,
					[Fusion.OnEvent("Activated")] = function()
						if not playing then
							return
						end
						FishingService.Miss:Fire()
						misses += 1
						if misses >= MINIGAME.MissesPerPenalty then
							misses = 0
							points = math.max(0, points - 1)
							showCount()
						end
					end,
				}),
				lane,
				Kit.Stack(scope, {
					Name = "Strips",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					ZIndex = 3,
					Visible = stripsShown,
					Children = {
						strip("Difficulty", DIFFICULTY_SIZE, DIFFICULTY_COLOR, 0.5, difficultyText, Kit.TextSize.Title, 1),
						strip("Count", COUNT_SIZE, COUNT_COLOR, 0, countText, Kit.TextSize.Heading, 2),
					},
				}),
			},
		}) :: any
		-- Everything on the water is placed by the game as a share of the screen: the
		-- scaler pins nothing here (it would also keep watching every target ever spawned).
		water:SetAttribute("ScreenScale", false)

		local function remove(target: Instance)
			live[target] = nil
			target:Destroy()
		end

		local function score(index: number, target: Instance)
			points += 1
			showCount()
			FishingService.Hit:Fire(index)
			remove(target)
		end

		local function spawnTarget(id: number, index: number, variant: string, schedule: FishingConfig.Schedule)
			if run ~= id then
				return
			end

			local target, ring, stroke = newTarget(targetSize)

			if variant == "Scatter" then
				-- Any hue but the blues of the water behind.
				local hue = random:NextInteger(0, 360)
				if hue >= 170 and hue <= 230 then
					hue = (hue + random:NextInteger(90, 300)) % 360
				end
				local color = Color3.fromHSV(hue / 360, 1, 1)
				target.BackgroundColor3 = color
				stroke.Color = color
				target.Position = UDim2.fromScale(
					random:NextInteger(SCATTER_X.Min, SCATTER_X.Max) / 100,
					random:NextInteger(SCATTER_Y.Min, SCATTER_Y.Max) / 100
				)
			else
				target.BackgroundColor3 = Color3.new(1, 1, 1)
				stroke.Color = Color3.new(0, 0, 0)
				target.Position = if variant == "Center"
					then CENTER
					else UDim2.fromScale(
						random:NextInteger(SCATTER_X.Min, SCATTER_X.Max) / 100,
						random:NextInteger(TIMED_Y.Min, TIMED_Y.Max) / 100
					)
			end

			local spawnedAt = os.clock()
			local opensIn = schedule.Opens[index] - schedule.Spawns[index]
			target.ZIndex = 2
			target.Parent = water
			live[target] = true

			target.Activated:Connect(function()
				if not live[target] then
					return
				end
				if os.clock() - spawnedAt < opensIn then
					-- Too eager: the target is lost.
					remove(target)
				else
					score(index, target)
				end
			end)

			task.delay(MINIGAME.Settle, function()
				if live[target] then
					local info = TweenInfo.new(schedule.Lifetime)
					TweenService:Create(ring, info, { Position = RING_CLOSED_POSITION, Size = RING_CLOSED_SIZE }):Play()
					TweenService:Create(target, info, { BackgroundTransparency = 0 }):Play()
					TweenService:Create(stroke, info, { Transparency = 0 }):Play()
				end
			end)
			task.delay(schedule.Ends[index] - schedule.Spawns[index], function()
				if live[target] then
					remove(target)
				end
			end)
		end

		local function spawnArrow(id: number, index: number, schedule: FishingConfig.Schedule)
			if run ~= id then
				return
			end

			local left = random:NextInteger(1, 2) == 1
			local button = newArrow(left)
			button.Parent = lane
			live[button] = true

			local arrow: Arrow = {
				Button = button,
				Index = index,
				Side = if left then "Left" else "Right",
				OpensAt = os.clock() + schedule.Opens[index] - schedule.Spawns[index],
			}
			table.insert(arrows, arrow)

			task.delay(MINIGAME.ArrowSettle, function()
				if live[button] then
					TweenService:Create(button, TweenInfo.new(schedule.Lifetime), { Position = ARROW_CENTER }):Play()
				end
			end)
			task.delay(schedule.Ends[index] - schedule.Spawns[index], function()
				if live[button] then
					remove(button)
				end
			end)
		end

		-- D-pad press: always judges the oldest arrow still coming from that side.
		local function pressSide(side: string)
			for position, arrow in arrows do
				if arrow.Side ~= side or not live[arrow.Button] then
					continue
				end
				table.remove(arrows, position)

				if os.clock() < arrow.OpensAt then
					local button = arrow.Button
					live[button] = nil
					TweenService:Create(button, MISS_FLASH, { ImageColor3 = MISS_COLOR }):Play()
					task.delay(MISS_FLASH.Time, button.Destroy, button)
				else
					score(arrow.Index, arrow.Button)
				end
				return
			end
		end

		local function clear()
			for target in live do
				target:Destroy()
			end
			table.clear(live)
			table.clear(arrows)
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
			points, misses = 0, 0

			-- The config gives a target's side as a share of the reference screen's width.
			local buttonSize = FishingConfig.Difficulties[difficulty :: string].ButtonSize
			targetSize = math.round(buttonSize.X.Scale * ScreenScale.Reference.X + buttonSize.X.Offset)
			water.BackgroundColor3 = if variant == "Scatter" then SHALLOW_COLOR else DEEP_COLOR
			water.BackgroundTransparency = 1
			difficultyText:set(`Difficulty: {difficulty}`)
			stripsShown:set(false)
			showCount()
			laneShown:set(variant == "Arrows")
			water.Visible = true
			TweenService:Create(water, FADE, { BackgroundTransparency = WATER_TRANSPARENCY }):Play()

			task.delay(MINIGAME.Intro, function()
				if run ~= id then
					return
				end
				stripsShown:set(true)

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
				points = hits
				showCount()
			end
			TweenService:Create(water, FADE, { BackgroundTransparency = 1 }):Play()
			task.delay(FADE.Time, function()
				if run == id then
					water.Visible = false
					laneShown:set(false)
				end
			end)
		end

		Bind.connect(scope, FishingService.MinigameStarted, start)
		Bind.connect(scope, FishingService.MinigameEnded, finish)

		Bind.connect(scope, UserInputService.InputBegan, function(input: InputObject, processed: boolean)
			if not playing or processed or not Fusion.peek(laneShown) then
				return
			end
			if input.KeyCode == Enum.KeyCode.DPadLeft then
				pressSide("Left")
			elseif input.KeyCode == Enum.KeyCode.DPadRight then
				pressSide("Right")
			end
		end)

		return Kit.Screen(scope, {
			Name = "Fishing",
			DisplayOrder = DISPLAY_ORDER,
			Children = { water },
		})
	end,
}
