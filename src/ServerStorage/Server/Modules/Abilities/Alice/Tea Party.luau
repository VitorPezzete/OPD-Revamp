--!strict
--[[
	Alice fruit - Tea Party: drinks a random cup of tea. 15 s cooldown, no haki cost.
	The tea drunk last also changes what Cards of Fate and Cheshire's Grin do.

	Caster's cup (chance):
		Health  30%  heals 10% * defense affinity of the *current* health
		Max     25%  +20% max health for 15 s
		Haki    20%  +haki level * 2 * 0.15 * melee affinity haki
		Neutral 15%  Cards of Fate deals x1.25 damage (its 2 card charges never let
		             anyone throw sooner: see Cards of Fate)
		Weird    5%  stunned for 1 s
		Bad      5%  loses 5% of the current health

	While the caster's Wonderland is running, every player held in it is forced to
	drink a cup of their own:
		Weird   30%  stunned for 3 s
		Bad     30%  nothing
		Neutral 15%  nothing
		Health  10%  loses 10% of their current health (unmitigated)
		Max     10%  +20% max health for 15 s (yes, good for them)
		Haki     5%  the caster steals 20% of twice their haki level

	Teas are consumed buffs, like a DoT on a target: they run on their own timers and
	are not undone by OnInterrupt (a stun must not spill the tea). Losing the fruit
	clears them through Passives/Alice.

	Legacy problems fixed here:
	- The guests' Haki tea read `store.HakiLvl` (it is `store.Data.HakiLvl`), an error
	  that aborted the loop for every guest after the first one who rolled it.
	- The legacy "TeaBad" flag set by the Weird tea was never read by anything; dropped.
	- The server created the cup Tool and played the animation; both are now client
	  side (Effects.OneShot.AliceTea).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity
type TeaTable = { { Name: string, Weight: number } }

local EFFECT = "AliceTea"
local BUFF_DURATION = 15

local USER_TEAS: TeaTable = {
	{ Name = "Health", Weight = 30 },
	{ Name = "Max", Weight = 25 },
	{ Name = "Haki", Weight = 20 },
	{ Name = "Neutral", Weight = 15 },
	{ Name = "Weird", Weight = 5 },
	{ Name = "Bad", Weight = 5 },
}
local GUEST_TEAS: TeaTable = {
	{ Name = "Weird", Weight = 30 },
	{ Name = "Bad", Weight = 30 },
	{ Name = "Neutral", Weight = 15 },
	{ Name = "Health", Weight = 10 },
	{ Name = "Max", Weight = 10 },
	{ Name = "Haki", Weight = 5 },
}

local random = Random.new()

local function pickTea(teas: TeaTable): string
	local total = 0
	for _, tea in teas do
		total += tea.Weight
	end

	local roll = random:NextNumber() * total
	for _, tea in teas do
		roll -= tea.Weight
		if roll <= 0 then
			return tea.Name
		end
	end
	return teas[#teas].Name
end

local TeaParty = Ability.extend()

TeaParty.Debounce = 15

local function serveGuest(self: any, guest: CharacterEntity)
	local entity: CharacterEntity = self.Entity
	local tea = pickTea(GUEST_TEAS)
	self:PlayEffect(EFFECT, guest.Root.Position, { Tea = tea, Drinker = guest.Model })

	if tea == "Haki" then
		Shared.StealHaki(self.Services, guest, entity, guest.Levels.Haki * 2 * 0.2)
	elseif tea == "Health" then
		guest:TakeDamage(guest.Health * 0.1)
	elseif tea == "Max" then
		Shared.ApplyTeaMax(guest, BUFF_DURATION)
	elseif tea == "Weird" then
		self.Services.Status:ApplyStun(guest, 3)
	end
end

function TeaParty:OnBegin()
	local entity: CharacterEntity = self.Entity
	local tea = pickTea(USER_TEAS)

	entity:SetStatus(Shared.TeaStatus, tea)
	self:PlayEffect(EFFECT, entity.Root.Position, { Tea = tea, Drinker = entity.Model })

	if tea == "Haki" then
		Shared.AddHaki(self.Services, entity, self:GetLevel("Haki") * 2 * 0.15 * self:GetAffinity("Melee"))
	elseif tea == "Health" then
		entity:Heal(entity.Health * 0.1 * self:GetAffinity("Defense"))
	elseif tea == "Max" then
		Shared.ApplyTeaMax(entity, BUFF_DURATION)
	elseif tea == "Bad" then
		-- Self-inflicted and unmitigated, as it always was; 5% of what is left never kills.
		entity:TakeDamage(entity.Health * 0.05)
	elseif tea == "Neutral" then
		entity:SetStatus(Shared.CardChargesStatus, 2)
	end

	if entity:HasStatus(Shared.WonderlandActiveStatus) then
		local userId = self.Player.UserId
		local guests: { CharacterEntity } = {}
		for _, other in self.Services.Character:GetEntities() do
			if other ~= entity and other.Player and not other.Dead and other:GetStatus(Shared.WonderlandStatus) == userId then
				table.insert(guests, other)
			end
		end
		for _, guest in guests do
			serveGuest(self, guest)
		end
	end

	-- Last: the stun ends whatever of the caster's does not outlive one (Wonderland does).
	if tea == "Weird" then
		self.Services.Status:ApplyStun(entity, 1)
	end
end

return TeaParty
