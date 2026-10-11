--!strict
--[[
	Developer commands on the target's character: the Player and Combat tabs of the menu.

	Health, movement, teleports, statuses and test hits. Each one goes through the entity
	or the service that owns the mechanic (CombatService for hits, StatusService for stuns
	and slows, HakiService for the bar, AbilityService for seals), so what a test shows is
	what the game does.

	Whatever a command leaves on a character (god mode, speed, stun, slow, seal) lives on
	its entity under a "Dev" name: it ends with the character and can never be forgotten
	on. Handlers trust their caller (see DevKit).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local World = require(ReplicatedStorage.Shared.Util.World)
local DevKit = require(ServerStorage.Server.Modules.DevKit)

local TRAITS = { "Melee", "Sword", "Special", "Haki", "Bleed" }
local STYLES = { "Weapon", "Ability", "Environment" }

local SPEED_BONUS = "DevSpeed"
local STUN_NAME = "DevStun"
local SLOW_NAME = "DevSlow"
local SEAL_SOURCE = "Dev"

local MAX_DAMAGE = 1e9
local MAX_SHIELD = 1e7
-- Far beyond any health pool, and still a finite number for the combat pipeline.
local LETHAL_DAMAGE = 1e12
local MAX_EFFECT_SECONDS = 60
local MAX_KILL_RADIUS = 500
local MAX_KILLS = 100
local MAX_COORDINATE = 100000
-- Added to the body removal delay before asking for the new character.
local RESPAWN_MARGIN = 0.5
-- How far above an island's bounds the search for its ground starts.
local ISLAND_CLEARANCE = 20

local NO_CHARACTER = "target has no living character"

local handlers: { [string]: DevKit.Handler } = {}

-- Where a character can stand on an island: the ground under the middle of its bounds.
-- Islands are Models or plain Folders, so the bounds are taken from their parts.
local function getIslandCFrame(island: Instance): CFrame?
	local parts: { BasePart } = {}
	if island:IsA("BasePart") then
		table.insert(parts, island)
	end
	for _, descendant in island:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 then
		return nil
	end

	local low, high = parts[1].Position, parts[1].Position
	for _, part in parts do
		local half = part.Size / 2
		low = low:Min(part.Position - half)
		high = high:Max(part.Position + half)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { island }
	local origin = Vector3.new((low.X + high.X) / 2, high.Y + ISLAND_CLEARANCE, (low.Z + high.Z) / 2)
	local hit = Workspace:Raycast(origin, Vector3.new(0, low.Y - origin.Y, 0), params)
	-- A hollow middle (a bay, a crater): dropped from the top of the bounds instead.
	local ground = if hit then hit.Position else Vector3.new(origin.X, high.Y, origin.Z)
	return CFrame.new(ground + Vector3.new(0, WorldConfig.SpawnHeightOffset, 0))
end

function handlers.Heal(_developer, target)
	local entity = DevKit.Living(target)
	if not entity then
		return false, NO_CHARACTER
	end
	entity:Heal(math.huge)
	local HakiService = Knit.GetService("HakiService")
	local _, maximum = HakiService:GetBar(entity)
	HakiService:AddBar(entity, maximum)
	return true, "healed, haki refilled"
end

function handlers.HealAmount(_developer, target, amountArg)
	local amount = DevKit.Number(amountArg, 1, MAX_DAMAGE)
	local entity = DevKit.Living(target)
	if not amount or not entity then
		return false, `invalid amount, or {NO_CHARACTER}`
	end
	local healed = entity:Heal(amount)
	return true, `healed {math.floor(healed)}, health {math.floor(entity.Health)} / {math.floor(entity.MaxHealth)}`
end

-- Exact on purpose (low health perks, last stands): no mitigation, no hit effects, and
-- never lethal, the lowest setting being 1% of the maximum.
function handlers.SetHealth(_developer, target, percentArg)
	local percent = DevKit.Number(percentArg, 1, 100)
	local entity = DevKit.Living(target)
	if not percent or not entity then
		return false, `invalid percent, or {NO_CHARACTER}`
	end

	local wanted = entity.MaxHealth * percent / 100
	if wanted >= entity.Health then
		entity:Heal(wanted - entity.Health)
	else
		entity:TakeDamage(entity.Health - wanted)
	end
	return true, `health = {math.floor(entity.Health)} / {math.floor(entity.MaxHealth)}`
end

function handlers.SetShield(_developer, target, amountArg)
	local amount = DevKit.Number(amountArg, 0, MAX_SHIELD)
	local entity = DevKit.Living(target)
	if not amount or not entity then
		return false, `invalid amount, or {NO_CHARACTER}`
	end
	entity:SetShield(amount)
	return true, `shield = {math.floor(amount)}`
end

function handlers.SetHaki(_developer, target, percentArg)
	local percent = DevKit.Number(percentArg, 0, 100)
	local entity = DevKit.Living(target)
	if not percent or not entity then
		return false, `invalid percent, or {NO_CHARACTER}`
	end

	local HakiService = Knit.GetService("HakiService")
	local bar, maximum = HakiService:GetBar(entity)
	if maximum <= 0 then
		return false, "target has no haki bar (Haki level 0)"
	end
	-- An empty bar turns both haki toggles off, as running dry does.
	HakiService:AddBar(entity, maximum * percent / 100 - bar)
	return true, `haki = {math.floor(maximum * percent / 100)} / {math.floor(maximum)}`
end

function handlers.Kill(_developer, target)
	local entity = DevKit.Living(target)
	if not entity then
		return false, NO_CHARACTER
	end
	entity:SetStatus(DevKit.GodStatus, nil)
	entity:Kill()
	return true, "killed"
end

--[[
	Puts the target back in the world: kills the current character if there is one, then
	asks for a new one once the body is gone. Nothing respawns by itself in this game, and
	RequestSpawn is its one way in: saved spawn point, its own guards and rate limit.
]]
function handlers.Respawn(_developer, target)
	if not DevKit.Data(target) then
		return false, "target data is not loaded"
	end

	local entity = DevKit.Living(target)
	if entity then
		entity:SetStatus(DevKit.GodStatus, nil)
		entity:Kill()
	end

	-- A body stays for RespawnDelay after its death, and blocks the request until then.
	local seconds = if target.Character then WorldConfig.RespawnDelay + RESPAWN_MARGIN else 0
	task.delay(seconds, function()
		if target.Parent == Players then
			Knit.GetService("CharacterService").Client:RequestSpawn(target)
		end
	end)
	return true, if seconds > 0 then `respawning in {seconds} s` else "spawning"
end

function handlers.SetGod(_developer, target, enabledArg)
	local entity = DevKit.Entity(target)
	if not entity then
		return false, "target has no character"
	end
	-- Lives on the character: it ends with it, so it can never be forgotten on.
	entity:SetStatus(DevKit.GodStatus, enabledArg == true, nil, true)
	return true, if enabledArg == true then "god mode on" else "god mode off"
end

-- Multiplier of the base walk speed, as a named bonus: it adds up with perks and fruit
-- bonuses and is still cut by slows and roots, like any other.
function handlers.SetWalkSpeed(_developer, target, multiplierArg)
	local multiplier = DevKit.Number(multiplierArg, 0.1, 10)
	local entity = DevKit.Living(target)
	if not multiplier or not entity then
		return false, `invalid multiplier, or {NO_CHARACTER}`
	end
	entity:SetSpeedBonus(SPEED_BONUS, if multiplier == 1 then nil else multiplier - 1)
	return true, string.format("speed x%.1f of base (walk speed %.1f)", multiplier, entity.Humanoid.WalkSpeed)
end

function handlers.ClearStatuses(_developer, target)
	local entity = DevKit.Entity(target)
	if not entity then
		return false, "target has no character"
	end

	local AbilityService = Knit.GetService("AbilityService")
	local StatusService = Knit.GetService("StatusService")
	AbilityService:Interrupt(entity)
	-- What the menu applied goes back through its owner, so no root or seal outlives it.
	StatusService:Clear(entity, STUN_NAME)
	StatusService:Clear(entity, SLOW_NAME)
	AbilityService:SetSealed(entity, false, nil, SEAL_SOURCE)

	local cleared = 0
	for name in entity:GetStatuses() do
		if name ~= DevKit.GodStatus then
			entity:ClearStatus(name)
			cleared += 1
		end
	end
	return true, `abilities interrupted, {cleared} statuses cleared`
end

function handlers.Teleport(developer, target, kindArg, whereArg)
	local entity = DevKit.Living(target)
	if not entity then
		return false, NO_CHARACTER
	end

	local destination: CFrame? = nil
	if kindArg == "Spawn" then
		local index = DevKit.Integer(whereArg, 1, WorldConfig.SpawnCount)
		destination = if index then WorldConfig.GetSpawnCFrame(index) else nil
	elseif kindArg == "Island" then
		local name = DevKit.Name(whereArg)
		local island = name and World.Island(name)
		destination = if island then getIslandCFrame(island) else nil
	elseif kindArg == "Merchant" then
		local name = DevKit.Name(whereArg)
		local folder = World.Merchants()
		local merchant = name and folder and folder:FindFirstChild(name)
		if merchant and merchant:IsA("Model") then
			destination = merchant:GetPivot() * CFrame.new(0, 3, -6)
		end
	elseif kindArg == "Position" then
		local position = DevKit.Vector(whereArg, MAX_COORDINATE)
		destination = if position then CFrame.new(position) else nil
	elseif kindArg == "Player" then
		local other = if type(whereArg) == "number" then Players:GetPlayerByUserId(whereArg) else nil
		local otherEntity = other and DevKit.Entity(other)
		if otherEntity then
			destination = otherEntity.Root.CFrame * CFrame.new(0, 0, 5)
		end
	elseif kindArg == "Developer" then
		local own = DevKit.Entity(developer)
		if own then
			destination = own.Root.CFrame * CFrame.new(0, 0, -5)
		end
	end

	if not destination then
		return false, "destination not found"
	end
	Knit.GetService("CharacterService"):Teleport(entity, destination)
	local position = destination.Position
	return true, `teleported to {math.floor(position.X)}, {math.floor(position.Y)}, {math.floor(position.Z)}`
end

--[[
	A hit through the combat pipeline: immunities, resistances, shields, god mode and
	spawn protection all answer as they would in a fight. Credited, the developer's own
	character is the attacker (range, teams, on-hit perks, kill rewards); otherwise the
	hit comes from nowhere and nobody is rewarded for it.
]]
function handlers.Damage(developer, target, amountArg, traitArg, styleArg, creditArg)
	local amount = DevKit.Number(amountArg, 1, MAX_DAMAGE)
	local trait = DevKit.Member(traitArg, TRAITS)
	local style = DevKit.Member(styleArg, STYLES)
	local entity = DevKit.Living(target)
	if not amount or not trait or not style or not entity then
		return false, `invalid amount, trait or style, or {NO_CHARACTER}`
	end

	local attacker = if creditArg == true and developer ~= target then DevKit.Living(developer) else nil
	local dealt = Knit.GetService("CombatService"):Damage({
		Target = entity,
		Attacker = attacker,
		Amount = amount,
		Trait = trait,
		Style = style,
		Dodgeable = false,
	})
	return true,
		`{trait} / {style} hit of {math.floor(amount)}: {math.floor(dealt)} dealt, health {math.floor(entity.Health)} / {math.floor(entity.MaxHealth)}`
end

function handlers.Stun(_developer, target, secondsArg)
	local seconds = DevKit.Number(secondsArg, 0.1, MAX_EFFECT_SECONDS)
	local entity = DevKit.Living(target)
	if not seconds or not entity then
		return false, `invalid duration, or {NO_CHARACTER}`
	end
	Knit.GetService("StatusService"):ApplyStun(entity, seconds, STUN_NAME)
	return true, string.format("stunned for %.1f s", seconds)
end

function handlers.Slow(_developer, target, scaleArg, secondsArg)
	local scale = DevKit.Number(scaleArg, 0.05, 1)
	local seconds = DevKit.Number(secondsArg, 0.1, MAX_EFFECT_SECONDS)
	local entity = DevKit.Living(target)
	if not scale or not seconds or not entity then
		return false, `invalid scale or duration, or {NO_CHARACTER}`
	end
	Knit.GetService("StatusService"):ApplySlow(entity, SLOW_NAME, scale, seconds)
	return true, string.format("slowed to %d%% for %.1f s", math.floor(scale * 100 + 0.5), seconds)
end

-- Seals under a source of its own: lifting it never lifts a seal the game applied.
function handlers.Seal(_developer, target, enabledArg, secondsArg)
	local entity = DevKit.Living(target)
	if not entity then
		return false, NO_CHARACTER
	end

	local AbilityService = Knit.GetService("AbilityService")
	if enabledArg ~= true then
		AbilityService:SetSealed(entity, false, nil, SEAL_SOURCE)
		return true, "developer seal lifted"
	end
	-- Without a duration it lasts as long as the character.
	local seconds = DevKit.Number(secondsArg, 1, MAX_EFFECT_SECONDS)
	AbilityService:SetSealed(entity, true, seconds, SEAL_SOURCE)
	return true, if seconds then string.format("abilities sealed for %.0f s", seconds) else "abilities sealed"
end

function handlers.KillNearby(developer, _target, radiusArg, creditArg)
	local radius = DevKit.Number(radiusArg, 5, MAX_KILL_RADIUS)
	local own = DevKit.Living(developer)
	if not radius or not own then
		return false, "invalid radius, or you have no living character"
	end
	local credited = creditArg == true
	if credited and not own.Spawned then
		return false, "your spawn protection is still on: credited kills need a hit of yours"
	end

	-- Collected first: a death takes its entity out of the table being walked.
	local origin = own.Root.Position
	local victims = {}
	for _, entity in Knit.GetService("CharacterService"):GetEntities() do
		if not entity.Player and not entity.Dead and (entity.Root.Position - origin).Magnitude <= radius then
			table.insert(victims, entity)
			if #victims >= MAX_KILLS then
				break
			end
		end
	end

	local CombatService = Knit.GetService("CombatService")
	local killed = 0
	for _, entity in victims do
		if credited then
			-- Through the pipeline, so rewards, drops and quest progress go to the developer.
			CombatService:Damage({
				Target = entity,
				Attacker = own,
				Amount = LETHAL_DAMAGE,
				Trait = "Special",
				Style = "Environment",
				Dodgeable = false,
			})
		else
			entity:Kill()
		end
		if entity.Dead then
			killed += 1
		end
	end
	return true, `killed {killed} of {#victims} NPCs within {math.floor(radius)} studs{if credited then " (credited)" else ""}`
end

local function getCatalog(): { [string]: any }
	local function childNames(container: Instance?): { string }
		local names = {}
		for _, child in if container then container:GetChildren() else {} do
			table.insert(names, child.Name)
		end
		table.sort(names)
		return names
	end

	return {
		SpawnCount = WorldConfig.SpawnCount,
		Islands = childNames(World.Islands()),
		Merchants = childNames(World.Merchants()),
		Traits = TRAITS,
		Styles = STYLES,
	}
end

local function getState(target: Player): { [string]: any }
	local state: { [string]: any } = { Statuses = {} }
	local entity = DevKit.Entity(target)
	if not entity then
		return state
	end

	local bar, barMax = Knit.GetService("HakiService"):GetBar(entity)
	state.Health = entity.Health
	state.MaxHealth = entity.MaxHealth
	state.Shield = entity.Shield
	state.Haki = bar
	state.HakiMax = barMax
	state.WalkSpeed = entity.Humanoid.WalkSpeed
	state.Position = entity.Root.Position
	state.Rooted = entity:IsRooted()
	state.Dead = entity.Dead
	state.Spawned = entity.Spawned
	state.Team = entity.Team
	state.God = entity:HasStatus(DevKit.GodStatus)

	for name, status in entity:GetStatuses() do
		table.insert(state.Statuses, {
			Name = name,
			Value = string.sub(tostring(status.Value), 1, 48),
			TimeLeft = if status.TimeLeft == math.huge then -1 else status.TimeLeft,
		})
	end
	table.sort(state.Statuses, function(a, b)
		return a.Name < b.Name
	end)
	return state
end

return {
	Handlers = handlers,
	Costs = {
		Respawn = 3,
		KillNearby = 5,
	},
	GetCatalog = getCatalog,
	GetState = getState,
} :: DevKit.CommandModule
