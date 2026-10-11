--!strict
--[[
	Every item merchant of the game: Workspace.Map.Merchants.<Name> -> what it sells.

	The legacy game had one hand-written script per merchant with the prices repeated in
	the script, in the GUI text and (for the client-side "can afford" check) parsed back
	out of that text. This table is now the only source: ShopService charges from it and
	the shop screens print it.

	Grant decides what a purchase gives; the service that owns that kind of thing
	registers the handler with ShopService:
		Weapon      permanent, data.Items[Name] = true          (ShopService)
		Consumable  a one-use tool in the backpack              (ConsumableService)
		Boat        spawns the player's boat at the merchant    (BoatService)
		Emote       permanent, data.Emotes[Name] = true         (EmoteService)

	Items are listed in the order of the slots of the shop layout (A, B, C, ...).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)

export type Currency = "Beri" | "Gems"
export type GrantType = "Weapon" | "Consumable" | "Boat" | "Emote"

export type Item = {
	Name: string,
	Price: number,
	Currency: Currency,
	Grant: GrantType,
	-- Skill level needed to buy.
	Requirement: { Skill: DataTypes.SkillName, Level: number }?,
	-- An owned item (data.Items) needed to buy.
	RequiresItem: string?,
}

export type Merchant = {
	Items: { Item },
	-- Kept in the catalogue but refuses every purchase.
	Disabled: boolean?,
	-- Max distance to the merchant model (studs). Legacy ClickDetectors used 32.
	Range: number?,
}

local function item(name: string, price: number, grant: GrantType, extra: { [string]: any }?): Item
	local definition: Item = { Name = name, Price = price, Currency = "Beri", Grant = grant }
	for key, value in extra or {} do
		(definition :: any)[key] = value
	end
	return table.freeze(definition)
end

local function boats(): { Item }
	return {
		item("Raft", 200, "Boat"),
		item("Boat", 500, "Boat"),
		item("Escort", 1000, "Boat"),
		item("Schooner", 2000, "Boat"),
		-- The legacy shop only showed the Galleon to owners of a Sturdy Rod, but its
		-- server never checked: anyone could fire the remote for it.
		item("Galleon", 10000, "Boat", { RequiresItem = "Sturdy Rod" }),
	}
end

-- CB_Mark3 (Meditate) is free for everyone and was never sold.
local EMOTE_PRICES: { { number } } = {
	{ 1, 1_000_000 },
	{ 2, 1_000_000 },
	{ 4, 1_000_000 },
	-- The legacy button read "200,000$" while the server charged 1,000,000.
	-- The amount that was really charged is kept.
	{ 5, 1_000_000 },
	{ 6, 400_000 },
	{ 7, 400_000 },
	{ 8, 400_000 },
	{ 9, 1_000_000 },
	{ 10, 1_000_000 },
	{ 11, 1_000_000 },
	{ 12, 1_000_000 },
	{ 13, 1_000_000 },
	{ 14, 2_000_000 },
	{ 15, 10_000_000 },
	{ 16, 50_000_000 },
}

local function emotes(): { Item }
	local items = {}
	for _, entry in EMOTE_PRICES do
		table.insert(items, item(`CB_Mark{entry[1]}`, entry[2], "Emote"))
	end
	return items
end

local Merchants: { [string]: Merchant } = {
	SwordMerchant = {
		Items = {
			item("Dagger", 1000, "Weapon"),
			item("Wakizashi", 5000, "Weapon"),
			item("Tachi", 7500, "Weapon"),
			item("Katana", 10000, "Weapon"),
		},
	},
	SniperMerchant = {
		Items = {
			item("Slingshot", 1000, "Weapon"),
			item("Stars", 5000, "Weapon"),
			item("Crossbow", 7500, "Weapon"),
			item("Flintlock", 10000, "Weapon"),
		},
	},
	-- Timmy's shop had a GUI (Flail, 50,000) but no script behind its remotes in the
	-- legacy place: nothing could be bought. Flip Disabled to open it.
	FlailMerchant = {
		Disabled = true,
		Items = {
			item("Flail", 50000, "Weapon"),
		},
	},
	DrinkMerchant = {
		Items = {
			item("Cider", 500, "Consumable"),
			item("Lemonade", 500, "Consumable"),
			item("Juice", 500, "Consumable"),
			item("Smoothie", 500, "Consumable"),
		},
	},
	BetterDrinkMerchant = {
		Items = {
			item("Cider+", 10000, "Consumable"),
			item("Lemonade+", 10000, "Consumable"),
			item("Juice+", 10000, "Consumable"),
			item("Smoothie+", 10000, "Consumable"),
		},
	},
	KrizmaMerch = { Items = { item("Krizma", 80000, "Weapon") } },
	Boat1Merchant = { Items = boats() },
	Boat2Merchant = { Items = boats() },
	Boat3Merchant = { Items = boats() },
	Boat4Merchant = { Items = boats() },
	Boat5Merchant = { Items = boats() },
	EmoteMerchant = { Items = emotes() },
}

for _, merchant in Merchants do
	table.freeze(merchant.Items)
	table.freeze(merchant)
end

local ShopConfig = {
	Merchants = table.freeze(Merchants),
	DefaultRange = 40,
	MaxNameLength = 40,
}

function ShopConfig.Find(merchantName: string, itemName: string): Item?
	local merchant = Merchants[merchantName]
	if not merchant then
		return nil
	end
	for _, definition in merchant.Items do
		if definition.Name == itemName then
			return definition
		end
	end
	return nil
end

return table.freeze(ShopConfig)
