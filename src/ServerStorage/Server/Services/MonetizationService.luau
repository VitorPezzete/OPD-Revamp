--!strict
--[[
	Robux purchases: the game's single MarketplaceService.ProcessReceipt, the prompts,
	gifting and the game pass cache.

	Client
		MonetizationService.Client:Prompt(productName, receiverUserId?) -> boolean
		MonetizationService.Client:PromptPass(passName) -> boolean
	Server
		MonetizationService:PromptProduct(player, productName, receiver?) -> boolean
		MonetizationService:OwnsPass(player, passName) -> boolean
		MonetizationService:SetGrantHandler(kind, handler)     -- e.g. "PrivateServer"
		MonetizationService:SetPrivateServerOwner(userId?)     -- custom private servers
		MonetizationService:IsWeekend() -> boolean
		MonetizationService.Granted (buyer, productName, recipient)
		MonetizationService.PassChanged (player, passName, owned)

	Receipts (the flow ProfileStore recommends):
	  1. The purchase id is written to the buyer's profile ("PurchaseIds") and the product is
	     granted in the same step, with nothing yielding in between, so a save contains
	     either both or neither. A receipt whose id is already there is not granted again.
	  2. PurchaseGranted is returned only once a save containing the id has reached the
	     DataStore. In every other case (buyer gone, data not loaded, unknown product, grant
	     failed, session ended before the save) the answer is NotProcessedYet and Roblox
	     delivers the receipt again later, or refunds it.

	The legacy script marked the receipt as processed in a separate DataStore before it
	even looked for the player, then answered PurchaseGranted for products it did not
	know and for aura compasses bought outside a private server (paid, nothing given).
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local ProductConfig = require(ReplicatedStorage.Shared.Configs.ProductConfig)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

type PlayerData = PlayerData.PlayerData
type Product = ProductConfig.Product
type GrantHandler = (recipient: Player, product: Product) -> boolean

local MonetizationService = Knit.CreateService({
	Name = "MonetizationService",
	Client = {},
})

MonetizationService.Granted = Signal.new() :: Signal.Signal<Player, string, Player>
MonetizationService.PassChanged = Signal.new() :: Signal.Signal<Player, string, boolean>

local NOT_PROCESSED = Enum.ProductPurchaseDecision.NotProcessedYet
local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted

-- New data field (not in the template, read defensively): list of processed purchase ids.
local PURCHASE_IDS_PATH = "PurchaseIds"
-- Seconds between two attempts to get a purchase saved.
local SAVE_RETRY_SECONDS = 10
-- Longest wait for one save to come back before trying again.
local SAVE_TIMEOUT_SECONDS = 30
--[[
	PromptGamePassPurchaseFinished is not proof of a purchase (it has been spoofed by
	exploits), so ownership is confirmed with UserOwnsGamePassAsync. That call can keep
	answering "not owned" for a while after a real purchase: retry at these delays.
]]
local PASS_VERIFY_DELAYS = { 0, 5, 15, 30 }

local DataService
local FruitService
local NotifyService
local WebhookService

local promptLimiter = RateLimiter.new(3, 0.5)

-- The gift a buyer was last prompted for. A gift product id does not say who it is for.
local pendingGifts: { [Player]: { ReceiverUserId: number, ProductId: number } } = {}
local grantHandlers: { [string]: GrantHandler } = {}
local grantsInProgress: { [string]: boolean } = {}
local verifyingPasses: { [Player]: { [string]: boolean } } = {}
local privateOwnerOverride: number? = nil

local function getActiveData(player: Player): PlayerData?
	local data: PlayerData? = DataService:GetData(player)
	return if data and data:IsActive() then data else nil
end

local function isPrivateServer(): boolean
	return privateOwnerOverride ~= nil or game.PrivateServerId ~= ""
end

local function getPrivateServerOwner(): number
	return privateOwnerOverride or game.PrivateServerOwnerId
end

local function grantCurrency(data: PlayerData, currency: string, amount: number): boolean
	data:Increment(`Economy.{currency}`, amount)
	data:Increment(`Economy.{currency}Bought`, amount)
	return true
end

-- Slot 1 is emptied; a fruit in slot 2 takes its place with its colour and affinities.
local function removeFruit(player: Player, data: PlayerData): boolean
	local second = data.Data.DevilFruits.Slot2
	if second.Name == FruitConfig.EmptyName then
		FruitService:RemoveFruit(player, 1)
		return true
	end

	local moved = table.clone(second)
	data:Set("Affinities.DF1", table.clone(data.Data.Affinities.DF2))
	data:Set("DevilFruits.Slot1", moved)
	FruitService:RemoveFruit(player, 2)
	FruitService.FruitChanged:Fire(player, 1, moved.Name)
	return true
end

-- Built-in grants. None of them may yield: see step 1 of the receipt flow.
local function grantBuiltIn(recipient: Player, product: Product): boolean
	local data = getActiveData(recipient)
	if not data then
		return false
	end

	local kind = product.Kind
	local amount = product.Amount or 0
	if kind == "Gems" or kind == "Beri" then
		return amount > 0 and grantCurrency(data, kind, amount)
	elseif kind == "Pass" then
		if not product.Pass then
			return false
		end
		data:Set(`GamePasses.{product.Pass}`, true)
		MonetizationService.PassChanged:Fire(recipient, product.Pass, true)
		return true
	elseif kind == "RemoveFruit" then
		return removeFruit(recipient, data)
	elseif kind == "AuraCompass" then
		-- Only the owner of a private server is ever prompted for it; once paid it is always given.
		data:Increment("CompassTokens.AuraBonus", amount)
		return amount > 0
	elseif kind == "Compass" then
		data:Increment(if isPrivateServer() then "CompassTokens.VIPBonus" else "CompassTokens.Current", amount)
		return amount > 0
	end
	return false
end

local function grantTo(recipient: Player, product: Product): boolean
	local handler = grantHandlers[product.Kind]
	if handler then
		return handler(recipient, product) == true
	end
	return grantBuiltIn(recipient, product)
end

-- The legacy "Gift Purchased" post. Queued, never yields: safe inside a grant.
local function reportGift(buyer: Player, recipient: Player, product: Product)
	WebhookService:Send("GiftPurchases", {
		embeds = {
			{
				title = "Gift Purchased",
				description = `**{buyer.Name}** bought a gift for **{recipient.Name}**.`,
				color = 16733333,
				fields = { { name = "Item Bought", value = "```" .. product.Label .. "```", inline = true } },
				footer = { text = `buyer ID: {buyer.UserId} | receiver ID: {recipient.UserId}` },
			},
		},
	})
end

-- Gives the product of a receipt to whoever it is for. Returns false when nothing was given.
local function grant(buyer: Player, productName: string, product: Product, productId: number, isGift: boolean): boolean
	local recipient = buyer
	if isGift then
		local pending = pendingGifts[buyer]
		if pending and pending.ProductId == productId then
			pendingGifts[buyer] = nil
			local receiver = Players:GetPlayerByUserId(pending.ReceiverUserId)
			if receiver and getActiveData(receiver) then
				recipient = receiver
			end
		end
	end

	local granted = grantTo(recipient, product)
	if not granted and recipient ~= buyer then
		-- As in the legacy game, a gift that cannot be delivered goes to the buyer.
		recipient = buyer
		granted = grantTo(buyer, product)
	end
	if not granted then
		return false
	end

	if recipient ~= buyer then
		NotifyService:Send(recipient, `{buyer.Name} gifted you {product.Label}!`, "Success")
		NotifyService:Send(buyer, `{product.Label} sent to {recipient.Name}.`, "Success")
		reportGift(buyer, recipient, product)
	elseif isGift then
		NotifyService:Send(buyer, `The gift could not be delivered: {product.Label} was added to your account.`, "Info")
	end
	MonetizationService.Granted:Fire(buyer, productName, recipient)
	return true
end

local function isPurchaseSaved(profile: any, purchaseId: string): boolean
	local lastSaved = profile.LastSavedData
	local saved = if type(lastSaved) == "table" then lastSaved[PURCHASE_IDS_PATH] else nil
	return type(saved) == "table" and table.find(saved, purchaseId) ~= nil
end

-- Yields until a save containing the purchase id is confirmed, or the session ends.
local function confirmSaved(data: PlayerData, purchaseId: string): Enum.ProductPurchaseDecision
	local profile = (data :: any)._profile
	if type(profile) ~= "table" or type(profile.Save) ~= "function" then
		-- Cannot observe saves: the id is in the session data and goes out with the next save.
		return GRANTED
	end

	while data:IsActive() do
		if isPurchaseSaved(profile, purchaseId) then
			return GRANTED
		end

		local saved = false
		local connection = profile.OnAfterSave:Connect(function()
			saved = true
		end)
		profile:Save()

		local deadline = os.clock() + SAVE_TIMEOUT_SECONDS
		while not saved and data:IsActive() and os.clock() < deadline do
			task.wait(0.5)
		end
		connection:Disconnect()

		if isPurchaseSaved(profile, purchaseId) then
			return GRANTED
		end
		if data:IsActive() then
			task.wait(SAVE_RETRY_SECONDS)
		end
	end
	return NOT_PROCESSED
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local purchaseId = receipt.PurchaseId
	local productId = receipt.ProductId
	if type(purchaseId) ~= "string" or type(productId) ~= "number" then
		return NOT_PROCESSED
	end

	local buyer = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = if buyer then getActiveData(buyer) else nil
	if not buyer or not data then
		return NOT_PROCESSED
	end

	local productName, product, variant = ProductConfig.Resolve(productId)
	if not productName or not product then
		warn(`[Monetization] receipt {purchaseId} is for unknown product {productId}`)
		return NOT_PROCESSED
	end

	local purchaseIds = data:Get(PURCHASE_IDS_PATH)
	if type(purchaseIds) ~= "table" then
		purchaseIds = {}
	end

	if not table.find(purchaseIds, purchaseId) then
		-- A custom grant handler may yield; a second delivery must not start a second grant.
		if grantsInProgress[purchaseId] then
			return NOT_PROCESSED
		end
		grantsInProgress[purchaseId] = true

		table.insert(purchaseIds, purchaseId)
		while #purchaseIds > ProductConfig.PurchaseIdCacheSize do
			table.remove(purchaseIds, 1)
		end
		data:Set(PURCHASE_IDS_PATH, purchaseIds)

		local ok, granted = pcall(grant, buyer, productName, product, productId, variant == "Gift")
		grantsInProgress[purchaseId] = nil

		if not ok or granted ~= true then
			local index = table.find(purchaseIds, purchaseId)
			if index then
				table.remove(purchaseIds, index)
				data:Set(PURCHASE_IDS_PATH, purchaseIds)
			end
			warn(`[Monetization] {productName} not granted to {buyer.Name} ({purchaseId}): {granted}`)
			return NOT_PROCESSED
		end
	end

	return confirmSaved(data, purchaseId)
end

local function setPass(player: Player, data: PlayerData, passName: string, owned: boolean)
	if data:Get(`GamePasses.{passName}`) ~= owned then
		data:Set(`GamePasses.{passName}`, owned)
		MonetizationService.PassChanged:Fire(player, passName, owned)
	end
end

-- (callSucceeded, owned)
local function userOwnsPass(player: Player, gamePassId: number): (boolean, boolean)
	local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gamePassId)
	return ok, ok and owned == true
end

-- Runs once per join: mirrors real game pass ownership into the saved data.
local function refreshPasses(player: Player, data: PlayerData)
	for passName, pass in ProductConfig.GamePasses do
		local ok, owned = userOwnsPass(player, pass.Id)
		if ok and data:IsActive() then
			setPass(player, data, passName, owned)
		end
	end
end

local function verifyPassPurchase(player: Player, passName: string, gamePassId: number)
	local verifying = verifyingPasses[player]
	if not verifying then
		verifying = {}
		verifyingPasses[player] = verifying
	end
	if verifying[passName] then
		return
	end
	verifying[passName] = true

	for _, seconds in PASS_VERIFY_DELAYS do
		task.wait(seconds)
		local data = getActiveData(player)
		if not data then
			break
		end

		local ok, owned = userOwnsPass(player, gamePassId)
		if ok and owned then
			setPass(player, data, passName, true)
			break
		end
	end

	if verifyingPasses[player] == verifying then
		verifying[passName] = nil
	end
end

function MonetizationService:IsWeekend(): boolean
	local date: any = os.date("!*t")
	return table.find(ProductConfig.WeekendDays, date.wday) ~= nil
end

function MonetizationService:OwnsPass(player: Player, passName: string): boolean
	local data: PlayerData? = DataService:GetData(player)
	return data ~= nil and data:Get(`GamePasses.{passName}`) == true
end

-- Replaces how a kind of product is granted. The handler returns true only when it has
-- given the product; anything else leaves the receipt unprocessed.
function MonetizationService:SetGrantHandler(kind: ProductConfig.Kind, handler: GrantHandler)
	grantHandlers[kind] = handler
end

-- Marks this server as a custom private server of that user (reserved servers have no
-- PrivateServerOwnerId). nil goes back to what Roblox reports.
function MonetizationService:SetPrivateServerOwner(userId: number?)
	privateOwnerOverride = userId
end

-- Opens the purchase prompt of a product after checking the offer makes sense for the
-- buyer (and the receiver of a gift). Returns whether the prompt was opened.
function MonetizationService:PromptProduct(player: Player, productName: string, receiver: Player?): boolean
	local product = ProductConfig.Products[productName]
	local data = getActiveData(player)
	if not product or not data then
		return false
	end

	local productId = product.Id
	local isGift = receiver ~= nil and receiver ~= player

	if isGift and receiver then
		local receiverData = getActiveData(receiver)
		if not product.GiftId or not receiverData then
			return false
		end
		if product.Kind == "Pass" and receiverData:Get(`GamePasses.{product.Pass}`) == true then
			NotifyService:Send(player, `{receiver.Name} already owns {product.Label}.`, "Error")
			return false
		end
		productId = product.GiftId
	elseif product.Kind == "Pass" then
		if data:Get(`GamePasses.{product.Pass}`) == true then
			NotifyService:Send(player, `You already own {product.Label}.`, "Error")
			return false
		end
	elseif product.Kind == "RemoveFruit" then
		if data.Data.DevilFruits.Slot1.Name == FruitConfig.EmptyName then
			return false
		end
	elseif product.Kind == "AuraCompass" then
		if not isPrivateServer() or getPrivateServerOwner() ~= player.UserId then
			return false
		end
	end

	if not isGift and product.WeekendId and MonetizationService:IsWeekend() then
		productId = product.WeekendId
	end

	if isGift and receiver then
		pendingGifts[player] = { ReceiverUserId = receiver.UserId, ProductId = productId }
	end

	local ok, problem = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, productId)
	if not ok then
		warn(`[Monetization] could not prompt {productName}: {problem}`)
	end
	return ok
