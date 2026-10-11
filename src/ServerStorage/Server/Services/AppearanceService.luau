--!strict
--[[
	Character customization: clothing, face, skin, skin dye and accessories.

	The look is built on the server once per character (AppearanceBuilder) and patched
	when a field of Appearance changes. The service listens to the data itself rather
	than patching from its own request handlers, so any writer of Appearance (this
	service, an admin tool, a data fix) ends up on the character.

	Requests carry intent only: "set Hair to 5", "put Crown in slot B", "buy Halo",
	"spin the rare dye". Ranges come from AppearanceConfig, prices from the configs,
	ownership and game passes from the player data.

	Legacy holes closed here:
	- UpdateExtra never checked that the accessory was owned, nor the game pass of slots
	  D-F (both checks only existed in the menu LocalScript): every accessory was free.
	- Customize accepted any value that FindFirstChild could resolve and rebuilt the whole
	  outfit per call, with no rate limit.
	- The dye spin had no limit either and could be accepted again and again; the pending
	  result is now consumed by Accept / Decline.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AccessoryConfig = require(ReplicatedStorage.Shared.Configs.AccessoryConfig)
local AppearanceConfig = require(ReplicatedStorage.Shared.Configs.AppearanceConfig)
local AppearanceAssets = require(ReplicatedStorage.Shared.Util.AppearanceAssets)
local PlaceManifest = require(ReplicatedStorage.Shared.Configs.PlaceManifest)
local AccessoryMountConfig = require(ServerStorage.Server.Configs.AccessoryMountConfig)
local AppearanceBuilder = require(ServerStorage.Server.Modules.AppearanceBuilder)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

type CharacterEntity = CharacterEntity.CharacterEntity
type PlayerData = PlayerData.PlayerData

local AppearanceService = Knit.CreateService({
	Name = "AppearanceService",
	Client = {
		-- (field: string, value: number) one clothing / face / skin field, see AppearanceConfig.GetLimit.
		Change = Knit.CreateSignal(),
		-- () wear the owned skin dye instead of the skin tone.
		UseSkinDye = Knit.CreateSignal(),
		-- (slot: string, accessoryName: string)
		EquipAccessory = Knit.CreateSignal(),
		-- (slot: string) take off whatever the slot wears.
		RemoveAccessory = Knit.CreateSignal(),
		-- (slot: string, colorIndex: number)
		SetAccessoryColor = Knit.CreateSignal(),
		-- () keep / discard the dye of the last spin.
		AcceptSkinDye = Knit.CreateSignal(),
		DeclineSkinDye = Knit.CreateSignal(),
	},
})

local DataService
local CharacterService
local NotifyService
local WebhookService

-- Looks are edited from the menu's Customize tab. A place without that tab (PlaceManifest)
-- only shows them: the requests below are then not published at all (end of this file).
local EDITABLE = PlaceManifest.Has("MenuTabs", "Customize")

local APPEARANCE_PREFIX = "Appearance."
local SLOTS_PREFIX = "ExtraSlots."
local COLOR_SUFFIX = "_Color"

-- Arrow clicks of the menu: generous burst, each one rebuilds at most two parts.
local changeLimiter = RateLimiter.new(12, 6)
-- Purchases and spins.
local economyLimiter = RateLimiter.new(3, 0.5)

local random = Random.new()
-- Dye rolled by the last paid spin, waiting for Accept / Decline.
local pendingDye: { [Player]: string } = {}

local function isIndex(value: unknown, limit: number): boolean
	return type(value) == "number" and value >= 1 and value <= limit and value % 1 == 0
end

local function isSlot(slot: unknown): boolean
	return type(slot) == "string" and table.find(AccessoryConfig.Slots, slot) ~= nil
end

local function canUseSlot(data: PlayerData, slot: string): boolean
	local pass = AppearanceConfig.PremiumSlots[slot]
	return pass == nil or data:Get("GamePasses." .. pass) == true
end

local function ownsAccessory(data: PlayerData, name: string): boolean
	-- OwnedAccessories is a set: { [accessoryName] = true }.
	local owned = data:Get("Appearance.OwnedAccessories")
	return type(owned) == "table" and owned[name] == true
end

-- Rebuilds whatever a changed Appearance path shows on the character.
local function onDataChanged(player: Player, data: PlayerData, path: string)
	if path ~= "Appearance" and string.sub(path, 1, #APPEARANCE_PREFIX) ~= APPEARANCE_PREFIX then
		return
	end
	local entity: CharacterEntity? = CharacterService:GetPlayerEntity(player)
	if not entity then
		return
	end

	local character = entity.Model
	local appearance = data.Data.Appearance
	local key = string.sub(path, #APPEARANCE_PREFIX + 1)

	if key == "" then
		AppearanceBuilder.ApplyAll(character, appearance, player.UserId)
	elseif key == "SkinColor" or key == "SkinDye" or key == "UsingSkinDye" then
		AppearanceBuilder.ApplySkin(character, appearance)
	elseif key == "Face" then
		AppearanceBuilder.ApplyFace(character, appearance, player.UserId)
	elseif key == "ExtraSlots" then
		for _, slot in AccessoryConfig.Slots do
			AppearanceBuilder.ApplyAccessory(character, appearance, slot)
		end
	elseif string.sub(key, 1, #SLOTS_PREFIX) == SLOTS_PREFIX then
		local slot = string.sub(key, #SLOTS_PREFIX + 1, #SLOTS_PREFIX + 1)
		if isSlot(slot) then
			AppearanceBuilder.ApplyAccessory(character, appearance, slot)
		end
	else
		local category = if string.sub(key, -#COLOR_SUFFIX) == COLOR_SUFFIX
			then string.sub(key, 1, -#COLOR_SUFFIX - 1)
			else key
		if AppearanceBuilder.IsClothing(category) then
			AppearanceBuilder.ApplyClothing(character, appearance, category, player.UserId)
		end
	end
end

local function onEntityAdded(entity: CharacterEntity)
	local player = entity.Player
	local data = player and DataService:GetData(player)
	if player and data then
		AppearanceBuilder.ApplyAll(entity.Model, data.Data.Appearance, player.UserId)
	end
end

local function onChange(player: Player, field: unknown, value: unknown)
	local data: PlayerData? = DataService:GetData(player)
	if not data or type(field) ~= "string" or not changeLimiter:Consume(player) then
		return
	end

	local limit = AppearanceConfig.GetLimit(field)
	if not limit or not isIndex(value, limit) then
		return
	end

	data:Set(APPEARANCE_PREFIX .. field, value)
	if field == "SkinColor" then
		-- Picking a skin tone takes the dye off (it stays owned).
		data:Set("Appearance.UsingSkinDye", false)
	end
end

local function onUseSkinDye(player: Player)
	local data: PlayerData? = DataService:GetData(player)
	if data and changeLimiter:Consume(player) then
		data:Set("Appearance.UsingSkinDye", true)
	end
end

local function onEquipAccessory(player: Player, slot: unknown, name: unknown)
	local data: PlayerData? = DataService:GetData(player)
	if not data or not isSlot(slot) or type(name) ~= "string" or not changeLimiter:Consume(player) then
		return
	end
	local slotName = slot :: string

	if not AccessoryConfig.Prices[name] then
		-- No menu offers a name that is not an accessory (the legacy remote banned for it).
		WebhookService:Flag(player, "InvalidAccessory", name)
		return
	end
	if not AccessoryMountConfig.Mounts[name] or not ownsAccessory(data, name) then
		return
	end
	if not canUseSlot(data, slotName) then
		NotifyService:Send(player, `Accessory slot {slotName} is locked`, "Error")
		return
	end

	-- One copy per character. The legacy check only looked at slots A-C, so the same
	-- accessory could be stacked in the premium slots.
	for _, other in AccessoryConfig.Slots do
		if other ~= slotName and data:Get(`Appearance.ExtraSlots.{other}`) == name then
			data:Set(`Appearance.ExtraSlots.{other}`, "")
		end
	end
	data:Set(`Appearance.ExtraSlots.{slotName}`, name)
end

-- Empties a slot. The accessory stays owned; the slot keeps its colour for the next one.
local function onRemoveAccessory(player: Player, slot: unknown)
	local data: PlayerData? = DataService:GetData(player)
	if not data or not isSlot(slot) or not changeLimiter:Consume(player) then
		return
	end
	local slotName = slot :: string
	local equipped = data:Get(`Appearance.ExtraSlots.{slotName}`)
	if type(equipped) == "string" and equipped ~= "" then
		data:Set(`Appearance.ExtraSlots.{slotName}`, "")
	end
end

local function onSetAccessoryColor(player: Player, slot: unknown, colorIndex: unknown)
	local data: PlayerData? = DataService:GetData(player)
	if not data or not isSlot(slot) or not isIndex(colorIndex, AppearanceConfig.ColorCount) then
		return
	end
	local slotName = slot :: string
	if not changeLimiter:Consume(player) or not canUseSlot(data, slotName) then
		return
	end

	local equipped = data:Get(`Appearance.ExtraSlots.{slotName}`)
	if type(equipped) == "string" and equipped ~= "" then
		data:Set(`Appearance.ExtraSlots.{slotName}{COLOR_SUFFIX}`, colorIndex)
	end
end

local function onAcceptSkinDye(player: Player)
	local dye = pendingDye[player]
	local data: PlayerData? = DataService:GetData(player)
	if not dye or not data then
		return
	end

	pendingDye[player] = nil
	data:Set("Appearance.SkinDye", dye)
	data:Set("Appearance.UsingSkinDye", true)
end

-- Buys an accessory with gems. Bought from the menu, so there is no merchant to stand next to.
function AppearanceService.Client:BuyAccessory(player: Player, name: unknown): boolean
	local data: PlayerData? = DataService:GetData(player)
	if not data or type(name) ~= "string" or not economyLimiter:Consume(player) then
		return false
	end

	local price = AccessoryConfig.Prices[name]
	if not price or ownsAccessory(data, name) then
		return false
	end
	if not data:TrySpend(AppearanceConfig.AccessoryCurrency, price) then
		NotifyService:Send(player, "Not enough Gems", "Error")
		return false
	end

	data:Set(`Appearance.OwnedAccessories.{name}`, true)
	NotifyService:Send(player, `Bought {name}`, "Success")
	return true
end

--[[
	Pays for one spin and returns the dye it landed on (nil: not paid). The client plays
	the roulette towards that name; the dye is only worn after AcceptSkinDye.
]]
function AppearanceService.Client:SpinSkinDye(player: Player, rare: unknown): string?
	local data: PlayerData? = DataService:GetData(player)
	if not data or type(rare) ~= "boolean" or not economyLimiter:Consume(player) then
		return nil
	end

	local tier = if rare then AppearanceConfig.SkinDye.Rare else AppearanceConfig.SkinDye.Common
	local pool = AppearanceAssets.GetDyeNames(tier.Pool)
	if #pool == 0 then
		NotifyService:Send(player, "Skin dyes are unavailable right now", "Error")
		return nil
	end
	if not data:TrySpend(tier.Currency, tier.Price) then
		NotifyService:Send(player, if rare then "Not enough Gems" else "Not enough Beri", "Error")
		return nil
	end

	local dye = pool[random:NextInteger(1, #pool)]
	pendingDye[player] = dye
	return dye
end

-- The paid spin still waiting for an answer (the shop was closed mid-roulette), if any.
function AppearanceService.Client:GetPendingSkinDye(player: Player): string?
	return pendingDye[player]
end

function AppearanceService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	NotifyService = Knit.GetService("NotifyService")
	WebhookService = Knit.GetService("WebhookService")
end

function AppearanceService:KnitStart()
	if EDITABLE then
		local client = AppearanceService.Client
		client.Change:Connect(onChange)
		client.UseSkinDye:Connect(onUseSkinDye)
		client.EquipAccessory:Connect(onEquipAccessory)
		client.RemoveAccessory:Connect(onRemoveAccessory)
		client.SetAccessoryColor:Connect(onSetAccessoryColor)
		client.AcceptSkinDye:Connect(onAcceptSkinDye)
		client.DeclineSkinDye:Connect(function(player: Player)
			pendingDye[player] = nil
		end)
	end

	DataService:ObserveData(function(player: Player, data: PlayerData)
		data.Changed:Connect(function(path: string)
			onDataChanged(player, data, path)
		end)
	end)

	CharacterService.EntityAdded:Connect(onEntityAdded)
	for _, entity in CharacterService:GetEntities() do
		onEntityAdded(entity)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		pendingDye[player] = nil
		changeLimiter:Forget(player)
		economyLimiter:Forget(player)
	end)
end

-- Knit turns what is in Client into remotes when it starts: taken out before that, the
-- signals and methods (purchases and spins among them) never exist in this place.
if not EDITABLE then
	local client: { [string]: any } = AppearanceService.Client :: any
	for name in client do
		if name ~= "Server" then
			client[name] = nil
		end
	end
end

return AppearanceService
