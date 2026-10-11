--!strict
--[[
	Everything sold for Robux: developer products, what each one grants, and game passes.
	Ids are the legacy ones (ServerScriptService.etc.Purchases and the scripts that
	prompted them). Prices live on Roblox, never here.

	A product can have up to three ids that grant the same thing:
		Id         bought for yourself
		GiftId     bought for another player of the server (legacy "...Gift" products)
		WeekendId  discounted product prompted instead of Id on weekends

	Kinds (handled by MonetizationService):
		Gems / Beri      Amount of the currency (also counted in Economy.<Currency>Bought)
		Pass             sets GamePasses.<Pass>; the customize slots were always sold as products
		RemoveFruit      removes the fruit of slot 1; the fruit of slot 2 moves up
		AuraCompass      Amount of CompassTokens.AuraBonus (aura man, private servers)
		Compass          Amount of compass claims (Sam quest)
		PrivateServer    a month of custom private server; granted by whoever registers the handler
]]

export type Kind = "Gems" | "Beri" | "Pass" | "RemoveFruit" | "AuraCompass" | "Compass" | "PrivateServer"
export type Variant = "Self" | "Gift" | "Weekend"

export type Product = {
	Kind: Kind,
	Label: string,
	Id: number,
	GiftId: number?,
	WeekendId: number?,
	Amount: number?,
	Pass: string?,
	-- false: only the server may prompt it (it decides when the offer applies).
	ClientPrompt: boolean?,
}

export type GamePass = {
	Id: number,
	Label: string,
}

local Products: { [string]: Product } = {
	Gems100 = { Kind = "Gems", Label = "100 Gems", Amount = 100, Id = 3532459616, GiftId = 3544872709 },
	Gems1000 = { Kind = "Gems", Label = "1000 Gems", Amount = 1000, Id = 3532459799, GiftId = 3544872971 },
	Gems10000 = { Kind = "Gems", Label = "10000 Gems", Amount = 10000, Id = 3575498222, GiftId = 3575498317 },

	-- Only the old menu had buttons for these; the receipts are still honoured.
	Beri10K = { Kind = "Beri", Label = "10,000 Beri", Amount = 10000, Id = 3532458059 },
	Beri100K = { Kind = "Beri", Label = "100,000 Beri", Amount = 100000, Id = 3532458795 },
	Beri1000K = { Kind = "Beri", Label = "1,000,000 Beri", Amount = 1000000, Id = 3532458902 },

	SlotD = { Kind = "Pass", Label = "Customize Slot D", Pass = "SlotD", Id = 3574848286, GiftId = 3574849841 },
	SlotE = { Kind = "Pass", Label = "Customize Slot E", Pass = "SlotE", Id = 3574848564, GiftId = 3574849961 },
	SlotF = { Kind = "Pass", Label = "Customize Slot F", Pass = "SlotF", Id = 3574848651, GiftId = 3574850061 },

	RemoveFruit = { Kind = "RemoveFruit", Label = "Remove Devil Fruit", Id = 3532850338 },

	Aura1 = { Kind = "AuraCompass", Label = "1 Aura Compass", Amount = 1, Id = 3532873617, WeekendId = 3532874123 },
	Aura10 = { Kind = "AuraCompass", Label = "10 Aura Compasses", Amount = 10, Id = 3532873785, WeekendId = 3532875796 },

	Claim1 = { Kind = "Compass", Label = "1 Compass Claim", Amount = 1, Id = 3532460253, WeekendId = 3532461013 },
	Claim10 = { Kind = "Compass", Label = "10 Compass Claims", Amount = 10, Id = 3532460435, WeekendId = 3532461138 },

	PrivateServerMonth = {
		Kind = "PrivateServer",
		Label = "Private Server (1 month)",
		Id = 3541255352,
		ClientPrompt = false,
	},
}

-- Real game passes, checked with MarketplaceService and cached in GamePasses.<Name>.
-- GamePasses.DiscoVIP exists in the data but the legacy game never sold or read it.
local GamePasses: { [string]: GamePass } = {
	SkipSpin = { Id = 1704493370, Label = "Skip Affinity Spin" },
}

type Resolved = { Name: string, Product: Product, Variant: Variant }

local byId: { [number]: Resolved } = {}
for name, product in Products do
	byId[product.Id] = { Name = name, Product = product, Variant = "Self" }
	if product.GiftId then
		byId[product.GiftId] = { Name = name, Product = product, Variant = "Gift" }
	end
	if product.WeekendId then
		byId[product.WeekendId] = { Name = name, Product = product, Variant = "Weekend" }
	end
end

local ProductConfig = {}

ProductConfig.Products = Products
ProductConfig.GamePasses = GamePasses

-- Days of the week (os.date wday: 1 = Sunday) with weekend prices: Friday to Sunday, UTC.
ProductConfig.WeekendDays = { 1, 6, 7 }

-- Purchase ids remembered per player to recognise a receipt that is delivered twice.
ProductConfig.PurchaseIdCacheSize = 100

-- Which product a developer product id belongs to, and in which variant.
function ProductConfig.Resolve(productId: number): (string?, Product?, Variant?)
	local resolved = byId[productId]
	if not resolved then
		return nil, nil, nil
	end
	return resolved.Name, resolved.Product, resolved.Variant
end

function ProductConfig.GetPassName(gamePassId: number): string?
	for name, pass in GamePasses do
		if pass.Id == gamePassId then
			return name
		end
	end
	return nil
end

return table.freeze(ProductConfig)
