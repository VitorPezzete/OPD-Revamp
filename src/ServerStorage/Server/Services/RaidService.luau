--!strict
--[[
	Raid parties of the Legendary Hero (Marine Raid, Endless Raid).

	A raid is played in another place of the experience (RaidConfig.PlaceId). This place
	only does the lobby:

	1. LegendaryService validates the quest (requirements, cooldown, distance to the
	   merchant) and calls RaidService:CreateLobby. The owner is moved to the waiting
	   room and anchored there.
	2. The owner invites players of this server. An invite is remembered on the server
	   for RaidConfig.InviteLifetime seconds; only a player holding one can join, and
	   only if they meet the quest's requirements themselves.
	3. After RaidConfig.Countdown seconds, or when the owner starts early, the party is
	   teleported to a reserved server of the raid place. What that server believes
	   about the party (type, host, who is in it) is the ticket left for it in a
	   MemoryStore map; the teleport data the legacy place sent ({ VIPCode, Members,
	   Host, Type }) still travels along but is not trusted by anyone. No ticket, no
	   departure. The owner's cooldown (and the gem price of the Endless Raid) is
	   charged once the server is reserved and the ticket written, and given back if
	   the teleport call itself fails. A member whose own teleport fails is sent once
	   more, then released; the charge stays (a refund there would let a leader who
	   blocks its own teleport send a party for free, over and over).

	The client receives the whole lobby state on every change (Lobby signal, nil when it
	is no longer in one) and counts the seconds down itself from EndsAt.

	Not in this place: waves, raid bosses and completion rewards. RaidRunService runs
	them in the raid place (same codebase, PlaceConfig.Role == "Raid") and stores the
	outcome through RecordResult, which only touches the shared player data.

	Legacy problems fixed here (LegendaryHeroServer.RemoteEvent):
	- "Join" needed no invitation and its requirement check was an empty `if`: anyone
	  could put themselves into any party by sending the owner's name.
	- "Accept" started a 60 s server loop per call with nothing preventing a second
	  call, so one player could run several lobbies and reserve servers at will.
	- Endless gems were checked before the countdown and removed after it; the balance
	  could go negative. The cooldown was written before the teleport was even tried.
	- "Invite" could be fired without limit (each one cloned a GUI into the target) and
	  errored for anyone who did not own a lobby; "Kick" was sent by the client under a
	  name the server did not handle, so the owner could not remove anyone.
	- "Leave" indexed PlayerGui on a NumberValue and left the others anchored in the sky.
	- A member whose teleport failed stayed anchored in the waiting room for good.
]]
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local LegendaryConfig = require(ReplicatedStorage.Shared.Configs.LegendaryConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local RaidConfig = require(ServerStorage.Server.Configs.RaidConfig)

type CharacterEntity = CharacterEntity.CharacterEntity

type Lobby = {
	Quest: string,
	Owner: Player,
	-- Owner first.
	Members: { Player },
	-- Workspace:GetServerTimeNow() at which the party leaves.
	EndsAt: number,
	Launching: boolean,
	Closed: boolean,
}

type Invite = { Lobby: Lobby, ExpiresAt: number }

-- A member on its way to the raid server: what its teleport was sent with.
type Departure = { PlaceId: number, Options: TeleportOptions, Retried: boolean }

export type RaidResult = {
	Completed: boolean,
	-- Endless Raid: highest wave reached in that run.
	Wave: number?,
}

local LOBBY_STATUS = "RaidLobby"
local TICKET_ATTEMPTS = 2
local TICKET_RETRY = 1

-- Lobbies are gathered wherever raids are started from; the raid place itself has none.
local HAS_LOBBY = PlaceConfig.Role ~= "Raid"

local RaidService = Knit.CreateService({
	Name = "RaidService",
	Client = {
		-- Server -> client: lobby state, or nil when the player is no longer in one.
		-- { Quest, OwnerId, Members = { { UserId, Name } }, EndsAt, PartySize }
		Lobby = Knit.CreateSignal(),
		-- Server -> client: (ownerName, questName, lifetimeSeconds).
		Invited = Knit.CreateSignal(),

		-- Client -> server.
		Invite = Knit.CreateSignal(), -- (target: Player)
		Respond = Knit.CreateSignal(), -- (accept: boolean)
		Kick = Knit.CreateSignal(), -- (target: Player)
		Leave = Knit.CreateSignal(),
		Start = Knit.CreateSignal(),
	},
})

local CharacterService
local DataService
local NotifyService

local lobbies: { [Player]: Lobby } = {}
local invites: { [Player]: Invite } = {}
-- Per leader: until when (os.clock) each player it invited cannot be invited by it again.
local asked: { [Player]: { [Player]: number } } = {}
local departing: { [Player]: Departure } = {}
local inviteLimiter = RateLimiter.new(4, 0.5)
local actionLimiter = RateLimiter.new(5, 1)

local function describe(lobby: Lobby): { [string]: any }
	local members = table.create(#lobby.Members)
	for index, member in lobby.Members do
		members[index] = { UserId = member.UserId, Name = member.Name }
	end
	return {
		Quest = lobby.Quest,
		OwnerId = lobby.Owner.UserId,
		Members = members,
		EndsAt = lobby.EndsAt,
		PartySize = RaidConfig.PartySize,
	}
end

local function replicate(lobby: Lobby)
	local state = describe(lobby)
	for _, member in lobby.Members do
		RaidService.Client.Lobby:Fire(member, state)
	end
end

local function notifyAll(lobby: Lobby, text: string, kind: any)
	for _, member in lobby.Members do
		NotifyService:Send(member, text, kind)
	end
end

local function enterRoom(player: Player, index: number): boolean
	local entity: CharacterEntity? = CharacterService:GetPlayerEntity(player)
	if not entity or entity.Dead or not entity.Spawned then
		return false
	end

	local humanoid = entity.Humanoid
	if humanoid.SeatPart then
		humanoid.Sit = false
	end
	entity:SetStatus(LOBBY_STATUS, true)
	-- Nothing stands under the waiting room: the anchor is what holds the character.
	entity.Root.Anchored = true
	CharacterService:Teleport(entity, RaidConfig.LobbyCFrame * CFrame.new((index - 1) * RaidConfig.LobbySpacing, 0, 0))
	return true
end

local function leaveRoom(player: Player)
	local entity: CharacterEntity? = CharacterService:GetPlayerEntity(player)
	if not entity or not entity:HasStatus(LOBBY_STATUS) then
		return
	end
	entity:ClearStatus(LOBBY_STATUS)
	entity.Root.Anchored = false
	CharacterService:Teleport(entity, RaidConfig.ReturnCFrame)
end

-- Takes one member out. `sendBack` is false when the character is already gone.
local function removeMember(lobby: Lobby, player: Player, sendBack: boolean)
	local index = table.find(lobby.Members, player)
	if not index then
		return
	end
	table.remove(lobby.Members, index)
	lobbies[player] = nil
	if sendBack then
		leaveRoom(player)
	end
	if player.Parent == Players then
		RaidService.Client.Lobby:Fire(player, nil)
	end
end

local function disband(lobby: Lobby, sendBack: boolean)
	if lobby.Closed then
		return
	end
	lobby.Closed = true
	for _, member in table.clone(lobby.Members) do
		removeMember(lobby, member, sendBack)
	end
	for invitee, invite in invites do
		if invite.Lobby == lobby then
			invites[invitee] = nil
		end
	end
end

local function leave(player: Player, sendBack: boolean)
	local lobby = lobbies[player]
	if not lobby or lobby.Closed then
		return
	end

	if lobby.Owner == player then
		-- The party does not outlive its owner.
		for _, member in lobby.Members do
			if member ~= player then
				NotifyService:Send(member, "The raid party was disbanded.", "Info")
			end
		end
		removeMember(lobby, player, sendBack)
		disband(lobby, true)
	else
		removeMember(lobby, player, sendBack)
		replicate(lobby)
	end
end

--[[
	A launching lobby no longer listens to leavers, and launching yields (reserving the
	server, writing the ticket): whoever left the game meanwhile was still on the ticket
	and in the list given to TeleportAsync, so one member quitting at the right moment
	failed the departure of the whole party. Returns false when the leader is the one
	who left: the lobby is disbanded.
]]
local function dropAbsent(lobby: Lobby): boolean
	for index = #lobby.Members, 1, -1 do
		local member = lobby.Members[index]
		if member.Parent ~= Players then
			table.remove(lobby.Members, index)
			lobbies[member] = nil
		end
	end
	if lobby.Owner.Parent ~= Players then
		notifyAll(lobby, "The raid party was disbanded.", "Info")
		disband(lobby, true)
		return false
	end
	return true
end

-- A departing member that will not make it: back on the ground, lobby screen closed.
local function release(player: Player)
	departing[player] = nil
	if player.Parent ~= Players then
		return
	end
	leaveRoom(player)
	RaidService.Client.Lobby:Fire(player, nil)
	NotifyService:Send(player, "Your teleport to the raid failed.", "Error")
end

local function launch(lobby: Lobby)
	if lobby.Launching or lobby.Closed then
		return
	end
	lobby.Launching = true

	local owner = lobby.Owner
	local quest = LegendaryConfig.Quests[lobby.Quest]
	local placeId = RaidConfig.PlaceId

	-- TeleportService does nothing useful in Studio, and the raid place may not exist
	-- in a copy of the experience: say so and put everyone back instead of erroring.
	if RunService:IsStudio() or placeId == 0 then
		notifyAll(lobby, "Raids are played in another place and cannot start from here (Studio or no raid place set).", "Error")
		disband(lobby, true)
		return
	end

	-- Before a server is reserved, not only after: a leader whose gems went elsewhere
	-- during the countdown would reserve one (and write a ticket) per attempt for nothing.
	local price = quest.GemCost or 0
	local data = DataService:GetData(owner)
	if not data or (price > 0 and data.Data.Economy.Gems < price) then
		notifyAll(lobby, "The party leader cannot pay for this raid.", "Error")
		disband(lobby, true)
		return
	end

	local reserved, code, serverId = pcall(function()
		return TeleportService:ReserveServerAsync(placeId)
	end)
	if lobby.Closed then
		return
	end
	if not reserved or type(code) ~= "string" or type(serverId) ~= "string" or serverId == "" then
		warn(`[RaidService] could not reserve a server of place {placeId}: {code}`)
		notifyAll(lobby, "The raid could not be started. Try again later.", "Error")
		disband(lobby, true)
		return
	end
	if not dropAbsent(lobby) then
		return
	end

	--[[
		What the raid server believes about this party (RaidRunService reads it back by
		its own PrivateServerId), and the only thing it believes: the teleport data goes
		through the clients. So a party is not sent without it, and nothing has been
		charged yet when it cannot be written.
	]]
	local party = table.create(#lobby.Members)
	for index, member in lobby.Members do
		party[index] = member.UserId
	end
	local ticketed: boolean, ticketProblem: any = false, nil
	for attempt = 1, TICKET_ATTEMPTS do
		ticketed, ticketProblem = pcall(function()
			MemoryStoreService:GetHashMap(RaidConfig.TicketMap):SetAsync(
				serverId,
				{ Type = RaidConfig.TeleportType[lobby.Quest], Host = owner.UserId, Party = party },
				RaidConfig.TicketLifetime
			)
		end)
		if ticketed or lobby.Closed then
			break
		end
		warn(`[RaidService] could not write the raid ticket ({attempt}/{TICKET_ATTEMPTS}): {ticketProblem}`)
		if attempt < TICKET_ATTEMPTS then
			task.wait(TICKET_RETRY)
		end
	end
	if lobby.Closed then
		return
	end
	if not ticketed then
		notifyAll(lobby, "The raid could not be started. Try again later.", "Error")
		disband(lobby, true)
		return
	end
	if not dropAbsent(lobby) then
		return
	end

	data = DataService:GetData(owner)
	if not data then
		disband(lobby, true)
		return
	end

	if price > 0 and not data:TrySpend("Economy.Gems", price) then
		notifyAll(lobby, "The party leader cannot pay for this raid.", "Error")
		disband(lobby, true)
		return
	end
	local previousCooldown = data:Get(quest.CooldownPath)
	data:Set(quest.CooldownPath, os.time() + quest.Cooldown)

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({
		VIPCode = code,
		Members = #lobby.Members,
		Host = owner.UserId,
		Type = RaidConfig.TeleportType[lobby.Quest],
	})

	local teleported, problem = pcall(function()
		TeleportService:TeleportAsync(placeId, lobby.Members, options)
	end)
	if not teleported then
		warn(`[RaidService] teleport to place {placeId} failed: {problem}`)
		if data:IsActive() then
			data:Set(quest.CooldownPath, previousCooldown)
			if price > 0 then
				data:Increment("Economy.Gems", price)
			end
		end
		notifyAll(lobby, "The raid could not be started. Try again later.", "Error")
		disband(lobby, true)
		return
	end

	-- The party is on its way: forget the lobby without walking anyone back. A member
	-- whose own teleport fails is sent again, then released, by the TeleportInitFailed
	-- handler.
	lobby.Closed = true
	local departure: Departure = { PlaceId = placeId, Options = options, Retried = false }
	local party = table.clone(lobby.Members)
	for _, member in party do
		lobbies[member] = nil
		departing[member] = table.clone(departure)
	end
	-- A teleport can also just never happen, with no failure reported (a client can see
	-- to that): such a member stayed anchored in the waiting room for good.
	task.delay(RaidConfig.DepartureTimeout, function()
		for _, member in party do
			local pending = departing[member]
			if pending and pending.Options == options then
				release(member)
			end
		end
	end)
end

-- The teleport of one departing member did not go through: once more, then let it walk.
local function onTeleportFailed(player: Player)
	local departure = departing[player]
	-- Only a departure: this used to release anyone standing in a waiting room, also a
	-- member of a lobby still counting down whose unrelated teleport had failed. That
	-- member walked free while still in the party.
	if not departure then
		return
	end
	if departure.Retried then
		release(player)
		return
	end
	departure.Retried = true
	task.delay(RaidConfig.TeleportRetry, function()
		if departing[player] ~= departure or player.Parent ~= Players then
			return
		end
		local ok, problem = pcall(function()
			TeleportService:TeleportAsync(departure.PlaceId, { player }, departure.Options)
		end)
		if not ok then
			warn(`[RaidService] second teleport of {player.Name} failed: {problem}`)
			release(player)
		end
	end)
end

local function canJoin(player: Player, questName: string): boolean
	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not data or not entity or entity.Dead or not entity.Spawned then
		return false
	end
	return LegendaryConfig.MeetsRequirements(questName, function(path: string)
		return data:Get(path)
	end)
end

local function asPlayer(value: unknown): Player?
	if typeof(value) == "Instance" and (value :: Instance):IsA("Player") and (value :: Instance).Parent == Players then
		return value :: Player
	end
	return nil
end

local function onInvite(player: Player, target: unknown)
	local lobby = lobbies[player]
	local invitee = asPlayer(target)
	if not lobby or lobby.Owner ~= player or lobby.Launching or not invitee or invitee == player then
		return
	end
	if not inviteLimiter:Consume(player) then
		return
	end
	if #lobby.Members >= RaidConfig.PartySize then
		NotifyService:Send(player, "The party is full.", "Error")
		return
	end
	if lobbies[invitee] or departing[invitee] then
		NotifyService:Send(player, `{invitee.Name} is already in a raid party.`, "Error")
		return
	end
	if not canJoin(invitee, lobby.Quest) then
		NotifyService:Send(player, `{invitee.Name} does not meet the requirements of this raid.`, "Error")
		return
	end

	--[[
		One prompt at a time per player, and one per leader every RaidConfig.InviteRepeat
		seconds whatever the answer was. A newer invite used to replace the pending one:
		a leader could keep a prompt on a victim's screen for as long as it liked (decline,
		prompt, decline, prompt; a new lobby costs nothing) and wipe the invitation a
		friend had just sent to that player.
	]]
	local now = os.clock()
	local pending = invites[invitee]
	if pending and now < pending.ExpiresAt and not pending.Lobby.Closed then
		NotifyService:Send(player, `{invitee.Name} has an invitation to answer first.`, "Error")
		return
	end
	local sent = asked[player]
	if not sent then
		sent = {}
		asked[player] = sent
	end
	if now < (sent[invitee] or 0) then
		NotifyService:Send(player, `You invited {invitee.Name} a moment ago.`, "Error")
		return
	end
	sent[invitee] = now + RaidConfig.InviteRepeat

	invites[invitee] = { Lobby = lobby, ExpiresAt = now + RaidConfig.InviteLifetime }
	RaidService.Client.Invited:Fire(invitee, player.Name, lobby.Quest, RaidConfig.InviteLifetime)
end

local function onRespond(player: Player, accept: unknown)
	local invite = invites[player]
	invites[player] = nil
	if not invite or accept ~= true or not actionLimiter:Consume(player) then
		return
	end

	local lobby = invite.Lobby
	if os.clock() > invite.ExpiresAt or lobby.Closed or lobby.Launching then
		NotifyService:Send(player, "That invitation is no longer valid.", "Error")
		return
	end
	-- `departing`: still here while the teleport of a launched party is in flight.
	if lobbies[player] or departing[player] or #lobby.Members >= RaidConfig.PartySize or not canJoin(player, lobby.Quest) then
		return
	end

	table.insert(lobby.Members, player)
	if not enterRoom(player, #lobby.Members) then
		table.remove(lobby.Members)
		return
	end
	lobbies[player] = lobby
	replicate(lobby)
end

local function onKick(player: Player, target: unknown)
	local lobby = lobbies[player]
	local member = asPlayer(target)
	if not lobby or lobby.Owner ~= player or lobby.Launching or not member or member == player then
		return
	end
	if not actionLimiter:Consume(player) or lobbies[member] ~= lobby then
		return
	end

	removeMember(lobby, member, true)
	NotifyService:Send(member, "You were removed from the raid party.", "Info")
	replicate(lobby)
end

function RaidService:IsInLobby(player: Player): boolean
	return lobbies[player] ~= nil or departing[player] ~= nil
end

--[[
	Opens a lobby owned by `player`. The caller (LegendaryService) has already validated
	the quest; this only refuses a player who is already in a party or has no character.
]]
function RaidService:CreateLobby(player: Player, questName: string): boolean
	local quest = LegendaryConfig.Quests[questName]
	if not quest or not quest.Raid or lobbies[player] or departing[player] then
		return false
	end

	local lobby: Lobby = {
		Quest = questName,
		Owner = player,
		Members = { player },
		EndsAt = Workspace:GetServerTimeNow() + RaidConfig.Countdown,
		Launching = false,
		Closed = false,
	}
	if not enterRoom(player, 1) then
		return false
	end

	lobbies[player] = lobby
	invites[player] = nil
	replicate(lobby)
	-- One timer per lobby, not a loop: clients count down from EndsAt.
	task.delay(RaidConfig.Countdown, launch, lobby)
	return true
end

--[[
	Stores the outcome of a raid for one player: Bosses.<Raid>.Completed counts finished
	runs and Bosses.EndlessRaid.Max keeps the best wave. Server-only: meant for the code
	that runs the raid (in the raid place, which shares this data store).
]]
function RaidService:RecordResult(player: Player, questName: string, result: RaidResult)
	local key = RaidConfig.DataKey[questName]
	local data = DataService:GetData(player)
	if not key or not data then
		return
	end

	if result.Completed and type(data:Get(`Bosses.{key}.Completed`)) == "number" then
		data:Increment(`Bosses.{key}.Completed`, 1)
	end
	local wave = result.Wave
	local best = data:Get(`Bosses.{key}.Max`)
	if type(wave) == "number" and wave == wave and type(best) == "number" and wave > best then
		data:Set(`Bosses.{key}.Max`, math.floor(wave))
	end
end

function RaidService:KnitInit()
	CharacterService = Knit.GetService("CharacterService")
	DataService = Knit.GetService("DataService")
	NotifyService = Knit.GetService("NotifyService")
end

function RaidService:KnitStart()
	-- The raid place only uses RecordResult: no lobby is ever made there.
	if not HAS_LOBBY then
		return
	end

	RaidService.Client.Invite:Connect(onInvite)
	RaidService.Client.Respond:Connect(onRespond)
	RaidService.Client.Kick:Connect(onKick)

	RaidService.Client.Leave:Connect(function(player: Player)
		local lobby = lobbies[player]
		if lobby and not lobby.Launching and actionLimiter:Consume(player) then
			leave(player, true)
		end
	end)

	RaidService.Client.Start:Connect(function(player: Player)
		local lobby = lobbies[player]
		if lobby and lobby.Owner == player and actionLimiter:Consume(player) then
			launch(lobby)
		end
	end)

	-- A character that is removed (reset, death) cannot stay in the waiting room.
	CharacterService.EntityRemoving:Connect(function(entity: CharacterEntity)
		local player = entity.Player
		local lobby = player and lobbies[player]
		if player and lobby and not lobby.Launching then
			leave(player, false)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		inviteLimiter:Forget(player)
		actionLimiter:Forget(player)
		invites[player] = nil
		departing[player] = nil
		asked[player] = nil
		for _, sent in asked do
			sent[player] = nil
		end
		local lobby = lobbies[player]
		if lobby and not lobby.Launching then
			leave(player, false)
		end
		lobbies[player] = nil
	end)

	TeleportService.TeleportInitFailed:Connect(onTeleportFailed)
end

-- Knit turns what is in Client into remotes when it starts: taken out before that, the
-- lobby requests (invite, start, kick...) do not exist in the raid place at all.
if not HAS_LOBBY then
	local client: { [string]: any } = RaidService.Client :: any
	for name in client do
		if name ~= "Server" then
			client[name] = nil
		end
	end
end

return RaidService
