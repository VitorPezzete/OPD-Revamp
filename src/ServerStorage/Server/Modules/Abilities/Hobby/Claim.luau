--!strict
--[[
	Hobby fruit - Claim: every *player* the user has turned into a toy is killed and
	replaced, where it stands, by a toy soldier that keeps obeying Command / Target.

	Soldier health:  the victim's max health * defense affinity
	Soldier attack:  the victim's melee level + 0.25 * melee affinity, "Melee"; the
	                 level is doubled and the hit "Haki" if the victim's haki level is
	                 above 200. The legacy line reads `level * 1 + (.25 * affinity)`: the
	                 affinity adds a fraction of a point, and that is what is kept.
	At most 6 soldiers per user. Soldiers last until they are killed or the user uses
	Revert, dies, leaves or loses the fruit. The victim's death credits nobody.

	The soldier is a real NPC (Assets.Models.Fruits.Hobby.Power5.Toy) registered with
	CharacterService: it has to be hit, killed and collided with by everyone. Without
	that model nothing happens and the victim is left alone.

	Legacy problems fixed here:
	- Reaching the cap `return`ed out of the whole remote handler in the middle of the
	  loop over a table that was being modified.
	- Soldiers were painted with `Color3.fromRGB(color2)` (a Color3 passed as the red
	  channel: always black); the client paints them with the fruit's second color.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Toys = require(script.Parent._Toys)

local ATTACK_PER_AFFINITY = 0.25

local Claim = Ability.extend()

function Claim:OnBegin()
	local entity = self.Entity
	local healthMultiplier = self:GetAffinity("Defense")
	local damageBonus = ATTACK_PER_AFFINITY * self:GetAffinity("Melee")
	local colors = self:GetColorString()

	for _, toy in Toys.List(entity) do
		if Toys.CountClaimed(entity) >= Toys.MaxClaimed then
			break
		end
		Toys.Claim(entity, toy, healthMultiplier, damageBonus, colors)
	end
end

return Claim
