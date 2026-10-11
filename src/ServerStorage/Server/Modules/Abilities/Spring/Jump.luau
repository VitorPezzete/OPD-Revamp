--!strict
--[[
	Spring fruit - Jump: launches the caster up.

	The legacy LocalScript had no server side at all: on the press it set
	Humanoid.HipHeight to 100 * (melee level / 500) for a single frame and back to 0, and
	the humanoid's own leg spring threw the character up. How far depends on that spring
	(and on standing on something: a humanoid in free fall has no legs to push with), so
	the launch is reproduced the very same way, by the owning client, in the SpringJump
	effect. The server only checks who may jump and sends the height.

	Nothing else existed in legacy: no cooldown, no damage, no animation.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local EFFECT = "SpringJump"
-- Hip height (studs) at the melee cap of 500.
local MAX_HEIGHT = 100

local Jump = Ability.extend()

function Jump:OnBegin()
	local entity = self.Entity
	self:PlayEffect(EFFECT, entity.Root.Position, {
		Height = MAX_HEIGHT * self:GetLevelScale("Melee"),
	})
end

return Jump
