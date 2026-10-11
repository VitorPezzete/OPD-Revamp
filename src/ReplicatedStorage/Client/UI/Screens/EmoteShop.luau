--!strict
--[[
	The emote shop of the EmoteMerchant ("Professional Dancer"): one card per unlockable
	emote with a dancing preview and a buy button that turns into "Owned".

	Prices come from ShopConfig; the purchase goes through ShopService like every other
	merchant. Each card gets its own copy of the matching dancer standing next to the
	merchant, in a WorldModel, and plays the emote on it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ShopConfig = require(ReplicatedStorage.Shared.Configs.ShopConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local MerchantSpeech = require(ReplicatedStorage.Client.UI.Components.MerchantSpeech)
local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

type Scope = Theme.Scope

local MERCHANT_NAME = "EmoteMerchant"
local PORTRAIT = "rbxassetid://3685581766"
local GREETING = "Do you wish that you could flex on people like me? You're in the right place, buddy."
local CAMERA_CFRAME = CFrame.new(Vector3.new(0, 4, 5), Vector3.new(0, 1, 0))

local SPEECH_HEIGHT = 120
local HINT_HEIGHT = 22
local CELL = Vector2.new(180, 250)
local BUY_HEIGHT = 40
local TITLE_HEIGHT = 24

local function findDancer(markName: string): Model?
	local merchants = World.Merchants()
	local merchant = merchants and merchants:FindFirstChild(MERCHANT_NAME)
	local dancers = merchant and merchant:FindFirstChild("Dancers")
	local dancer = dancers and dancers:FindFirstChild(markName)
	return if dancer and dancer:IsA("Model") then dancer else nil
end

-- "CB_Mark7" -> "Emote 7"
local function displayName(markName: string): string
	local number = string.match(markName, "(%d+)$")
	return if number then `Emote {number}` else markName
end

-- A ViewportFrame showing a dancing copy of the workspace dancer of that emote.
local function preview(scope: Scope, markName: string): ViewportFrame
	local camera = scope:New("Camera")({ CFrame = CAMERA_CFRAME })
	local world = scope:New("WorldModel")({})
	local viewport: ViewportFrame = scope:New("ViewportFrame")({
		Name = "Preview",
		Size = UDim2.new(1, 0, 1, -(TITLE_HEIGHT + BUY_HEIGHT + Theme.Space.S * 2)),
		BackgroundColor3 = Theme.Colors.Sunken,
		CurrentCamera = camera,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Small) }),
			camera,
			world,
		},
	}) :: any

	local source = findDancer(markName)
	local animationId = Knit.GetController("EmoteController"):GetMarkAnimation(markName)
	if not source or not animationId then
		return viewport
	end

	local wasArchivable = source.Archivable
	source.Archivable = true
	local dancer = source:Clone()
	source.Archivable = wasArchivable
	if not dancer then
		return viewport
	end
	table.insert(scope, dancer)

	for _, descendant in dancer:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	-- Facing the camera.
	dancer:PivotTo(CFrame.lookAt(Vector3.zero, CAMERA_CFRAME.Position))
	dancer.Parent = world

	local humanoid = dancer:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return viewport
	end
	local animator: any = humanoid:FindFirstChildOfClass("Animator")
		or scope:New("Animator")({ Parent = humanoid })
	local animation = scope:New("Animation")({ AnimationId = animationId })

	-- An Animator only loads animations once it is in the game, and the screen is
	-- parented after Mount returns.
	local started = false
	local function start()
		if started or not viewport:IsDescendantOf(game) then
			return
		end
		started = true
		local ok, problem = pcall(function()
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			track:Play()
		end)
		if not ok then
			warn(`[EmoteShop] preview of {markName} failed: {problem}`)
		end
	end
	table.insert(scope, viewport.AncestryChanged:Connect(start))
	start()

	return viewport
end

return {
	Merchants = { MERCHANT_NAME },

	Mount = function(scope: Scope, _gui: any, context: any)
		local owned = Bind.data(scope :: any, "Emotes", {})
		local beri = Bind.data(scope :: any, "Economy.Beri", 0)
		-- Name of the emote whose purchase is waiting for the server.
		local buying: Fusion.Value<string?> = scope:Value(nil :: string?)
		local closed = false
		table.insert(scope, function()
			closed = true
		end)

		local cards: { any } = {}
		for index, item in ShopConfig.Merchants[MERCHANT_NAME].Items do
			local isOwned = scope:Computed(function(use): boolean
				local emotes = use(owned)
				return type(emotes) == "table" and emotes[item.Name] == true
			end)
			local price = ShopWindow.priceText(item.Price, item.Currency)

			-- A broken dancer model must not take the shop down with it.
			local ok, viewport = pcall(preview, scope, item.Name)
			if not ok then
				warn(`[EmoteShop] preview of {item.Name} failed: {viewport}`)
			end

			cards[index] = UI.Panel(scope, {
				Name = item.Name,
				LayoutOrder = index,
				Color = Theme.Colors.Raised,
				Padding = Theme.Space.S,
				Stroke = scope:Computed(function(use): Color3
					return if use(isOwned) then Theme.Colors.BorderStrong else Theme.Colors.Border
				end),
				Children = {
					if ok then viewport else nil,
					UI.Label(scope, {
						Name = "Title",
						Text = displayName(item.Name),
						Variant = "BodyBold",
						TextSize = Theme.TextSize.Small,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, 0, 1, -(BUY_HEIGHT + Theme.Space.S)),
						Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
					}),
					UI.Button(scope, {
						Name = "Buy",
						Text = scope:Computed(function(use): string
							if use(isOwned) then
								return "Owned"
							end
							return if use(buying) == item.Name then "..." else price
						end),
						TextSize = Theme.TextSize.Small,
						Disabled = scope:Computed(function(use): boolean
							return use(isOwned) or use(buying) ~= nil
						end),
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, BUY_HEIGHT),
						OnClick = function()
							if Fusion.peek(isOwned) or Fusion.peek(buying) then
								return
							end
							buying:set(item.Name)
							ShopWindow.buy(MERCHANT_NAME, item.Name, function()
								if not closed then
									buying:set(nil)
								end
							end)
						end,
					}),
				} :: { any },
			})
		end

		ShopWindow.closeOnMove(scope, context)

		return UI.Screen(scope, {
			Name = "EmoteShop",
			Children = UI.Window(scope, {
				Title = "Professional Dancer",
				Subtitle = scope:Computed(function(use): string
					return `$ {Bind.formatNumber(tonumber(use(beri)) or 0)}`
				end),
				Size = UDim2.fromOffset(1024, 760),
				Children = {
					MerchantSpeech(scope, {
						Portrait = PORTRAIT,
						Speaker = "Hans",
						Text = GREETING,
						Height = SPEECH_HEIGHT,
					}),
					UI.Scroll(scope, {
						Name = "Emotes",
						Position = UDim2.fromOffset(0, SPEECH_HEIGHT + Theme.Space.M),
						Size = UDim2.new(1, 0, 1, -(SPEECH_HEIGHT + Theme.Space.M + HINT_HEIGHT + Theme.Space.S)),
						CellSize = CELL,
						Gap = Theme.Space.M,
						Padding = Theme.Space.M,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Children = cards,
					}),
					UI.Label(scope, {
						Name = "Hint",
						Text = ShopWindow.HINT,
						Variant = "Tiny",
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.fromScale(0.5, 1),
						Size = UDim2.new(1, 0, 0, HINT_HEIGHT),
					}),
				},
			}),
		})
	end,
}
