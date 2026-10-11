--!strict
--[[
	Conqueror's Haki (Haoshoku): a burst of will that brings everyone around the user to
	their knees. Numbers and stages: ConquerorConfig.

	A press spends a share of the haki bar (HakiService owns the bar) and starts one burst:
	for its duration the area is swept five times a second and every character caught in
	it, once, is stunned and kneels. Players holding stage 2 or 3 do not kneel. From stage
	2, catching somebody whose own haki is out (a burst running, or the coating) is settled
	by Haki level: 25 levels apart the weaker one kneels, closer than that both stand
	locked in a clash, unable to act or to be hurt, until it blows over.

	Stage 3 also wears a coating: the press that starts the burst turns it on, the next
	press turns it off (and nothing else), and it drains the bar while it is on.

	The body can let a burst out by itself when its owner is about to fall or is stunned
	(ConquerorConfig.Auto). That one costs more, holds its victims for less, and never
	touches the coating.

	The client only ever says "I pressed the button": stage, cooldown, cost, reach,
	victims and stun lengths are all decided here. Nothing is built on the server either;
	what is seen comes from two one-shot effects (ConquerorBurst, ConquerorClash) and two
	replicated statuses (ConquerorCoating, Conquered).

	Server API
		ConquerorService:GetStage(player) -> 0..3
		ConquerorService:SetStage(player, stage)
		ConquerorService:GetColor(player) -> Color3
		ConquerorService:IsCoated(entity) -> boolean

	Left behind from the place this came from: the effects, sounds and screen tints were
	server instances; two hard-coded UserIds had a 3 second cooldown; and its bursts
	stopped for "Stunned" and "Knocked" flags that nothing there ever raised.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local ConquerorConfig = require(ReplicatedStorage.Shared.Configs.ConquerorConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity
type Stage = ConquerorConfig.Stage

local STATUS = ConquerorConfig.Status
local CLASH = ConquerorConfig.Clash
local COATING = ConquerorConfig.Coating
local AUTO = ConquerorConfig.Auto
-- Names of the stuns handed to StatusService: one per cause, so neither cuts the other short.
local KNEEL_STUN = "Conquered"
local CLASH_STUN = "ConquerorClash"
local STUN_STATUS = "Stunned"
local PRESS_DEBOUNCE = 0.5

local ConquerorService = Knit.CreateService({
	Name = "ConquerorService",
	Client = {
		-- The whole request: no arguments are read.
		Activate = Knit.CreateSignal(),
	},
})

local DataService
local CharacterService
local HakiService
local StatService
local StatusService
local EffectService

local random = Random.new()
local pressLimiter = RateLimiter.new(2, 1 / PRESS_DEBOUNCE)
-- os.clock of each player's last burst. Kept across respawns: dying does not refresh it.
local lastUse: { [Player]: number } = {}
-- The drain loop of each coating answers to its token: a new coating never inherits an old loop.
local coatings: { [CharacterEntity]: {} } = {}

local function isLive(entity: CharacterEntity): boolean
	return not entity.Dead and CharacterService:GetEntity(entity.Model) == entity
end

local function hakiOut(entity: CharacterEntity): boolean
	return entity:HasStatus(STATUS.Active) or entity:HasStatus(STATUS.Coating)
end

function ConquerorService:GetStage(player: Player): number
	local data = DataService:GetData(player)
	local stage = data and data:Get(ConquerorConfig.StagePath)
	if type(stage) ~= "number" or stage ~= stage then
		return 0
	end
	return math.clamp(math.floor(stage), 0, ConquerorConfig.MaxStage)
end

-- The only writer of the stage. Whatever grants one (a quest, a boss, a dev command) calls this.
function ConquerorService:SetStage(player: Player, stage: number)
	local data = DataService:GetData(player)
	if not data or stage ~= stage then
		return
	end

	local value = math.clamp(math.floor(stage), 0, ConquerorConfig.MaxStage)
	data:Set(ConquerorConfig.StagePath, value)
	-- A coating belongs to the third stage only.
	local entity = CharacterService:GetPlayerEntity(player)
	local held = ConquerorConfig.Stages[value]
	if entity and not (held and held.Coating) then
		ConquerorService:RemoveCoating(entity)
	end
end

-- The player's own colour, drawn from the palette and saved the first time it is asked for.
function ConquerorService:GetColor(player: Player): Color3
	local data = DataService:GetData(player)
	local saved = data and ConquerorConfig.ParseColor(data:Get(ConquerorConfig.ColorPath))
	if saved then
		return saved
	end

	local palette = ConquerorConfig.Palette
	local color = palette[random:NextInteger(1, #palette)]
	if data then
		data:Set(ConquerorConfig.ColorPath, color:ToHex())
	end
	return color
end

function ConquerorService:IsCoated(entity: CharacterEntity): boolean
	return coatings[entity] ~= nil
end

function ConquerorService:RemoveCoating(entity: CharacterEntity)
	if coatings[entity] then
		coatings[entity] = nil
		entity:ClearStatus(STATUS.Coating)
	end
end

local function startCoating(entity: CharacterEntity, color: Color3)
	if not ConquerorConfig.Enabled then
		return
	end
	local token = {}
	coatings[entity] = token
	entity:SetStatus(STATUS.Coating, color:ToHex(), nil, true)

	task.spawn(function()
		while true do
			task.wait(COATING.DrainInterval)
			if coatings[entity] ~= token then
				return
			end
			if not isLive(entity) then
				ConquerorService:RemoveCoating(entity)
				return
			end

			local bar, max = HakiService:GetBar(entity)
			local drain = math.max(COATING.DrainMinimum, max * COATING.DrainFraction)
			if bar < drain then
				HakiService:AddBar(entity, -bar)
				ConquerorService:RemoveCoating(entity)
				return
			end
			HakiService:AddBar(entity, -drain)
		end
	end)
end

-- Brings `victim` down for `seconds`. Somebody already on their knees is left alone.
local function conquer(victim: CharacterEntity, seconds: number, stageIndex: number)
	if victim.Dead or victim:HasStatus(STATUS.Conquered) then
		return
	end
	victim:SetStatus(STATUS.Conquered, stageIndex, seconds, true)
	StatusService:ApplyStun(victim, seconds, KNEEL_STUN)
end

local function faceEachOther(first: CharacterEntity, second: CharacterEntity)
	local a, b = first.Root.Position, second.Root.Position
	-- Level with the ground: looking up or down at the other would tilt the whole body.
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	CharacterService:Teleport(first, CFrame.lookAt(a, a + flat))
	CharacterService:Teleport(second, CFrame.lookAt(b, b - flat))
end

local function lockInClash(entity: CharacterEntity)
	entity:SetStatus(STATUS.ClashLock, true, CLASH.Lockout)
	entity:SetStatus(STATUS.Guard, true, CLASH.Seconds)
	StatusService:ApplyStun(entity, CLASH.Seconds, CLASH_STUN)
end

--[[
	The caster's burst caught somebody whose own haki is out. Returns true when the
	caster's burst is over because of it (it lost, or the two are now locked in a clash).
]]
local function meet(caster: CharacterEntity, other: CharacterEntity, level: number, color: Color3, seconds: number, stageIndex: number): boolean
	if caster:HasStatus(STATUS.ClashLock) or other:HasStatus(STATUS.ClashLock) then
		return false
	end
	-- Only another player answers: a coated boss is simply not moved.
	local otherPlayer = other.Player
	if not otherPlayer then
		return false
	end

	local otherLevel = StatService:GetLevel(otherPlayer, "Haki")
	if math.abs(level - otherLevel) >= CLASH.LevelGap then
		if level > otherLevel then
			conquer(other, seconds, stageIndex)
			return false
		end
		conquer(caster, seconds, stageIndex)
		return true
	end

	local otherColor = ConquerorService:GetColor(otherPlayer)
	lockInClash(caster)
	lockInClash(other)
	faceEachOther(caster, other)

	local middle = (caster.Root.Position + other.Root.Position) / 2
	EffectService:Play(ConquerorConfig.Effects.Clash, middle, {
		Color = color:Lerp(otherColor, 0.5),
		Seconds = CLASH.Seconds,
	})
	return true
end

local function sweep(caster: CharacterEntity, stage: Stage, stageIndex: number, level: number, color: Color3, seconds: number)
	local range = stage.Range + stage.RangePerLevel * level
	local caught: { [CharacterEntity]: boolean } = {}
	local endsAt = os.clock() + stage.Duration

	while os.clock() < endsAt and isLive(caster) and not caster:HasStatus(STATUS.ClashLock) do
		local over = false
		for _, victim in Hitbox.Sphere(caster.Root.Position, range, caster) do
			if caught[victim] then
				continue
			end
			caught[victim] = true
			if caster.Team ~= "" and caster.Team == victim.Team then
				continue
			end

			local victimPlayer = victim.Player
			if stage.Clashes and hakiOut(victim) then
				if meet(caster, victim, level, color, seconds, stageIndex) then
					over = true
					break
				end
			elseif victimPlayer and ConquerorService:GetStage(victimPlayer) >= ConquerorConfig.ImmuneStage then
				continue
			else
				conquer(victim, seconds, stageIndex)
			end
		end
		if over then
			break
		end
		task.wait(ConquerorConfig.SweepInterval)
	end

	if isLive(caster) then
		caster:ClearStatus(STATUS.Active)
	end
end

--[[
	One use of the technique. `auto` is the burst the body lets out by itself: dearer,
	shorter on its victims, allowed while stunned and never a coating toggle.
]]
local function activate(player: Player, auto: boolean)
	-- Every use ends up here: the press, and the two bursts nobody pressed for.
	if not ConquerorConfig.Enabled then
		return
	end
	local entity = CharacterService:GetPlayerEntity(player)
	if not entity or not isLive(entity) or not entity.Spawned then
		return
	end
	if entity:HasStatus(STATUS.Active) or entity:HasStatus(STATUS.ClashLock) then
		return
	end
	if not auto and (entity:HasStatus(STUN_STATUS) or entity:HasStatus(AbilityConfig.Status.AbilitiesDisabled)) then
		return
	end

	-- A press with the coating on takes it off, and that is all it does.
	if not auto and coatings[entity] then
		ConquerorService:RemoveCoating(entity)
		return
	end

	local stageIndex = ConquerorService:GetStage(player)
	local stage = ConquerorConfig.Stages[stageIndex]
	local level = StatService:GetLevel(player, "Haki")
	if not stage or level < ConquerorConfig.HakiLevel then
		return
	end

	local now = os.clock()
	local last = lastUse[player]
	if last and now - last < stage.Cooldown then
		return
	end

	local _, max = HakiService:GetBar(entity)
	local cost = max * (if auto then AUTO.Cost else stage.Cost)
	if max <= 0 or not HakiService:AddBar(entity, -cost) then
		return
	end
	lastUse[player] = now

	local color = ConquerorService:GetColor(player)
	entity:SetStatus(STATUS.Active, true, stage.Duration + 1)
	entity:SetStatus(STATUS.Guard, true, ConquerorConfig.GuardSeconds)
	if stage.Coating and not auto then
		startCoating(entity, color)
	end

	EffectService:Play(ConquerorConfig.Effects.Burst, entity.Root.Position, {
		Caster = entity.Model,
		Color = color,
		Stage = stageIndex,
	})

	task.spawn(sweep, entity, stage, stageIndex, level, color, if auto then stage.AutoStun else stage.Stun)
end

local function watch(entity: CharacterEntity)
	local player = entity.Player
	if not player then
		return
	end

	entity.Died:Connect(function()
		ConquerorService:RemoveCoating(entity)
	end)

	-- About to fall: health crossing into the band just above the last tenth.
	entity.HealthChanged:Connect(function(health: number, previous: number)
		local max = entity.MaxHealth
		if health >= previous or previous <= max * AUTO.HealthHigh then
			return
		end
		if health > max * AUTO.HealthHigh or health < max * AUTO.HealthLow then
			return
		end
		if random:NextInteger(1, AUTO.HealthChance) == 1 then
			activate(player, true)
		end
	end)
end

function ConquerorService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	HakiService = Knit.GetService("HakiService")
	StatService = Knit.GetService("StatService")
	StatusService = Knit.GetService("StatusService")
	EffectService = Knit.GetService("EffectService")
end

function ConquerorService:KnitStart()
	--[[
		Switched off (ConquerorConfig.Enabled): the service stays loaded, because others
		look it up (the developer commands write the stage through it), but it listens to
		nothing. The remote exists and is deaf: no handler, so no cost per press either.
	]]
	if not ConquerorConfig.Enabled then
		return
	end

	CharacterService.EntityAdded:Connect(watch)
	CharacterService.EntityRemoving:Connect(function(entity: CharacterEntity)
		coatings[entity] = nil
	end)

	-- Stunned: sometimes the will answers by itself. Never from a clash, which is a stun
	-- of this service's own making; deferred, so it never runs inside the stun being applied.
	StatusService.StunApplied:Connect(function(target: CharacterEntity, name: string)
		local player = target.Player
		if not player or name == CLASH_STUN or ConquerorService:GetStage(player) == 0 then
			return
		end
		if random:NextInteger(1, AUTO.StunChance) == 1 then
			task.defer(activate, player, true)
		end
	end)

	ConquerorService.Client.Activate:Connect(function(player: Player)
		if pressLimiter:Consume(player) then
			activate(player, false)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		pressLimiter:Forget(player)
		lastUse[player] = nil
	end)
end

return ConquerorService
