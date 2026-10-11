--!strict
--[[
	Runs a raid in the raid place (PlaceConfig.Role == "Raid"). Everywhere else this
	service is loaded and does nothing.

	A raid server is a reserved server the main place sent a party to (RaidService there).
	From the first arrival on:

	1. Admission. Who may be here and which raid this is comes from the ticket the main
	   place left in a MemoryStore map under this server's PrivateServerId: type, host and
	   the user ids of the party. The teleport data is never believed: it travels through
	   the clients, and a party member could name itself host (the gems) or turn a free
	   Marine raid into an Endless one. Without a ticket nobody is admitted (RaidService
	   does not send a party it could not write a ticket for). Anyone not on the ticket,
	   and everyone in a server that is not reserved, is sent back to the main place.
	2. Waiting. The party has RaidRunConfig.PartyTimeout seconds to load in; the raid
	   starts as soon as everyone is there. Nobody has a body before that.
	3. Waves. One thread walks the waves (RaidRunConfig.Raids): marines of a level that
	   grows with the wave, a boss on the boss waves (players are healed first), the next
	   wave when nothing is left standing. Enemies are EnemyService:SpawnEvent spawns.
	4. A player who dies is out: back to the main place. When the last wave falls, or the
	   server reaches its lifetime, everyone goes home.

	Rewards are paid by this server at the moment they are earned, to the members still
	in the raid: boss exp / gems / drops when the boss dies, the best Endless wave when
	the wave is cleared, the Marine completion after its last wave. A player who left or
	died gets nothing further. There is no remote: the client only reads the Workspace
	attributes of RaidStateConfig.

	Studio (no teleport, no join data): every player is admitted and the raid is the one
	named by the Workspace attribute "RaidType" ("Marine" / "Endless", default Endless).
	A dead player is put back on the raid spawn instead of being teleported.

	Legacy problems fixed (place "Raids": JoinRaid, RaidsHandler)
	- Type, host and party size were read from the teleport data of whoever joined last,
	  unchecked: a client could name itself host (the gems) or pick the raid.
	- Rewards went to every player in the server, and a public server of the place ran a
	  raid for anybody after 30 s.
	- A wave whose enemies fell out of the map never ended; the wave was polled per
	  enemy folder child. A boss wave with a missing model errored the whole script.
	- The lifetime script kicked in an endless loop without yielding.
]]
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local RaidStateConfig = require(ReplicatedStorage.Shared.Configs.RaidStateConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Allies = require(ServerStorage.Server.Modules.Allies)
local BossConfig = require(ServerStorage.Server.Configs.BossConfig)
local EnemyConfig = require(ServerStorage.Server.Configs.EnemyConfig)
local RaidConfig = require(ServerStorage.Server.Configs.RaidConfig)
local RaidRunConfig = require(ServerStorage.Server.Configs.RaidRunConfig)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity
type RaidType = RaidRunConfig.RaidType
type RaidDefinition = RaidRunConfig.RaidDefinition

type Session = {
	Type: RaidType,
	-- User id of the party leader.
	Host: number,
	-- Players the raid waits for.
	Expected: number,
	-- User ids let in (from the ticket). Nil in Studio only, where everyone is.
	Party: { [number]: boolean }?,
}

local ATTRIBUTES = RaidStateConfig.Attributes
local IS_RAID = PlaceConfig.Role == "Raid"
local IS_STUDIO = RunService:IsStudio()

local TICKET_ATTEMPTS = 5
local TICKET_RETRY = 2
-- Rolls for a free marine level before a duplicate is accepted.
local LEVEL_TRIES = 20
-- Teleports home one player is given (a failed one is tried again HOME_RETRY seconds
-- later, never in a loop), and when a player who is still here after all is removed.
local HOME_ATTEMPTS = 3
local HOME_RETRY = 5
local HOME_KICK_DELAY = 20
local HOME_MESSAGE = "You were returned to the main game."
-- Where a stalled enemy is put, relative to a member (RaidRunConfig.StallTimeout).
local REGROUP_RADIUS = 15
local REGROUP_HEIGHT = 5

local RaidRunService = Knit.CreateService({
	Name = "RaidRunService",
	Client = {},
})

local CharacterService
local CombatService
local DataService
local EnemyService
local HakiService
local NotifyService
local RaidService
local StatService
local WeaponUnlockService

local random = Random.new()

local session: Session? = nil
-- The ticket is read once per server; arrivals meanwhile wait for the answer.
local ticketRead = false
local ticketReading = false

-- Admitted players still in the raid, with the damage each has dealt to its enemies.
local members: { [Player]: number } = {}
-- Since when (os.clock) a member has had no body, while the raid runs.
local bodiless: { [Player]: number } = {}
-- Players already on their way to the main place, with the teleports each was given.
local leaving: { [Player]: number } = {}
-- os.clock() of the last time a member hurt a raid enemy.
local lastProgress = 0
local started = false
local nextSlot = 0
-- No raid any more (finished, retired, emptied): arrivals are turned away.
local closed = false
local runThread: thread? = nil
local timeoutThread: thread? = nil

-- Living raid enemies and the marine level each holds (0 for a boss).
local alive: { [CharacterEntity]: number } = {}
local usedLevels: { [number]: boolean } = {}

local function setPhase(phase: RaidStateConfig.Phase)
	Workspace:SetAttribute(ATTRIBUTES.Phase, phase)
end

local function countMembers(): number
	local count = 0
	for _ in members do
		count += 1
	end
	return count
end

local function publishParty()
	local current = session
	Workspace:SetAttribute(ATTRIBUTES.Arrived, countMembers())
	Workspace:SetAttribute(ATTRIBUTES.Expected, if current then current.Expected else 0)
end

-- Drops the enemies that died or left the world (a marine pushed off the map never
-- fires Died) and frees their levels. Returns how many are left.
local function countAlive(): number
	local count = 0
	for entity, level in alive do
		if entity.Dead or entity.Model.Parent == nil or entity.Root.Parent == nil then
			-- The void takes the parts and leaves the model: such an enemy can no longer
			-- be hit and would hold its wave until the server retires.
			if not entity.Dead and entity.Model.Parent ~= nil then
				EnemyService:Despawn(entity)
			end
			alive[entity] = nil
			usedLevels[level] = nil
		else
			count += 1
		end
	end
	return count
end

local function publishEnemies(): number
	local count = countAlive()
	Workspace:SetAttribute(ATTRIBUTES.Enemies, count)
	return count
end

-- Yields. A call that fails as a whole is tried again a few seconds later, a bounded
-- number of times; whoever is still here in the end is removed by sendHome's timer.
local function teleportHome(list: { Player })
	for attempt = 1, HOME_ATTEMPTS do
		local present: { Player } = {}
		for _, player in list do
			if player.Parent == Players then
				table.insert(present, player)
			end
		end
		if #present == 0 then
			return
		end
		local ok, problem = pcall(TeleportService.TeleportAsync, TeleportService, RaidConfig.ReturnPlaceId, present)
		if ok then
			return
		end
		warn(`[RaidRunService] teleport to the main place failed ({attempt}/{HOME_ATTEMPTS}): {problem}`)
		if attempt < HOME_ATTEMPTS then
			task.wait(HOME_RETRY)
		end
	end
end

--[[
	Back to the main place. Never yields. In Studio there is nowhere to go: the players
	only read the message. A player is only sent once: the end of the raid used to
	teleport (and schedule a kick for) those a death was already taking home.
]]
local function sendHome(list: { Player }, message: string?)
	if message then
		for _, player in list do
			NotifyService:Send(player, message, "Info")
		end
	end
	if IS_STUDIO then
		return
	end

	local going: { Player } = {}
	for _, player in list do
		if leaving[player] == nil and player.Parent == Players then
			leaving[player] = 1
			table.insert(going, player)
		end
	end
	if #going == 0 then
		return
	end

	task.spawn(teleportHome, going)
	task.delay(HOME_KICK_DELAY, function()
		for _, player in going do
			if player.Parent == Players then
				player:Kick(HOME_MESSAGE)
			end
		end
	end)
end

-- The teleport of one player did not go through: once more, a few seconds later.
local function onTeleportFailed(player: Player)
	local attempts = leaving[player]
	if not attempts or attempts >= HOME_ATTEMPTS then
		return
	end
	leaving[player] = attempts + 1
	task.delay(HOME_RETRY, teleportHome, { player })
end

local function isRaidType(value: unknown): boolean
	return type(value) == "string" and RaidRunConfig.Raids[value :: RaidType] ~= nil
end

local function isUserId(value: unknown): boolean
	return type(value) == "number" and value == value and value > 0 and value % 1 == 0
end

-- The ticket RaidService wrote for this reserved server, nil when there is none.
local function readTicket(): Session?
	local map = MemoryStoreService:GetHashMap(RaidConfig.TicketMap)
	for attempt = 1, TICKET_ATTEMPTS do
		local ok, ticket: any = pcall(map.GetAsync, map, game.PrivateServerId)
		if ok then
			if type(ticket) ~= "table" or not isRaidType(ticket.Type) or not isUserId(ticket.Host) or type(ticket.Party) ~= "table" then
				return nil
			end
			local party: { [number]: boolean } = {}
			local size = 0
			for _, userId in ticket.Party do
				if isUserId(userId) and not party[userId] and size < RaidConfig.PartySize then
					party[userId] = true
					size += 1
				end
			end
			if size == 0 then
				return nil
			end
			return { Type = ticket.Type, Host = ticket.Host, Expected = size, Party = party }
		end
		warn(`[RaidRunService] raid ticket read failed ({attempt}/{TICKET_ATTEMPTS}): {ticket}`)
		if attempt < TICKET_ATTEMPTS then
			task.wait(TICKET_RETRY)
		end
	end
	return nil
end

-- Whether this player belongs to the raid of this server. Yields on the first call.
local function admit(player: Player): boolean
	if closed then
		return false
	end

	if IS_STUDIO then
		if not session then
			local wanted = Workspace:GetAttribute(RaidRunConfig.StudioTypeAttribute)
			session = {
				Type = if isRaidType(wanted) then wanted :: RaidType else RaidRunConfig.StudioType,
				Host = player.UserId,
				Expected = 1,
				Party = nil,
			}
		end
		return true
	end

	-- A raid only exists in a server reserved for it.
	if game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 then
		return false
	end
	local joinData = player:GetJoinData()
	if joinData.SourceGameId ~= game.GameId or joinData.SourcePlaceId ~= RaidConfig.ReturnPlaceId then
		return false
	end

	while ticketReading do
		task.wait(0.2)
	end
	if not ticketRead then
		ticketReading = true
		-- An error in here must not leave ticketReading set: every later arrival would
		-- wait on it for good.
		local ok, ticket: any = pcall(readTicket)
		session = if ok then ticket else nil
		ticketRead = true
		ticketReading = false
		if not session then
			local reason = if ok then "none stored" else tostring(ticket)
			warn(`[RaidRunService] no usable raid ticket for server "{game.PrivateServerId}" ({reason}): nobody is admitted`)
		end
	end
	if player.Parent ~= Players or closed then
		return false
	end

	--[[
		Only the ticket lets anyone in. This used to fall back to the teleport data when
		there was none, the first arrival's describing the raid: a party member who sends
		forged data on every trip (it costs nothing, a ticket overrides it) was host, or
		in an Endless raid nobody paid for, whenever MemoryStore hiccupped.
	]]
	local current = session
	return current ~= nil and current.Party ~= nil and current.Party[player.UserId] == true
end

local function spawnMember(player: Player)
	-- Side by side on the spawn, one slot after the other.
	local slot = nextSlot
	nextSlot = (nextSlot + 1) % RaidConfig.PartySize
	local position = RaidRunConfig.PlayerSpawn + Vector3.new(slot * RaidRunConfig.PlayerSpacing, 0, 0)
	task.spawn(function()
		CharacterService:SpawnAt(player, CFrame.new(position))
	end)
end

-- Full health and a full haki bar for everyone still fighting (before a boss).
local function healMembers()
	for player in members do
		local entity: CharacterEntity? = CharacterService:GetPlayerEntity(player)
		if entity and not entity.Dead then
			entity:Heal(entity.MaxHealth)
			local bar, max = HakiService:GetBar(entity)
			if max > bar then
				HakiService:AddBar(entity, max - bar)
			end
		end
	end
end

local function track(entity: CharacterEntity, level: number)
	alive[entity] = level
	entity.Died:Once(publishEnemies)
end

local function randomEnemyPosition(): Vector3
	local areas = RaidRunConfig.EnemyAreas
	local area = areas[random:NextInteger(1, #areas)]
	local from, to = area[1], area[2]
	-- Each axis on its own: anywhere in the box, not on its diagonal.
	return Vector3.new(
		from.X + (to.X - from.X) * random:NextNumber(),
		from.Y + (to.Y - from.Y) * random:NextNumber(),
		from.Z + (to.Z - from.Z) * random:NextNumber()
	)
end

local function rollLevel(wave: number): number
	local bonus = RaidRunConfig.LevelPerWave * wave
	local level = random:NextInteger(RaidRunConfig.Level.Min, RaidRunConfig.Level.Max) + bonus
	local tries = 0
	while usedLevels[level] and tries < LEVEL_TRIES do
		level = random:NextInteger(RaidRunConfig.LevelRetry.Min, RaidRunConfig.LevelRetry.Max) + bonus
		tries += 1
	end
	return level
end

local function spawnMarine(templateName: string, wave: number): boolean
	local level = rollLevel(wave)
	local entity: CharacterEntity? = EnemyService:SpawnEvent(templateName, CFrame.new(randomEnemyPosition()), {
		Name = `Lv{level} {templateName}`,
		Levels = { Defense = level * ((RaidRunConfig.DefenseFactor :: { [string]: number })[templateName] or 1) },
	})
	if not entity then
		return false
	end
	usedLevels[level] = true
	track(entity, level)
	return true
end

-- Returns how many marines actually appeared.
local function spawnMarines(amount: number, wave: number): number
	local spawned = 0
	for index = 1, amount do
		if index % 2 == 0 and spawnMarine(RaidRunConfig.Gunner, wave) then
			spawned += 1
		end
		if spawnMarine(RaidRunConfig.Sword, wave) then
			spawned += 1
		end
		publishEnemies()
		task.wait(random:NextNumber(RaidRunConfig.SpawnGap.Min, RaidRunConfig.SpawnGap.Max))
	end
	return spawned
end

local function topDamageDealer(): Player?
	local best: Player? = nil
	local bestDamage = 0
	for player, damage in members do
		if damage > bestDamage then
			best, bestDamage = player, damage
		end
	end
	return best
end

local function rollDrops(player: Player, bossName: string, lucky: boolean)
	local drops = RaidRunConfig.Drops[bossName]
	local data = DataService:GetData(player)
	if not drops or not data then
		return
	end

	for _, drop in drops do
		local chance = drop.Chance * (if lucky then RaidRunConfig.TopDamageFactor else 1)
		if random:NextNumber() >= chance then
			continue
		end
		if drop.Kind == "Weapon" then
			-- Refuses (and stays silent) when the weapon is already owned.
			if WeaponUnlockService:Unlock(player, drop.Item) then
				NotifyService:Send(player, `The boss dropped {drop.Item}!`, "Success")
			end
		elseif data:Get(`Appearance.OwnedAccessories.{drop.Item}`) ~= true then
			data:Set(`Appearance.OwnedAccessories.{drop.Item}`, true)
			NotifyService:Send(player, `The boss dropped {drop.Item}!`, "Success")
		end
	end
end

-- Paid when the boss dies, to whoever is in the raid at that moment.
local function rewardBoss(current: Session, definition: RaidDefinition, bossName: string)
	local reward = definition.BossReward(bossName)
	local top = topDamageDealer()
	for player in members do
		local data = DataService:GetData(player)
		if not data then
			continue
		end

		local isHost = player.UserId == current.Host
		StatService:AddExp(player, "Expertise", reward.Expertise + (if isHost then reward.HostExpertise else 0))
		if isHost and reward.HostGems > 0 then
			data:Increment("Economy.Gems", reward.HostGems)
		end
		rollDrops(player, bossName, player == top)
	end
end

-- A boss needs its EnemyConfig entry, its BossConfig entry and the behaviour that names.
local function spawnBoss(current: Session, definition: RaidDefinition, bossName: string, wave: number): boolean
	local boss = BossConfig.Bosses[bossName]
	local behaviours = ServerStorage.Server.Modules:FindFirstChild("Bosses")
	if not boss or not EnemyConfig[bossName] or not behaviours or not behaviours:FindFirstChild(boss.Behaviour) then
		warn(`[RaidRunService] wave {wave}: boss "{bossName}" is not available (EnemyConfig, BossConfig or behaviour module missing), wave skipped`)
		return false
	end

	local defense = definition.BossDefense(bossName, wave)
	local entity: CharacterEntity? = EnemyService:SpawnEvent(
		bossName,
		CFrame.new(RaidRunConfig.BossSpawn),
		if defense then { Levels = { Defense = defense } } else nil
	)
	if not entity then
		warn(`[RaidRunService] wave {wave}: boss "{bossName}" has no model in Assets.Models.Bosses, wave skipped`)
		return false
	end

	track(entity, 0)
	entity.Died:Once(function()
		rewardBoss(current, definition, bossName)
	end)
	publishEnemies()
	return true
end

-- A cleared wave is stored right away (best Endless wave); the last one may complete the raid.
local function recordWave(definition: RaidDefinition, wave: number)
	local completed = wave == definition.Waves and definition.CountsCompletion
	for player in members do
		RaidService:RecordResult(player, definition.Quest, { Completed = completed, Wave = wave })
	end
end

local function despawnEnemies()
	for entity in alive do
		EnemyService:Despawn(entity)
	end
	table.clear(alive)
	table.clear(usedLevels)
	Workspace:SetAttribute(ATTRIBUTES.Enemies, 0)
end

-- Nothing of the raid runs after this: phase, threads, enemies. Arrivals are turned away.
local function stop()
	closed = true
	setPhase("Ended")

	local running = coroutine.running()
	local thread = runThread
	runThread = nil
	if thread and thread ~= running then
		task.cancel(thread)
	end
	local timeout = timeoutThread
	timeoutThread = nil
	if timeout and timeout ~= running then
		task.cancel(timeout)
	end
	despawnEnemies()
end

-- Ends the raid for everyone: phase, enemies, the trip home, then the stragglers.
local function close(message: string)
	if closed then
		return
	end
	stop()

	for _, player in Players:GetPlayers() do
		NotifyService:Send(player, message, "Announcement")
	end
	task.delay(RaidRunConfig.EndDelay, function()
		table.clear(members)
		sendHome(Players:GetPlayers())
	end)
end

--[[
	Takes a member out of the raid (death, lost body) and sends it home. A started raid
	with no member left is over: it used to keep spawning waves for as long as anybody,
	even a refused player waiting for its teleport, was still in the server.
]]
local function removeMember(player: Player, message: string?)
	if members[player] == nil then
		return
	end
	members[player] = nil
	bodiless[player] = nil
	publishParty()
	if message and player.Parent == Players then
		sendHome({ player }, message)
	end
	if started and not closed and next(members) == nil then
		stop()
	end
end

--[[
	A member can be left without a body and without having died: LoadCharacter failed,
	the character never got its entity, or it was destroyed. RequestSpawn is refused in
	this place, so nothing would bring it back: the player stayed a member that cannot
	be killed and, alone, held the wave until the server retired. After
	RaidRunConfig.BodyTimeout seconds such a member is out (Studio: spawned again).
]]
local function checkBodies()
	local now = os.clock()
	for player in members do
		if CharacterService:GetPlayerEntity(player) then
			bodiless[player] = nil
			continue
		end
		local since = bodiless[player]
		if not since then
			bodiless[player] = now
		elseif now - since >= RaidRunConfig.BodyTimeout then
			bodiless[player] = nil
			if IS_STUDIO then
				spawnMember(player)
			else
				removeMember(player, "Your character was lost: the raid is over for you.")
			end
		end
	end
end

--[[
	Enemies no member has hurt for RaidRunConfig.StallTimeout seconds are out of reach
	(under the map, in the sea, behind a wall): the wave would never end. They are put
	next to a member. Moved, not removed: hiding from a wave must not clear it.
]]
local function regroupEnemies()
	local now = os.clock()
	if now - lastProgress < RaidRunConfig.StallTimeout then
		return
	end
	lastProgress = now

	local targets: { Vector3 } = {}
	for player in members do
		local entity: CharacterEntity? = CharacterService:GetPlayerEntity(player)
		if entity and not entity.Dead then
			table.insert(targets, entity.Root.Position)
		end
	end
	if #targets == 0 then
		return
	end
	for entity in alive do
		if not entity.Dead then
			local target = targets[random:NextInteger(1, #targets)]
			local offset = Vector3.new(
				random:NextNumber(-REGROUP_RADIUS, REGROUP_RADIUS),
				REGROUP_HEIGHT,
				random:NextNumber(-REGROUP_RADIUS, REGROUP_RADIUS)
			)
			CharacterService:Teleport(entity, CFrame.new(target + offset))
		end
	end
end

-- The one loop of a raid. Only ever waits in task.wait, so task.cancel stops it cleanly.
local function run(current: Session)
	local definition = RaidRunConfig.Raids[current.Type]
	task.wait(RaidRunConfig.StartDelay)

	for wave = 1, definition.Waves do
		Workspace:SetAttribute(ATTRIBUTES.Wave, wave)
		if definition.SpawnDelay > 0 then
			task.wait(definition.SpawnDelay)
		end

		local bossName = definition.Boss(wave, random)
		local fought: boolean
		if bossName then
			fought = spawnBoss(current, definition, bossName, wave)
			if fought then
				healMembers()
			end
		else
			fought = spawnMarines(definition.Enemies(wave), wave) > 0
			if not fought then
				-- Without marines every wave would "clear" at once and pay for nothing.
				warn(`[RaidRunService] no "{RaidRunConfig.Sword}" / "{RaidRunConfig.Gunner}" could be spawned: the raid is cancelled`)
				close("The raid could not be started.")
				return
			end
		end

		if fought then
			lastProgress = os.clock()
			repeat
				task.wait(RaidRunConfig.ClearCheck)
				checkBodies()
				if closed then
					-- The last member was just taken out.
					return
				end
				regroupEnemies()
			until publishEnemies() == 0
			recordWave(definition, wave)
		end
		task.wait(RaidRunConfig.WaveRest)
	end

	close("Raid complete!")
end

local function begin()
	local current = session
	if started or closed or not current then
		return
	end
	if timeoutThread and timeoutThread ~= coroutine.running() then
		task.cancel(timeoutThread)
	end
	timeoutThread = nil
	-- Everyone who had arrived left again: a raid for nobody is not started (it spawned
	-- its waves into an empty map), the next arrival waits for the party anew.
	if next(members) == nil then
		return
	end
	started = true

	setPhase("Running")
	for player in members do
		spawnMember(player)
	end
	--[[
		An error in the loop used to kill its thread and nothing else: the wave counter
		froze and the party sat in the map until the server retired. It now ends the raid
		and sends everyone home.
	]]
	runThread = task.spawn(function()
		local ok, problem = xpcall(run, debug.traceback, current)
		if not ok then
			warn(`[RaidRunService] the raid loop failed: {problem}`)
			close("The raid ran into a problem and was ended.")
		end
	end)
end

local function onDataLoaded(player: Player)
	if members[player] ~= nil then
		return
	end
	if not admit(player) then
		if player.Parent == Players then
			sendHome({ player }, "There is no raid for you here.")
		end
		return
	end
	if player.Parent ~= Players then
		return
	end

	members[player] = 0
	publishParty()

	local current = session :: Session
	if started then
		-- Loaded in late: straight into the fight.
		spawnMember(player)
	elseif countMembers() >= current.Expected then
		begin()
	elseif not timeoutThread then
		timeoutThread = task.delay(RaidRunConfig.PartyTimeout, begin)
	end
end

local function onMemberDied(player: Player)
	if members[player] == nil or closed then
		return
	end

	if IS_STUDIO then
		-- Nowhere to send them: back on the raid spawn once the body is gone.
		task.delay(WorldConfig.RespawnDelay + 1, function()
			if members[player] ~= nil and not closed then
				spawnMember(player)
			end
		end)
		return
	end

	removeMember(player, "You died: the raid is over for you.")
end

local function onDamaged(context: CombatTypes.DamageContext, dealt: number)
	local attacker = context.Attacker
	local player = attacker and attacker.Player
	if player and dealt > 0 and members[player] ~= nil and alive[context.Target] ~= nil then
		members[player] += dealt
		lastProgress = os.clock()
	end
end

--[[
	A started raid ends with its last member (removeMember). One that is still waiting
	stays open: closing it when the server was empty for a moment turned away the rest
	of a party whose first arrival had crashed, although the leader had paid for it.
]]
local function onPlayerRemoving(player: Player)
	leaving[player] = nil
	removeMember(player, nil)
end

function RaidRunService:KnitInit()
	if not IS_RAID then
		return
	end
	CharacterService = Knit.GetService("CharacterService")
	CombatService = Knit.GetService("CombatService")
	DataService = Knit.GetService("DataService")
	EnemyService = Knit.GetService("EnemyService")
	HakiService = Knit.GetService("HakiService")
	NotifyService = Knit.GetService("NotifyService")
	RaidService = Knit.GetService("RaidService")
	StatService = Knit.GetService("StatService")
	WeaponUnlockService = Knit.GetService("WeaponUnlockService")

	-- Before any client can read them: the waiting cover is up from the first frame.
	setPhase("Waiting")
	Workspace:SetAttribute(ATTRIBUTES.Wave, 0)
	Workspace:SetAttribute(ATTRIBUTES.Enemies, 0)
	publishParty()
end

function RaidRunService:KnitStart()
	if not IS_RAID then
		return
	end

	DataService:ObserveData(onDataLoaded)
	CombatService.Damaged:Connect(onDamaged)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	TeleportService.TeleportInitFailed:Connect(onTeleportFailed)

	CharacterService.EntityAdded:Connect(function(entity: CharacterEntity)
		local player = entity.Player
		if player then
			-- The party is one side: no player harms or hinders another here (Allies).
			entity.Team = Allies.RaidTeam
			entity.Died:Once(function()
				onMemberDied(player)
			end)
		end
	end)

	task.delay(RaidRunConfig.ServerLifetime, function()
		close("This raid server is closing.")
	end)
end

return RaidRunService
