--!strict
--[[
	Dash and Shave: the two movement techniques unlocked by the Melee skill.

	Dash  (Melee 50)  - a 0.3 s push toward the aimed point. The character belongs to its
	                    client, so the server only decides *whether* and *how fast* and the
	                    owner applies the push (DashController).
	Shave (Melee 200) - an instant step to the aimed point, within reach. The server moves
	                    the character itself.

	The client sends one thing: where it is aiming. Level, cooldown, perks, fruit bonuses,
	reach and every refusal are resolved here from server state.

	Legacy problems fixed:
	- Shave tested `character:FindFirstChild("InSandstorm")`, a BoolValue present in every
	  character, so in the last version of the game Shave was refused for everybody. The
	  flag's value is what is tested now (status "SandInSandstorm").
	- Both remotes indexed `player.Character.X.Value` before checking anything: a request
	  sent while respawning errored, and for Dash the per-player lock had already been
	  taken by then on some paths, leaving the technique dead until rejoin.
	- Dash built a unit vector from the client's point without checking it: a point equal
	  to the character's position produced NaN velocity on a server-created BodyVelocity.
	- The Gum bonus of a second-slot fruit raised its affinity to the power of the *first*
	  slot's affinity.
	- Cooldowns were `task.delay` flags per user id; they are timestamps here.
	- The rule about Barrier Rooms was three overlapping distance tests against parts
	  found by name around the aimed point. It is one rule now: a Shave may not cross the
	  wall of a Barrier Room, in either direction.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

type CharacterEntity = CharacterEntity.CharacterEntity
type PlayerData = PlayerData.PlayerData

type Cooldowns = { Dash: number, Shave: number }

local DASH = MovementConfig.Dash
local SHAVE = MovementConfig.Shave

-- Status written by the Barrier fruit: "<kind>|px|py|pz|lx|ly|lz|sx|sy|sz|<colors>".
local BARRIER_STATUS = "BarrierConstruct"
local BARRIER_ROOM = "Room"

local MovementService = Knit.CreateService({
	Name = "MovementService",
	Client = {
		-- Client -> server: (aimPosition: Vector3)
		Dash = Knit.CreateSignal(),
		Shave = Knit.CreateSignal(),
		-- Server -> owner: (direction: Vector3, speed: number, cooldown: number)
		Dashed = Knit.CreateSignal(),
		-- Server -> owner: (cooldown: number)
		Shaved = Knit.CreateSignal(),
	},
})

local DataService
local CharacterService
local EffectService
local StatusService

-- os.clock() from which each technique is available again. Per player, not per
-- character: dying does not reset a cooldown.
local cooldowns: { [Player]: Cooldowns } = {}
local requestLimiter = RateLimiter.new(6, 3)

local function isFiniteVector(value: Vector3): boolean
	return value.X == value.X and value.Y == value.Y and value.Z == value.Z and value.Magnitude < math.huge
end

local function getCooldowns(player: Player): Cooldowns
	local owned = cooldowns[player]
	if not owned then
		owned = { Dash = 0, Shave = 0 }
		cooldowns[player] = owned
	end
	return owned
end

-- Fruit slot (1 or 2) holding `fruitName`, with that slot's melee affinity and colors.
local function findFruit(data: PlayerData, fruitName: string): (number?, number, string)
	local fruits = data.Data.DevilFruits
	local affinities = data.Data.Affinities
	if fruits.Slot1.Name == fruitName then
		return 1, affinities.DF1.Melee, fruits.Slot1.Color
	elseif fruits.Slot2.Name == fruitName then
		return 2, affinities.DF2.Melee, fruits.Slot2.Color
	end
	return nil, 1, "None"
end

local function isSlowed(entity: CharacterEntity): boolean
	for _, status in MovementConfig.SlowingStatuses do
		if entity:HasStatus(status) or StatusService:Has(entity, status) then
			return true
		end
	end
	return false
end

--[[
	Everything Dash and Shave have in common. Returns nil when the request must be
	dropped: unknown or dead character, still in the lobby, sitting, stunned or rooted by
	anything (the legacy NoMovement / DF_Disabled flags), or carrying a blocking status.
	A plain seal of fruit powers does not stop them: they are not fruit powers.
]]
local function getActor(player: Player, aim: unknown): (CharacterEntity?, PlayerData?, Vector3)
	if not requestLimiter:Consume(player) then
		return nil, nil, Vector3.zero
	end
	if typeof(aim) ~= "Vector3" or not isFiniteVector(aim :: Vector3) then
		return nil, nil, Vector3.zero
	end

	local entity = CharacterService:GetPlayerEntity(player)
	local data = DataService:GetData(player)
	if not entity or not data or entity.Dead or not entity.Spawned then
		return nil, nil, Vector3.zero
	end
	if entity.Humanoid.Sit or entity:IsRooted() then
		return nil, nil, Vector3.zero
	end
	for _, status in MovementConfig.BlockingStatuses do
		if entity:HasStatus(status) then
			return nil, nil, Vector3.zero
		end
	end

	-- The client aims up to HardMaxAimDistance away (the sky, the horizon). Dash only needs
	-- the direction; Shave refuses by its own reach, far below either limit.
	local aimPosition = aim :: Vector3
	if (aimPosition - entity.Root.Position).Magnitude > AbilityConfig.HardMaxAimDistance then
		return nil, nil, Vector3.zero
	end
	return entity, data, aimPosition
end

local function getPerk(data: PlayerData, name: string): number
	local perk = data.Data.Expertise.Perks[name]
	return if perk then perk.Value else 0
end

local function onDash(player: Player, aim: unknown)
	local entity, data, aimPosition = getActor(player, aim)
	if not entity or not data then
		return
	end

	local melee = data.Data.Skills.Melee.Level
	local owned = getCooldowns(player)
	local now = os.clock()
	if melee < DASH.Requirement or now < owned.Dash then
		return
	end

	local offset = aimPosition - entity.Root.Position
	if offset.Magnitude < 0.1 then
		return
	end

	local speed: number
	if isSlowed(entity) then
		speed = math.clamp((DASH.Base + melee * DASH.PerLevel) * DASH.SlowedScale, DASH.SlowedMin, DASH.Max)
	else
		local float = DASH.Float
		local slot, affinity = findFruit(data, float.Fruit)
		if slot then
			speed = math.clamp(float.Base + melee * float.PerLevel * affinity, float.Min, float.Max)
		else
			speed = math.clamp(DASH.Base + melee * DASH.PerLevel, DASH.Min, DASH.Max)
		end
	end
	speed = math.floor(speed)

	local cooldown = DASH.Cooldown - melee * DASH.CooldownPerLevel * (1 + getPerk(data, "BuffDash") * DASH.PerkScale)
	cooldown = math.max(cooldown, DASH.Duration)
	owned.Dash = now + cooldown

	entity:SetStatus(DASH.Status, true, DASH.Duration, true)
	MovementService.Client.Dashed:Fire(player, offset.Unit, speed, cooldown)
end

local function parseBarrier(value: any): (CFrame?, Vector3?)
	if type(value) ~= "string" then
		return nil, nil
	end

	local fields = string.split(value, "|")
	if fields[1] ~= BARRIER_ROOM then
		return nil, nil
	end

	local numbers = table.create(9)
	for index = 2, 10 do
		local number = tonumber(fields[index])
		if not number then
			return nil, nil
		end
		numbers[index - 1] = number
	end

	local position = Vector3.new(numbers[1], numbers[2], numbers[3])
	local look = Vector3.new(numbers[4], numbers[5], numbers[6])
	local size = Vector3.new(numbers[7], numbers[8], numbers[9])
	-- Same construction as the Barrier fruit's own frame.
	local cframe = if look.Magnitude < 1e-3
		then CFrame.new(position)
		elseif math.abs(look.Unit.Y) > 0.999 then CFrame.lookAt(position, position + look.Unit, Vector3.xAxis)
		else CFrame.lookAt(position, position + look.Unit)
	return cframe, size
end

local function isInsideBox(cframe: CFrame, size: Vector3, point: Vector3): boolean
	local localPoint = cframe:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= size.X / 2
		and math.abs(localPoint.Y) <= size.Y / 2
		and math.abs(localPoint.Z) <= size.Z / 2
end

-- True when going from `origin` to `destination` would pass the wall of any Barrier Room.
local function crossesBarrierRoom(origin: Vector3, destination: Vector3): boolean
	for _, other in CharacterService:GetEntities() do
		local cframe, size = parseBarrier(other:GetStatus(BARRIER_STATUS))
		if cframe and size and isInsideBox(cframe, size, origin) ~= isInsideBox(cframe, size, destination) then
			return true
		end
	end
	return false
end

-- Center and radius of the character's own Snow Globe ("<x>,<y>,<z>|<radius>|<colors>").
local function getSnowGlobe(entity: CharacterEntity): (Vector3?, number)
	local value = entity:GetStatus(SHAVE.Snow.Status)
	if type(value) ~= "string" then
		return nil, 0
	end

	local fields = string.split(value, "|")
	local coordinates = string.split(fields[1] or "", ",")
	local x, y, z = tonumber(coordinates[1]), tonumber(coordinates[2]), tonumber(coordinates[3])
	local radius = tonumber(fields[2])
	if not x or not y or not z or not radius then
		return nil, 0
	end
	return Vector3.new(x, y, z), radius
end

local function onShave(player: Player, aim: unknown)
	local entity, data, aimPosition = getActor(player, aim)
	if not entity or not data then
		return
	end

	local melee = data.Data.Skills.Melee.Level
	local owned = getCooldowns(player)
	local now = os.clock()
	if melee < SHAVE.Requirement or now < owned.Shave or isSlowed(entity) then
		return
	end

	local origin = entity.Root.Position
	local destination = aimPosition + Vector3.new(0, SHAVE.LandingHeight, 0)
	if destination.Y < WorldConfig.SeaFloor then
		return
	end

	local reach = math.clamp(melee * SHAVE.PerLevel, SHAVE.Min, SHAVE.Max)
	local cooldown = SHAVE.Cooldown
	local colors = "None"

	local rumble = SHAVE.Rumble
	local rumbleSlot, rumbleAffinity, rumbleColors = findFruit(data, rumble.Fruit)
	if rumbleSlot then
		reach = math.clamp(melee * rumble.PerLevel * rumbleAffinity, rumble.Min, rumble.Max)
		cooldown = rumble.Cooldown - rumble.CooldownPerAffinity * rumbleAffinity
		colors = rumbleColors
	end

	local gum = SHAVE.Gum
	local gumSlot, gumAffinity = findFruit(data, gum.Fruit)
	local inSecondGear = gumSlot ~= nil and entity:HasStatus(gum.Status)
	if inSecondGear then
		reach *= gumAffinity ^ gumAffinity
	end

	local snowStatue: string? = nil
	local snowSlot, _, snowColors = findFruit(data, SHAVE.Snow.Fruit)
	if snowSlot then
		local center, radius = getSnowGlobe(entity)
		if center and (origin - center).Magnitude <= radius and (aimPosition - center).Magnitude <= radius then
			reach = radius * 2
			snowStatue = snowColors
		end
	end

	-- Out of reach or through a barrier: refused without spending the cooldown, as before.
	local distance = (destination - origin).Magnitude
	if distance > reach or crossesBarrierRoom(origin, destination) then
		return
	end

	cooldown *= 1 - getPerk(data, "BuffShave") * SHAVE.PerkScale
	owned.Shave = now + math.max(cooldown, 0)

	local rotation = entity.Root.CFrame.Rotation
	CharacterService:Teleport(entity, CFrame.new(destination) * rotation)

	if inSecondGear then
		-- The legacy cost could take the last health without going through the damage
		-- pipeline (no kill credit, no Phoenix egg). It stops at 1 health here.
		entity:TakeDamage(math.min(gum.HealthCost, entity.Health - 1))
	end

	EffectService:Play(SHAVE.Effect, origin, {
		Caster = entity.Model,
		Destination = destination,
		Rotation = rotation,
		Rumble = rumbleSlot ~= nil,
		Colors = colors,
		SnowStatue = snowStatue,
	}, AbilityConfig.EffectRadius + distance)

	MovementService.Client.Shaved:Fire(player, math.max(cooldown, 0))
end

-- Seconds until `player` may dash / shave again (0 when ready). For other server systems.
function MovementService:GetCooldown(player: Player, technique: "Dash" | "Shave"): number
	local owned = cooldowns[player]
	return if owned then math.max(0, owned[technique] - os.clock()) else 0
end

function MovementService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	EffectService = Knit.GetService("EffectService")
	StatusService = Knit.GetService("StatusService")
end

function MovementService:KnitStart()
	MovementService.Client.Dash:Connect(onDash)
	MovementService.Client.Shave:Connect(onShave)

	Players.PlayerRemoving:Connect(function(player: Player)
		cooldowns[player] = nil
		requestLimiter:Forget(player)
	end)
end

return MovementService
