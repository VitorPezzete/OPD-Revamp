--!strict
--[[
	Gum fruit - 2nd Gear (toggle; "Gear Down" while on): the body steams, the user runs
	faster, every Gum move becomes its Jet version, and it burns health.

	While on (status "Gum2nd", replicated, value = fruit color string):
	- walk speed bonus = (1 + 1.5 * melee affinity) * (melee level / cap) of base speed;
	- 10 health lost every second, taken straight from health (it can kill);
	- no natural health regeneration (entity status RegenMultiplier = 0), unless the
	  user also owns the Phoenix fruit;
	- Pistol / Bazooka / Gatling / Gum Rocket read the status (see _Shared).

	Switching either way has a cooldown of 12 - melee level / 50 seconds.

	It keeps running through a stun (the legacy flag was only ever cleared by the toggle);
	death, a seal or losing the fruit turn it off.

	Legacy problems fixed here:
	- The drain was a `while UsingGum2nd` loop started inside the remote handler: toggling
	  off and on within a second left two loops draining at once, and the flag survived
	  a seal.
	- The switch cooldown and the "no switching for 1.75 s after starting a Pistol,
	  Bazooka or Gatling" rule lived on the client; both are enforced here.
	- Body colors were rewritten on the server and restored from the saved skin; the
	  tint is a client effect now (Effects.Status.Gum2nd) and nothing has to be restored.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

local SPEED_MODIFIER = "Gum2nd"
-- Read by the regeneration loop of CharacterService.
local REGEN_STATUS = "RegenMultiplierGum"

local DRAIN = 10
local DRAIN_INTERVAL = 1
local SWITCH_COOLDOWN = 12
local SWITCH_COOLDOWN_LEVEL_DIVISOR = 50

local SecondGear = Ability.extend()

SecondGear.KeepThroughStun = true

function SecondGear:CanBegin(): boolean
	local cooldown = SWITCH_COOLDOWN - self:GetLevel("Melee") / SWITCH_COOLDOWN_LEVEL_DIVISOR
	return os.clock() - (self.LastSwitch or 0) >= cooldown and not self.Entity:HasStatus(Shared.MovedStatus)
end

function SecondGear:OnBegin()
	self.LastSwitch = os.clock()
	self:StartCooldown(SWITCH_COOLDOWN - self:GetLevel("Melee") / SWITCH_COOLDOWN_LEVEL_DIVISOR)

	if self.Active then
		self:OnInterrupt()
		return
	end

	local entity = self.Entity
	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	entity:SetStatus(Shared.GearStatus, self:GetColorString(), nil, true)
	entity:SetSpeedBonus(SPEED_MODIFIER, (1 + 1.5 * self:GetAffinity("Melee")) * self:GetLevelScale("Melee"))
	if not self.Services.Fruit:HasFruit(self.Player, "Phoenix") then
		entity:SetStatus(REGEN_STATUS, 0)
		self.BlockedRegen = true
	end

	-- One bounded-rate tick per geared user; it dies with the run that started it.
	local function drain()
		if self.Run ~= run or not self.Active or entity.Dead then
			return
		end
		entity:TakeDamage(DRAIN)
		if self.Run == run and not entity.Dead then
			task.delay(DRAIN_INTERVAL, drain)
		end
	end
	drain()
end

function SecondGear:OnInterrupt()
	local entity = self.Entity
	self.Active = false
	self.Run = (self.Run or 0) + 1
	entity:ClearStatus(Shared.GearStatus)
	entity:SetSpeedBonus(SPEED_MODIFIER, nil)
	if self.BlockedRegen then
		self.BlockedRegen = false
		entity:ClearStatus(REGEN_STATUS)
	end
end

return SecondGear
