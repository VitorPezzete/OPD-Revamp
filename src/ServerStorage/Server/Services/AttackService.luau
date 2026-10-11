--!strict
--[[
	Attacks of the equipped weapon: basic attacks (punches, sword swings, shots) and the
	special attack of the weapons that have one.

	The client only says "attack" or "special" and where it is aiming. Which weapon, its
	damage, cooldown and hitbox are resolved on the server from the tool the character is
	actually holding. The legacy tools each carried their own Script (42 copies of
	nearly the same code); what really differed between them is now data (WeaponConfig,
	AttackConfig) plus one small module per weapon with unique logic
	(Server.Modules.Weapons.<Weapon>, see Types.WeaponTypes).

	Basic attack damage
		(weapon damage + level scale * level of the slot's skill), or the module's formula.
		Armament haki doubles it and makes it Haki damage. The BuffWeapons perk adds 1% per
		point (legacy applied it in most weapon scripts but forgot it in others).

	Special attack (legacy "special function" key, SlashCooldown)
		Needs the level in AttackConfig.Specials, unsealed fruit powers (unless the weapon
		ignores seals) and a valid aim. One cooldown per weapon slot, shared by every weapon
		of the slot as the legacy per-character SlashCooldown was: swapping swords does not
		reset it.

	Swing trails: the fighting styles and Kanshou and Bakuya drew a trail on every basic
	attack (a part with a Trail cloned into the striking limb by the legacy server; the
	blade trails switched on). The server now only says "this character swung" and each
	client draws it (Effects.OneShot.WeaponSwingTrail).

	Legacy holes closed here: every tool listened to the same global remote, so one press
	ran the handler of every sword script alive on the server; the remote carried a
	target part chosen by the client (Ice Dagger homed on it at any distance); cooldowns
	of several tools lived in script variables shared by all their users.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AttackConfig = require(ReplicatedStorage.Shared.Configs.AttackConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local ThrownSlashes = require(ServerStorage.Server.Modules.ThrownSlashes)
local WeaponShared = require(ServerStorage.Server.Modules.Weapons._Shared)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)

type CharacterEntity = CharacterEntity.CharacterEntity
type WeaponContext = WeaponTypes.WeaponContext
type WeaponBehaviour = WeaponTypes.WeaponBehaviour

local SLOT_ATTRIBUTE = "WeaponSlot"
local STUN_STATUS = "Stunned"
-- A phoenix reborn in its egg cannot swing (legacy PhoenixEgg check in every tool).
local EGG_STATUS = "PhoenixEgg"
-- Size multiplier of a character resized by the More fruit: its sword reach grows with it.
local SIZE_STATUS = "MoreMored"
-- Shown to players who turned the "Hitbox" setting on.
local HITBOX_EFFECT = "WeaponHitbox"
local SLASH_EFFECT = "WeaponSlash"
local SWING_TRAIL_EFFECT = "WeaponSwingTrail"
-- Weapons whose basic attack leaves a trail (the only legacy tool scripts that had one).
local SWING_TRAILS: { [string]: boolean } = {
	Melee = true,
	["Black Leg"] = true,
	["Table Kick"] = true,
	["Kanshou and Bakuya"] = true,
}
local MIN_SLASH_SCALE = 0.05

local AttackService = Knit.CreateService({
	Name = "AttackService",
	Client = {
		-- Client -> server: (aimPosition)
		Attack = Knit.CreateSignal(),
		-- Client -> server: (aimPosition)
		Special = Knit.CreateSignal(),
		-- Server -> owner: (weaponName, cooldown) when a special attack was accepted.
		SpecialUsed = Knit.CreateSignal(),
	},
})

-- (attacker, weaponName, targets hit) after every landed melee / sword attack.
AttackService.Landed = Signal.new() :: Signal.Signal<CharacterEntity, string, { CharacterEntity }>
-- (user, weaponName) after every accepted special attack.
AttackService.SpecialUsed = Signal.new() :: Signal.Signal<CharacterEntity, string>

local DataService
local CharacterService
local CombatService
local StatService
local HakiService
local EffectService
local SettingsService

local services: { [string]: any } = {}
local behaviours: { [string]: WeaponBehaviour } = {}
local noBehaviour: WeaponBehaviour = {}

-- Per player, per weapon slot: swapping weapons does not carry a cooldown over.
local lastAttack: { [Player]: { [string]: number } } = {}
local specialReady: { [Player]: { [string]: number } } = {}
-- Side of the next trailed swing: the legacy tools alternated left, right, left...
local swingRight: { [Player]: boolean } = {}
-- Fast blades swing up to 10 times per second.
local attackLimiter = RateLimiter.new(12, 10)
local specialLimiter = RateLimiter.new(6, 3)

local function getHeldWeapon(entity: CharacterEntity): (Tool?, WeaponConfig.WeaponDefinition?)
	local tool = entity.Model:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute(SLOT_ATTRIBUTE) == nil then
		return nil, nil
	end
	return tool, WeaponConfig.Weapons[tool.Name]
end

local function isFiniteVector(value: Vector3): boolean
	return value.X == value.X and value.Y == value.Y and value.Z == value.Z and value.Magnitude < math.huge
end

-- The aim point when it is a sane one, else nil.
local function readAim(entity: CharacterEntity, aim: unknown): Vector3?
	if typeof(aim) ~= "Vector3" or not isFiniteVector(aim :: Vector3) then
		return nil
	end
	local offset = (aim :: Vector3) - entity.Root.Position
	local distance = offset.Magnitude
	if distance > AbilityConfig.HardMaxAimDistance or distance < 1e-3 then
		return nil
	end
	-- Aimed further than a weapon reaches (the sky, the horizon): same direction, at the limit.
	if distance > AbilityConfig.MaxAimDistance then
		return entity.Root.Position + offset.Unit * AbilityConfig.MaxAimDistance
	end
	return aim :: Vector3
end

local function isHolding(context: WeaponContext): boolean
	return not context.Entity.Dead and context.Tool.Parent == context.Entity.Model
end

local function buildContext(
	player: Player,
	entity: CharacterEntity,
	data: PlayerData.PlayerData,
	tool: Tool,
	weapon: WeaponConfig.WeaponDefinition,
	skill: string,
	aim: Vector3
): WeaponContext
	local haki = HakiService:IsArmamentActive(entity)
	local perk = data.Data.Expertise.Perks.BuffWeapons.Value
	return {
		Player = player,
		Entity = entity,
		Data = data,
		Tool = tool,
		WeaponName = tool.Name,
		Weapon = weapon,
		Level = data.Data.Skills[skill :: any].Level,
		Haki = haki,
		HakiMultiplier = if haki then AttackConfig.HakiMultiplier else 1,
		PerkMultiplier = (weapon.PerkBase or 1) + perk * AttackConfig.WeaponPerkPerPoint,
		Aim = aim,
		Services = services,
		IsHolding = isHolding,
	}
end

local function showHitbox(context: WeaponContext, cframe: CFrame, size: Vector3)
	-- The setting left the settings menu; the developer menu can still turn it on.
	if SettingsService:Get(context.Player, "Hitbox") == true then
		EffectService.Client.Play:Fire(context.Player, HITBOX_EFFECT, cframe.Position, { CFrame = cframe, Size = size })
	end
end

--[[
	Tells the clients around to draw the trail of this swing. `Right` is only the
	fallback side: the client follows the swing clip it sees when there is one.
]]
local function showSwingTrail(context: WeaponContext)
	local player = context.Player
	local right = swingRight[player] == true
	swingRight[player] = not right
	EffectService:Play(SWING_TRAIL_EFFECT, context.Entity.Root.Position, {
		Caster = context.Entity.Model,
		Weapon = context.WeaponName,
		Right = right,
	})
end

local function swing(context: WeaponContext, attack: AttackConfig.AttackDefinition, damage: number, trait: CombatTypes.DamageTrait)
	local entity = context.Entity
	local behaviour = behaviours[context.WeaponName] or noBehaviour
	local size = attack.HitboxSize :: Vector3
	local distance = attack.HitboxDistance :: number

	if context.Weapon.Slot == "Sword" then
		-- Legacy SwordHitbox: box scaled by the giant's size and pushed size^2 / 2 forward.
		local scale = entity:GetStatus(SIZE_STATUS)
		if type(scale) == "number" and scale > 0 then
			size *= scale
			distance += scale * scale / 2
		end
	end

	local cframe = entity.Root.CFrame * CFrame.new(0, 0, -distance)
	showHitbox(context, cframe, size)

	local targets = Hitbox.Box(cframe, size, entity)
	if attack.SingleTarget then
		local closest = Hitbox.Closest(targets, entity.Root.Position)
		targets = if closest then { closest } else {}
	end

	for _, target in targets do
		local dealt = CombatService:Damage({
			Target = target,
			Attacker = entity,
			Amount = damage,
			Trait = trait,
			Style = "Weapon",
			Dodgeable = not attack.Undodgeable,
			Tag = if attack.SlashTag then "Slash" else nil,
		})
		if behaviour.OnHit then
			behaviour.OnHit(context, target, dealt)
		end
	end
	if #targets > 0 then
		AttackService.Landed:Fire(entity, context.WeaponName, targets)
	end
end

local function shoot(context: WeaponContext, attack: AttackConfig.AttackDefinition, damage: number, trait: CombatTypes.DamageTrait)
	local entity = context.Entity
	local behaviour = behaviours[context.WeaponName] or noBehaviour
	local origin = entity.Root.Position
	local speed = attack.ProjectileSpeed :: number
	local range = math.min(attack.ProjectileRange :: number, AttackConfig.MaxProjectileRange)
	local direction = Projectile.Lead(entity, origin, (context.Aim - origin).Unit, speed, range)

	EffectService:Play(attack.ProjectileEffect or "Bullet", origin, {
		Direction = direction,
		Speed = speed,
		Range = range,
		Weapon = context.WeaponName,
		Caster = entity.Model,
	})
	Projectile.Fire({
		Origin = origin,
		Direction = direction,
		Speed = speed,
		MaxDistance = range,
		Owner = entity,
		IgnoreWorld = attack.ProjectileIgnoreWorld,
		OnHit = function(target: CharacterEntity)
			local dealt = CombatService:Damage({
				Target = target,
				Attacker = entity,
				Amount = damage,
				Trait = trait,
				Style = "Weapon",
				Dodgeable = not attack.Undodgeable,
			})
			if behaviour.OnHit then
				behaviour.OnHit(context, target, dealt)
			end
		end,
	})
end

local function onAttack(player: Player, aim: unknown)
	if not attackLimiter:Consume(player) then
		return
	end

	local entity = CharacterService:GetPlayerEntity(player)
	local data = DataService:GetData(player)
	if not entity or not data or entity.Dead or not entity.Spawned or entity:IsRooted() or entity:HasStatus(EGG_STATUS) then
		return
	end

	local tool, weapon = getHeldWeapon(entity)
	if not tool or not weapon or weapon.Slot == "Utility" then
		return
	end
	local attack: AttackConfig.AttackDefinition? = AttackConfig.Get(tool.Name, weapon.Slot)
	if not attack then
		return
	end

	-- Shots need a real aim; swings only face where the character faces.
	local aimPoint = readAim(entity, aim)
	if not aimPoint then
		if weapon.Slot == "Sniper" then
			return
		end
		aimPoint = entity.Root.Position + entity.Root.CFrame.LookVector * 10
	end

	local context = buildContext(player, entity, data, tool, weapon, attack.Skill, aimPoint :: Vector3)
	local behaviour = behaviours[tool.Name] or noBehaviour
	if behaviour.CanUse and not behaviour.CanUse(context) then
		return
	end

	local now = os.clock()
	local history = lastAttack[player]
	if not history then
		history = {}
		lastAttack[player] = history
	end
	if now - (history[weapon.Slot] or 0) < attack.Cooldown then
		return
	end
	history[weapon.Slot] = now

	local damage = weapon.Damage + (weapon.LevelScale or 1) * context.Level
	if behaviour.GetDamage then
		damage = behaviour.GetDamage(context, damage)
	end

	local trait: CombatTypes.DamageTrait = weapon.Trait
	if weapon.Slot == "Melee" then
		-- Fruits can change what a bare-handed hit is made of (Dark punches are Special
		-- and scale with its melee affinity) by setting these statuses from their passive.
		local override = entity:GetStatus("MeleeTraitOverride")
		if override == "Special" or override == "Sword" then
			trait = override
		end
		local multiplier = entity:GetStatus("MeleeDamageMultiplier")
		if type(multiplier) == "number" then
			damage *= multiplier
		end
	end
	if context.Haki then
		damage *= context.HakiMultiplier
		trait = "Haki"
	end
	damage *= context.PerkMultiplier

	StatService:AddExp(player, attack.Skill, attack.ExpPerUse, true)

	if SWING_TRAILS[tool.Name] then
		showSwingTrail(context)
	end

	if weapon.Slot == "Sniper" then
		shoot(context, attack, damage, trait)
	elseif attack.HitDelay then
		-- Heavy weapons hit at the end of their wind-up, if still held by then.
		task.delay(attack.HitDelay, function()
			if context:IsHolding() and entity.Spawned then
				swing(context, attack, damage, trait)
			end
		end)
	else
		swing(context, attack, damage, trait)
	end
end

-- Template size of a slash, as the box swept by the server: X width, Y height, Z depth.
local function getSlashSize(assetName: string, scale: number): Vector3
	local template = WeaponShared.FindAsset(assetName)
	local size: Vector3 = AttackConfig.SlashFallbackSize
	if template and template:IsA("BasePart") then
		size = template.Size
	elseif template and template:IsA("Model") then
		size = template:GetExtentsSize()
	end
	-- The legacy part flew sideways: its X axis was the flight direction.
	return Vector3.new(size.Z, size.Y, size.X) * scale
end

-- The generic sword special: a blade thrown along the aim that cuts whoever it crosses.
local function throwSlash(context: WeaponContext, slash: AttackConfig.SlashDefinition): boolean
	local entity = context.Entity
	local behaviour = behaviours[context.WeaponName] or noBehaviour
	local direction = (context.Aim - entity.Root.Position).Unit
	local origin = entity.Root.Position + direction * (slash.Forward or 0)
	local scale = math.max(context.Level / AttackConfig.SlashFullLevel, MIN_SLASH_SCALE)
	local lifetime = math.min(slash.Lifetime, AttackConfig.MaxProjectileRange / slash.Speed)

	local damage = (slash.Damage + slash.LevelScale * context.Level) * context.PerkMultiplier
	local trait: CombatTypes.DamageTrait = slash.Trait
	if context.Haki then
		damage *= slash.HakiMultiplier or AttackConfig.HakiMultiplier
		if slash.HakiTrait ~= false then
			trait = "Haki"
		end
	end

	local params: { [string]: any } = {
		Asset = slash.Asset,
		Direction = direction,
		Speed = slash.Speed,
		Lifetime = lifetime,
		Scale = scale,
		Haki = context.Haki,
		Caster = entity.Model,
	}
	if behaviour.SlashParams then
		for key, value in behaviour.SlashParams(context) or {} do
			params[key] = value
		end
	end
	EffectService:Play(SLASH_EFFECT, origin, params)

	local size = getSlashSize(slash.Asset, scale)
	-- The slash is something that can be held while it flies (Gum Rocket onto a Kogatana
	-- slash, as in the old game): its flight is on record for the surface checks.
	ThrownSlashes.Track(origin, direction, slash.Speed, lifetime, size)

	WeaponShared.Sweep(entity, origin, direction, slash.Speed, lifetime, size, function(target: CharacterEntity): boolean?
		CombatService:Damage({
			Target = target,
			Attacker = entity,
			Amount = damage,
			Trait = trait,
			Style = "Weapon",
			Dodgeable = not slash.Undodgeable,
		})
		if behaviour.OnSlashHit then
			behaviour.OnSlashHit(context, target)
		end
		return slash.SingleTarget
	end)
	return true
end

local function onSpecial(player: Player, aim: unknown)
	if not specialLimiter:Consume(player) then
		return
	end

	local entity = CharacterService:GetPlayerEntity(player)
	local data = DataService:GetData(player)
	if not entity or not data or entity.Dead or not entity.Spawned or entity:HasStatus(STUN_STATUS) or entity:HasStatus(EGG_STATUS) then
		return
	end

	local tool, weapon = getHeldWeapon(entity)
	local special: AttackConfig.SpecialDefinition? = if tool then AttackConfig.Specials[tool.Name] else nil
	local slotDefaults: AttackConfig.AttackDefinition? = if weapon then AttackConfig[weapon.Slot] else nil
	if not tool or not weapon or not special or not slotDefaults then
		return
	end

	local behaviour = behaviours[tool.Name] or noBehaviour
	if not special.Slash and not behaviour.Special then
		return
	end
	if data.Data.Skills[slotDefaults.Skill].Level < special.LevelRequirement then
		return
	end
	if not special.IgnoreSeal and entity:HasStatus(AbilityConfig.Status.AbilitiesDisabled) then
		return
	end

	local aimPoint = readAim(entity, aim)
	if not aimPoint then
		return
	end

	local context = buildContext(player, entity, data, tool, weapon, slotDefaults.Skill, aimPoint)
	if behaviour.CanUse and not behaviour.CanUse(context) then
		return
	end

	local now = os.clock()
	local ready = specialReady[player]
	if not ready then
		ready = {}
		specialReady[player] = ready
	end
	local previous = ready[weapon.Slot] or 0
	if now < previous then
		return
	end
	local cooldown = if context.Haki and special.HakiCooldown then special.HakiCooldown else special.Cooldown
	ready[weapon.Slot] = now + cooldown

	local used: boolean?
	if special.Slash then
		used = throwSlash(context, special.Slash)
	else
		used = (behaviour.Special :: any)(context)
	end
	if used == false then
		-- Nothing happened (no target under the aim, ...): the cooldown is not spent.
		ready[weapon.Slot] = previous
		return
	end

	AttackService.Client.SpecialUsed:Fire(player, tool.Name, cooldown)
	AttackService.SpecialUsed:Fire(entity, tool.Name)
end

-- Seconds until `player` can use the special of the weapon slot again.
function AttackService:GetSpecialCooldown(player: Player, slot: string): number
	local ready = specialReady[player]
	return math.max(0, ((ready and ready[slot]) or 0) - os.clock())
end

local function loadBehaviours()
	local folder = ServerStorage.Server.Modules:FindFirstChild("Weapons")
	if not folder then
		return
	end
	for _, module in folder:GetChildren() do
		if module:IsA("ModuleScript") and string.sub(module.Name, 1, 1) ~= "_" then
			local ok, behaviour = pcall(require, module)
			if ok and type(behaviour) == "table" then
				behaviours[module.Name] = behaviour
			else
				warn(`[AttackService] weapon module "{module.Name}" failed to load: {behaviour}`)
			end
		end
	end
end

function AttackService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	CombatService = Knit.GetService("CombatService")
	StatService = Knit.GetService("StatService")
	HakiService = Knit.GetService("HakiService")
	EffectService = Knit.GetService("EffectService")
	SettingsService = Knit.GetService("SettingsService")

	services.Combat = CombatService
	services.Character = CharacterService
	services.Effect = EffectService
	services.Haki = HakiService
	services.Stat = StatService
	services.Data = DataService
	services.Status = Knit.GetService("StatusService")
	services.Fruit = Knit.GetService("FruitService")
	services.Ability = Knit.GetService("AbilityService")
	services.Notify = Knit.GetService("NotifyService")
	services.Attack = AttackService

	loadBehaviours()
end

function AttackService:KnitStart()
	AttackService.Client.Attack:Connect(onAttack)
	AttackService.Client.Special:Connect(onSpecial)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastAttack[player] = nil
		specialReady[player] = nil
		swingRight[player] = nil
		attackLimiter:Forget(player)
		specialLimiter:Forget(player)
	end)
end

return AttackService
