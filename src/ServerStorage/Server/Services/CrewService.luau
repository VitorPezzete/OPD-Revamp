--!strict
--[[
	Crews: a named group with an owner, one co-owner and a few members, a logo, a level
	and member slots bought with Gems.

	Where the truth lives
	- The crew record (DataStore "Crews", one key per crew) is the member list. Every
	  change is one UpdateAsync, so two servers editing the same crew cannot lose a write.
	- The player's profile only keeps a pointer (`Crew.Id`, `Crew.Rank`). It is checked
	  against the record when the profile loads: a player kicked or whose crew was
	  disbanded while offline is simply cleared on the next join.
	- A server caches the crews of the players it hosts. Other servers are told a crew
	  changed through MessagingService and re-read it.

	Other players see a crew through the attributes `CrewId` / `CrewName` on the Player.

	Server API
		CrewService:GetCrewId(player) -> string?        CrewService:GetRole(player) -> Role?
		CrewService:GetCrewName(player) -> string?      CrewService:AreCrewmates(a, b) -> boolean
		CrewService:AddExp(crewId, amount)              -- world events reward crew experience

	Record shape is the legacy one (existing crews keep working):
		{ CrewName, OwnerId, ImageId, Data = { Level, XP, Bounty, TotalPoints, Points,
		  CoOwner, MemberLimit, Members = { userId } } }

	Legacy holes closed here are listed next to the code that closes them.
]]
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CrewConfig = require(ReplicatedStorage.Shared.Configs.CrewConfig)
local AuditLog = require(ServerStorage.Server.Modules.AuditLog)
local DataStoreUtil = require(ServerStorage.Server.Modules.DataStoreUtil)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

type PlayerData = PlayerData.PlayerData

export type Role = "Owner" | "CoOwner" | "Member"

type CrewData = {
	Level: number,
	XP: number,
	Bounty: number,
	TotalPoints: number,
	Points: number,
	CoOwner: number,
	MemberLimit: number,
	Members: { number },
}
type CrewRecord = { CrewName: string, OwnerId: number, ImageId: string, Data: CrewData }
type Crew = { Id: string, Record: CrewRecord, Online: { [Player]: true } }
type Invite = { CrewId: string, From: string, Expires: number }

export type MemberView = { UserId: number, Name: string, Role: Role }
export type CrewView = {
	Id: string,
	Name: string,
	ImageId: string,
	Level: number,
	XP: number,
	MemberLimit: number,
	Members: { MemberView },
}

local STORE_NAME = "Crews"
local TOPIC = "CrewChanged"
local GEMS = "Economy.Gems"
local UNAVAILABLE = "Crew data is unavailable right now, try again in a moment."

local CrewService = Knit.CreateService({
	Name = "CrewService",
	Client = {
		-- (view: CrewView?) whenever the caller's crew changes; nil = not in a crew.
		Updated = Knit.CreateSignal(),
		-- (crewName: string, inviterName: string, seconds: number)
		Invited = Knit.CreateSignal(),

		-- (name: string, imageId: string)
		Create = Knit.CreateSignal(),
		-- (playerName: string)
		Invite = Knit.CreateSignal(),
		-- (accept: boolean)
		RespondInvite = Knit.CreateSignal(),
		Leave = Knit.CreateSignal(),
		Disband = Knit.CreateSignal(),
		-- (userId: number)
		Kick = Knit.CreateSignal(),
		-- (userId: number)
		Promote = Knit.CreateSignal(),
		Demote = Knit.CreateSignal(),
		UpgradeCapacity = Knit.CreateSignal(),
		-- (name: string)
		Rename = Knit.CreateSignal(),
		-- (imageId: string)
		ChangeLogo = Knit.CreateSignal(),
	},
})

local DataService
local NotifyService

local store: DataStore? = nil
local crews: { [string]: Crew } = {}
local membership: { [Player]: string } = {}
local invites: { [Player]: Invite } = {}
local names: { [number]: string } = {}
-- A player runs one crew action at a time: each one waits on the DataStore.
local busy: { [Player]: boolean } = {}
local refreshing: { [string]: boolean } = {}
local actionLimiter = RateLimiter.new(3, 0.5)
local inviteLimiter = RateLimiter.new(2, 0.2)

