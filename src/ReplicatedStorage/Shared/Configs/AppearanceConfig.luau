--!strict
--[[
	Character customization: how many options every category has, what things cost.

	The legacy game kept these numbers in three places (the menu LocalScript hardcoded the
	option counts, the server scripts hardcoded the prices, the palettes were parts in
	ReplicatedStorage). The colours themselves still live in the assets
	(Shared.Util.AppearanceAssets): only their counts are here, so a request can be
	validated without touching an instance.

	Accessory prices are in AccessoryConfig (generated).
]]

export type Category = {
	-- Number of styles: valid values are 1..Count.
	Count: number,
	-- Folder of ReplicatedStorage.Assets.Models.Customization holding the styles ("1".."N").
	Folder: string,
	-- Whether the category has a "<Name>_Color" field (index in the clothing palette).
	Colored: boolean,
}

export type DyeTier = {
	-- Player data path of the currency spent on one spin.
	Currency: string,
	Price: number,
	-- Folder with the colours the spin can land on.
	Pool: string,
}

local Categories: { [string]: Category } = {
	Hair = { Count = 21, Folder = "Hair", Colored = true },
	Torso = { Count = 6, Folder = "Torso", Colored = true },
	Arms = { Count = 5, Folder = "Arms", Colored = true },
	Pants = { Count = 6, Folder = "Pants", Colored = true },
	Gloves = { Count = 20, Folder = "Gloves", Colored = true },
	Feet = { Count = 20, Folder = "Feet", Colored = true },
	Face = { Count = 14, Folder = "Faces", Colored = false },
	SkinColor = { Count = 7, Folder = "Skins", Colored = false },
}

-- Clothing palette shared by every coloured category and by the accessories.
local COLOR_COUNT = 39
local COLOR_SUFFIX = "_Color"

local AppearanceConfig = {
	Categories = table.freeze(Categories),
	ColorCount = COLOR_COUNT,
	ColorFolder = "Colors",

	SkinDye = table.freeze({
		-- "Skin Dye" of the shop tab: a random colour of the common pool.
		Common = table.freeze({ Currency = "Economy.Beri", Price = 10000, Pool = "ColorsCommon" } :: DyeTier),
		-- "Rare Skin Dye": a random colour of the whole pool.
		Rare = table.freeze({ Currency = "Economy.Gems", Price = 100, Pool = "ColorsAll" } :: DyeTier),
	}),

	-- Recolouring the aura of an eaten fruit.
	Aura = table.freeze({ Currency = "Economy.Gems", Price = 1000 }),

	AccessoryCurrency = "Economy.Gems",
	-- Accessory slot -> GamePasses key that unlocks it. Slots A-C are free.
	PremiumSlots = table.freeze({ D = "SlotD", E = "SlotE", F = "SlotF" } :: { [string]: string }),
}

--[[
	Highest valid value of an Appearance field a player may set directly ("Hair",
	"Hair_Color", "Face", ...), nil for anything else. This is the whitelist of the
	change request: skin dye, accessories and ownership are never set through it.
]]
function AppearanceConfig.GetLimit(field: string): number?
	local category = Categories[field]
	if category then
		return category.Count
	end

	if string.sub(field, -#COLOR_SUFFIX) == COLOR_SUFFIX then
		local owner = Categories[string.sub(field, 1, -#COLOR_SUFFIX - 1)]
		if owner and owner.Colored then
			return COLOR_COUNT
		end
	end
	return nil
end

return table.freeze(AppearanceConfig)
