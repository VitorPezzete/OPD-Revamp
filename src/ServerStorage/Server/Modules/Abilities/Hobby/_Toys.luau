--!strict
--[[
	Hobby fruit - the registry of who is whose toy, shared by the fruit's abilities and
	its passive. Not an ability: the leading underscore keeps it apart from the modules
	AbilityService looks up by ability name.

	The legacy script kept one `hobbies` table, one `Killorder` counter and one death
	connection per character script and trusted the client for the kill target. Here
	every relation is owner entity -> toy entity, and nothing a client sends is more
	than an aim point that AbilityService already validated.

	A toy is either
	- a transformed victim (player or NPC): powers sealed (under the fruit's own seal
	  source, so no other seal ending can give them back), "HobbyToy" status replicated
	  for the look. NPC victims are also rooted, which is what makes EnemyService leave
	  them alone (it skips rooted enemies); or
	- a claimed toy soldier: an NPC summoned by Claim, registered with CharacterService.

	Orders (Command / Target) are one bounded 4 Hz tick per owner that walks every toy
	towards the goal. Player toys are walked through the replicated "HobbyWalk" status
	(their own client moves them) and lose their controls through "HobbyControlled";
	NPC toys are driven directly. While an order runs an NPC toy's WalkSpeed is written
	directly on the humanoid: it has to stay "rooted" for EnemyService, and the entity
	has no way to walk while rooted.

	Statuses (all replicated):
	  HobbyToy         on a transformed victim: the owner's fruit colors
	  HobbyControlled  on a player toy that received an order: "<Move|Focus|Special>|<n>"
	  HobbyWalk        on a player toy: Vector3 it must walk to
	  HobbyClaimed     on a claimed toy soldier: the owner's fruit colors
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local World = require(ReplicatedStorage.Shared.Util.World)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local EnemyConfig = require(ServerStorage.Server.Configs.EnemyConfig)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

export type Toy = {
	Entity: CharacterEntity,
	Owner: CharacterEntity,
	Claimed: boolean,
	-- Claimed toys carry the attack of the player they were made from.
	Damage: number?,
	Trait: CombatTypes.DamageTrait?,
	-- Speed an NPC toy walks at while following an order.
	WalkSpeed: number,
	LastHit: number,
	DiedConnection: any,
}

local TOY_STATUS = "HobbyToy"
local CONTROLLED_STATUS = "HobbyControlled"
local WALK_STATUS = "HobbyWalk"
local CLAIMED_STATUS = "HobbyClaimed"
-- Replicated by HakiService while observation haki is on: such a target cannot be transformed.
local OBSERVATION_STATUS = "UsingObs"

local TICK = 0.25
local ARRIVE_DISTANCE = 4
-- A toy within this distance of the kill target hits it...
local ATTACK_DISTANCE = 10
-- ...at most this often.
local ATTACK_COOLDOWN = 0.5
-- Player toys above this haki level hit as haki, for double damage.
local HAKI_LEVEL = 200
local HAKI_MULTIPLIER = 2
-- Orders are bounded. A walk lasts what the legacy single Humanoid:MoveTo did before it
-- gave up; the legacy kill loops ran on Heartbeat until the target died.
local MOVE_TIMEOUT = 8
local KILL_TIMEOUT = 120
-- Every seal on a toy is this fruit's own: lifting it never lifts someone else's.
local SEAL_SOURCE = "HobbyToy"

local CLAIMED_WALK_SPEED = 16
local CLAIMED_CORPSE_SECONDS = 3
local MAX_CLAIMED = 6

local Toys = {}

Toys.MaxClaimed = MAX_CLAIMED

local toysByOwner: { [CharacterEntity]: { [CharacterEntity]: Toy } } = {}
local toyByEntity: { [CharacterEntity]: Toy } = {}
-- Bumped to invalidate the running order of an owner.
local runs: { [CharacterEntity]: number } = setmetatable({}, { __mode = "k" }) :: any
local hooked = false

local function bump(owner: CharacterEntity): number
	local run = (runs[owner] or 0) + 1
	runs[owner] = run
	return run
end

-- NPC toys stand still again; player toys stop being walked.
local function settle(owner: CharacterEntity)
	local owned = toysByOwner[owner]
	if not owned then
		return
	end
	for entity in owned do
		if entity.Dead then
			continue
		end
		if entity.Player then
			entity:ClearStatus(WALK_STATUS)
		else
			-- Re-applies the root, which puts WalkSpeed back to 0.
			entity:SetRooted(TOY_STATUS, true)
			entity.Humanoid:MoveTo(entity.Root.Position)
		end
	end
end

local function remove(toy: Toy, restore: boolean)
	local entity = toy.Entity
	if toyByEntity[entity] ~= toy then
		return
	end
	toyByEntity[entity] = nil

	local owned = toysByOwner[toy.Owner]
	if owned then
		owned[entity] = nil
		if next(owned) == nil then
			toysByOwner[toy.Owner] = nil
			bump(toy.Owner)
		end
	end

	if toy.DiedConnection then
		toy.DiedConnection:Disconnect()
		toy.DiedConnection = nil
	end

	if not restore then
		return
	end
	if toy.Claimed then
		entity.Model:Destroy()
		return
	end

	entity:ClearStatus(TOY_STATUS)
	entity:ClearStatus(CONTROLLED_STATUS)
	entity:ClearStatus(WALK_STATUS)
	entity:SetRooted(TOY_STATUS, false)
	Knit.GetService("AbilityService"):SetSealed(entity, false, nil, SEAL_SOURCE)
end

local function register(toy: Toy)
	local owned = toysByOwner[toy.Owner]
	if not owned then
		owned = {}
		toysByOwner[toy.Owner] = owned
	end
	owned[toy.Entity] = toy
	toyByEntity[toy.Entity] = toy

	toy.DiedConnection = toy.Entity.Died:Connect(function()
		-- A dead victim keeps its toy look until it respawns, as before.
		remove(toy, false)
		if toy.Claimed then
			local model = toy.Entity.Model
			task.delay(CLAIMED_CORPSE_SECONDS, function()
				model:Destroy()
			end)
		end
	end)
end

local function hook()
	if hooked then
		return
	end
	hooked = true

	Knit.GetService("CharacterService").EntityRemoving:Connect(function(entity: CharacterEntity)
		local toy = toyByEntity[entity]
		if toy then
			remove(toy, false)
		end
		if toysByOwner[entity] then
			Toys.ReleaseAll(entity)
		end
	end)
end

local function getAttack(toy: Toy): (number, CombatTypes.DamageTrait)
	if toy.Damage then
		return toy.Damage, toy.Trait or "Melee"
	end

	local entity = toy.Entity
	if entity.Player then
		local amount = entity.Levels.Melee
		if entity.Levels.Haki > HAKI_LEVEL then
			return amount * HAKI_MULTIPLIER, "Haki"
		end
		return amount, "Melee"
	end

	local definition = (EnemyConfig :: any)[entity.Model.Name]
	if definition then
		return definition.Damage, definition.DamageTrait
	end
	return entity.Levels.Melee, "Melee"
end

-- Starts an order for every toy of the owner, replacing the previous one.
local function order(owner: CharacterEntity, label: string, position: Vector3?, target: CharacterEntity?)
	local owned = toysByOwner[owner]
	if not owned then
		return
	end

	local run = bump(owner)
	for entity in owned do
		if entity.Player and not entity.Dead then
			entity:SetStatus(CONTROLLED_STATUS, `{label}|{run}`, nil, true)
		end
	end

	local deadline = os.clock() + (if target then KILL_TIMEOUT else MOVE_TIMEOUT)

	local function finish()
		if runs[owner] == run then
			bump(owner)
			settle(owner)
		end
	end

	local function step()
		if runs[owner] ~= run then
			return
		end

		local current = toysByOwner[owner]
		if not current or owner.Dead or os.clock() >= deadline then
			finish()
			return
		end

		local goal = position
		if target then
			if target.Dead or not target.Spawned or target.Model.Parent == nil then
				finish()
				return
			end
			goal = target.Root.Position
		end
		if not goal then
			finish()
			return
		end

		local now = os.clock()
		local moving = false
		for entity, toy in current do
			if entity.Dead or entity == target then
				continue
			end

			local humanoid = entity.Humanoid
			if entity.Player then
				entity:SetStatus(WALK_STATUS, goal, nil, true)
			else
				humanoid.WalkSpeed = toy.WalkSpeed
			end
			if humanoid.Sit then
				humanoid.Jump = true
			end
			humanoid:MoveTo(goal)

			local distance = (goal - entity.Root.Position).Magnitude
			if distance > ARRIVE_DISTANCE then
				moving = true
			end

			if target and distance < ATTACK_DISTANCE and now - toy.LastHit >= ATTACK_COOLDOWN then
				toy.LastHit = now
				local amount, trait = getAttack(toy)
				-- Credited to the owner, like every kill made through a toy.
				Knit.GetService("CombatService"):Damage({
					Target = target,
					Attacker = owner,
					Amount = amount,
					Trait = trait,
					Style = "Ability",
					Dodgeable = false,
					Tag = "HobbyToy",
				})
			end
		end

		if not target and not moving then
			finish()
			return
		end
		task.delay(TICK, step)
	end
	step()
end

function Toys.IsToy(entity: CharacterEntity): boolean
	return toyByEntity[entity] ~= nil
end

function Toys.GetOwner(entity: CharacterEntity): CharacterEntity?
	local toy = toyByEntity[entity]
	return if toy then toy.Owner else nil
end

-- Snapshot, safe to iterate while toys are added or removed.
function Toys.List(owner: CharacterEntity): { Toy }
	local list: { Toy } = {}
	local owned = toysByOwner[owner]
	if owned then
		for _, toy in owned do
			table.insert(list, toy)
		end
	end
	return list
end

function Toys.CountClaimed(owner: CharacterEntity): number
	local count = 0
	local owned = toysByOwner[owner]
	if owned then
		for _, toy in owned do
			if toy.Claimed then
				count += 1
			end
		end
	end
	return count
end

-- Turns a character into the owner's toy. False when it cannot be (already a toy,
-- observation haki on, dead). Team mates can be transformed, as in the legacy game.
function Toys.Transform(owner: CharacterEntity, victim: CharacterEntity, colors: string): boolean
	if victim == owner or victim.Dead or not victim.Spawned or owner.Dead then
		return false
	end
	if toyByEntity[victim] or victim:HasStatus(OBSERVATION_STATUS) then
		return false
	end
	-- A toy cannot make toys of its own owner.
	local ownerRecord = toyByEntity[owner]
	if ownerRecord and ownerRecord.Owner == victim then
		return false
	end

	hook()

	local toy: Toy = {
		Entity = victim,
		Owner = owner,
		Claimed = false,
		Damage = nil,
		Trait = nil,
		-- A victim caught while rooted / stunned reads 0: fall back to the default.
		WalkSpeed = if victim.Humanoid.WalkSpeed >= 1 then victim.Humanoid.WalkSpeed else CLAIMED_WALK_SPEED,
		LastHit = 0,
		DiedConnection = nil,
	}
	register(toy)

	Knit.GetService("AbilityService"):SetSealed(victim, true, nil, SEAL_SOURCE)
	victim:SetStatus(TOY_STATUS, colors, nil, true)
	if not victim.Player then
		victim:SetRooted(TOY_STATUS, true)
	end
	return true
end

-- Frees every toy of the owner; claimed toy soldiers are removed.
function Toys.ReleaseAll(owner: CharacterEntity)
	bump(owner)
	for _, toy in Toys.List(owner) do
		remove(toy, true)
	end
end

-- "Go there": every toy walks to the point.
function Toys.Command(owner: CharacterEntity, position: Vector3)
	order(owner, "Move", position, nil)
end

-- "Kill him": every toy chases the target and hits it when close.
function Toys.Attack(owner: CharacterEntity, target: CharacterEntity)
	order(owner, "Focus", nil, target)
end

-- Cancels the running order, if any.
function Toys.Halt(owner: CharacterEntity)
	if toysByOwner[owner] then
		bump(owner)
		settle(owner)
	end
end

--[[
	Replaces a transformed player with a toy soldier that keeps serving the owner, and
	kills the player. Returns false when it cannot be done (not a player toy, the cap is
	reached, the soldier model is missing): the victim is then left untouched.
]]
function Toys.Claim(
	owner: CharacterEntity,
	toy: Toy,
	healthMultiplier: number,
	damageBonus: number,
	colors: string
): boolean
	local victim = toy.Entity
	if toyByEntity[victim] ~= toy or toy.Claimed or toy.Owner ~= owner then
		return false
	end
	if not victim.Player or victim.Dead or not victim.Spawned then
		return false
	end
	if Toys.CountClaimed(owner) >= MAX_CLAIMED then
		return false
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local fruits = models and models:FindFirstChild("Fruits")
	local fruit = fruits and fruits:FindFirstChild("Hobby")
	local folder = fruit and fruit:FindFirstChild("Power5")
	local template = folder and folder:FindFirstChild("Toy")
	if not template or not template:IsA("Model") then
		return false
	end

	local model = template:Clone()
	-- The legacy model carried its own Animate / health scripts.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	model.Name = "Toy"
	model:PivotTo(victim.Root.CFrame)
	-- Workspace.Alive.NPCs is where clients look for NPCs (status effects, nameplates).
	model.Parent = World.Alive("NPCs") or Workspace

	-- All-zero levels: killing a toy soldier is worth no reward.
	local soldier = Knit.GetService("CharacterService"):RegisterNPC(
		model,
		{ Melee = 0, Defense = 0, Sniper = 0, Sword = 0, Haki = 0, Special = 0 }
	)
	if not soldier then
		model:Destroy()
		return false
	end

	soldier:SetBaseMaxHealth(math.max(1, victim.MaxHealth * healthMultiplier))
	soldier:SetBaseWalkSpeed(CLAIMED_WALK_SPEED)
	soldier.Team = owner.Team
	soldier:SetRooted(TOY_STATUS, true)
	soldier:SetStatus(CLAIMED_STATUS, colors, nil, true)
	pcall(function()
		soldier.Root:SetNetworkOwner(nil)
	end)

	-- The legacy line was `level * 1 + (.25 * affinity)` (`level * 2 * 1 + ...` with
	-- haki): the victim's level, doubled by haki, plus a fraction of a point.
	local damage = victim.Levels.Melee
	local trait: CombatTypes.DamageTrait = "Melee"
	if victim.Levels.Haki > HAKI_LEVEL then
		damage *= HAKI_MULTIPLIER
		trait = "Haki"
	end
	damage += damageBonus

	-- The player stops being a toy and dies; no kill is credited, as before.
	remove(toy, false)
	victim:SetStatus(CONTROLLED_STATUS, "Special|0", nil, true)
	victim:Kill()

	register({
		Entity = soldier,
		Owner = owner,
		Claimed = true,
		Damage = damage,
		Trait = trait,
		WalkSpeed = CLAIMED_WALK_SPEED,
		LastHit = 0,
		DiedConnection = nil,
	})
	return true
end

return Toys