local function notify(player: Player, text: string, kind: string?)
	NotifyService:Send(player, text, kind or "Error")
end

--[[
	Makes a stored record safe to use. Legacy records can miss fields, and every crew was
	created with co-owner 451082957 (a developer's account, also what "Demote" assigned):
	that id could invite players into any crew. A co-owner is only valid if it is a member.
]]
local function normalise(record: any): CrewRecord?
	if type(record) ~= "table" or type(record.OwnerId) ~= "number" then
		return nil
	end

	local data = if type(record.Data) == "table" then record.Data else {}
	record.Data = data
	record.CrewName = if type(record.CrewName) == "string" then record.CrewName else "Crew"
	record.ImageId = string.match(tostring(record.ImageId), "^%d+$") or "0"

	data.Level = math.clamp(tonumber(data.Level) or 0, 0, CrewConfig.MaxLevel)
	data.XP = math.max(0, tonumber(data.XP) or 0)
	data.Bounty = tonumber(data.Bounty) or 0
	data.TotalPoints = tonumber(data.TotalPoints) or 0
	data.Points = tonumber(data.Points) or 0
	data.MemberLimit =
		math.clamp(tonumber(data.MemberLimit) or CrewConfig.StartMemberLimit, 0, CrewConfig.MaxMemberLimit)

	local members: { number } = {}
	if type(data.Members) == "table" then
		for _, userId in data.Members do
			if type(userId) == "number" and userId ~= record.OwnerId and not table.find(members, userId) then
				table.insert(members, userId)
			end
		end
	end
	data.Members = members
	data.CoOwner = if type(data.CoOwner) == "number" and table.find(members, data.CoOwner) then data.CoOwner else 0

	return record
end

local function roleOf(record: CrewRecord, userId: number): Role?
	if record.OwnerId == userId then
		return "Owner"
	elseif record.Data.CoOwner == userId then
		return "CoOwner"
	elseif table.find(record.Data.Members, userId) then
		return "Member"
	end
	return nil
end

local function removeMember(record: CrewRecord, userId: number): boolean
	local index = table.find(record.Data.Members, userId)
	if not index then
		return false
	end
	table.remove(record.Data.Members, index)
	if record.Data.CoOwner == userId then
		record.Data.CoOwner = 0
	end
	return true
end

local function resolveName(userId: number): string
	local known = names[userId]
	if known then
		return known
	end

	local online = Players:GetPlayerByUserId(userId)
	local name: string? = if online then online.Name else nil
	if not name then
		local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		name = if ok and type(result) == "string" then result else nil
	end
	if name then
		names[userId] = name
	end
	return name or `Player {userId}`
end

-- Yields the first time a member's name is needed.
local function buildView(crew: Crew): CrewView
	local record = crew.Record
	local members: { MemberView } = { { UserId = record.OwnerId, Name = resolveName(record.OwnerId), Role = "Owner" } }
	for _, userId in record.Data.Members do
		table.insert(members, {
			UserId = userId,
			Name = resolveName(userId),
			Role = if record.Data.CoOwner == userId then "CoOwner" else "Member",
		})
	end

	return {
		Id = crew.Id,
		Name = record.CrewName,
		ImageId = record.ImageId,
		Level = record.Data.Level,
		XP = record.Data.XP,
		MemberLimit = record.Data.MemberLimit,
		Members = members,
	}
end

local function setPointer(player: Player, crewId: string, role: string, crewName: string?)
	local data: PlayerData? = DataService:GetData(player)
	if data then
		data:Set("Crew.Id", crewId)
		data:Set("Crew.Rank", role)
	end
	player:SetAttribute("CrewId", if crewId ~= "" then crewId else nil)
	player:SetAttribute("CrewName", crewName)
end

local function detach(player: Player)
	local crewId = membership[player]
	membership[player] = nil

	local crew = if crewId then crews[crewId] else nil
	if crew then
		crew.Online[player] = nil
		if next(crew.Online) == nil then
			crews[crew.Id] = nil
		end
	end
end

-- The player is no longer part of a crew: forget it everywhere on this server.
local function clearMembership(player: Player, message: string?)
	detach(player)
	setPointer(player, "", "", nil)
	CrewService.Client.Updated:Fire(player, nil)
	if message then
		notify(player, message, "Info")
	end
end

local function attach(player: Player, crew: Crew)
	crew.Online[player] = true
	membership[player] = crew.Id
	crews[crew.Id] = crew
end

-- Sends the current state of a crew to its members on this server.
local function push(crew: Crew)
	task.spawn(function()
		local view = buildView(crew)
		for player in crew.Online do
			if membership[player] == crew.Id then
				local role = roleOf(crew.Record, player.UserId)
				setPointer(player, crew.Id, role or "", crew.Record.CrewName)
				CrewService.Client.Updated:Fire(player, view)
			end
		end
	end)
end

-- Installs a fresh record (nil: the crew is gone) and reconciles who is still in it.
local function applyRecord(crewId: string, record: CrewRecord?)
	local crew = crews[crewId]
	if not crew then
		return
	end

	if not record then
		for player in table.clone(crew.Online) do
			clearMembership(player, "Your crew was disbanded.")
		end
		crews[crewId] = nil
		return
	end

	crew.Record = record
	for player in table.clone(crew.Online) do
		if not roleOf(record, player.UserId) then
			clearMembership(player, "You are no longer in the crew.")
		end
	end
	if crews[crewId] == crew then
		push(crew)
	end
end

local function publish(crewId: string)
	task.spawn(function()
		pcall(MessagingService.PublishAsync, MessagingService, TOPIC, { Id = crewId, Job = game.JobId })
	end)
end

--[[
	One atomic change to a crew. `transform` edits the record in place and returns an
	error text to cancel. Replaces the legacy GetAsync -> edit -> SetAsync pairs, which
	dropped members whenever two servers touched the same crew.
]]
local function mutate(crewId: string, transform: (record: CrewRecord) -> string?): (boolean, string?, CrewRecord?)
	if not store then
		return false, UNAVAILABLE, nil
	end

	local failure: string? = nil
	local ok, result = DataStoreUtil.Update(store, crewId, function(current: any): any
		failure = nil
		local record = normalise(current)
		if not record then
			failure = "This crew no longer exists."
			return nil
		end
		failure = transform(record)
		if failure then
			return nil
		end
		return record
	end)

	if not ok then
		return false, UNAVAILABLE, nil
	elseif failure or type(result) ~= "table" then
		return false, failure or UNAVAILABLE, nil
	end

	local record = normalise(result) :: CrewRecord
	applyRecord(crewId, record)
	publish(crewId)
	return true, nil, record
end

-- (reached the store, crew or nil when it does not exist)
local function loadCrew(crewId: string): (boolean, Crew?)
	local cached = crews[crewId]
	if cached then
		return true, cached
	end
	if not store then
		return false, nil
	end

	local ok, result = DataStoreUtil.Get(store, crewId)
	if not ok then
		return false, nil
	end

	-- Another member may have loaded it while this request was in flight.
	cached = crews[crewId]
	if cached then
		return true, cached
	end

	local record = normalise(result)
	if not record then
		return true, nil
	end
	return true, { Id = crewId, Record = record, Online = {} }
end

--[[
	The legacy game stored the unfiltered text (the filter result was thrown away) and
	accepted any length. A name is kept only if the filter leaves it untouched.
]]
local function validateName(player: Player, raw: unknown): (string?, string?)
	if type(raw) ~= "string" or #raw > CrewConfig.NameMaxLength * 4 then
		return nil, "Invalid crew name."
	end

	local name = string.gsub(string.match(raw, "^%s*(.-)%s*$") or "", "%s+", " ")
	local length = utf8.len(name)
	if not length or string.find(name, "%c") then
		return nil, "Invalid crew name."
	elseif length < CrewConfig.NameMinLength or length > CrewConfig.NameMaxLength then
		return nil, `A crew name has {CrewConfig.NameMinLength} to {CrewConfig.NameMaxLength} characters.`
	end

	local ok, filtered = pcall(function(): string
		local result = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return nil, "The name could not be checked, try again."
	elseif filtered ~= name then
		return nil, "That crew name is not allowed."
	end
	return name, nil
end

local function parseImageId(raw: unknown): string?
	if type(raw) == "number" then
		raw = tostring(math.floor(raw))
	end
	if type(raw) ~= "string" or #raw > 40 then
		return nil
	end
	local digits = string.match(raw, "^%s*(%d+)%s*$") or string.match(raw, "^%s*rbxassetid://(%d+)%s*$")
	return if digits and #digits <= 20 then digits else nil
end

local function getCrewOf(player: Player): (Crew?, Role?)
	local crewId = membership[player]
	local crew = if crewId then crews[crewId] else nil
	if not crew then
		return nil, nil
	end
	return crew, roleOf(crew.Record, player.UserId)
end

-- Charges first and gives the Gems back if the store rejects the change, so a failed
-- request is free (the legacy game charged for crews it then failed to save).
local function chargedMutation(
	player: Player,
	data: PlayerData,
	crew: Crew,
	price: number,
	transform: (record: CrewRecord) -> string?
): boolean
	if not data:TrySpend(GEMS, price) then
		notify(player, "Not enough Gems.")
		return false
	end

	local ok, problem = mutate(crew.Id, transform)
	if not ok then
		if data:IsActive() then
			data:Increment(GEMS, price)
		end
		notify(player, problem or UNAVAILABLE)
	end
	return ok
end

local actions = {}

function actions.Create(player: Player, data: PlayerData, rawName: unknown, rawImage: unknown)
	-- Legacy: creating while already in a crew orphaned the old one and its members.
	if membership[player] or data:Get("Crew.Id") ~= "" then
		notify(player, "Leave your crew first.")
		return
	end
	if not store then
		notify(player, UNAVAILABLE)
		return
	end

	local name, problem = validateName(player, rawName)
	if not name then
		notify(player, problem or "Invalid crew name.")
		return
	end
	local imageId = parseImageId(rawImage) or "0"

	if not data:IsActive() or not data:TrySpend(GEMS, CrewConfig.CreatePrice) then
		notify(player, `Creating a crew costs {CrewConfig.CreatePrice} Gems.`)
		return
	end

	local crewId = string.lower(HttpService:GenerateGUID(false))
	local record: CrewRecord = {
		CrewName = name,
		OwnerId = player.UserId,
		ImageId = imageId,
		Data = {
			Level = 0,
			XP = 0,
			Bounty = 0,
			TotalPoints = 0,
			Points = 0,
			CoOwner = 0,
			MemberLimit = CrewConfig.StartMemberLimit,
			Members = {},
		},
	}

	local ok, written = DataStoreUtil.Update(store, crewId, function(current: any): any
		return if current == nil then record else nil
	end)
	if not ok or written == nil or player.Parent ~= Players or membership[player] then
		if data:IsActive() then
			data:Increment(GEMS, CrewConfig.CreatePrice)
		end
		if ok and written ~= nil then
			DataStoreUtil.Remove(store, crewId)
		end
		notify(player, UNAVAILABLE)
		return
	end

	local crew: Crew = { Id = crewId, Record = record, Online = {} }
	attach(player, crew)
	push(crew)
	AuditLog.Record(player, "crew.create", `{crewId} "{name}"`)
	notify(player, `Crew "{name}" created.`, "Success")
end

function actions.Invite(player: Player, _data: PlayerData, rawName: unknown)
	local crew, role = getCrewOf(player)
	if not crew or (role ~= "Owner" and role ~= "CoOwner") then
		notify(player, "Only the owner and the co-owner can invite.")
		return
	end
	if type(rawName) ~= "string" or #rawName < 3 or #rawName > 20 or not inviteLimiter:Consume(player) then
		return
	end

	local wanted = string.lower(rawName)
	local target: Player? = nil
	for _, candidate in Players:GetPlayers() do
		if string.lower(candidate.Name) == wanted then
			target = candidate
			break
		end
	end

	local targetData: PlayerData? = if target then DataService:GetData(target) else nil
	if not target or not targetData or target == player then
		notify(player, "That player is not in this server.")
		return
	elseif membership[target] or targetData:Get("Crew.Id") ~= "" then
		notify(player, `{target.Name} is already in a crew.`)
		return
	elseif #crew.Record.Data.Members >= crew.Record.Data.MemberLimit then
		notify(player, "Your crew is full.")
		return
	end

	local pending = invites[target]
	if pending and pending.Expires > os.clock() then
		notify(player, `{target.Name} already has a pending invite.`)
		return
	end

	invites[target] = { CrewId = crew.Id, From = player.Name, Expires = os.clock() + CrewConfig.InviteSeconds }
	CrewService.Client.Invited:Fire(target, crew.Record.CrewName, player.Name, CrewConfig.InviteSeconds)
	notify(player, `Invite sent to {target.Name}.`, "Success")
end

--[[
	Legacy "Accept" took the crew id from the client: anyone could join any crew without
	being invited, and the pointer was written even when the crew was full. The invite
	is now remembered here and the client only answers yes or no.
]]
function actions.RespondInvite(player: Player, data: PlayerData, accept: unknown)
	local invite = invites[player]
	invites[player] = nil
	if not invite or accept ~= true then
		return
	end
	if invite.Expires < os.clock() then
		notify(player, "That invite expired.")
		return
	end
	if membership[player] or data:Get("Crew.Id") ~= "" then
		return
	end

	local userId = player.UserId
	local ok, problem, record = mutate(invite.CrewId, function(current: CrewRecord): string?
		if roleOf(current, userId) then
			return nil
		elseif #current.Data.Members >= current.Data.MemberLimit then
			return "That crew is full."
		end
		table.insert(current.Data.Members, userId)
		return nil
	end)
	if not ok or not record then
		notify(player, problem or UNAVAILABLE)
		return
	end
	if player.Parent ~= Players then
		return
	end

	local crew = crews[invite.CrewId] or { Id = invite.CrewId, Record = record, Online = {} }
	attach(player, crew)
	push(crew)
	notify(player, `You joined {record.CrewName}.`, "Success")
end

function actions.Leave(player: Player)
	local crew, role = getCrewOf(player)
	if not crew then
		return
	elseif role == "Owner" then
		notify(player, "The owner cannot leave: disband the crew instead.")
		return
	end

	local userId = player.UserId
	local ok, problem = mutate(crew.Id, function(record: CrewRecord): string?
		removeMember(record, userId)
		return nil
	end)
	if not ok then
		notify(player, problem or UNAVAILABLE)
	end
	-- mutate already cleared the membership when the write went through.
end

-- Not in the legacy game: an owner had no way out of a crew.
function actions.Disband(player: Player)
	local crew, role = getCrewOf(player)
	if not crew or role ~= "Owner" or not store then
		return
	end

	local crewId = crew.Id
	-- Read again from the store: a stale cache must not let a former owner delete the crew.
	local ok, current = DataStoreUtil.Get(store, crewId)
	local record = if ok then normalise(current) else nil
	if not ok then
		notify(player, UNAVAILABLE)
		return
	elseif record and record.OwnerId ~= player.UserId then
		notify(player, "Only the owner can disband the crew.")
		return
	elseif record and not DataStoreUtil.Remove(store, crewId) then
		notify(player, UNAVAILABLE)
		return
	end

	AuditLog.Record(player, "crew.disband", crewId)
	applyRecord(crewId, nil)
	publish(crewId)
end

function actions.Kick(player: Player, _data: PlayerData, rawUserId: unknown)
	local crew, role = getCrewOf(player)
	if not crew or role ~= "Owner" then
		notify(player, "Only the owner can kick members.")
		return
	end
	if type(rawUserId) ~= "number" or rawUserId == player.UserId then
		return
	end

	local targetId: number = rawUserId
	local ok, problem = mutate(crew.Id, function(record: CrewRecord): string?
		if record.OwnerId ~= player.UserId then
			return "Only the owner can kick members."
		elseif not removeMember(record, targetId) then
			return "That player is not in the crew."
		end
		return nil
	end)
	if not ok then
		notify(player, problem or UNAVAILABLE)
	end
end

local function setCoOwner(player: Player, targetId: number)
	local crew, role = getCrewOf(player)
	if not crew or role ~= "Owner" then
		notify(player, "Only the owner can change the co-owner.")
		return
	end

	local ok, problem = mutate(crew.Id, function(record: CrewRecord): string?
		if record.OwnerId ~= player.UserId then
			return "Only the owner can change the co-owner."
		elseif targetId ~= 0 and not table.find(record.Data.Members, targetId) then
			return "That player is not in the crew."
		end
		record.Data.CoOwner = targetId
		return nil
	end)
	if not ok then
		notify(player, problem or UNAVAILABLE)
	end
end

function actions.Promote(player: Player, _data: PlayerData, rawUserId: unknown)
	if type(rawUserId) == "number" and rawUserId ~= player.UserId and rawUserId > 0 then
		setCoOwner(player, rawUserId)
	end
end

function actions.Demote(player: Player)
	setCoOwner(player, 0)
end

function actions.UpgradeCapacity(player: Player, data: PlayerData)
	local crew, role = getCrewOf(player)
	if not crew or role ~= "Owner" then
		notify(player, "Only the owner can buy upgrades.")
		return
	end

	local level = crew.Record.Data.Level
	if not CrewConfig.CanUpgradeCapacity(level, crew.Record.Data.MemberLimit) then
		notify(player, "Level up the crew to unlock another slot.")
		return
	end

	-- Legacy took the Gems and wrote the new limit in two unrelated steps (and the client
	-- bumped its own copy of the limit before the server answered).
	chargedMutation(player, data, crew, CrewConfig.GetCapacityPrice(level), function(record: CrewRecord): string?
		if record.OwnerId ~= player.UserId then
			return "Only the owner can buy upgrades."
		elseif record.Data.Level ~= level or not CrewConfig.CanUpgradeCapacity(level, record.Data.MemberLimit) then
			return "The crew changed, try again."
		end
		record.Data.MemberLimit += 1
		return nil
	end)
end

function actions.Rename(player: Player, data: PlayerData, rawName: unknown)
	local crew, role = getCrewOf(player)
	-- Legacy never checked the role: any player with a crew id could rename the crew.
	if not crew or role ~= "Owner" then
		notify(player, "Only the owner can rename the crew.")
		return
	end

	local name, problem = validateName(player, rawName)
	if not name then
		notify(player, problem or "Invalid crew name.")
		return
	end

	chargedMutation(player, data, crew, CrewConfig.RenamePrice, function(record: CrewRecord): string?
		if record.OwnerId ~= player.UserId then
			return "Only the owner can rename the crew."
		end
		record.CrewName = name
		return nil
	end)
end

function actions.ChangeLogo(player: Player, data: PlayerData, rawImage: unknown)
	local crew, role = getCrewOf(player)
	if not crew or role ~= "Owner" then
		notify(player, "Only the owner can change the logo.")
		return
	end

	local imageId = parseImageId(rawImage)
	if not imageId then
		notify(player, "The logo must be an image id (numbers only).")
		return
	end

	chargedMutation(player, data, crew, CrewConfig.LogoPrice, function(record: CrewRecord): string?
		if record.OwnerId ~= player.UserId then
			return "Only the owner can change the logo."
		end
		record.ImageId = imageId
		return nil
	end)
end

local function runAction(name: string, player: Player, ...: unknown)
	local data: PlayerData? = DataService:GetData(player)
	if not data or busy[player] or not actionLimiter:Consume(player) then
		return
	end

	busy[player] = true
	local ok, problem = pcall((actions :: any)[name], player, data, ...)
	busy[player] = nil
	if not ok then
		warn(`[Crew] {name} failed for {player.Name}: {problem}`)
	end
end

-- Checks the saved pointer against the crew record when a profile loads.
local function onDataLoaded(player: Player, data: PlayerData)
	local crewId = data:Get("Crew.Id")
	if type(crewId) ~= "string" or crewId == "" then
		return
	end

	busy[player] = true
	local reached, crew = loadCrew(crewId)
	busy[player] = nil
	if player.Parent ~= Players or not data:IsActive() or membership[player] then
		return
	end
	if not reached then
		-- Store unreachable: keep the pointer, the player is just crewless this session.
		return
	end

	if not crew or not roleOf(crew.Record, player.UserId) then
		setPointer(player, "", "", nil)
		return
	end

	attach(player, crew)
	push(crew)
end

local function onCrewChangedElsewhere(message: any)
	local payload = message.Data
	if type(payload) ~= "table" or payload.Job == game.JobId then
		return
	end

	local crewId = payload.Id
	if type(crewId) ~= "string" or not crews[crewId] or refreshing[crewId] or not store then
		return
	end

	-- Bursts of changes collapse into one read.
	refreshing[crewId] = true
	task.delay(2, function()
		refreshing[crewId] = nil
		if not crews[crewId] or not store then
			return
		end
		local ok, result = DataStoreUtil.Get(store, crewId)
		if ok then
			applyRecord(crewId, normalise(result))
		end
	end)
end

function CrewService:GetCrewId(player: Player): string?
	return membership[player]
end

function CrewService:GetRole(player: Player): Role?
	local _, role = getCrewOf(player)
	return role
end

function CrewService:GetCrewName(player: Player): string?
	local crew = getCrewOf(player)
	return if crew then crew.Record.CrewName else nil
end

function CrewService:AreCrewmates(a: Player, b: Player): boolean
	local crewId = membership[a]
	return crewId ~= nil and crewId == membership[b]
end

-- Crew experience (world events). Levels up at the legacy thresholds, capped at MaxLevel.
function CrewService:AddExp(crewId: string, amount: number)
	if type(crewId) ~= "string" or crewId == "" or amount ~= amount or amount <= 0 then
		return
	end
	task.spawn(mutate, crewId, function(record: CrewRecord): string?
		local data = record.Data
		data.XP += amount
		while data.Level < CrewConfig.MaxLevel and data.XP >= CrewConfig.GetExpRequired(data.Level) do
			data.Level += 1
		end
		return nil
	end)
end

-- For a screen that opens after the last Updated signal was sent.
function CrewService.Client:GetCrew(player: Player): CrewView?
	local crew = getCrewOf(player)
	return if crew then buildView(crew) else nil
end

function CrewService:KnitInit()
	DataService = Knit.GetService("DataService")
	NotifyService = Knit.GetService("NotifyService")

	-- Studio never edits live crews (same rule as player data).
	store = DataStoreUtil.GetStore(if RunService:IsStudio() then STORE_NAME .. "_Studio" else STORE_NAME)
end

function CrewService:KnitStart()
	for name in actions do
		local signal = (CrewService.Client :: any)[name]
		signal:Connect(function(player: Player, ...: unknown)
			runAction(name, player, ...)
		end)
	end

	DataService:ObserveData(onDataLoaded)
	DataService.Releasing:Connect(function(player: Player)
		detach(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		detach(player)
		invites[player] = nil
		busy[player] = nil
		actionLimiter:Forget(player)
		inviteLimiter:Forget(player)
	end)

	task.spawn(function()
		local ok, problem = pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, onCrewChangedElsewhere)
		if not ok then
			warn(`[Crew] cross-server updates are off: {problem}`)
		end
	end)
end

return CrewService
