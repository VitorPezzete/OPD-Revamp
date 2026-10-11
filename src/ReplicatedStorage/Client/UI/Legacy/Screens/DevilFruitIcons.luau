--!strict
--[[
	Devil fruit HUD (legacy DevilFruitIcons): the small gauges and messages the fruit
	LocalScripts used to draw, now driven by the statuses the fruit code replicates on the
	local character.

		Ope       stamina bar     "OpeStamina" ("<current>|<max>") + "OpeRoom" (Room open)
		Diamond   stamina bar     "DiamondBodyStamina" (0-1, only while the body is on)
		LuckBar   luck gauge      "LuckPercent" (0-100)
		Slash     cooldown text   "SlashFrenzyReadyAt" (server time; not replicated yet)
		Haki      "You feel ..."  shown while the Meditate emote plays

	Where things are, as in the old game. The three bars stand upright side by side at the
	right edge of the screen, a little below mid-height, filling from the bottom (Luck,
	Ope, Diamond from left to right; the old ones were 14 and 5 pixels apart, they are on
	one pitch now). The Slash cooldown is on a ribbon in the bottom-right corner. The Luck
	reels are three pictures in a row at the top centre and the die's face is on the right,
	over the bars (the old one was drawn across their tops). The Haki and Hobby messages
	are a ribbon across the top centre with the screen dimmed behind it; the Hobby one has
	the pair of eyes over the upper half of the screen.

	Effect modules write into this ScreenGui by path (the rework's keeps the same names),
	so these instances keep their names, classes and places in the tree, and are NOT bound
	to state where a module writes them:

		LuckBar.Visible, LuckBar.ChargeBar.Bar.Size        Effects.Status.LuckPercent
		Luck.Visible, Luck.Icon1..Icon3 (Image, Visible)   Effects.OneShot.LuckSlot
		Luck.IconExtra (Image, Visible)                    Effects.OneShot.LuckDice
		Hobby.Visible, Hobby.Eyes.ImageTransparency,       Effects.Status.HobbyControlled
		Hobby.ImageLabel.ImageTransparency,                (Effects.OneShot.HobbyMessage)
		Hobby.TextLabel (Text, TextTransparency),
		Hobby.Frame.BackgroundTransparency

	A bar is written as a share of its width (Bar.Size = UDim2.new(share, -2, 1, -2)), so
	a ChargeBar is still a lying bar turned upright, inside a frame that is not turned (the
	old frame was the one turned, which the screen scaler could only place by its lying
	size). (LuckBar is also bound here from the same status with the same formula, so it
	does not depend on that effect module running.) The Hobby overlay only starts faded out
	here, so that its first line fades in like the others, and the outline of its text
	follows the text, which is all the module fades.
	BurningBoss is not used any more (CompassService sends that line through NotifyService)
	and is not built.

	Stamina only refills while its ability is off, and the server credits the refill when
	the ability is used again, so nothing replicates meanwhile. The bars predict it with
	the server's own formula, expressed as a fraction of the maximum per second:
		Ope      25 * (level / 500) * a ^ a  over  level * a   =  a ^ (a - 1) / 20
		Diamond  500 * p                     over  20000 * p   =  1 / 40
	(a: defense affinity of the fruit's slot). The legacy scripts ran a `while task.wait()`
	loop for this; here a Heartbeat connection exists only while a bar is refilling.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local Optional = require(ReplicatedStorage.Shared.Util.Optional)
local World = require(ReplicatedStorage.Shared.Util.World)

type Scope = Fusion.Scope<typeof(Fusion)>

local OPE_STAMINA = "OpeStamina"
local OPE_ROOM = "OpeRoom"
local OPE_REGEN_DIVISOR = 20
local DIAMOND_STAMINA = "DiamondBodyStamina"
local DIAMOND_REGEN = 1 / 40
local LUCK_STATUS = "LuckPercent"
local MAX_LUCK = 100

local SLASH_FRUIT = "Slash"
local SLASH_READY_AT = "SlashFrenzyReadyAt"
local SLASH_SHOWN_SECONDS = 4
local SLASH_MAX_SECONDS = 200
local SLASH_FADE = TweenInfo.new(0.5)

local MEDITATE_MARK = "CB_Mark3"
local HAKI_MASTER = "QuestHakiMerchant"
-- Melee + Sword + Sniper + Defense levels needed to sense the Haki master.
local SENSE_LEVELS = 1000
local SENSE_SKILLS = { "Melee", "Sword", "Sniper", "Defense" }
local SENSE_RADIUS = 5
local SENSE_HINTS: { { Position: Vector3, Text: string } } = {
	{ Position = Vector3.new(-6051.499, 402.1, -7), Text = "You feel shade" },
	{ Position = Vector3.new(-1181, 218, 1797.5), Text = "You feel hidden" },
	{ Position = Vector3.new(2054, 492, -584.283), Text = "You seek enlightenment" },
	{ Position = Vector3.new(-5159.5, 295, -7800.5), Text = "You feel evil" },
	{ Position = Vector3.new(-2028.5, 239.5, 3382.5), Text = "You hear an echo" },
	{ Position = Vector3.new(6908, 216.5, -1312.414), Text = "You feel cold" },
}
local SENSE_NOTHING = "You don't sense anything"
local SENSE_TOO_WEAK = "You aren't strong enough to sense anything."
local HINT_BACKDROP = 0.3
local HINT_BACKDROP_IN = TweenInfo.new(1)
local HINT_IN = TweenInfo.new(2.5)
local HINT_OUT = TweenInfo.new(0.2)

-- Design pixels of a 1920x1080 screen.
-- The bars: upright, their tops a little above mid-height, the last one 50 px from the edge.
local BAR_SIZE = Vector2.new(40, 328)
local BAR_PITCH = BAR_SIZE.X + Kit.Space.S
local BAR_RIGHT = 50
local BAR_TOP = 0.48
local BAR_FILL_TRANSPARENCY = 0.5
local BAR_TRACK_TRANSPARENCY = 0.7
local OPE_COLOR = Color3.fromRGB(255, 150, 64)
local DIAMOND_COLOR = Color3.fromRGB(41, 255, 237)
local LUCK_COLOR = Color3.fromRGB(255, 255, 0)
-- From the right edge: Diamond, Ope, Luck.
local DIAMOND_SLOT, OPE_SLOT, LUCK_SLOT = 0, 1, 2

-- The ribbon of the messages (the same picture as the weapon unlock banner).
local RIBBON = "rbxassetid://13656415409"
local SLASH_SIZE = Vector2.new(306, 102)
local SLASH_POSITION = UDim2.fromScale(0.9839, 0.8897)
local SLASH_COLOR = Color3.fromRGB(255, 0, 0)
-- Larger than a title: the old messages filled their ribbon.
local MESSAGE_TEXT_SIZE = 44
local MESSAGE_SIZE = Vector2.new(1228, 122)
local MESSAGE_POSITION = UDim2.fromScale(0.5, 0.25)
local HAKI_COLOR = Color3.fromRGB(93, 40, 116)
local HOBBY_COLOR = Color3.fromRGB(255, 0, 0)
local EYES = "rbxassetid://113397675955254"
local EYES_SIZE = Vector2.new(948, 744)
-- The eyes start this far above the ribbon.
local EYES_RISE = 436
-- The dimming behind a message: larger than any screen, whatever the scale.
local BACKDROP_SIZE = UDim2.fromOffset(8000, 5000)

-- The Luck reels: a strip across the screen, its middle a fifth of the way down.
local LUCK_HEIGHT = 152
local REEL_SIZE = Vector2.new(138, LUCK_HEIGHT)
local REELS: { { Name: string, Image: string } } = {
	{ Name = "Icon1", Image = "rbxassetid://109934563325412" },
	{ Name = "Icon2", Image = "rbxassetid://124752643682692" },
	{ Name = "Icon3", Image = "rbxassetid://127211345890609" },
}
local DIE_IMAGE = "rbxassetid://105881039709094"
-- The die's face: at the right edge, just above the bars.
local DIE_TOP = 202

local localPlayer = Players.LocalPlayer

--[[
	A 0-1 reserve: the last value the server sent, plus the refill predicted since then.
]]
local Gauge = {}
Gauge.__index = Gauge

type Gauge = typeof(setmetatable(
	{} :: {
		Fraction: Fusion.Value<number>,
		Base: number,
		Rate: number,
		Since: number?,
		Connection: RBXScriptConnection?,
	},
	Gauge
))

function Gauge.new(scope: Scope): Gauge
	local self: Gauge = setmetatable({
		Fraction = scope:Value(1),
		Base = 1,
		Rate = 0,
		Since = nil :: number?,
		Connection = nil :: RBXScriptConnection?,
	}, Gauge)
	table.insert(scope, function()
		if self.Connection then
			self.Connection:Disconnect()
			self.Connection = nil
		end
	end)
	return self
end

function Gauge.Refresh(self: Gauge)
	local value = self.Base
	if self.Since then
		value += (os.clock() - self.Since) * self.Rate
	end
	value = math.clamp(value, 0, 1)
	self.Fraction:set(value)

	local refilling = self.Since ~= nil and self.Rate > 0 and value < 1
	if refilling and not self.Connection then
		self.Connection = RunService.Heartbeat:Connect(function()
			self:Refresh()
		end)
	elseif not refilling and self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

-- The value the server sent.
function Gauge.SetBase(self: Gauge, fraction: number)
	self.Base = math.clamp(fraction, 0, 1)
	self:Refresh()
end

-- Starts predicting the refill from now.
function Gauge.StartRefill(self: Gauge, ratePerSecond: number)
	self.Rate = ratePerSecond
	self.Since = os.clock()
	self:Refresh()
end

function Gauge.StopRefill(self: Gauge)
	self.Since = nil
	self:Refresh()
end

-- Full and idle (new character).
function Gauge.Reset(self: Gauge)
	self.Base = 1
	self.Since = nil
	self:Refresh()
end

--[[
	One of the upright bars. `slot` counts from the right edge. The frame is upright and
	holds the old lying bar turned a quarter: its Bar is still sized along its length.
]]
local function gauge(
	scope: Scope,
	name: string,
	color: Color3,
	slot: number,
	fraction: Fusion.UsedAs<number>,
	shown: Fusion.UsedAs<boolean>
): Instance
	return scope:New("Frame")({
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(BAR_RIGHT + slot * BAR_PITCH), BAR_TOP, 0),
		Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y),
		Visible = shown,
		[Fusion.Children] = {
			scope:New("ImageLabel")({
				Name = "ChargeBar",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(BAR_SIZE.Y, BAR_SIZE.X),
				Rotation = 90,
				Image = Kit.Images.Bar,
				ImageColor3 = Kit.Colors.BarBack,
				ImageTransparency = BAR_TRACK_TRANSPARENCY,
				[Fusion.Children] = {
					-- Held at the end that is the bottom once turned.
					scope:New("ImageLabel")({
						Name = "Bar",
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -1, 0.5, 0),
						Image = Kit.Images.Bar,
						ImageColor3 = color,
						ImageTransparency = BAR_FILL_TRANSPARENCY,
						Size = scope:Computed(function(use): UDim2
							return UDim2.new(use(fraction), -2, 1, -2)
						end),
					}),
				},
			}),
		},
	})
end

-- The dimming behind a message. The Hobby effect fades it by its BackgroundTransparency.
local function backdrop(scope: Scope): CanvasGroup
	return scope:New("CanvasGroup")({
		Name = "Frame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = BACKDROP_SIZE,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
	}) :: any
end

-- The ribbon of a message, faded out.
local function ribbon(scope: Scope): ImageLabel
	return Kit.Image(scope, {
		Name = "ImageLabel",
		Image = RIBBON,
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.fromScale(1, 1),
		Transparency = 1,
	})
end

-- The line written on a ribbon, faded out. The code that shows it fades it by hand.
local function message(scope: Scope, color: Color3): TextLabel
	local label = Kit.Label(scope, {
		Name = "TextLabel",
		Text = "",
		TextSize = MESSAGE_TEXT_SIZE,
		Color = color,
		Fit = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.55, 0, 1, -2 * Kit.Space.L),
		ZIndex = 3,
	})
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	return label
end