end

--[[
	The legacy remote took (what, amount, receiverUserId) and built the product key from
	the client's amount. The client now names a product of ProductConfig and, for a gift,
	the receiver; which id is prompted, weekend pricing and eligibility are decided here.
	Paying is handled by Roblox, so a forged call can at most open a prompt on the caller's
	own screen.
]]
function MonetizationService.Client:Prompt(player: Player, productName: unknown, receiverUserId: unknown): boolean
	if not promptLimiter:Consume(player) then
		return false
	end
	if type(productName) ~= "string" then
		return false
	end

	local product = ProductConfig.Products[productName]
	if not product or product.ClientPrompt == false then
		return false
	end

	local receiver: Player? = nil
	if receiverUserId ~= nil then
		if type(receiverUserId) ~= "number" or receiverUserId ~= receiverUserId or receiverUserId % 1 ~= 0 then
			return false
		end
		receiver = Players:GetPlayerByUserId(receiverUserId)
		-- The chosen player left: do not silently turn the gift into a purchase for the buyer.
		if not receiver or receiver == player then
			return false
		end
	end

	return MonetizationService:PromptProduct(player, productName, receiver)
end

function MonetizationService.Client:PromptPass(player: Player, passName: unknown): boolean
	if not promptLimiter:Consume(player) then
		return false
	end
	if type(passName) ~= "string" then
		return false
	end

	local pass = ProductConfig.GamePasses[passName]
	if not pass or MonetizationService:OwnsPass(player, passName) then
		return false
	end

	local ok = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, pass.Id)
	return ok
