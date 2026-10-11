--!strict
--[[
	The single purchase path of every item merchant (weapons, drinks, boats, emotes).

	The client sends two names: the merchant it is standing at and the item it wants.
	Everything else - that the merchant sells it, the price, the currency, requirements,
	ownership - comes from ShopConfig and the player's saved data.

	What a purchase gives is delegated by grant type, so this service knows nothing about
	boats or drinks. The owner of each kind registers a handler in its KnitInit:

		ShopService:RegisterGrant("Boat", {
			Check = function(player, data, item, merchant) return true end,  -- before paying
			Give = function(player, data, item, merchant) return true end,   -- after paying
		})

	Check refuses without touching the balance (returns false and the text to show).
	Give returning false refunds. Handlers must not yield: the purchase is atomic.

	Legacy holes closed here: no distance check at all (shops could be used from anywhere),
	the drink shops gave any tool of the Juices folder for the price of the shop the remote
	belonged to (a 10,000 drink for 500), and one RemoteEvent per merchant with no limiter.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local ShopConfig = require(ReplicatedStorage.Shared.Configs.ShopConfig)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local Proximity = require(ServerStorage.Server.Modules.Proximity)

type PlayerData = PlayerData.PlayerData
type Item = ShopConfig.Item

export type GrantHandler = {
	Check: ((player: Player, data: PlayerData, item: Item, merchant: Model) -> (boolean, string?))?,
	Give: (player: Player, data: PlayerData, item: Item, merchant: Model) -> boolean,
}

local CURRENCY_PATHS: { [ShopConfig.Currency]: string } = {
	Beri = "Economy.Beri",
	Gems = "Economy.Gems",
}

local ShopService = Knit.CreateService({
	Name = "ShopService",
	Client = {},
})

-- (player, merchantName, item) after a completed purchase. Challenges that count money
-- spent at a kind of shop listen here instead of being written into the purchase path.
ShopService.Purchased = Signal.new() :: Signal.Signal<Player, string, Item>

local DataService
local CharacterService
local NotifyService

local buyLimiter = RateLimiter.new(3, 1)
local grants: { [ShopConfig.GrantType]: GrantHandler } = {}

local function refuse(player: Player, text: string): boolean
	NotifyService:Send(player, text, "Error")
	return false
end

local function meetsRequirements(player: Player, data: PlayerData, item: Item): boolean
	local requirement = item.Requirement
	if requirement then
		local skill = data.Data.Skills[requirement.Skill]
		if not skill or skill.Level < requirement.Level then
			return refuse(player, `Requires {requirement.Skill} level {requirement.Level}`)
		end
	end
	if item.RequiresItem and data.Data.Items[item.RequiresItem] ~= true then
		return refuse(player, `Requires a {item.RequiresItem}`)
	end
	return true
end

function ShopService:RegisterGrant(grantType: ShopConfig.GrantType, handler: GrantHandler)
	assert(grants[grantType] == nil, `grant "{grantType}" is already registered`)
	grants[grantType] = handler
end

function ShopService.Client:Buy(player: Player, merchantName: unknown, itemName: unknown): boolean
	if not buyLimiter:Consume(player) then
		return false
	end
	if type(merchantName) ~= "string" or type(itemName) ~= "string" then
		return false
	end
	if #merchantName > ShopConfig.MaxNameLength or #itemName > ShopConfig.MaxNameLength then
		return false
	end

	local catalogue = ShopConfig.Merchants[merchantName]
	local item = ShopConfig.Find(merchantName, itemName)
	if not catalogue or not item then
		return false
	end

	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not data or not entity or entity.Dead or not entity.Spawned then
		return false
	end

	local merchant = Proximity.GetMerchant(player, merchantName, catalogue.Range or ShopConfig.DefaultRange)
	if not merchant then
		return false
	end
	if catalogue.Disabled then
		return refuse(player, "This shop is closed")
	end

	local handler = grants[item.Grant]
	if not handler then
		warn(`[ShopService] No grant handler for "{item.Grant}" ({merchantName}.{item.Name})`)
		return refuse(player, "This item is unavailable")
	end

	if not meetsRequirements(player, data, item) then
		return false
	end
	if handler.Check then
		local allowed, reason = handler.Check(player, data, item, merchant)
		if not allowed then
			return if reason then refuse(player, reason) else false
		end
	end

	local currencyPath = CURRENCY_PATHS[item.Currency]
	if not data:TrySpend(currencyPath, item.Price) then
		return refuse(player, `Not enough {item.Currency}`)
	end
	if not handler.Give(player, data, item, merchant) then
		data:Increment(currencyPath, item.Price)
		return refuse(player, "This item is unavailable")
	end

	ShopService.Purchased:Fire(player, merchantName, item)
	return true
end

function ShopService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	NotifyService = Knit.GetService("NotifyService")

	-- Weapons are plain ownership flags; WeaponService reads them when equipping.
	ShopService:RegisterGrant("Weapon", {
		Check = function(_player: Player, data: PlayerData, item: Item): (boolean, string?)
			if data.Data.Items[item.Name] == true then
				return false, `You already own the {item.Name}`
			end
			return true, nil
		end,
		Give = function(player: Player, data: PlayerData, item: Item): boolean
			data:Set(`Items.{item.Name}`, true)
			return true
		end,
	})
end

function ShopService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		buyLimiter:Forget(player)
	end)
end

return ShopService
