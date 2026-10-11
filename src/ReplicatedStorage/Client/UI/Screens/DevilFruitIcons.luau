--!strict
--[[
	Devil fruit HUD: the small gauges and messages that belong to a fruit, driven by the
	statuses the fruit code replicates on the local character.

		Ope       stamina gauge   "OpeStamina" ("<current>|<max>") + "OpeRoom" (Room open)
		Diamond   stamina gauge   "DiamondBodyStamina" (0-1, only while the body is on)
		LuckBar   luck gauge      "LuckPercent" (0-100)
		Slash     cooldown        "SlashFrenzyReadyAt" (server time)
		Sense     "You feel ..."  shown while the Meditate emote plays

	Effect modules write into this ScreenGui by path, exactly as they do with the legacy
	one, so these instances keep the legacy names and are NOT bound to state where a
	module writes them:

		LuckBar.Visible, LuckBar.ChargeBar.Bar.Size        Effects.Status.LuckPercent
		Luck.Visible, Luck.Icon1..Icon3 (Image, Visible)   Effects.OneShot.LuckSlot
		Luck.IconExtra (Image, Visible)                    Effects.OneShot.LuckDice
		Hobby.Visible, Hobby.Eyes.ImageTransparency,       Effects.Status.HobbyControlled
		Hobby.TextLabel (Text, TextTransparency),
		Hobby.Frame.BackgroundTransparency

	(LuckBar is also bound here from the same status with the same formula, so it does
	not depend on that effect module running.)

	Stamina only refills while its ability is off, and the server credits the refill when
	the ability is used again, so nothing replicates meanwhile. The gauges predict it with
	the server's own formula, expressed as a fraction of the maximum per second:
		Ope      25 * (level / 500) * a ^ a  over  level * a   =  a ^ (a - 1) / 20
		Diamond  500 * p                     over  20000 * p   =  1 / 40
	(a: defense affinity of the fruit's slot). A Heartbeat connection exists only while a
	gauge is refilling.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)
local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Optional = require(ReplicatedStorage.Shared.Util.Optional)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

local OPE_FRUIT = "Ope"
local OPE_STAMINA = "OpeStamina"
local OPE_ROOM = "OpeRoom"
local OPE_REGEN_DIVISOR = 20
local DIAMOND_FRUIT = "Diamond"
local DIAMOND_STAMINA = "DiamondBodyStamina"
local DIAMOND_REGEN = 1 / 40
local LUCK_STATUS = "LuckPercent"
local MAX_LUCK = 100

local SLASH_FRUIT = "Slash"
local SLASH_READY_AT = "SlashFrenzyReadyAt"
local SLASH_SHOWN_SECONDS = 4
local SLASH_MAX_SECONDS = 200

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
local SENSE_BACKDROP = 0.3
local SENSE_BACKDROP_IN = TweenInfo.new(1)
local SENSE_TEXT_IN = TweenInfo.new(2.5)
local SENSE_OUT = TweenInfo.new(0.2)

-- Game art.
local HOBBY_EYES = "rbxassetid://113397675955254"
local SLOT_PLACEHOLDER = "rbxassetid://109934563325412"
local DICE_PLACEHOLDER = "rbxassetid://105881039709094"

-- Gauges stack upwards from the bottom right corner (the version label sits under them).
local GAUGE_SIZE = UDim2.fromOffset(280, 40)
local GAUGE_STEP = 40 + Theme.Space.S
local GAUGE_MARGIN = 24
local GAUGE_BOTTOM = 72
local GAUGE_TITLE_WIDTH = 78
local GAUGE_TRACK_HEIGHT = 14

local REEL_SIZE = 84
local REEL_STEP = REEL_SIZE + Theme.Space.M
local MESSAGE_SIZE = UDim2.fromOffset(1200, 64)

local localPlayer = Players.LocalPlayer

--[[
	A 0-1 reserve: the last value the server sent, plus the refill predicted since then.
]]
local Reserve = {}
Reserve.__index = Reserve

type Reserve = typeof(setmetatable(
	{} :: {
		Fraction: Fusion.Value<number>,
		Base: number,
		Rate: number,
		Since: number?,
		Connection: RBXScriptConnection?,
	},
	Reserve
))

function Reserve.new(scope: Scope): Reserve
	local self: Reserve = setmetatable({
		Fraction = scope:Value(1),
		Base = 1,
		Rate = 0,
		Since = nil :: number?,
		Connection = nil :: RBXScriptConnection?,
	}, Reserve)
	table.insert(scope, function()
		if self.Connection then
			self.Connection:Disconnect()
			self.Connection = nil
		end
	end)
	return self
end

function Reserve.Refresh(self: Reserve)
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
function Reserve.SetBase(self: Reserve, fraction: number)
	self.Base = math.clamp(fraction, 0, 1)
	self:Refresh()
end

-- Starts predicting the refill from now.
function Reserve.StartRefill(self: Reserve, ratePerSecond: number)
	self.Rate = ratePerSecond
	self.Since = os.clock()
	self:Refresh()
end

function Reserve.StopRefill(self: Reserve)
	self.Since = nil
	self:Refresh()
end

-- Full and idle (new character).
function Reserve.Reset(self: Reserve)
	self.Base = 1
	self.Since = nil
	self:Refresh()
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

-- Where the gauge with `slot` visible gauges under it sits.
local function gaugePosition(scope: Scope, slot: UsedAs<number>): UsedAs<UDim2>
	return scope:Computed(function(use): UDim2
		return UDim2.new(1, -GAUGE_MARGIN, 1, -(GAUGE_BOTTOM + use(slot) * GAUGE_STEP))
	end)
end

type GaugeProps = {
	Name: string,
	Title: string,
	Color: Color3,
	Fraction: UsedAs<number>,
	Visible: UsedAs<boolean>,
	Position: UsedAs<UDim2>,
}

--[[
	A titled bar. The track and its fill are named ChargeBar / Bar and the fill is sized
	`UDim2.new(fraction, -2, 1, -2)`: Effects.Status.LuckPercent writes that path itself.
]]
local function gauge(scope: Scope, props: GaugeProps): Frame
	local pill = UDim.new(0, Theme.Radius.Pill)

	return UI.Panel(scope, {
		Name = props.Name,
		AnchorPoint = Vector2.new(1, 1),
		Position = props.Position,
		Size = GAUGE_SIZE,
		Color = Theme.Colors.Background,
		Transparency = Theme.Transparency.Hud,
		Visible = props.Visible,
		Children = {
			UI.Label(scope, {
				Name = "Title",
				Text = props.Title,
				Variant = "Tiny",
				Font = Theme.Fonts.Heading,
				Color = Theme.Colors.TextMuted,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, Theme.Space.M, 0.5, 0),
				Size = UDim2.fromOffset(GAUGE_TITLE_WIDTH, 20),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("Frame")({
				Name = "ChargeBar",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -Theme.Space.M, 0.5, 0),
				Size = UDim2.new(1, -(GAUGE_TITLE_WIDTH + Theme.Space.M * 2 + Theme.Space.S), 0, GAUGE_TRACK_HEIGHT),
				BackgroundColor3 = Theme.Colors.Sunken,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = pill }),
					scope:New("UIStroke")({ Color = Theme.Colors.Border, Thickness = 1 }),
					scope:New("Frame")({
						Name = "Bar",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 1, 0.5, 0),
						Size = scope:Computed(function(use): UDim2
							return UDim2.new(math.clamp(use(props.Fraction), 0, 1), -2, 1, -2)
						end),
						BackgroundColor3 = props.Color,
						[Fusion.Children] = { scope:New("UICorner")({ CornerRadius = pill }) },
					}),
				},
			}),
		},
	})
