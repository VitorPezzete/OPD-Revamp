--!strict
--[[
	Loadout: which weapon sits in each slot, and handing the matching Tool to the player.

	Equip requests carry only a weapon name. Slot, level requirement and ownership are
	resolved from WeaponConfig and the player's saved data.

	Legacy hole closed here: UpdateWeapon checked ownership weapon by weapon in a long
	if-chain, so anything missing from the chain (Wakizashi, Cannon Ball) was free to
	equip. Ownership is now one rule for every weapon in WeaponConfig.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)
local InventoryConfig = require(ReplicatedStorage.Shared.Configs.InventoryConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local WeaponModels = require(ServerStorage.Server.Modules.WeaponModels)
local NetworkConfig = require(ServerStorage.Server.Configs.NetworkConfig)

type WeaponSlot = DataTypes.WeaponSlot

local SLOT_ATTRIBUTE = "WeaponSlot"
local MAX_NAME_LENGTH = 40
local SLOTS: { WeaponSlot } = { "Melee", "Sniper", "Sword", "Utility" }
local DEFAULT_MELEE = "Melee"

local WeaponService = Knit.CreateService({
	Name = "WeaponService",
	Client = {},
})

WeaponService.Equipped = Signal.new() :: Signal.Signal<Player, WeaponSlot, string>

local DataService
local CharacterService

local equipLimiter =
	RateLimiter.new(NetworkConfig.Actions.EquipWeapon[1], NetworkConfig.Actions.EquipWeapon[2])
local warnedMissing: { [string]: boolean } = {}

-- Tool templates live in ReplicatedStorage.Assets.Models.Weapons.<Slot>.<Name>.
local function findTemplate(slot: WeaponSlot, name: string): Tool?
	local models = ReplicatedStorage.Assets:FindFirstChild("Models")
	local weapons = models and models:FindFirstChild("Weapons")
	local folder = weapons and weapons:FindFirstChild(slot)
	local template = folder and folder:FindFirstChild(name)
	if template and template:IsA("Tool") then
		return template
	end

	if not warnedMissing[name] then
		warnedMissing[name] = true
		warn(`[WeaponService] Missing tool template: Assets.Models.Weapons.{slot}.{name}`)
	end
	return nil
end

local function removeSlotTools(container: Instance?, slot: WeaponSlot)
	if not container then
		return
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(SLOT_ATTRIBUTE) == slot then
			child:Destroy()
		end
	end
end

local function giveSlotTool(player: Player, slot: WeaponSlot, name: string)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	removeSlotTools(backpack, slot)
	removeSlotTools(player.Character, slot)
	if name == WeaponConfig.EmptyName then
		return
	end

	local template = findTemplate(slot, name)
	if template then
		local tool = template:Clone()
		tool:SetAttribute(SLOT_ATTRIBUTE, slot)
		-- What the weapon looks like in the hand (its Tool has no Handle).
		WeaponModels.Attach(tool, player.Character)
		tool.Parent = backpack
	end

	-- A second tool that rides along with the first (Tea Cup -> Tea Kettle at 100 tea).
	-- It carries the same slot attribute, so it leaves with the slot.
	local companion = InventoryConfig.CompanionTools[name]
	local data = DataService:GetData(player)
	local progress = if companion and data then data:Get(companion.Path) else nil
	if companion and type(progress) == "number" and progress >= companion.Goal then
		local companionTemplate = findTemplate(slot, companion.Tool)
		if companionTemplate then
			local tool = companionTemplate:Clone()
			tool:SetAttribute(SLOT_ATTRIBUTE, slot)
			WeaponModels.Attach(tool, player.Character)
			tool.Parent = backpack
		end
	end
end

local function canUse(player: Player, name: string): boolean
	local data = DataService:GetData(player)
	local definition = WeaponConfig.Weapons[name]
	if not data or not definition then
		return false
	end

	if definition.LevelRequirement then
		return data.Data.Skills[definition.Slot :: any].Level >= definition.LevelRequirement
	end
	return data.Data.Items[name] == true
end

local function setSlot(player: Player, slot: WeaponSlot, name: string): boolean
	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not data or not entity or entity.Dead or not entity.Spawned then
		return false
	end

	if data.Data.Weapons[slot] ~= name then
		data:Set(`Weapons.{slot}`, name)
		giveSlotTool(player, slot, name)
		WeaponService.Equipped:Fire(player, slot, name)
	end
	return true
end

function WeaponService:GetEquipped(player: Player, slot: WeaponSlot): WeaponConfig.WeaponDefinition?
	local data = DataService:GetData(player)
	return if data then WeaponConfig.Weapons[data.Data.Weapons[slot]] else nil
end

-- Drops every saved weapon the player can no longer use (item removed, level reset) and
-- hands the tools out again. Called on spawn and by systems that rewrite stats or items.
function WeaponService:Refresh(player: Player)
	local data = DataService:GetData(player)
	if not data then
		return
	end

	local entity = CharacterService:GetPlayerEntity(player)
	local canHold = entity ~= nil and not entity.Dead and entity.Spawned
	for _, slot in SLOTS do
		local name = data.Data.Weapons[slot]
		if name ~= WeaponConfig.EmptyName and not canUse(player, name) then
			name = if slot == "Melee" then DEFAULT_MELEE else WeaponConfig.EmptyName
			data:Set(`Weapons.{slot}`, name)
			WeaponService.Equipped:Fire(player, slot, name)
		end
		if canHold then
			giveSlotTool(player, slot, name)
		end
	end
end

-- Back to the starting loadout: bare fists, nothing else.
function WeaponService:ResetLoadout(player: Player)
	local data = DataService:GetData(player)
	if not data then
		return
	end

	for _, slot in SLOTS do
		local name = if slot == "Melee" then DEFAULT_MELEE else WeaponConfig.EmptyName
		if data.Data.Weapons[slot] ~= name then
			data:Set(`Weapons.{slot}`, name)
			WeaponService.Equipped:Fire(player, slot, name)
		end
	end
	WeaponService:Refresh(player)
end

function WeaponService.Client:Equip(player: Player, weaponName: unknown): boolean
	if not equipLimiter:Consume(player) then
		return false
	end
	if type(weaponName) ~= "string" or #weaponName > MAX_NAME_LENGTH then
		return false
	end

	local definition = WeaponConfig.Weapons[weaponName]
	if not definition or not canUse(player, weaponName) then
		return false
	end
	return setSlot(player, definition.Slot, weaponName)
end

function WeaponService.Client:Unequip(player: Player, slot: unknown): boolean
	if not equipLimiter:Consume(player) then
		return false
	end
	if type(slot) ~= "string" or not WeaponConfig.OptionalSlots[slot] then
		return false
	end
	return setSlot(player, slot :: WeaponSlot, WeaponConfig.EmptyName)
end

function WeaponService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
end

function WeaponService:KnitStart()
	CharacterService.EntitySpawned:Connect(function(entity: CharacterEntity.CharacterEntity)
		if entity.Player then
			WeaponService:Refresh(entity.Player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		equipLimiter:Forget(player)
	end)
end

return WeaponService
