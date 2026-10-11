--!strict
--[[
	More fruit - Restore All: every character the user resized with Resize Other goes back
	to its normal size. The user's own Resize is not touched (legacy: only the victims).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local MoreScale = require(script.Parent.MoreScale)

local RestoreAll = Ability.extend()

function RestoreAll:OnBegin()
	MoreScale.RestoreOwnedBy(self.Entity, false)
end

return RestoreAll
