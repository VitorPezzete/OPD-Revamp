--!strict
--[[
	Server-side combat state of one character (player or NPC).

	Replaces the legacy CharacterTrait folder and the ~80 BoolValues cloned into every
	character: health, shield and timed statuses live here as plain fields. Only what
	clients need to render is mirrored, through attributes on the model.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Packages.Signal)
local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)

type Status = { Value: any, ExpiresAt: number }

local CharacterEntity = {}
CharacterEntity.__index = CharacterEntity

export type CharacterEntity = typeof(setmetatable(
	{} :: {
		Model: Model,
		Humanoid: Humanoid,
		Root: BasePart,
		Player: Player?,
		Levels: StatConfig.Levels,

		Health: number,
		MaxHealth: number,
		Shield: number,
		Team: string,
		Spawned: boolean,
		Dead: boolean,

		-- Healing reduction left by the AntiHeal perk; consumed one hit per regen tick.
		AntiHealFraction: number,
		AntiHealHits: number,

		Died: Signal.Signal<()>,
		HealthChanged: Signal.Signal<number, number>,

		_baseMaxHealth: number,
		_maxHealthModifiers: { [string]: number },
		_baseWalkSpeed: number,
		_speedBonuses: { [string]: number },
		_speedScales: { [string]: number },
		_roots: { [string]: boolean },
		_statuses: { [string]: Status },
		_diedConnection: RBXScriptConnection?,
	},
	CharacterEntity
))

function CharacterEntity.new(model: Model, humanoid: Humanoid, root: BasePart, player: Player?): CharacterEntity
	local self = setmetatable({
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Player = player,
		Levels = { Melee = 0, Defense = 0, Sniper = 0, Sword = 0, Haki = 0 },

		Health = 0,
		MaxHealth = 0,
		Shield = 0,
		Team = "",
		Spawned = false,
		Dead = false,

		AntiHealFraction = 0,
		AntiHealHits = 0,

		Died = Signal.new(),
		HealthChanged = Signal.new(),

		_baseMaxHealth = 0,
		_maxHealthModifiers = {},
		_baseWalkSpeed = humanoid.WalkSpeed,
		_speedBonuses = {},
		_speedScales = {},
		_roots = {},
		_statuses = {},
		_diedConnection = nil,
	}, CharacterEntity)

	-- The engine's own death breaks EVERY joint of the model, welds included: clothes,
	-- accessories, shells and weapon models all fell off the limbs. It is turned off, and
	-- Kill takes the body apart itself (dismember): the limbs come off, what they wear stays.
	humanoid.BreakJointsOnDeath = false

	-- Deaths that bypass the entity (void, reset) still have to end it.
	self._diedConnection = humanoid.Died:Connect(function()
		self:Kill()
	end)

	return self
end

function CharacterEntity._replicateHealth(self: CharacterEntity)
	self.Model:SetAttribute("Health", self.Health)
	self.Model:SetAttribute("MaxHealth", self.MaxHealth)
	self.Model:SetAttribute("Shield", self.Shield)
end

function CharacterEntity._recomputeMaxHealth(self: CharacterEntity)
	local maxHealth = self._baseMaxHealth
	for _, multiplier in self._maxHealthModifiers do
		maxHealth *= multiplier
	end

	-- A character that was at full health stays at full health.
	local wasFull = self.Health >= self.MaxHealth
	self.MaxHealth = math.max(1, maxHealth)
	self.Health = if wasFull then self.MaxHealth else math.min(self.Health, self.MaxHealth)
	self:_replicateHealth()
end

function CharacterEntity.SetBaseMaxHealth(self: CharacterEntity, value: number)
	self._baseMaxHealth = value
	self:_recomputeMaxHealth()
end

-- Named multiplier over max health (fruit passives, day/night, etc). Pass nil to remove.
function CharacterEntity.SetMaxHealthModifier(self: CharacterEntity, name: string, multiplier: number?)
	self._maxHealthModifiers[name] = multiplier
	self:_recomputeMaxHealth()
end

-- WalkSpeed = base * (1 + sum of bonuses) * product of scales, or 0 while rooted.
function CharacterEntity._applyMovement(self: CharacterEntity)
	if next(self._roots) ~= nil then
		self.Humanoid.WalkSpeed = 0
		return
	end

	local multiplier = 1
	for _, bonus in self._speedBonuses do
		multiplier += bonus
	end
	for _, scale in self._speedScales do
		multiplier *= scale
	end
	self.Humanoid.WalkSpeed = self._baseWalkSpeed * multiplier
end

function CharacterEntity.SetBaseWalkSpeed(self: CharacterEntity, value: number)
	self._baseWalkSpeed = value
	self:_applyMovement()
end

-- Named additive speed bonus (1 = +100% of base). Pass nil to remove.
function CharacterEntity.SetSpeedBonus(self: CharacterEntity, name: string, bonus: number?)
	self._speedBonuses[name] = bonus
	self:_applyMovement()
end

-- Named multiplicative slow (0.1 = 10% speed). Pass nil to remove.
function CharacterEntity.SetSpeedScale(self: CharacterEntity, name: string, scale: number?)
	self._speedScales[name] = scale
	self:_applyMovement()
end

-- Named root: the character cannot walk while any root is active.
function CharacterEntity.SetRooted(self: CharacterEntity, name: string, rooted: boolean)
	self._roots[name] = if rooted then true else nil
	self:_applyMovement()
end

function CharacterEntity.IsRooted(self: CharacterEntity): boolean
	return next(self._roots) ~= nil
end

function CharacterEntity.GetHealthRatio(self: CharacterEntity): number
	return if self.MaxHealth > 0 then self.Health / self.MaxHealth else 0
end

