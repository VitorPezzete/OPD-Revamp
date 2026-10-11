--!strict
--[[
	Identity and audit trail of fruit items (the legacy "Fruit Logs").

	Every fruit item has an id, "<creatorUserId>-<time>-<random>-<ownerUserId>", that
	follows it through storage (Storages.<n>.ID). The last field is the player the fruit
	was first given to: SellerMerchant only buys a fruit from that player.

	The log is a ring of the last movements of tracked fruits (Rare and above, or any
	aura fruit), kept in memory for moderation tools of this server. The legacy game
	wrote each movement to a DataStore with UpdateAsync and posted duplicates and box
	bursts to Discord webhooks; both are gone. A duplicated id is found when it is
	registered, not by scanning every backpack every five seconds.

	Whoever creates a fruit for a player registers it:

		local tool = FruitService:CreateItem(name)
		FruitLogService:Register(tool, player)             -- "Spawned"
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local FruitOddsConfig = require(ServerStorage.Server.Configs.FruitOddsConfig)

export type Entry = {
	Time: number,
	UserId: number,
	PlayerName: string,
	Action: string,
	Fruit: string,
	Id: string,
	HasAura: boolean,
}

type Record = { Id: string, OwnerId: number }

local UNKNOWN_ID = "?"

local FruitLogService = Knit.CreateService({
	Name = "FruitLogService",
	Client = {},
})

local FruitService
local WebhookService

-- Keyed by the FruitService item table, which lives exactly as long as its Tool.
local records: { [any]: Record } = setmetatable({}, { __mode = "k" }) :: any
local liveTools: { [string]: Tool } = setmetatable({}, { __mode = "v" }) :: any

local entries: { Entry } = {}
local nextIndex = 1
local random = Random.new()
local warnedUnregistered = false

local function parseOwner(id: string): number
	local parts = string.split(id, "-")
	return tonumber(parts[4]) or tonumber(parts[1]) or 0
end

local function newId(creatorId: number, ownerId: number): string
	return string.format("%d-%d-%d-%d", creatorId, os.time(), random:NextInteger(100000000, 999999999), ownerId)
end

local function attach(tool: Tool, item: any, id: string, holder: Player?): Record
	local existing = liveTools[id]
	if existing and existing ~= tool and FruitService:GetItem(existing) then
		warn(`[FruitLog] duplicated fruit id {id} ({item.FruitName})`)
		FruitLogService:Record(nil, "Duplicate", item.FruitName, id, item.HasAura)
		local where = if holder then `**{holder.Name}** ({holder.UserId})` else "an unknown holder"
		WebhookService:Send("FruitDupes", `Duped **{item.FruitName}-{id}** on {where}`)
	end

	local record: Record = { Id = id, OwnerId = parseOwner(id) }
	records[item] = record
	liveTools[id] = tool
	return record
end

local function getRecord(tool: Tool, holder: Player?): Record?
	local item = FruitService:GetItem(tool)
	if not item then
		return nil
	end

	local record = records[item]
	if record then
		return record
	end
	if not holder then
		return nil
	end

	-- A fruit nobody registered: its first known holder becomes the owner.
	if not warnedUnregistered then
		warnedUnregistered = true
		warn(`[FruitLog] {item.FruitName} fruit was created without FruitLogService:Register`)
	end
	return attach(tool, item, newId(holder.UserId, holder.UserId))
end

function FruitLogService:Record(player: Player?, action: string, fruitName: string, id: string?, hasAura: boolean?)
	if not hasAura and not FruitEconomyConfig.IsTracked(fruitName) then
		return
	end

	entries[nextIndex] = {
		Time = os.time(),
		UserId = if player then player.UserId else 0,
		PlayerName = if player then player.Name else "",
		Action = action,
		Fruit = fruitName,
		Id = id or UNKNOWN_ID,
		HasAura = hasAura == true,
	}
	nextIndex = nextIndex % FruitOddsConfig.AuditLogSize + 1
end

-- Logs a movement of a fruit Tool.
function FruitLogService:RecordTool(player: Player, action: string, tool: Tool)
	local item = FruitService:GetItem(tool)
	if item then
		local record = getRecord(tool, player)
		FruitLogService:Record(player, action, item.FruitName, record and record.Id, item.HasAura)
	end
end

-- Gives a freshly created fruit its id. `ownerId` is the player the fruit counts as
-- found by (the owner of the box it came from); it defaults to `player`.
function FruitLogService:Register(tool: Tool, player: Player, ownerId: number?): string?
	local item = FruitService:GetItem(tool)
	if not item then
		return nil
	end

	local record = attach(tool, item, newId(player.UserId, ownerId or player.UserId))
	FruitLogService:Record(player, "Spawned", item.FruitName, record.Id, item.HasAura)
	return record.Id
end

-- Gives a fruit rebuilt from saved data the id it was saved with.
function FruitLogService:Restore(tool: Tool, id: string, holder: Player)
	local item = FruitService:GetItem(tool)
	if not item then
		return
	end
	-- Slots written before ids existed hold "None" or an empty string.
	local valid = string.match(id, "^%d+%-%d+%-%d+") ~= nil
	attach(tool, item, if valid then id else newId(holder.UserId, holder.UserId), holder)
end

function FruitLogService:GetId(tool: Tool, holder: Player?): string?
	local record = getRecord(tool, holder)
	return record and record.Id
end

-- UserId of the player the fruit was first given to.
function FruitLogService:GetOwnerId(tool: Tool, holder: Player?): number?
	local record = getRecord(tool, holder)
	return record and record.OwnerId
end

-- Newest first. `id` narrows the list to one fruit.
function FruitLogService:GetEntries(limit: number?, id: string?): { Entry }
	local result: { Entry } = {}
	local size = FruitOddsConfig.AuditLogSize
	for offset = 1, size do
		local entry = entries[(nextIndex - 1 - offset) % size + 1]
		if not entry then
			break
		end
		if not id or entry.Id == id then
			table.insert(result, entry)
			if limit and #result >= limit then
				break
			end
		end
	end
	return result
end

function FruitLogService:KnitInit()
	FruitService = Knit.GetService("FruitService")
	WebhookService = Knit.GetService("WebhookService")
end

function FruitLogService:KnitStart()
	-- Eaten / Dropped / Given. An eaten fruit's Tool is already gone, its item table is not.
	FruitService.ItemUsed:Connect(function(player: Player, item: any, action: string)
		local record = records[item]
		FruitLogService:Record(player, action, item.FruitName, record and record.Id, item.HasAura)
	end)
end

return FruitLogService
