--!strict
--[[
	Player-to-player trade: Beri, Gems, devil fruits and the three treasure compasses
	(Compass, Silver Compass, Golden Compass). The invitation is sent to any player of the
	server, wherever they are.

	What can be put up
	- carried items (Tools): fruit items and compasses, in the Backpack or held;
	- stored fruits: a slot of the sender's fruit storage. It lands in a free unlocked
	  storage slot of the receiver, with its id;
	- bound fruits: a Bound slot of the sender. It lands in a free unlocked Bound slot of
	  the receiver, so both players need the Bound feature.

	Flow
	1. Request(target): an invitation, answered with Respond(accept). One pending
	   invitation per player in each direction; it runs out by itself.
	2. Both sides edit their own offer: SetAmount(currency, amount), AddItem(tool),
	   AddStored(source, slot), RemoveItem(itemId). Every accepted change clears both
	   acceptances and starts a short lock (TradeConfig.ChangeLockSeconds) during which
	   nobody can accept.
	3. SetReady(true) from both starts the countdown (TradeConfig.ConfirmSeconds). Any
	   change, either side taking its acceptance back, or Cancel stops it.
	4. When the countdown ends the swap is executed.

	Everything a client sends is a request about its OWN offer; nothing it sends is
	trusted:
	- currencies are integers within the sender's balance, re-read from the data at the
	  moment of the swap;
	- an item is a Tool instance the server created, checked to be carried by the sender
	  (its Backpack or character) and to be a fruit item (FruitService) or a compass the
	  treasure hunt knows (TreasureService) - never recognised by name alone;
	- a tool that leaves its owner (dropped, eaten, used, lost on death) leaves the offer;
	- a stored or bound fruit is a slot NUMBER of the sender's own data; the server reads
	  what is in it, remembers the exact saved string, and the swap only goes through if
	  the slot still holds that very string. While a player trades, withdrawing from the
	  storage and binding are refused (FruitStorageService), and a slot whose withdrawal is
	  being processed cannot be offered;
	- the swap re-validates both players, both balances, every tool, every slot and the
	  free slots of the receiver, then applies all of it in one go without yielding, so it
	  either happens entirely or not at all. Tools are moved and slots are emptied before
	  they are written on the other side - nothing is ever copied - and each currency is
	  written as "balance - given + received" for both sides in the same breath;
	- a player is in at most one trade, every remote is rate limited, and the trade ends
	  when either player leaves. Carried items need both characters alive at the swap;
	- accounts younger than TradeConfig.MinAccountAgeDays cannot trade, and a player can
	  refuse every invitation (Settings.Trade_Requests).

	What does not change hands: a fruit or compass keeps the finder it was first given to
	(FruitLogService / TreasureService), so the seller's "only from its finder" rule still
	holds after a trade.

	Each client only ever receives its own view of the trade (TradeService.Client.Changed):
	what both sides put up, never the partner's balances or inventory.

	Completed trades are written to the audit log, fruits with their ids (FruitLogService).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local TradeConfig = require(ReplicatedStorage.Shared.Configs.TradeConfig)
local FruitItemCodec = require(ReplicatedStorage.Shared.Util.FruitItemCodec)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local AuditLog = require(ServerStorage.Server.Modules.AuditLog)

type CharacterEntity = CharacterEntity.CharacterEntity
type PlayerData = PlayerData.PlayerData

type Source = "Held" | "Storage" | "Bound"
type OfferedItem = {
	Id: number,
	Source: Source,
	-- Held items.
	Tool: Tool?,
	Connection: RBXScriptConnection?,
	-- Stored and bound fruits: the slot ("1"..) and the exact string saved in it when it
	-- was put up (and the fruit id kept beside a stored item).
	Key: string?,
	Saved: string?,
	SavedId: string?,
}
type Side = {
	Player: Player,
	Amounts: { [string]: number },
	Items: { OfferedItem },
	Ready: boolean,
}
type Session = {
	Sides: { Side },
	NextItemId: number,
	-- os.clock() of the last change to either offer.
	ChangedAt: number,
	ActivityAt: number,
	-- Server time (Workspace:GetServerTimeNow) of the swap while the countdown runs.
	ConfirmAt: number?,
	-- Bumped whenever the countdown is stopped, so a stale timer does nothing.
	Token: number,
	Closed: boolean,
}
type Invite = { From: Player, To: Player }

-- What one player is shown of an offered item.
export type ItemView = {
	Id: number,
	Name: string,
	Kind: "Fruit" | "Compass",
	-- Where it comes from, and the slot number of a stored / bound fruit.
	Source: "Held" | "Storage" | "Bound",
	Slot: number?,
	-- Fruits only. Scores: 0-10 affinity scores of an item; Affinities: 1.0-2.0
	-- multipliers of a bound fruit.
	Fruit: string?,
	Scores: { [string]: number }?,
	Affinities: { [string]: number }?,
	HasAura: boolean?,
}
export type OfferView = { Amounts: { [string]: number }, Items: { ItemView }, Ready: boolean }
export type Snapshot = {
	Partner: Player,
	Mine: OfferView,
	Theirs: OfferView,
	ConfirmAt: number?,
	-- Server time until which Accept is refused (a change was just made).
	LockedUntil: number,
}

-- Largest balance a trade may leave someone with (well inside exact integers).
local MAX_BALANCE = 9_000_000_000_000_000
local IS_STUDIO = RunService:IsStudio()
local EMPTY = FruitItemCodec.Empty
local STORAGE_SLOTS = FruitEconomyConfig.Storage.SlotCount
local BOUND_SLOTS = FruitEconomyConfig.Bound.SlotCount

local TradeService = Knit.CreateService({
	Name = "TradeService",
	Client = {
		-- Server -> client: (from: Player, seconds: number) an invitation arrived.
		Invited = Knit.CreateSignal(),
		-- Server -> client: () the pending invitation is gone (answered, expired, withdrawn).
		InviteClosed = Knit.CreateSignal(),
		-- Server -> client: (snapshot: Snapshot?, reason: string?) the trade as this player
		-- sees it; nil when it is over ("Completed", "Cancelled", "PartnerLeft", "Failed"...).
		Changed = Knit.CreateSignal(),

		-- Client -> server.
		Respond = Knit.CreateSignal(), -- (accept: boolean)
		SetAmount = Knit.CreateSignal(), -- (currency: string, amount: number)
		AddItem = Knit.CreateSignal(), -- (tool: Tool)
		AddStored = Knit.CreateSignal(), -- (source: "Storage" | "Bound", slot: number)
		RemoveItem = Knit.CreateSignal(), -- (itemId: number)
		SetReady = Knit.CreateSignal(), -- (ready: boolean)
		Cancel = Knit.CreateSignal(), -- ()
	},
})

local DataService
local CharacterService
local FruitService
local FruitLogService
local FruitStorageService
local NotifyService
local SettingsService
local TreasureService

local sessions: { [Player]: Session } = {}
-- Pending invitation by the player it was sent to, and by the player who sent it.
local invitesTo: { [Player]: Invite } = {}
local invitesFrom: { [Player]: Invite } = {}
local lastRequest: { [Player]: number } = {}
-- declined[sender][target user id] = os.clock() of the refusal.
local declined: { [Player]: { [number]: number } } = {}

local requestLimiter = RateLimiter.new(3, 0.5)
local actionLimiter = RateLimiter.new(12, 6)

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- Fresh accounts cannot trade (Studio test players are always fresh: not checked there).
local function isOldEnough(player: Player): boolean
	return IS_STUDIO or player.AccountAge >= TradeConfig.MinAccountAgeDays
end

-- The data of a player able to trade right now.
local function getTrader(player: Player): PlayerData?
	if player.Parent ~= Players or not isOldEnough(player) then
		return nil
	end
	local data: PlayerData? = DataService:GetData(player)
	return if data and data:IsActive() then data else nil
end

-- The living, spawned character of a player: what carried items need on both sides.
local function getBody(player: Player): CharacterEntity?
	local entity: CharacterEntity? = CharacterService:GetPlayerEntity(player)
	return if entity and not entity.Dead and entity.Spawned then entity else nil
end

-- "3" for a valid slot number, nil for anything else a client may send.
local function toSlotKey(slot: unknown, count: number): string?
	if type(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 or slot < 1 or slot > count then
		return nil
	end
	return tostring(slot)
end

-- What a slot of the player's data holds right now: the saved string and, for the
-- storage, the fruit id kept beside it. nil when the slot is locked, empty, unreadable
-- or (storage) being withdrawn.
local function readSlot(player: Player, data: PlayerData, source: Source, key: string): (string?, string?)
	if source == "Storage" then
		local stored = (data.Data :: any).Storages[key]
		if type(stored) ~= "table" or stored.Unlocked ~= true or not FruitItemCodec.DecodeItem(stored.Item) then
			return nil, nil
		end
		if FruitStorageService:IsWithdrawing(player, key) then
			return nil, nil
		end
		return stored.Item, if type(stored.ID) == "string" then stored.ID else EMPTY
	elseif source == "Bound" then
		local bound = (data.Data :: any).Bounds[key]
		if type(bound) ~= "table" or bound.Unlocked ~= true or not FruitItemCodec.DecodeBound(bound.Fruit) then
			return nil, nil
		end
		return bound.Fruit, nil
	end
	return nil, nil
end

-- Whether the slot still holds exactly what was put up.
local function slotHolds(player: Player, data: PlayerData, item: OfferedItem): boolean
	local key = item.Key
	if not key then
		return false
	end
	local saved, savedId = readSlot(player, data, item.Source, key)
	return saved ~= nil and saved == item.Saved and savedId == item.SavedId
end

-- Unlocked, empty slots of a player ("1".. in order) that can receive a fruit.
local function freeSlots(player: Player, data: PlayerData, source: Source): { string }
	local result: { string } = {}
	if source == "Storage" then
		for slot = 1, STORAGE_SLOTS do
			local key = tostring(slot)
			local stored = (data.Data :: any).Storages[key]
			if
				type(stored) == "table"
				and stored.Unlocked == true
				and stored.Item == EMPTY
				and not FruitStorageService:IsWithdrawing(player, key)
			then
				table.insert(result, key)
			end
		end
	else
		for slot = 1, BOUND_SLOTS do
			local key = tostring(slot)
			local bound = (data.Data :: any).Bounds[key]
			if type(bound) == "table" and bound.Unlocked == true and bound.Fruit == EMPTY then
				table.insert(result, key)
			end
		end
	end
	return result
end

local function countSource(side: any, source: Source): number
	local count = 0
	for _, item in side.Items do
		if item.Source == source then
			count += 1
		end
	end
	return count
end

-- Whether the player is carrying the tool: in the Backpack or held.
local function carries(player: Player, tool: Tool): boolean
	local parent = tool.Parent
	if not parent then
		return false
	end
	return parent == player:FindFirstChildOfClass("Backpack") or (player.Character ~= nil and parent == player.Character)
end

-- "Fruit" / "Compass" for a tool that may change hands, nil for anything else.
local function getKind(tool: Tool): ("Fruit" | "Compass")?
	if FruitService:GetItem(tool) then
		return "Fruit"
	end
	if TradeConfig.Compasses[tool.Name] and TreasureService:IsCompass(tool) then
		return "Compass"
	end
	return nil
end

local function describe(item: OfferedItem): ItemView
	if item.Source == "Storage" then
		local stored = FruitItemCodec.DecodeItem(item.Saved)
		return {
			Id = item.Id,
			Name = if stored then `{stored.FruitName} Fruit` else "Fruit",
			Kind = "Fruit",
			Source = "Storage",
			Slot = tonumber(item.Key),
			Fruit = stored and stored.FruitName,
			Scores = if stored then table.clone(stored.Scores) :: any else nil,
			HasAura = stored ~= nil and stored.HasAura,
		}
	elseif item.Source == "Bound" then
		local bound = FruitItemCodec.DecodeBound(item.Saved)
		return {
			Id = item.Id,
			Name = if bound then `{bound.FruitName} Fruit (Bound)` else "Bound Fruit",
			Kind = "Fruit",
			Source = "Bound",
			Slot = tonumber(item.Key),
			Fruit = bound and bound.FruitName,
			Affinities = if bound then table.clone(bound.Affinities) :: any else nil,
		}
	end

	local tool = item.Tool :: Tool
	local fruit = FruitService:GetItem(tool)
	if fruit then
		return {
			Id = item.Id,
			Name = `{fruit.FruitName} Fruit`,
			Kind = "Fruit",
			Source = "Held",
			Fruit = fruit.FruitName,
			Scores = table.clone(fruit.Scores) :: any,
			HasAura = fruit.HasAura,
		}
	end
	return { Id = item.Id, Name = tool.Name, Kind = "Compass", Source = "Held" }
end

local function viewOf(side: Side): OfferView
	local items: { ItemView } = {}
	for index, item in side.Items do
		items[index] = describe(item)
	end
	return { Amounts = table.clone(side.Amounts), Items = items, Ready = side.Ready }
end

local function push(session: Session)
	if session.Closed then
		return
	end
	local lockedUntil = serverNow() + math.max(0, TradeConfig.ChangeLockSeconds - (os.clock() - session.ChangedAt))
	for index, side in session.Sides do
		local other = session.Sides[3 - index]
		local snapshot: Snapshot = {
			Partner = other.Player,
			Mine = viewOf(side),
			Theirs = viewOf(other),
			ConfirmAt = session.ConfirmAt,
			LockedUntil = lockedUntil,
		}
		TradeService.Client.Changed:Fire(side.Player, snapshot)
	end
end

local function stopCountdown(session: Session)
	session.ConfirmAt = nil
	session.Token += 1
end

-- An offer changed: nobody has accepted what is on the table now.
local function touch(session: Session)
	for _, side in session.Sides do
		side.Ready = false
	end
	session.ChangedAt = os.clock()
	session.ActivityAt = session.ChangedAt
	stopCountdown(session)
end

-- Forgets the session and lets go of everything it holds. Nothing is sent.
local function release(session: Session)
	session.Closed = true
	stopCountdown(session)
	for _, side in session.Sides do
		if sessions[side.Player] == session then
			sessions[side.Player] = nil
		end
		for _, item in side.Items do
			if item.Connection then
				item.Connection:Disconnect()
			end
		end
	end
end

local function close(session: Session, reason: string, message: string?)
	if session.Closed then
		return
	end
	release(session)
	for _, side in session.Sides do
		if side.Player.Parent == Players then
			TradeService.Client.Changed:Fire(side.Player, nil, reason)
			if message then
				NotifyService:Send(side.Player, message, "Error")
			end
		end
	end
end

local function getSide(player: Player): (Session?, Side?)
	local session = sessions[player]
	if not session or session.Closed then
		return nil, nil
	end
	for _, side in session.Sides do
		if side.Player == player then
			return session, side
		end
	end
	return nil, nil
end

local function removeItem(session: Session, side: Side, index: number)
	local item = table.remove(side.Items, index)
	if item then
		if item.Connection then
			item.Connection:Disconnect()
		end
		touch(session)
		push(session)
	end
end

-- Why the swap cannot happen right now, nil when everything holds.
local function validate(session: Session): string?
	local traders: { { Data: PlayerData } } = {}
	local carried = false
	for index, side in session.Sides do
		local data = getTrader(side.Player)
		if not data then
			return "A trader is no longer able to trade."
		end
		traders[index] = { Data = data }
		if countSource(side, "Held") > 0 then
			carried = true
		end
	end
	-- Carried items change hands between two living characters: a Backpack is replaced
	-- on respawn, and what is put into the old one is lost.
	if carried then
		for _, side in session.Sides do
			if not getBody(side.Player) or not side.Player:FindFirstChildOfClass("Backpack") then
				return "Both traders must be alive to trade carried items."
			end
		end
	end

	for index, side in session.Sides do
		local other = session.Sides[3 - index]
		for currency, path in TradeConfig.Currencies do
			local giving = side.Amounts[currency] or 0
			local receiving = other.Amounts[currency] or 0
			local balance = traders[index].Data:Get(path)
			if type(balance) ~= "number" or balance ~= balance or giving < 0 or balance < giving then
				return `{side.Player.Name} no longer has the {currency} offered.`
			end
			if balance - giving + receiving > MAX_BALANCE then
				return `{side.Player.Name} cannot hold that much {currency}.`
			end
		end
		if #side.Items > TradeConfig.MaxItems then
			return "Too many items."
		end
		local seen: { [string]: boolean } = {}
		for _, item in side.Items do
			if item.Source == "Held" then
				local tool = item.Tool
				if not tool or not carries(side.Player, tool) or not getKind(tool) then
					return `{side.Player.Name} no longer has an item offered.`
				end
			else
				local slot = `{item.Source}{item.Key}`
				if seen[slot] or not slotHolds(side.Player, traders[index].Data, item) then
					return `{side.Player.Name} no longer has a fruit offered.`
				end
				seen[slot] = true
			end
		end

		-- Room on this side for what the other one sends: its free slots plus the ones
		-- it is giving away itself.
		for _, source: Source in { "Storage" :: Source, "Bound" :: Source } do
			local incoming = countSource(other, source)
			if incoming > 0 then
				local room = #freeSlots(side.Player, traders[index].Data, source) + countSource(side, source)
				if room < incoming then
					return if source == "Storage"
						then `{side.Player.Name} has no free storage slot for that.`
						else `{side.Player.Name} has no free Bound slot for that.`
				end
			end
		end
	end
	return nil
end

local function summarise(side: Side): string
	local parts: { string } = {}
	for _, currency in TradeConfig.CurrencyOrder do
		local amount = side.Amounts[currency] or 0
		if amount > 0 then
			table.insert(parts, `{amount} {currency}`)
		end
	end
	for _, item in side.Items do
		local name = describe(item).Name
		local tool = item.Tool
		if item.Source == "Storage" then
			table.insert(parts, `{name} [{item.SavedId}] (storage {item.Key})`)
		elseif item.Source == "Bound" then
			table.insert(parts, `{name} (bound {item.Key}: {item.Saved})`)
		elseif tool then
			local id = if FruitService:GetItem(tool) then FruitLogService:GetId(tool, side.Player) else nil
			table.insert(parts, if id then `{name} [{id}]` else tool.Name)
		end
	end
	return if #parts > 0 then table.concat(parts, ", ") else "nothing"
end

-- The swap. Everything after the validation runs without yielding.
local function execute(session: Session)
	if session.Closed then
		return
	end
	local problem = validate(session)
	if problem then
		close(session, "Failed", problem)
		return
	end

	local first, second = session.Sides[1], session.Sides[2]
	local firstData = DataService:GetData(first.Player) :: PlayerData
	local secondData = DataService:GetData(second.Player) :: PlayerData
	local firstBackpack = first.Player:FindFirstChildOfClass("Backpack")
	local secondBackpack = second.Player:FindFirstChildOfClass("Backpack")
	local firstGives, secondGives = summarise(first), summarise(second)

	-- From here on the session no longer watches its tools: moving them is not "losing" them.
	release(session)

	for currency, path in TradeConfig.Currencies do
		local fromFirst = first.Amounts[currency] or 0
		local fromSecond = second.Amounts[currency] or 0
		if fromFirst ~= fromSecond then
			local firstBalance = firstData:Get(path) :: number
			local secondBalance = secondData:Get(path) :: number
			firstData:Set(path, firstBalance - fromFirst + fromSecond)
			secondData:Set(path, secondBalance - fromSecond + fromFirst)
		end
	end

	-- Stored and bound fruits. Every slot given away is emptied on both sides first;
	-- only then is anything written, into slots that are empty at that moment. The
	-- validation above guarantees there is room.
	local function takeOut(side: Side, data: PlayerData)
		for _, item in side.Items do
			if item.Source == "Storage" then
				data:Set(`Storages.{item.Key}`, { Item = EMPTY, ID = EMPTY, Unlocked = true })
			elseif item.Source == "Bound" then
				data:Set(`Bounds.{item.Key}.Fruit`, EMPTY)
			end
		end
	end
	takeOut(first, firstData)
	takeOut(second, secondData)

	local function putIn(side: Side, receiver: Player, data: PlayerData)
		local storage = freeSlots(receiver, data, "Storage")
		local bounds = freeSlots(receiver, data, "Bound")
		for _, item in side.Items do
			if item.Source == "Storage" then
				local key = table.remove(storage, 1)
				local stored = FruitItemCodec.DecodeItem(item.Saved)
				if key and stored then
					data:Set(`Storages.{key}`, { Item = item.Saved, ID = item.SavedId or EMPTY, Unlocked = true })
					FruitLogService:Record(side.Player, "Traded", stored.FruitName, item.SavedId, stored.HasAura)
					FruitLogService:Record(receiver, "Received", stored.FruitName, item.SavedId, stored.HasAura)
				end
			elseif item.Source == "Bound" then
				local key = table.remove(bounds, 1)
				local bound = FruitItemCodec.DecodeBound(item.Saved)
				if key and bound then
					data:Set(`Bounds.{key}.Fruit`, item.Saved)
					FruitLogService:Record(side.Player, "Traded", bound.FruitName)
					FruitLogService:Record(receiver, "Received", bound.FruitName)
				end
			end
		end
	end
	putIn(first, second.Player, secondData)
	putIn(second, first.Player, firstData)

	local function hand(side: Side, receiver: Player, backpack: Backpack?)
		for _, item in side.Items do
			local tool = item.Tool
			if item.Source == "Held" and tool and backpack then
				if FruitService:GetItem(tool) then
					FruitLogService:RecordTool(side.Player, "Traded", tool)
				end
				tool.Parent = backpack
				if FruitService:GetItem(tool) then
					FruitLogService:RecordTool(receiver, "Received", tool)
				end
			end
		end
	end
	hand(first, second.Player, secondBackpack)
	hand(second, first.Player, firstBackpack)

	AuditLog.Record(
		first.Player,
		"trade",
		`with {second.Player.Name} ({second.Player.UserId}): gave {firstGives}; received {secondGives}`
	)

	-- Both profiles are written now rather than at the next autosave.
	firstData:Save()
	secondData:Save()

	for _, side in session.Sides do
		TradeService.Client.Changed:Fire(side.Player, nil, "Completed")
		NotifyService:Send(side.Player, "Trade completed.", "Success")
	end
end

local function startCountdown(session: Session)
	stopCountdown(session)
	local token = session.Token
	session.ConfirmAt = serverNow() + TradeConfig.ConfirmSeconds
	task.delay(TradeConfig.ConfirmSeconds, function()
		if session.Closed or session.Token ~= token then
			return
		end
		for _, side in session.Sides do
			if not side.Ready then
				return
			end
		end
		execute(session)
	end)
end

local function watchIdle(session: Session)
	task.delay(TradeConfig.IdleSeconds, function()
		if session.Closed then
			return
		end
		if os.clock() - session.ActivityAt >= TradeConfig.IdleSeconds then
			close(session, "Idle", "The trade was closed: nobody touched it.")
		else
			watchIdle(session)
		end
	end)
end

local function open(first: Player, second: Player)
	local now = os.clock()
	local session: Session = {
		Sides = {
			{ Player = first, Amounts = {}, Items = {}, Ready = false },
			{ Player = second, Amounts = {}, Items = {}, Ready = false },
		},
		NextItemId = 1,
		ChangedAt = now,
		ActivityAt = now,
		ConfirmAt = nil,
		Token = 0,
		Closed = false,
	}
	for _, side in session.Sides do
		for _, currency in TradeConfig.CurrencyOrder do
			side.Amounts[currency] = 0
		end
		sessions[side.Player] = session
	end
	watchIdle(session)
	push(session)
end

local function clearInvite(invite: Invite)
	if invitesTo[invite.To] == invite then
		invitesTo[invite.To] = nil
		if invite.To.Parent == Players then
			TradeService.Client.InviteClosed:Fire(invite.To)
		end
	end
	if invitesFrom[invite.From] == invite then
		invitesFrom[invite.From] = nil
	end
end

---------------------------------------------------------------------------------------
-- Requests

-- Invites `target` to trade. Returns whether the invitation was sent and, when it was
-- not, a short reason for the sender's screen.
function TradeService.Client:Request(player: Player, target: unknown): (boolean, string?)
	if not requestLimiter:Consume(player) then
		return false, "Wait a moment."
	end
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Player") or target == player then
		return false, "Unknown player."
	end
	local other = target :: Player
	if not isOldEnough(player) then
		return false, `Your account must be {TradeConfig.MinAccountAgeDays} days old to trade.`
	end
	if not isOldEnough(other) then
		return false, "That player's account is too new to trade."
	end

	if not getTrader(player) then
		return false, "You cannot trade right now."
	end
	if not getTrader(other) then
		return false, "That player cannot trade right now."
	end
	if SettingsService:Get(other, "Trade_Requests") == false then
		return false, "That player is not accepting trades."
	end
	if sessions[player] or invitesFrom[player] then
		return false, "You already have a trade going."
	end
	if sessions[other] or invitesTo[other] then
		return false, "That player is busy."
	end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < TradeConfig.RequestCooldown then
		return false, "Wait a moment."
	end
	local refusals = declined[player]
	if refusals and now - (refusals[other.UserId] or -math.huge) < TradeConfig.DeclineCooldown then
		return false, "That player declined. Try again later."
	end
	lastRequest[player] = now

	local invite: Invite = { From = player, To = other }
	invitesTo[other] = invite
	invitesFrom[player] = invite
	TradeService.Client.Invited:Fire(other, player, TradeConfig.RequestSeconds)
	task.delay(TradeConfig.RequestSeconds, function()
		if invitesTo[other] == invite then
			clearInvite(invite)
			if player.Parent == Players then
				NotifyService:Send(player, `{other.Name} did not answer the trade request.`, "Info")
			end
		end
	end)
	return true, nil
end

-- The trade as the caller sees it right now, nil when there is none (a screen mounted late).
function TradeService.Client:GetState(player: Player): Snapshot?
	local session, side = getSide(player)
	if not session or not side or not actionLimiter:Consume(player) then
		return nil
	end
	local other = session.Sides[if session.Sides[1] == side then 2 else 1]
	return {
		Partner = other.Player,
		Mine = viewOf(side),
		Theirs = viewOf(other),
		ConfirmAt = session.ConfirmAt,
		LockedUntil = serverNow() + math.max(0, TradeConfig.ChangeLockSeconds - (os.clock() - session.ChangedAt)),
	}
end

local function onRespond(player: Player, accept: unknown)
	local invite = invitesTo[player]
	if not invite or not actionLimiter:Consume(player) then
		return
	end
	clearInvite(invite)
	local sender = invite.From
	if sender.Parent ~= Players then
		return
	end

	if accept ~= true then
		local refusals = declined[sender]
		if not refusals then
			refusals = {}
			declined[sender] = refusals
		end
		refusals[player.UserId] = os.clock()
		NotifyService:Send(sender, `{player.Name} declined the trade.`, "Info")
		return
	end

	-- Everything is checked again: the invitation may be seconds old.
	if not getTrader(player) or not getTrader(sender) or sessions[player] or sessions[sender] then
		NotifyService:Send(player, "The trade could not start.", "Error")
		NotifyService:Send(sender, "The trade could not start.", "Error")
		return
	end
	open(sender, player)
end

---------------------------------------------------------------------------------------
-- Offers

local function onSetAmount(player: Player, currency: unknown, amount: unknown)
	local session, side = getSide(player)
	if not session or not side or not actionLimiter:Consume(player) then
		return
	end
	if type(currency) ~= "string" or not TradeConfig.Currencies[currency] then
		return
	end
	if type(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 then
		return
	end
	if amount < 0 or amount > TradeConfig.MaxAmount then
		return
	end

	local data = DataService:GetData(player)
	local balance = data and data:Get(TradeConfig.Currencies[currency])
	if type(balance) ~= "number" or amount > balance then
		NotifyService:Send(player, `You do not have that much {currency}.`, "Error")
		-- The sender's field goes back to what is really on the table.
		push(session)
		return
	end
	if side.Amounts[currency] == amount then
		return
	end

	side.Amounts[currency] = amount
	touch(session)
	push(session)
end

local function onAddItem(player: Player, tool: unknown)
	local session, side = getSide(player)
	if not session or not side or not actionLimiter:Consume(player) then
		return
	end
	if typeof(tool) ~= "Instance" or not (tool :: Instance):IsA("Tool") then
		return
	end
	local offered = tool :: Tool
	if not getBody(player) or not carries(player, offered) or not getKind(offered) then
		return
	end
	if #side.Items >= TradeConfig.MaxItems then
		NotifyService:Send(player, `At most {TradeConfig.MaxItems} items per trade.`, "Error")
		return
	end
	for _, item in side.Items do
		if item.Tool == offered then
			return
		end
	end

	local id = session.NextItemId
	session.NextItemId += 1
	local connection = offered.AncestryChanged:Connect(function()
		-- Dropped, eaten, used up or lost: it is no longer the owner's to give. Moving
		-- between the Backpack and the hand is still carrying it.
		if session.Closed or carries(player, offered) then
			return
		end
		for index, item in side.Items do
			if item.Id == id then
				removeItem(session, side, index)
				break
			end
		end
	end)
	table.insert(side.Items, { Id = id, Source = "Held", Tool = offered, Connection = connection })
	touch(session)
	push(session)
end

-- A fruit of the sender's own storage or Bound slots. The client only names the slot.
local function onAddStored(player: Player, source: unknown, slot: unknown)
	local session, side = getSide(player)
	if not session or not side or not actionLimiter:Consume(player) then
		return
	end
	if source ~= "Storage" and source ~= "Bound" then
		return
	end
	local kind = source :: Source
	local key = toSlotKey(slot, if kind == "Storage" then STORAGE_SLOTS else BOUND_SLOTS)
	local data = getTrader(player)
	if not key or not data then
		return
	end
	for _, item in side.Items do
		if item.Source == kind and item.Key == key then
			return
		end
	end
	if #side.Items >= TradeConfig.MaxItems then
		NotifyService:Send(player, `At most {TradeConfig.MaxItems} items per trade.`, "Error")
		return
	end

	local saved, savedId = readSlot(player, data, kind, key)
	if not saved then
		NotifyService:Send(player, "That slot has nothing to trade right now.", "Error")
		return
	end

	local id = session.NextItemId
	session.NextItemId += 1
	table.insert(side.Items, { Id = id, Source = kind, Key = key, Saved = saved, SavedId = savedId })
	touch(session)
	push(session)
end

local function onRemoveItem(player: Player, itemId: unknown)
	local session, side = getSide(player)
	if not session or not side or not actionLimiter:Consume(player) or type(itemId) ~= "number" then
		return
	end
	for index, item in side.Items do
		if item.Id == itemId then
			removeItem(session, side, index)
			return
		end
	end
end

local function onSetReady(player: Player, ready: unknown)
	local session, side = getSide(player)
	if not session or not side or not actionLimiter:Consume(player) or type(ready) ~= "boolean" then
		return
	end
	session.ActivityAt = os.clock()

	if not ready then
		if side.Ready then
			side.Ready = false
			stopCountdown(session)
			push(session)
		end
		return
	end
	if side.Ready then
		return
	end
	-- A change was just made: the other side must have had time to see it.
	if os.clock() - session.ChangedAt < TradeConfig.ChangeLockSeconds then
		push(session)
		return
	end

	local empty = true
	for _, each in session.Sides do
		if #each.Items > 0 then
			empty = false
		end
		for _, amount in each.Amounts do
			if amount > 0 then
				empty = false
			end
		end
	end
	if empty then
		NotifyService:Send(player, "There is nothing to trade yet.", "Error")
		return
	end

	side.Ready = true
	local other = session.Sides[if session.Sides[1] == side then 2 else 1]
	if other.Ready then
		startCountdown(session)
	end
	push(session)
end

local function onCancel(player: Player)
	local session = sessions[player]
	if session and actionLimiter:Consume(player) then
		close(session, "Cancelled")
		for _, side in session.Sides do
			if side.Player ~= player and side.Player.Parent == Players then
				NotifyService:Send(side.Player, `{player.Name} cancelled the trade.`, "Info")
			end
		end
	end
end

function TradeService:IsTrading(player: Player): boolean
	return sessions[player] ~= nil
end

function TradeService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	FruitService = Knit.GetService("FruitService")
	FruitLogService = Knit.GetService("FruitLogService")
	FruitStorageService = Knit.GetService("FruitStorageService")
	NotifyService = Knit.GetService("NotifyService")
	SettingsService = Knit.GetService("SettingsService")
	TreasureService = Knit.GetService("TreasureService")
end

function TradeService:KnitStart()
	local client = TradeService.Client
	client.Respond:Connect(onRespond)
	client.SetAmount:Connect(onSetAmount)
	client.AddItem:Connect(onAddItem)
	client.AddStored:Connect(onAddStored)
	client.RemoveItem:Connect(onRemoveItem)
	client.SetReady:Connect(onSetReady)
	client.Cancel:Connect(onCancel)

	Players.PlayerRemoving:Connect(function(player: Player)
		local session = sessions[player]
		if session then
			close(session, "PartnerLeft", "The trade was closed: a trader left.")
		end
		local received = invitesTo[player]
		if received then
			clearInvite(received)
		end
		local sent = invitesFrom[player]
		if sent then
			clearInvite(sent)
		end
		lastRequest[player] = nil
		declined[player] = nil
		requestLimiter:Forget(player)
		actionLimiter:Forget(player)
	end)
end

return TradeService
