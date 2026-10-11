--!strict
--[[
	The emote shop of the EmoteMerchant ("Professional Dancer"): one card per unlockable
	emote with a preview and a buy button that turns into "Owned".

	Prices come from ShopConfig; the purchase goes through ShopService like every other
	merchant (the legacy shop had its own remote and a 146 line if-chain of prices).

	The old dark blue board with its blue sheet: what Hans says in the dark box, the lilac
	strip of dancers scrolling sideways under it (each with its price button), his portrait
	and name on the right, the player's Beri beside the title.

	Preview: the legacy cards copied, every frame and part by part, the pose of the
	matching dancer standing next to the merchant. Here the card gets its own copy of
	that dancer in a WorldModel and simply plays the emote on it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ShopConfig = require(ReplicatedStorage.Shared.Configs.ShopConfig)
local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

local MERCHANT_NAME = "EmoteMerchant"
local PRICE_COLOR = Color3.fromRGB(0, 255, 0)
local OWNED_COLOR = Color3.fromRGB(255, 255, 255)
local OUTER_COLOR = Color3.fromRGB(0, 37, 93)
local INNER_COLOR = Color3.fromRGB(7, 0, 221)
local STRIP_COLOR = Color3.fromRGB(157, 164, 255)
local PORTRAIT_IMAGE = "rbxassetid://3685581766"
local LINE = "Do you wish that you could flex on people like me? You're in the right place, buddy."

-- Design pixels. The old board was 1.3 x 0.7 of the screen's height.
local WINDOW_SIZE = Vector2.new(1320, 700)
local FRAME_MARGIN = 30
local TITLE_HEIGHT = 56
local SIDE_WIDTH = 300
local NAME_HEIGHT = 40
local PORTRAIT_SIZE = 238
local CARD_WIDTH = 220
local BUY_HEIGHT = 48
local SCROLL_BAR = 8
local STRIP_HEIGHT = CARD_WIDTH + Kit.Space.S + BUY_HEIGHT + 2 * Kit.Space.S + SCROLL_BAR + Kit.Space.XS
local CAMERA_CFRAME = CFrame.new(Vector3.new(0, 4, 5), Vector3.new(0, 1, 0))

local function findDancer(markName: string): Model?
	local merchants = World.Merchants()
	local merchant = merchants and merchants:FindFirstChild(MERCHANT_NAME)
	local dancers = merchant and merchant:FindFirstChild("Dancers")
	local dancer = dancers and dancers:FindFirstChild(markName)
	return if dancer and dancer:IsA("Model") then dancer else nil
end

-- Fills a card's ViewportFrame with a dancing copy of the workspace dancer.
local function buildPreview(scope: Scope, viewport: ViewportFrame, markName: string)
	local source = findDancer(markName)
	local animationId = Knit.GetController("EmoteController"):GetMarkAnimation(markName)
	if not source or not animationId then
		return
	end

	local wasArchivable = source.Archivable
	source.Archivable = true
	local dancer = source:Clone()
	source.Archivable = wasArchivable
	if not dancer then
		return
	end

	for _, descendant in dancer:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end

	local world = Instance.new("WorldModel")
	local camera = Instance.new("Camera")
	camera.CFrame = CAMERA_CFRAME
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	table.insert(scope, world)
	table.insert(scope, camera)

	-- Facing the camera, as the legacy preview did.
	dancer:PivotTo(CFrame.lookAt(Vector3.zero, CAMERA_CFRAME.Position))
	dancer.Parent = world
	world.Parent = viewport

	local humanoid = dancer:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	table.insert(scope, animation)

	-- An Animator only loads animations once it is in the game, and the gui is
	-- parented after Mount returns.
	local started = false
	local function start()
		if started or not viewport:IsDescendantOf(game) then
			return
		end
		started = true
		local ok, problem = pcall(function()
			local track = (animator :: Animator):LoadAnimation(animation)
			track.Looped = true
			track:Play()
		end)
		if not ok then
			warn(`[EmoteShop] preview of {markName} failed: {problem}`)
		end
	end
	table.insert(scope, viewport.AncestryChanged:Connect(start))
	start()
end

return {
	Merchants = { MERCHANT_NAME },

	Mount = function(scope: Scope, _gui: any, context: any): ScreenGui
		local owned = Bind.data(scope, "Emotes", {})

		-- Name of the emote whose purchase is waiting for the server.
		local buying: Fusion.Value<string?> = scope:Value(nil :: string?)
		local closed = false
		table.insert(scope, function()
			closed = true
		end)

		local cards: { any } = {}
		for order, item in ShopConfig.Merchants[MERCHANT_NAME].Items do
			local isOwned = scope:Computed(function(use): boolean
				local emotes = use(owned)
				return type(emotes) == "table" and emotes[item.Name] == true
			end)
			local price = Bind.formatNumber(item.Price) .. (if item.Currency == "Gems" then " Gems" else "$")

			local viewport: ViewportFrame = scope:New("ViewportFrame")({
				Name = "Preview",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(CARD_WIDTH, CARD_WIDTH),
			}) :: any
			-- A broken dancer model must not take the shop down with it.
			local ok, problem = pcall(buildPreview, scope, viewport, item.Name)
			if not ok then
				warn(`[EmoteShop] preview of {item.Name} failed: {problem}`)
			end

			table.insert(
				cards,
				Kit.Stack(scope, {
					Name = item.Name,
					LayoutOrder = order,
					Gap = Kit.Space.S,
					Size = UDim2.fromOffset(CARD_WIDTH, CARD_WIDTH + Kit.Space.S + BUY_HEIGHT),
					Children = {
						viewport,
						Kit.Button(scope, {
							Name = "Buy",
							LayoutOrder = 2,
							-- Grey once owned, as the old button changed its style.
							Variant = scope:Computed(function(use): Kit.Variant
								return if use(isOwned) then "Grey" else "Blue"
							end),
							Text = scope:Computed(function(use): string
								if use(isOwned) then
									return "Owned"
								end
								return if use(buying) == item.Name then "..." else price
							end),
							TextColor = scope:Computed(function(use): Color3
								return if use(isOwned) then OWNED_COLOR else PRICE_COLOR
							end),
							Size = UDim2.fromOffset(CARD_WIDTH, BUY_HEIGHT),
							OnClick = function()
								-- One purchase at a time: the others wait for the server's answer.
								if Fusion.peek(isOwned) or Fusion.peek(buying) then
									return
								end
								buying:set(item.Name)
								ShopScreen.buy(MERCHANT_NAME, item.Name, function()
									if not closed then
										buying:set(nil)
									end
								end)
							end,
						}),
					},
				})
			)
		end

		local contentTop = TITLE_HEIGHT + Kit.Space.S
		local footer = Kit.Space.S + ShopScreen.HINT_HEIGHT
		local leftWidth = -(SIDE_WIDTH + Kit.Space.XL)

		local window = ShopScreen.Board(scope, {
			Color = OUTER_COLOR,
			Transparency = 0.5,
			Padding = FRAME_MARGIN,
			Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
			Children = {
				ShopScreen.Board(scope, {
					Name = "Frame",
					Color = INNER_COLOR,
					Transparency = 0.5,
					Padding = Kit.Space.L,
					Size = UDim2.fromScale(1, 1),
					Children = {
						Kit.Label(scope, {
							Name = "Shop",
							Text = "Professional Dancer",
							TextSize = Kit.TextSize.Title,
							Fit = true,
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.fromScale(0.5, 0),
							Size = UDim2.new(1, -2 * (SIDE_WIDTH + Kit.Space.M), 0, TITLE_HEIGHT),
						}),
						ShopScreen.Balance(scope, {
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.fromOffset(SIDE_WIDTH, TITLE_HEIGHT),
						}),

						Kit.Well(scope, {
							Name = "Dia",
							Transparency = 0.7,
							Padding = Kit.Space.M,
							Position = UDim2.fromOffset(0, contentTop),
							Size = UDim2.new(1, leftWidth, 1, -(contentTop + Kit.Space.M + STRIP_HEIGHT + footer)),
							Children = {
								Kit.Label(scope, {
									Text = LINE,
									TextSize = Kit.TextSize.Title,
									Fit = true,
									Size = UDim2.fromScale(1, 1),
								}),
							},
						}),
						Kit.Well(scope, {
							Name = "Dancers",
							Color = STRIP_COLOR,
							Transparency = 0,
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.new(0, 0, 1, -footer),
							Size = UDim2.new(1, leftWidth, 0, STRIP_HEIGHT),
							Children = {
								Kit.Scroll(scope, {
									Direction = "Horizontal",
									Background = false,
									Gap = Kit.Space.M,
									Padding = Kit.Space.S,
									Children = cards,
								}),
							},
						}),

						Kit.Stack(scope, {
							Name = "Hans",
							Gap = Kit.Space.XS,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, 0, 0, contentTop),
							Size = UDim2.new(0, SIDE_WIDTH, 1, -(contentTop + footer)),
							Children = {
								Kit.Label(scope, {
									Name = "LabelName",
									LayoutOrder = 1,
									Text = "Hans",
									TextSize = Kit.TextSize.Heading,
									Size = UDim2.new(1, 0, 0, NAME_HEIGHT),
								}),
								Kit.Image(scope, {
									Name = "Portrait",
									LayoutOrder = 2,
									Image = PORTRAIT_IMAGE,
									Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE),
								}),
							},
						}),

						ShopScreen.Hint(scope, {
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
						}),
					},
				}),
			},
		})

		ShopScreen.closeOnMove(scope, context)

		return Kit.Screen(scope, {
			Name = context.Name,
			Children = { window },
		})
	end,
}