function CharacterEntity.SetSpawned(self: CharacterEntity, spawned: boolean)
	self.Spawned = spawned
	self.Model:SetAttribute("Spawned", spawned)
end

function CharacterEntity.SetShield(self: CharacterEntity, value: number)
	self.Shield = math.max(0, value)
	self.Model:SetAttribute("Shield", self.Shield)
end

-- Absorbs up to amount with the shield and returns what is left to hit health.
function CharacterEntity.AbsorbWithShield(self: CharacterEntity, amount: number): number
	if self.Shield <= 0 then
		return amount
	end

	local absorbed = math.min(self.Shield, amount)
	self:SetShield(self.Shield - absorbed)
	return amount - absorbed
end

-- Final health subtraction: no mitigation here, that is CombatService's job.
function CharacterEntity.TakeDamage(self: CharacterEntity, amount: number): number
	if self.Dead or amount <= 0 then
		return 0
	end

	local previous = self.Health
	self.Health = math.max(0, previous - amount)
	self:_replicateHealth()
	self.HealthChanged:Fire(self.Health, previous)

	if self.Health <= 0 then
		self:Kill()
	end
	return previous - self.Health
end

function CharacterEntity.Heal(self: CharacterEntity, amount: number): number
	if self.Dead or amount <= 0 or self.Health >= self.MaxHealth then
		return 0
	end

	local previous = self.Health
	self.Health = math.min(self.MaxHealth, previous + amount)
	self:_replicateHealth()
	self.HealthChanged:Fire(self.Health, previous)
	return self.Health - previous
end

-- The joints of an R6 body: the ones a death takes apart.
local BODY_JOINTS: { [string]: boolean } = {
	Neck = true,
	RootJoint = true,
	-- The same joint in the enemy models.
	["Root Hip"] = true,
	["Left Shoulder"] = true,
	["Right Shoulder"] = true,
	["Left Hip"] = true,
	["Right Hip"] = true,
}

--[[
	The classic R6 death: head, arms, legs and torso come apart and fall. Only the body's
	own Motor6Ds are removed (in the Torso and the HumanoidRootPart); every Weld,
	WeldConstraint and other Motor6D is left alone, so whatever is fixed to a limb -
	accessories, clothes, armour and haki shells, weapon models - falls with that limb.
	Models that are not built this way (crabs, boars) have none of these joints and stay
	whole.
]]
local function dismember(model: Model)
	-- No R6 torso with a neck: not a body to take apart.
	local torso = model:FindFirstChild("Torso")
	if not torso or not torso:FindFirstChild("Neck") then
		return
	end
	for _, partName in { "Torso", "HumanoidRootPart" } do
		local part = model:FindFirstChild(partName)
		if part then
			for _, joint in part:GetChildren() do
				if joint:IsA("Motor6D") and BODY_JOINTS[joint.Name] then
					joint:Destroy()
				end
			end
		end
	end
end

function CharacterEntity.Kill(self: CharacterEntity)
	if self.Dead then
		return
	end

	self.Dead = true
	self.Health = 0
	self:_replicateHealth()
	self.Humanoid.Health = 0
	dismember(self.Model)
	self.Died:Fire()
end

-- Timed or permanent flag (stuns, immunities, fruit states). Mirrored only when asked.
function CharacterEntity.SetStatus(self: CharacterEntity, name: string, value: any, duration: number?, replicate: boolean?)
	if value == nil or value == false then
		self:ClearStatus(name)
		return
	end

	local status: Status = {
		Value = value,
		ExpiresAt = if duration then os.clock() + duration else math.huge,
	}
	self._statuses[name] = status
	if replicate then
		self.Model:SetAttribute(name, value)
		if duration then
			-- Server reads expire lazily, but clients only know the attribute: remove it on time.
			task.delay(duration, function()
				if self._statuses[name] == status then
					self:ClearStatus(name)
				end
			end)
		end
	end
end

function CharacterEntity.GetStatus(self: CharacterEntity, name: string): any
	local status = self._statuses[name]
	if not status then
		return nil
	end

	if os.clock() >= status.ExpiresAt then
		self:ClearStatus(name)
		return nil
	end
	return status.Value
end

-- Product of every numeric status whose name starts with `prefix` (1 when there is none).
-- Lets independent systems contribute to one value: "RegenMultiplier", "RegenMultiplierGum"...
function CharacterEntity.GetStatusProduct(self: CharacterEntity, prefix: string): number
	local product = 1
	for name in self._statuses do
		if string.sub(name, 1, #prefix) == prefix then
			local value = self:GetStatus(name)
			if type(value) == "number" then
				product *= value
			end
		end
	end
	return product
end

-- Live statuses with their values and seconds left (math.huge = permanent). For debug tooling.
function CharacterEntity.GetStatuses(self: CharacterEntity): { [string]: { Value: any, TimeLeft: number } }
	local now = os.clock()
	local result = {}
	for name, status in self._statuses do
		if now < status.ExpiresAt then
			result[name] = { Value = status.Value, TimeLeft = status.ExpiresAt - now }
		end
	end
	return result
end

function CharacterEntity.HasStatus(self: CharacterEntity, name: string): boolean
	return self:GetStatus(name) ~= nil
end

function CharacterEntity.ClearStatus(self: CharacterEntity, name: string)
	if self._statuses[name] then
		self._statuses[name] = nil
		self.Model:SetAttribute(name, nil)
	end
end

function CharacterEntity.Destroy(self: CharacterEntity)
	if self._diedConnection then
		self._diedConnection:Disconnect()
		self._diedConnection = nil
	end
	self.Died:Destroy()
	self.HealthChanged:Destroy()
	table.clear(self._statuses)
end

return CharacterEntity
