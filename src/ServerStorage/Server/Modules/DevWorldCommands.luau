--!strict
--[[
	Developer commands on the server as a whole: the World tab of the menu.

	Clock, seasons, world events, test enemies and bosses, drop parties. They act on the
	whole server whoever the selected target is, and each goes through the service that
	owns the system (TimeService, SeasonService, WorldEventService, EnemyService,
	FruitBoxService).

	Enemies spawned from here are test enemies: outside the world spawn list, limited in
	number, removed by themselves after a while, and remembered so the menu can take
	them all back at once. Handlers trust their caller (see DevKit).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Optional = require(ReplicatedStorage.Shared.Util.Optional)

local TimeConfig = require(ReplicatedStorage.Shared.Configs.TimeConfig)
local BossConfig = require(ServerStorage.Server.Configs.BossConfig)
local EnemyConfig = require(ServerStorage.Server.Configs.EnemyConfig)
local DevKit = require(ServerStorage.Server.Modules.DevKit)

local SEASONS = { "Weekend", "Halloween", "AprilFools", "AliceFruit", "Christmas" }
local NOTIFY_KINDS = { "Info", "Success", "Error", "Announcement" }

-- Game hours per real second: forty times the normal pace at most.
local MAX_TIME_RATE = 2
local MAX_SPAWN_COUNT = 10
-- Test enemies alive at once, for the whole server.
local MAX_TEST_ENEMIES = 40
local ENEMY_LIFETIME = 300
local BOSS_LIFETIME = 900
local ENEMY_DISTANCE = 15
local ENEMY_SPACING = 6
local BOSS_DISTANCE = 40
local MAX_NOTIFY_LENGTH = 200
local MAX_NOTIFY_SECONDS = 30

local ENEMIES = EnemyConfig :: { [string]: any }

local handlers: { [string]: DevKit.Handler } = {}

-- Entities of the test enemies that may still be standing.
local testEnemies: { any } = {}

local function isBoss(name: string): boolean
	return BossConfig.Bosses[name] ~= nil or ENEMIES[name].Boss == true
end

-- Drops the ones that died or were removed and returns how many are left.
local function countTestEnemies(): number
	for index = #testEnemies, 1, -1 do
		local entity = testEnemies[index]
		if entity.Dead or entity.Model.Parent == nil then
			table.remove(testEnemies, index)
		end
	end
	return #testEnemies
end

function handlers.SetTime(_developer, _target, hourArg)
	local hour = DevKit.Number(hourArg, 0, 24)
	if not hour then
		return false, "invalid hour"
	end
	Knit.GetService("TimeService"):SetClockTime(hour % 24)
	return true, string.format("clock = %.1fh", hour % 24)
end

-- Pace of the day in game hours per second; 0 freezes the clock.
function handlers.SetTimeRate(_developer, _target, rateArg)
	local rate = DevKit.Number(rateArg, 0, MAX_TIME_RATE)
	if not rate then
		return false, "invalid rate"
	end
	Knit.GetService("TimeService"):SetRate(rate)
	return true,
		if rate == 0
			then "clock frozen"
			else string.format("clock pace x%.1f (%.3f h/s)", rate / TimeConfig.HoursPerSecond, rate)
end

function handlers.StartEvent(_developer, _target, eventArg)
	local eventName = DevKit.Name(eventArg)
	local WorldEventService = Knit.GetService("WorldEventService")
	if not eventName or not table.find(WorldEventService:GetEventNames(), eventName) then
		return false, "unknown event"
	end
	if WorldEventService:GetActive() then
		return false, "an event is already running"
	end
	-- StartEvent yields for the whole invitation: answer the menu now.
	task.spawn(function()
		WorldEventService:StartEvent(eventName)
	end)
	return true, `{eventName} invitation started`
end

function handlers.SetSeason(_developer, _target, flagArg, stateArg)
	local flag = DevKit.Member(flagArg, SEASONS)
	if not flag then
		return false, "unknown season flag"
	end
	-- true / false force the flag, anything else goes back to the calendar.
	local override: boolean? = if type(stateArg) == "boolean" then stateArg else nil
	Knit.GetService("SeasonService"):SetOverride(flag, override)
	return true, `{flag} = {if override == nil then "calendar" else tostring(override)}`
end

-- Harmless enemies deal no contact or bullet damage: something to hit, not to fight.
function handlers.SpawnEnemy(developer, _target, enemyArg, countArg, harmlessArg)
	local enemyName = DevKit.Key(enemyArg, ENEMIES)
	local count = DevKit.Integer(countArg, 1, MAX_SPAWN_COUNT) or 1
	local own = DevKit.Living(developer)
	if not enemyName or not own then
		return false, "unknown enemy, or you have no living character"
	end
	local room = MAX_TEST_ENEMIES - countTestEnemies()
	if room <= 0 then
		return false, `{MAX_TEST_ENEMIES} test enemies are already out: remove them first`
	end
	-- Bosses come one at a time, whatever was asked.
	count = if isBoss(enemyName) then 1 else math.min(count, room)

	local EnemyService = Knit.GetService("EnemyService")
	local config: { [string]: any } = { Lifetime = ENEMY_LIFETIME }
	if harmlessArg == true then
		config.Damage = 0
	end

	local spawned = 0
	for index = 1, count do
		local offset = CFrame.new((index - (count + 1) / 2) * ENEMY_SPACING, 0, -ENEMY_DISTANCE)
		-- Temporary on purpose: a test enemy never becomes part of the world.
		local entity = EnemyService:SpawnEvent(enemyName, own.Root.CFrame * offset, config)
		if entity then
			table.insert(testEnemies, entity)
			spawned += 1
		end
	end
	return spawned > 0, `spawned {spawned} x {enemyName} ({ENEMY_LIFETIME // 60} min lifetime)`
end

-- One boss, with its own behaviour and attacks, further away and for longer.
function handlers.SpawnBoss(developer, _target, bossArg)
	local bossName = DevKit.Key(bossArg, ENEMIES)
	local own = DevKit.Living(developer)
	if not bossName or not isBoss(bossName) or not own then
		return false, "unknown boss, or you have no living character"
	end
	if countTestEnemies() >= MAX_TEST_ENEMIES then
		return false, `{MAX_TEST_ENEMIES} test enemies are already out: remove them first`
	end

	local entity = Knit.GetService("EnemyService"):SpawnEvent(
		bossName,
		own.Root.CFrame * CFrame.new(0, 0, -BOSS_DISTANCE),
		{ Lifetime = BOSS_LIFETIME }
	)
	if not entity then
		return false, `{bossName} has no template to spawn from`
	end
	table.insert(testEnemies, entity)
	return true, `spawned {bossName} ({BOSS_LIFETIME // 60} min lifetime)`
end

-- Takes back every test enemy still standing, without a death (no reward, no drop).
function handlers.RemoveTestEnemies()
	local EnemyService = Knit.GetService("EnemyService")
	local removed = countTestEnemies()
	for _, entity in testEnemies do
		EnemyService:Despawn(entity)
	end
	table.clear(testEnemies)
	return true, `removed {removed} test enemies`
end

-- The owner command's rain of boxes, around the developer.
function handlers.DropParty(developer)
	local own = DevKit.Living(developer)
	if not own then
		return false, "you have no living character"
	end
	local dropped = Knit.GetService("FruitBoxService"):DropParty(own.Root.Position)
	return dropped > 0, `dropped {dropped} boxes`
end

--[[
	A notification of the given kind, to try how the client shows it. Only ever sent to
	the developer who asked: free text never reaches another player from here.
]]
function handlers.Notify(developer, _target, textArg, kindArg, secondsArg)
	local kind = DevKit.Member(kindArg, NOTIFY_KINDS)
	if type(textArg) ~= "string" or #textArg == 0 or #textArg > MAX_NOTIFY_LENGTH or not kind then
		return false, "invalid text or kind"
	end
	local seconds = DevKit.Number(secondsArg, 1, MAX_NOTIFY_SECONDS)
	Knit.GetService("NotifyService"):Send(developer, textArg, kind, seconds)
	return true, `{kind} notification sent to you`
end

local function getCatalog(): { [string]: any }
	-- No world events in a place that does not load them (PlaceManifest): an empty list.
	local WorldEventService = Optional.Service("WorldEventService")
	local eventNames = if WorldEventService then WorldEventService:GetEventNames() else {}
	table.sort(eventNames)

	-- "Lv9 Bandit" before "Lv11 Boar": by level, then by name.
	local enemies, bosses = {}, {}
	for name in ENEMIES do
		table.insert(if isBoss(name) then bosses else enemies, name)
	end
	local function level(name: string): number
		return tonumber(string.match(name, "^Lv(%d+)")) or math.huge
	end
	table.sort(enemies, function(a: string, b: string): boolean
		local levelA, levelB = level(a), level(b)
		if levelA ~= levelB then
			return levelA < levelB
		end
		return a < b
	end)
	table.sort(bosses)

	return {
		Events = eventNames,
		Seasons = SEASONS,
		Enemies = enemies,
		Bosses = bosses,
		MaxSpawnCount = MAX_SPAWN_COUNT,
		TimeRate = TimeConfig.HoursPerSecond,
		MaxTimeRate = MAX_TIME_RATE,
		NotifyKinds = NOTIFY_KINDS,
	}
end

local function getState(_target: Player): { [string]: any }
	return { TestEnemies = countTestEnemies() }
end

return {
	Handlers = handlers,
	Costs = {
		StartEvent = 3,
		SpawnEnemy = 3,
		SpawnBoss = 5,
		RemoveTestEnemies = 3,
		DropParty = 10,
	},
	GetCatalog = getCatalog,
	GetState = getState,
} :: DevKit.CommandModule
