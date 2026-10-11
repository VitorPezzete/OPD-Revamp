--!strict
--[[
	Luck fruit - Fortune's Purge: spends 25 luck to turn a bad situation around.
	15 s cooldown.

	As in the legacy game the 25 luck is taken FIRST, on every press made with at least
	25 luck: a press during the cooldown, or one that has nothing to purge, still pays.
	A press that passes the cooldown then does both of these, when they apply:

	1. Sealed or stunned (fruit powers disabled): every seal is broken, whatever put it
	   there, a stun stops blocking the powers (not the legs), and the next 5 s are a
	   "lucky moment" (dice and coins roll 4-6).
	2. Inside the caster's own Golden Casino: the big skull bursts. Everyone within the
	   casino radius (125 * defense affinity) takes
	       1500 * (luck left after paying) / 100 * melee affinity
	   "Special", not dodgeable. The casino itself keeps running, without its skull.

	Framework note: AbilityService drops key *presses* of a sealed or stunned character
	before any ability code runs, which is exactly the situation case 1 exists for. Key
	*releases* are always delivered (with the same ownership / level / alive checks), so
	a disabled player purges when letting go of the key (OnEnd); everyone else on the
	press (OnBegin).

	Legacy problems fixed here:
	- The handler waited a second inside the remote callback to hide the skull.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local EFFECT = "LuckPurge"
local SEAL_STATUS = AbilityConfig.Status.AbilitiesDisabled
local STUN_STATUS = "Stunned"

local COST = 25
local COOLDOWN = 15
local MOMENT_DURATION = 5
local DAMAGE = 1500

local Purge = Ability.extend()
-- The legacy script never checked for disabled powers: a seal does not stop it.
Purge.IgnoreSeal = true

local function isDisabled(entity: CharacterEntity): boolean
	return entity:HasStatus(SEAL_STATUS) or Shared.IsStunned(entity)
end

local function purge(self: any, disabled: boolean)
	local entity: CharacterEntity = self.Entity
	local luck = Shared.Get(entity)
	if entity.Dead or luck < COST then
		return
	end
	-- Paid before the cooldown is even looked at.
	Shared.Add(entity, -COST)

	local now = os.clock()
	if now - (self.LastPurge or -COOLDOWN) < COOLDOWN then
		return
	end
	self.LastPurge = now
	self:StartCooldown(COOLDOWN)

	if disabled then
		-- The legacy game had one flag for "powers off" (DF_Disabled), set by seals and
		-- stuns alike, and the purge simply cleared it. The seal sources and the stuns are
		-- private to their services, so the two statuses the input gate reads are cleared
		-- here: the powers are back at once, while the roots of a stun last until it runs
		-- out (the legacy client kept the controls locked too).
		self.Services.Ability:SetSealed(entity, false)
		entity:ClearStatus(SEAL_STATUS)
		entity:ClearStatus(STUN_STATUS)
		entity:SetStatus(Shared.MomentStatus, self:GetColorString(), MOMENT_DURATION, true)
	end

	local area = entity:GetStatus(Shared.CasinoAreaStatus) :: Shared.CasinoArea?
	if area and entity:HasStatus(Shared.CasinoStatus) then
		local damage = DAMAGE * (luck - COST) / Shared.MaxLuck * self:GetAffinity("Melee")
		self:PlayEffect(EFFECT, area.Position, { Size = area.Radius * 2 })

		-- Same status, same remaining time, skull hidden from now on.
		local remaining = area.EndsAt - now
		if remaining > 0 then
			entity:SetStatus(
				Shared.CasinoStatus,
				Shared.PackCasino(area.Position, area.Radius * 2, true, self:GetColorString()),
				remaining,
				true
			)
		end

		for _, target in Hitbox.Sphere(area.Position, area.Radius, entity) do
			self:Damage(target, damage, "Special", EFFECT, false)
		end
	end
end

function Purge:OnBegin()
	-- The release of this press must not purge a second time.
	self.Handled = true
	purge(self, false)
end

function Purge:OnEnd()
	if self.Handled then
		self.Handled = false
		return
	end
	if isDisabled(self.Entity) then
		purge(self, true)
	end
end

return Purge