end

-- A slot the Luck effect modules put a picture in. Hidden until one of them shows it.
local function reel(scope: Scope, name: string, image: string, position: UDim2): ImageLabel
	return UI.Image(scope, {
		Name = name,
		Image = image,
		Background = Theme.Colors.Background,
		Radius = Theme.Radius.Medium,
		Position = position,
		Size = UDim2.fromOffset(REEL_SIZE, REEL_SIZE),
		Visible = false,
		Children = {
			scope:New("UIStroke")({ Color = Theme.Colors.BorderStrong, Thickness = 2 }),
		},
	})
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

		-- Gauges -------------------------------------------------------------------
		local ope = Reserve.new(scope)
		local diamond = Reserve.new(scope)
		local luck = scope:Value(nil :: number?)

		local luckVisible = scope:Computed(function(use): boolean
			return use(luck) ~= nil
		end)
		local opeVisible = scope:Computed(function(use): boolean
			return owns(use, OPE_FRUIT) and use(ope.Fraction) < 1
		end)
		local diamondVisible = scope:Computed(function(use): boolean
			return owns(use, DIAMOND_FRUIT) and use(diamond.Fraction) < 1
		end)

		-- Number of gauges shown among `below`: the slot of the gauge above them.
		local function slotAbove(below: { UsedAs<boolean> }): UsedAs<number>
			return scope:Computed(function(use): number
				local count = 0
				for _, visible in below do
					if use(visible) then
						count += 1
					end
				end
				return count
			end)
		end

		local function opeRefillRate(): number
			local onSecond = Fusion.peek(secondFruit) == OPE_FRUIT and Fusion.peek(firstFruit) ~= OPE_FRUIT
			local affinity = DataController:Get(`Affinities.DF{if onSecond then 2 else 1}.Defense`)
			local a: number = if type(affinity) == "number" and affinity > 0 then affinity else 1
			return a ^ (a - 1) / OPE_REGEN_DIVISOR
		end

		-- Slash Frenzy cooldown ----------------------------------------------------
		local slashShown = scope:Value(false)
		local slashSeconds = scope:Value(0)
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

		-- Shows the seconds left for a moment: on spawn and whenever the cooldown changes
		-- (every kill shortens it).
		local function showCooldown(readyAt: number)
			hideCooldown()
			slashShown:set(true)
			slashThread = task.spawn(function()
				for _ = 1, SLASH_SHOWN_SECONDS do
					local left = math.floor(readyAt - Workspace:GetServerTimeNow())
					slashSeconds:set(math.clamp(left, 0, SLASH_MAX_SECONDS))
					task.wait(1)
				end
				slashThread = nil
				hideCooldown()
			end)
		end

		-- Meditate hint ------------------------------------------------------------
		local senseShown = scope:Value(false)
		local senseText = scope:Value("")
		local meditating: AnimationTrack? = nil

		local senseBackdrop = scope:Tween(
			scope:Computed(function(use): number
				return if use(senseShown) then SENSE_BACKDROP else 1
			end),
			scope:Computed(function(use): TweenInfo
				return if use(senseShown) then SENSE_BACKDROP_IN else SENSE_OUT
			end)
		)
		local senseFade = scope:Tween(
			scope:Computed(function(use): number
				return if use(senseShown) then 0 else 1
			end),
			scope:Computed(function(use): TweenInfo
				return if use(senseShown) then SENSE_TEXT_IN else SENSE_OUT
			end)
		)

		local function showHint()
			senseText:set(senseHint(DataController))
			senseShown:set(true)
		end
		local function hideHint()
			senseShown:set(false)
		end

		-- The master comes and goes by being parented in and out of Workspace.Map.Merchants.
		local merchants = World.Merchants()
		if merchants then
			local function onMerchant(merchant: Instance)
				if merchant.Name == HAKI_MASTER and meditating then
					-- Deferred: he is moved right after being parented.
					task.defer(function()
						if meditating then
							senseText:set(senseHint(DataController))
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
				-- only Destroying is certain to arrive. Both die with the track.
				track.Stopped:Connect(ended)
				track.Destroying:Connect(ended)
			end)
		end

		-- Per character ------------------------------------------------------------
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

		-- Hobby overlay ------------------------------------------------------------
		-- Written by Effects.Status.HobbyControlled, which fades TextTransparency only:
		-- the outline of the text follows it from here.
		local hobbyText = UI.Label(scope, {
			Name = "TextLabel",
			Text = "",
			Variant = "Title",
			Color = Theme.Colors.Danger,
			Outline = true,
			Transparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.32),
			Size = MESSAGE_SIZE,
			ZIndex = 3,
		})
		local hobbyOutline = hobbyText:FindFirstChildOfClass("UIStroke")
		if hobbyOutline then
			local outline: UIStroke = hobbyOutline
			Bind.connect(scope, hobbyText:GetPropertyChangedSignal("TextTransparency"), function()
				outline.Transparency = hobbyText.TextTransparency
			end)
		end

		return UI.Screen(scope, {
			Name = "DevilFruitIcons",
			DisplayOrder = 1,
			IgnoreGuiInset = true,
			Children = {
				-- Bottom right, stacked upwards: luck, Ope, Diamond, Slash.
				gauge(scope, {
					Name = "LuckBar",
					Title = "LUCK",
					Color = Theme.Colors.Beri,
					Fraction = scope:Computed(function(use): number
						return (use(luck) or 0) / MAX_LUCK
					end),
					Visible = luckVisible,
					Position = gaugePosition(scope, 0),
				}),
				gauge(scope, {
					Name = "Ope",
					Title = "ROOM",
					Color = Theme.Colors.Stamina,
					Fraction = ope.Fraction,
					Visible = opeVisible,
					Position = gaugePosition(scope, slotAbove({ luckVisible })),
				}),
				gauge(scope, {
					Name = "Diamond",
					Title = "DIAMOND",
					Color = Theme.Colors.Gems,
					Fraction = diamond.Fraction,
					Visible = diamondVisible,
					Position = gaugePosition(scope, slotAbove({ luckVisible, opeVisible })),
				}),
				UI.Panel(scope, {
					Name = "Slash",
					AnchorPoint = Vector2.new(1, 1),
					Position = gaugePosition(scope, slotAbove({ luckVisible, opeVisible, diamondVisible })),
					Size = GAUGE_SIZE,
					Color = Theme.Colors.Background,
					Transparency = Theme.Transparency.Hud,
					Stroke = Theme.Colors.Danger,
					Visible = slashShown,
					Children = {
						UI.Label(scope, {
							Name = "Title",
							Text = "SLASH FRENZY",
							Variant = "Tiny",
							Font = Theme.Fonts.Heading,
							Color = Theme.Colors.TextMuted,
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0, Theme.Space.M, 0.5, 0),
						}),
						UI.Label(scope, {
							Name = "Seconds",
							Text = scope:Computed(function(use): string
								return `{use(slashSeconds)}s`
							end),
							Variant = "Heading",
							Color = Theme.Colors.Danger,
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -Theme.Space.M, 0.5, 0),
						}),
					},
				}),

				-- Upper centre: the reels of the slot machine and, under them, the die face.
				scope:New("Frame")({
					Name = "Luck",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.2),
					Size = UDim2.fromOffset(REEL_STEP * 2 + REEL_SIZE, REEL_STEP + REEL_SIZE),
					BackgroundTransparency = 1,
					Visible = false,
					[Fusion.Children] = {
						reel(scope, "Icon1", SLOT_PLACEHOLDER, UDim2.fromOffset(0, 0)),
						reel(scope, "Icon2", SLOT_PLACEHOLDER, UDim2.fromOffset(REEL_STEP, 0)),
						reel(scope, "Icon3", SLOT_PLACEHOLDER, UDim2.fromOffset(REEL_STEP * 2, 0)),
						reel(scope, "IconExtra", DICE_PLACEHOLDER, UDim2.fromOffset(REEL_STEP, REEL_STEP)),
					},
				}),

				-- The order a Hobby user gave to its toy, over a dimmed screen.
				scope:New("Frame")({
					Name = "Hobby",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Visible = false,
					ZIndex = 5,
					[Fusion.Children] = {
						scope:New("Frame")({
							Name = "Frame",
							Size = UDim2.fromScale(1, 1),
							BackgroundColor3 = Theme.Colors.Backdrop,
							BackgroundTransparency = 1,
						}),
						UI.Image(scope, {
							Name = "Eyes",
							Image = HOBBY_EYES,
							Transparency = 1,
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.fromScale(0.5, -0.1),
							Size = UDim2.fromScale(0.9, 0.7),
							ZIndex = 2,
						}),
						hobbyText,
					},
				}),

				-- What the player senses while meditating.
				scope:New("Frame")({
					Name = "Sense",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.Colors.Black,
					BackgroundTransparency = senseBackdrop,
					Visible = scope:Computed(function(use): boolean
						return use(senseBackdrop) < 1 or use(senseFade) < 1
					end),
					ZIndex = 4,
					[Fusion.Children] = {
						UI.Label(scope, {
							Name = "Hint",
							Text = senseText,
							Variant = "Title",
							Color = Theme.Colors.Accent,
							Outline = true,
							Transparency = senseFade,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.25),
							Size = MESSAGE_SIZE,
						}),
					},
				}),
			},
		})
	end,
}
