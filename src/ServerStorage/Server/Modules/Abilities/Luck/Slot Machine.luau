--!strict
--[[
	Luck fruit - Slot Machine: spins three reels. 1.5 s cooldown. This is how the luck
	gauge is filled.

	Each reel is drawn independently with these weights (L = current luck, 0-100):
		Cherry  40 - 0.2 L      Diamond  10 + 0.2 L
		Seven    5 + 0.5 L      Skull    45 - 0.45 L   (no skulls inside the caster's
		                                               own Golden Casino)

	With d = defense affinity:
		Three sevens    JACKPOT for 2.5 * d seconds: luck pinned at 100 and, every
		                0.1 s, +1% * d of max health and +10 haki. Luck drops to 0 when
		                it ends.
		Three cherries  at full health: +10 luck; otherwise heal 20% of max health and
		                lose 10 luck
		Three diamonds  +25 * d luck
		Three skulls    stunned for 1 s, +10 * d luck
		Anything else   +2.5 * d luck

	The reels are shown to the caster by Effects.OneShot.LuckSlot.
	A jackpot keeps running when its owner is stunned, and the machine can be spun while
	stunned: like the other Luck powers it had no "powers disabled" check in the legacy
	game (the seal gate of AbilityService still applies).

	Kept as they were:
	- Only the casino removes the skulls from the reels; the lucky moment and the
	  jackpot do not.
	- Three sevens DURING a jackpot do not make it longer. The jackpot still ends when
	  the first timer runs out; until then the second one adds its own heal / haki
	  ticks on top of the first (the legacy code ran one loop per triple seven on a
	  single flag). Each triple seven also arms its own end timer, which ends whatever
	  jackpot is running when it fires.

	Legacy problems fixed here:
	- The jackpot was a `while` loop inside the remote handler; the gauge value it kept
	  writing belonged to the script, so a death mid-jackpot left it running on a dead
	  character. It is a chain of delayed ticks that stops with the flag.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local EFFECT = "LuckSlot"

local JACKPOT_DURATION = 2.5
local JACKPOT_TICK = 0.1
local JACKPOT_HEAL = 0.01
local JACKPOT_HAKI = 10

local function spin(luck: number, lucky: boolean): string
	local cherry = 40 - luck * 0.2
	local diamond = 10 + luck * 0.2
	local seven = 5 + luck * 0.5
	local skull = if lucky then 0 else 45 - luck * 0.45

	local roll = Shared.Random() * (cherry + diamond + seven + skull)
	if roll < cherry then
		return "Cherry"
	elseif roll < cherry + diamond then
		return "Diamond"
	elseif roll < cherry + diamond + seven then
		return "Seven"
	end
	return if lucky then "Seven" else "Skull"
end

local SlotMachine = Ability.extend()
-- The legacy script never checked for disabled powers: a seal does not stop it.
SlotMachine.IgnoreSeal = true

SlotMachine.Debounce = 1.5
SlotMachine.KeepThroughStun = true

local function endJackpot(self: any)
	if not self.Active then
		return
	end
	self.Active = false

	local entity: CharacterEntity = self.Entity
	entity:ClearStatus(Shared.JackpotStatus)
	Shared.Set(entity, 0)
end

local function startJackpot(self: any)
	local entity: CharacterEntity = self.Entity
	local affinity = self:GetAffinity("Defense")

	self.Active = true
	Shared.Set(entity, Shared.MaxLuck)
	entity:SetStatus(Shared.JackpotStatus, self:GetColorString(), nil, true)

	-- Ends whatever jackpot is running by then (see the header).
	task.delay(JACKPOT_DURATION * affinity, endJackpot, self)

	-- One chain of ticks per triple seven; all of them stop with the flag.
	local function step()
		if not self.Active or entity.Dead then
			return
		end
		entity:Heal(entity.MaxHealth * JACKPOT_HEAL * affinity)
		Shared.AddHaki(self.Services, entity, JACKPOT_HAKI)
		task.delay(JACKPOT_TICK, step)
	end
	step()
end

function SlotMachine:OnBegin()
	local entity: CharacterEntity = self.Entity
	local affinity = self:GetAffinity("Defense")
	local luck = Shared.Get(entity)
	-- Skulls only leave the reels inside the casino.
	local lucky = entity:HasStatus(Shared.CasinoStatus)

	local a, b, c = spin(luck, lucky), spin(luck, lucky), spin(luck, lucky)
	self:PlayEffect(EFFECT, entity.Root.Position, { Symbols = { a, b, c } })

	if a ~= b or b ~= c then
		Shared.Add(entity, 2.5 * affinity)
		return
	end

	if a == "Seven" then
		startJackpot(self)
	elseif a == "Cherry" then
		if entity.Health >= entity.MaxHealth then
			Shared.Add(entity, 10)
		else
			entity:Heal(entity.MaxHealth * 0.2)
			Shared.Add(entity, -10)
		end
	elseif a == "Diamond" then
		Shared.Add(entity, 25 * affinity)
	else
		Shared.Add(entity, 10 * affinity)
		-- Last: the stun interrupts the caster's abilities.
		self.Services.Status:ApplyStun(entity, 1)
	end
end

function SlotMachine:OnInterrupt()
	endJackpot(self)
end

return SlotMachine