end

function MonetizationService:KnitInit()
	DataService = Knit.GetService("DataService")
	FruitService = Knit.GetService("FruitService")
	NotifyService = Knit.GetService("NotifyService")
	WebhookService = Knit.GetService("WebhookService")
end

function MonetizationService:KnitStart()
	MarketplaceService.ProcessReceipt = function(receipt: any): Enum.ProductPurchaseDecision
		local ok, decision = pcall(processReceipt, receipt)
		if not ok then
			warn(`[Monetization] receipt failed: {decision}`)
			return NOT_PROCESSED
		end
		return decision
	end

	-- A cancelled gift prompt must not leave its receiver attached to a later purchase.
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, isPurchased: boolean)
		local player = Players:GetPlayerByUserId(userId)
		local pending = if player then pendingGifts[player] else nil
		if player and pending and pending.ProductId == productId and not isPurchased then
			pendingGifts[player] = nil
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		local passName = ProductConfig.GetPassName(gamePassId)
		if wasPurchased and passName then
			verifyPassPurchase(player, passName, gamePassId)
		end
	end)

	DataService:ObserveData(refreshPasses)

	Players.PlayerRemoving:Connect(function(player: Player)
		pendingGifts[player] = nil
		verifyingPasses[player] = nil
		promptLimiter:Forget(player)
	end)
end

return MonetizationService
