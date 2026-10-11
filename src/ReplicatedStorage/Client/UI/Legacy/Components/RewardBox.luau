--!strict
--[[
	One reward box of the shop tab (daily or hourly): the box and its lid, dimmed while
	nothing is waiting, a counter badge on its corner, and the opening sequence. The box
	shakes until the server answers, then the lid lifts, the reward is shown in a burst
	and everything settles back.

		RewardBox(scope, {
			BoxImage = ..., LidImage = ...,
			BurstColor = ..., RewardColor = ..., Icon = gemIcon,
			Pending = daily, Claim = claim, Format = format,
		})

	Returns a cell (a transparent frame) with the box in its middle; the lid is the
	button. Timings are the old game's (ClientRewards); distances are design pixels.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = Kit.Layout & {
	BoxImage: string,
	LidImage: string,
	-- Tint of the burst behind the reward, and colour of the amount written on it.
	BurstColor: Color3,
	RewardColor: Color3,
	-- A picture drawn after the amount (the gem).
	Icon: string?,
	-- Unopened boxes (replicated data: read as it comes, anything but a number counts zero).
	Pending: Fusion.UsedAs<any>,
	-- Asks the server to open one. Yields; returns the amount won or nil when refused.
	Claim: () -> number?,
	Format: (amount: number) -> string,
}

local BURST_IMAGE = "rbxassetid://3796217556"

local CELL_SIZE = Vector2.new(300, 250)
local BOX_SIZE = 150
local BURST_SIZE = 190
local ICON_SIZE = 36

local IDLE_TRANSPARENCY = 0.7
local MAX_SHOWN = 99

-- { rotation, seconds } steps of one shake; the last step is followed by a pause.
local SHAKE = { { -20, 0.05 }, { 15, 0.1 }, { -10, 0.1 }, { 5, 0.1 } }
local SHAKE_SETTLE_SECONDS = 0.1
local SHAKE_PAUSE_SECONDS = 0.8

-- How far the box sinks and the lid rises when it opens.
local OPEN_OFFSET = 50
local OPEN_SECONDS = 0.5
local REWARD_SHOWN_SECONDS = 2
local CLOSE_PAUSE_SECONDS = 0.75

local HOME = UDim2.fromScale(0.5, 0.5)

local function tween(instance: Instance, seconds: number, style: Enum.EasingStyle, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(seconds, style), goal):Play()
end

return function(scope: Scope, props: Props): Frame
	local busy = scope:Value(false)
	local rewardText = scope:Value("")
	local alive = true
	table.insert(scope, function()
		alive = false
	end)

	local pending = scope:Computed(function(use): number
		return tonumber(use(props.Pending)) or 0
	end)
	-- Lit while it opens too: the last box is already counted out when the lid lifts.
	local transparency = scope:Computed(function(use): number
		return if use(pending) > 0 or use(busy) then 0 else IDLE_TRANSPARENCY
	end)

	local box: ImageLabel
	local lid: ImageButton
	local burst: ImageLabel

	-- Nothing below touches the box once the menu is gone (the interface can be swapped
	-- while a box is opening).
	local function rotate(rotation: number, seconds: number, style: Enum.EasingStyle)
		if not alive then
			return
		end
		tween(box, seconds, style, { Rotation = rotation })
		tween(lid, seconds, style, { Rotation = rotation })
		task.wait(seconds)
	end

	local function offset(pixels: number): UDim2
		return UDim2.new(HOME.X.Scale, 0, HOME.Y.Scale, pixels)
	end

	local function open()
		local finished = false
		local amount: number? = nil
		task.spawn(function()
			local ok, result = pcall(props.Claim)
			amount = if ok and type(result) == "number" then result else nil
			finished = true
		end)

		-- The old box shook forever when the server never answered; this one stops with the call.
		repeat
			for _, step in SHAKE do
				rotate(step[1], step[2], Enum.EasingStyle.Linear)
			end
			rotate(0, SHAKE_SETTLE_SECONDS, Enum.EasingStyle.Quart)
			if not finished then
				task.wait(SHAKE_PAUSE_SECONDS)
			end
		until finished or not alive

		if not amount or not alive then
			return
		end

		tween(box, OPEN_SECONDS, Enum.EasingStyle.Quart, { Position = offset(OPEN_OFFSET) })
		tween(lid, OPEN_SECONDS, Enum.EasingStyle.Quart, { Position = offset(-OPEN_OFFSET) })
		task.wait(OPEN_SECONDS)
		if not alive then
			return
		end

		rewardText:set(props.Format(amount))
		tween(burst, OPEN_SECONDS, Enum.EasingStyle.Linear, { Size = UDim2.fromOffset(BURST_SIZE, BURST_SIZE) })
		task.wait(REWARD_SHOWN_SECONDS)
		if not alive then
			return
		end
		tween(burst, OPEN_SECONDS, Enum.EasingStyle.Linear, { Size = UDim2.fromOffset(0, 0) })
		task.wait(OPEN_SECONDS)
		if not alive then
			return
		end

		tween(box, OPEN_SECONDS, Enum.EasingStyle.Quart, { Position = HOME })
		tween(lid, OPEN_SECONDS, Enum.EasingStyle.Quart, { Position = HOME })
		task.wait(CLOSE_PAUSE_SECONDS)
	end

	box = scope:New("ImageLabel")({
		Name = "Box",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = HOME,
		Size = UDim2.fromOffset(BOX_SIZE, BOX_SIZE),
		ZIndex = 1,
		Image = props.BoxImage,
		ImageTransparency = transparency,
	}) :: any

	lid = scope:New("ImageButton")({
		Name = "Lid",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = HOME,
		Size = UDim2.fromOffset(BOX_SIZE, BOX_SIZE),
		ZIndex = 2,
		Image = props.LidImage,
		ImageTransparency = transparency,
		[OnEvent("Activated")] = function()
			if Fusion.peek(busy) or Fusion.peek(pending) < 1 then
				return
			end
			busy:set(true)
			open()
			if alive then
				busy:set(false)
			end
		end,
	}) :: any

	-- Grows from nothing around the middle of the box: it clips what is written on it,
	-- which keeps its own size.
	burst = scope:New("ImageLabel")({
		Name = "Reward",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = HOME,
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 3,
		ClipsDescendants = true,
		Image = BURST_IMAGE,
		ImageColor3 = props.BurstColor,
		[Children] = {
			Kit.Stack(scope, {
				Name = "Amount",
				Direction = "Horizontal",
				Gap = Kit.Space.XS,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Children = {
					Kit.Label(scope, {
						Text = rewardText,
						TextSize = Kit.TextSize.Heading,
						Color = props.RewardColor,
						LayoutOrder = 1,
					}),
					if props.Icon
						then Kit.Image(scope, {
							Image = props.Icon,
							Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
							LayoutOrder = 2,
						})
						else nil,
				} :: { any },
			}),
		},
	}) :: any

	return scope:New("Frame")(Kit.place(props, {
		Name = "RewardBox",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(CELL_SIZE.X, CELL_SIZE.Y),
		[Children] = {
			box,
			lid,
			burst,
			Kit.Badge(scope, {
				Name = "Alert",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, BOX_SIZE / 2 - 12, 0.5, BOX_SIZE / 2 - 12),
				TextSize = Kit.TextSize.Small,
				Visible = scope:Computed(function(use): boolean
					return use(pending) > 0
				end),
				Text = scope:Computed(function(use): string
					local count = use(pending)
					return if count > MAX_SHOWN then `{MAX_SHOWN}+` else tostring(count)
				end),
			}),
		},
	})) :: any
end