-- Runs callback for the current character and every later one, each with its own scope.
local function eachCharacter(scope: Scope, callback: (characterScope: Scope, character: Model) -> ())
	local current: Scope? = nil
	local function bind(character: Model)
		if current then
			Fusion.doCleanup(current)
		end
		local characterScope = Fusion.scoped(Fusion)
		current = characterScope
		callback(characterScope, character)
	end

	Bind.connect(scope, localPlayer.CharacterAdded, bind)
	table.insert(scope, function()
		if current then
			Fusion.doCleanup(current)
			current = nil
		end
	end)
	if localPlayer.Character then
		bind(localPlayer.Character)
	end
end

local function parseOpeStamina(value: any): number?
	if type(value) ~= "string" then
		return nil
	end
	local fields = string.split(value, "|")
	local current, maximum = tonumber(fields[1]), tonumber(fields[2])
	if not current or not maximum or maximum <= 0 then
		return nil
	end
	return current / maximum
end

local function senseHint(DataController: any): string
	local total = 0
	for _, skill in SENSE_SKILLS do
		local level = DataController:Get(`Skills.{skill}.Level`)
		total += if type(level) == "number" then level else 0
	end
	if total < SENSE_LEVELS then
		return SENSE_TOO_WEAK
	end

	local merchants = World.Merchants()
	local master = merchants and merchants:FindFirstChild(HAKI_MASTER)
	if not master or not master:IsA("Model") then
		return SENSE_NOTHING
	end

	local root = master:FindFirstChild("HumanoidRootPart") or master:FindFirstChild("Torso")
	local position = if root and root:IsA("BasePart") then root.Position else master:GetPivot().Position
	for _, hint in SENSE_HINTS do
		if (hint.Position - position).Magnitude <= SENSE_RADIUS then
			return hint.Text
		end
	end
	return SENSE_NOTHING
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local DataController = Knit.GetController("DataController")
		-- Only for the meditation hint: without emotes (PlaceManifest) there is none.
		local EmoteController = Optional.Controller("EmoteController")

		local firstFruit = Bind.data(scope, "DevilFruits.Slot1.Name", "None")
		local secondFruit = Bind.data(scope, "DevilFruits.Slot2.Name", "None")

		local function owns(use: any, fruitName: string): boolean
			return use(firstFruit) == fruitName or use(secondFruit) == fruitName
		end

		-- Stamina bars ---------------------------------------------------------------
		local ope = Gauge.new(scope)
		local diamond = Gauge.new(scope)
		local luck = scope:Value(nil :: number?)

		local opeBar = gauge(scope, "Ope", OPE_COLOR, OPE_SLOT, ope.Fraction, scope:Computed(function(use): boolean
			return owns(use, "Ope") and use(ope.Fraction) < 1
		end))
		local diamondBar = gauge(
			scope,
			"Diamond",
			DIAMOND_COLOR,
			DIAMOND_SLOT,
			diamond.Fraction,
			scope:Computed(function(use): boolean
				return owns(use, "Diamond") and use(diamond.Fraction) < 1
			end)
		)
		local luckBar = gauge(
			scope,
			"LuckBar",
			LUCK_COLOR,
			LUCK_SLOT,
			scope:Computed(function(use): number
				return math.clamp((use(luck) or 0) / MAX_LUCK, 0, 1)
			end),
			scope:Computed(function(use): boolean
				return use(luck) ~= nil
			end)
		)

		local function opeRefillRate(): number
			local slot = if Fusion.peek(secondFruit) == "Ope" and Fusion.peek(firstFruit) ~= "Ope" then 2 else 1
			local affinity = DataController:Get(`Affinities.DF{slot}.Defense`)
			local a: number = if type(affinity) == "number" and affinity > 0 then affinity else 1
			return a ^ (a - 1) / OPE_REGEN_DIVISOR
		end

		-- Slash Frenzy cooldown ------------------------------------------------------
		local slashShown = scope:Value(false)
		local slashLeft = scope:Value("")
		local slashFade = scope:Tween(
			scope:Computed(function(use): number
				return if use(slashShown) then 0 else 1
			end),
			SLASH_FADE
		)
		local slashThread: thread? = nil

		local function hideCooldown()
			if slashThread then
				-- Never the running thread: showCooldown clears the field before it ends.
				task.cancel(slashThread)
				slashThread = nil
			end
			slashShown:set(false)
		end
		table.insert(scope, hideCooldown)

		-- Shows the seconds left for a moment, as the legacy HUD did on spawn and on
		-- every kill that shortened the cooldown.
		local function showCooldown(readyAt: number)
			hideCooldown()
			slashShown:set(true)

			slashThread = task.spawn(function()
				for _ = 1, SLASH_SHOWN_SECONDS do
					local left = math.clamp(math.floor(readyAt - Workspace:GetServerTimeNow()), 0, SLASH_MAX_SECONDS)
					slashLeft:set(`{left}s`)
					task.wait(1)
				end
				slashThread = nil
				hideCooldown()
			end)
		end

		local slashFrame = scope:New("Frame")({
			Name = "Slash",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = SLASH_POSITION,
			Size = UDim2.fromOffset(SLASH_SIZE.X, SLASH_SIZE.Y),
			Visible = scope:Computed(function(use): boolean
				return use(slashFade) < 1
			end),
			[Fusion.Children] = {
				Kit.Image(scope, {
					Name = "ImageLabel",
					Image = RIBBON,
					ScaleType = Enum.ScaleType.Stretch,
					Size = UDim2.fromScale(1, 1),
					Transparency = slashFade,
				}),
				Kit.Label(scope, {
					Name = "TextLabel",
					Text = slashLeft,
					TextSize = MESSAGE_TEXT_SIZE,
					Color = SLASH_COLOR,
					Fit = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -2 * Kit.Space.XL, 1, -2 * Kit.Space.L),
					ZIndex = 2,
					Transparency = slashFade,
				}),
			},
		})

		-- Meditate hint --------------------------------------------------------------
		local hintText = message(scope, HAKI_COLOR)
		local hintImage = ribbon(scope)
		local hintBackdrop = backdrop(scope)
		local hintFrame: Frame = scope:New("Frame")({
			Name = "Haki",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = MESSAGE_POSITION,
			Size = UDim2.fromOffset(MESSAGE_SIZE.X, MESSAGE_SIZE.Y),
			Visible = false,
			[Fusion.Children] = { hintBackdrop, hintImage, hintText },
		}) :: any
		local hintTweens: { Tween } = {}
		local hintRun = 0
		local meditating: AnimationTrack? = nil

		local function playHint(instance: Instance, info: TweenInfo, goal: { [string]: any })
			local tween = TweenService:Create(instance, info, goal)
			table.insert(hintTweens, tween)
			tween:Play()
		end

		local function stopHintTweens()
			for _, tween in hintTweens do
				tween:Cancel()
			end
			table.clear(hintTweens)
		end

		local function showHint()
			hintRun += 1
			stopHintTweens()
			hintText.Text = senseHint(DataController)
			hintFrame.Visible = true
			playHint(hintBackdrop, HINT_BACKDROP_IN, { BackgroundTransparency = HINT_BACKDROP })
			playHint(hintImage, HINT_IN, { ImageTransparency = 0 })
			playHint(hintText, HINT_IN, { TextTransparency = 0, TextStrokeTransparency = Kit.OutlineTransparency })
		end

		local function hideHint()
			if not hintFrame.Visible then
				return
			end
			hintRun += 1
			local run = hintRun
			stopHintTweens()
			playHint(hintBackdrop, HINT_OUT, { BackgroundTransparency = 1 })
			playHint(hintImage, HINT_OUT, { ImageTransparency = 1 })
			playHint(hintText, HINT_OUT, { TextTransparency = 1, TextStrokeTransparency = 1 })
			task.delay(HINT_OUT.Time, function()
				if hintRun == run then
					hintFrame.Visible = false
				end
			end)
		end

		table.insert(scope, function()
			hintRun += 1
			stopHintTweens()
			hintFrame.Visible = false
		end)

		-- The master comes and goes by being parented in and out of Workspace.Map.Merchants.
		-- (The legacy hint re-read his position every five seconds instead.)
		local merchants = World.Merchants()
		if merchants then
			local function onMerchant(merchant: Instance)
				if merchant.Name == HAKI_MASTER and meditating then
					-- Deferred: he is moved right after being parented.
					task.defer(function()
						if meditating then
							hintText.Text = senseHint(DataController)
						end
					end)
				end
			end
			Bind.connect(scope, merchants.ChildAdded, onMerchant)
			Bind.connect(scope, merchants.ChildRemoved, onMerchant)
		end

		local meditateId: string? = if EmoteController then EmoteController:GetMarkAnimation(MEDITATE_MARK) else nil

		local function watchEmotes(characterScope: Scope, character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			local animator = humanoid and humanoid:WaitForChild("Animator", 10)
			if not animator or not animator:IsA("Animator") or localPlayer.Character ~= character then
				return
			end

			Bind.connect(characterScope, animator.AnimationPlayed, function(track: AnimationTrack)
				local animation = track.Animation
				if not meditateId or not animation or animation.AnimationId ~= meditateId then
					return
				end

				meditating = track
				showHint()

				local function ended()
					if meditating == track then
						meditating = nil
						hideHint()
					end
				end
				-- EmoteController destroys the track as it stops it; with deferred signals
				-- only Destroying is certain to arrive.
				track.Stopped:Connect(ended)
				track.Destroying:Connect(ended)
			end)
		end

		-- Hobby overlay --------------------------------------------------------------
		-- Written by the Hobby effect modules, which fade everything in from wherever it
		-- is and fade TextTransparency only: everything starts faded out, and the outline
		-- follows the text.
		local hobbyText = message(scope, HOBBY_COLOR)
		Bind.connect(scope, hobbyText:GetPropertyChangedSignal("TextTransparency"), function()
			local faded = hobbyText.TextTransparency
			hobbyText.TextStrokeTransparency = Kit.OutlineTransparency + (1 - Kit.OutlineTransparency) * faded
		end)
		local hobby = scope:New("Frame")({
			Name = "Hobby",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = MESSAGE_POSITION,
			Size = UDim2.fromOffset(MESSAGE_SIZE.X, MESSAGE_SIZE.Y),
			Visible = false,
			[Fusion.Children] = {
				backdrop(scope),
				ribbon(scope),
				Kit.Image(scope, {
					Name = "Eyes",
					Image = EYES,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, -EYES_RISE),
					Size = UDim2.fromOffset(EYES_SIZE.X, EYES_SIZE.Y),
					Transparency = 1,
					ZIndex = 2,
				}),
				hobbyText,
			},
		})

		-- Luck reels and die -----------------------------------------------------------
		-- Shown and hidden by the Luck effect modules, picture by picture: each has its
		-- own fixed place, so one appearing does not move the others.
		local luckIcons: { Instance } = {}
		for index, reel in REELS do
			table.insert(
				luckIcons,
				Kit.Image(scope, {
					Name = reel.Name,
					Image = reel.Image,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, (index - 2) * REEL_SIZE.X, 0, 0),
					Size = UDim2.fromOffset(REEL_SIZE.X, REEL_SIZE.Y),
					Visible = false,
				})
			)
		end
		table.insert(
			luckIcons,
			Kit.Image(scope, {
				Name = "IconExtra",
				Image = DIE_IMAGE,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -BAR_RIGHT, 0, DIE_TOP),
				Size = UDim2.fromOffset(REEL_SIZE.X, REEL_SIZE.Y),
				Visible = false,
			})
		)
		-- As wide as the screen, so that the die keeps to its right edge on any screen.
		local luckFrame = scope:New("Frame")({
			Name = "Luck",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.2),
			Size = UDim2.new(1, 0, 0, LUCK_HEIGHT),
			Visible = false,
			[Fusion.Children] = luckIcons,
		})

		-- Per character -------------------------------------------------------------
		eachCharacter(scope, function(characterScope: Scope, character: Model)
			ope:Reset()
			diamond:Reset()
			meditating = nil
			hideHint()

			-- Ope: the replicated value is exact while the Room is open; while it is
			-- closed it is the base the refill is added to.
			local function readOpe()
				local fraction = parseOpeStamina(character:GetAttribute(OPE_STAMINA))
				if fraction then
					ope:SetBase(fraction)
				end
			end
			local function readRoom()
				if character:GetAttribute(OPE_ROOM) ~= nil then
					ope:StopRefill()
				elseif character:GetAttribute(OPE_STAMINA) ~= nil then
					ope:StartRefill(opeRefillRate())
				end
			end
			Bind.connect(characterScope, character:GetAttributeChangedSignal(OPE_STAMINA), readOpe)
			Bind.connect(characterScope, character:GetAttributeChangedSignal(OPE_ROOM), readRoom)
			readOpe()
			readRoom()

			-- Diamond: replicated only while the body is on; it refills from the last
			-- value once the status is gone.
			local function readDiamond()
				local fraction = character:GetAttribute(DIAMOND_STAMINA)
				if type(fraction) == "number" then
					diamond:StopRefill()
					diamond:SetBase(fraction)
				elseif Fusion.peek(diamond.Fraction) < 1 then
					diamond:SetBase(Fusion.peek(diamond.Fraction))
					diamond:StartRefill(DIAMOND_REGEN)
				end
			end
			Bind.connect(characterScope, character:GetAttributeChangedSignal(DIAMOND_STAMINA), readDiamond)
			readDiamond()

			local function readLuck()
				local value = character:GetAttribute(LUCK_STATUS)
				luck:set(if type(value) == "number" then value else nil)
			end
			Bind.connect(characterScope, character:GetAttributeChangedSignal(LUCK_STATUS), readLuck)
			readLuck()

			local function readSlash()
				local readyAt = character:GetAttribute(SLASH_READY_AT)
				local owned = Fusion.peek(firstFruit) == SLASH_FRUIT or Fusion.peek(secondFruit) == SLASH_FRUIT
				if owned and type(readyAt) == "number" then
					showCooldown(readyAt)
				end
			end
			Bind.connect(characterScope, character:GetAttributeChangedSignal(SLASH_READY_AT), readSlash)
			readSlash()

			local thread = task.spawn(watchEmotes, characterScope, character)
			table.insert(characterScope, function()
				if coroutine.status(thread) == "suspended" then
					task.cancel(thread)
				end
			end)
		end)

		return Kit.Screen(scope, {
			Name = "DevilFruitIcons",
			Children = { opeBar, diamondBar, luckBar, slashFrame, hintFrame, hobby, luckFrame },
		})
	end,
}
