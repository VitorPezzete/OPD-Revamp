--!strict
--[[
	String fruit - Sky String: the user hooks a string on the clouds and is pulled
	towards the aim point.

	- Speed: 100 + (sniper level / 25) * sniper affinity studs per second, for 0.3 s.
	- 0.5 s between two pulls (0.3 s of pull + 0.2 s, as in the legacy client).
	- Not while rooted (the legacy stun and seals blocked the key).

	The server only validates and announces the pull: the timed, replicated
	"StringSkyString" status carries the direction and the speed, the owner's client
	moves its own character and everyone draws the string
	(Effects.Status.StringSkyString). The status lasts 0.4 s, the time the legacy server
	kept the string everyone else saw; the owner's own pull (and its own string) is
	timed by its client and ends after 0.3 s, as it did.

	Legacy problems fixed here:
	- The pull was entirely client-side (its own BodyVelocity, its own cooldown flag) and
	  the client passed its own level to the server as an argument.
	- The server kept the "which side" flag in the `charging` argument sent by the client.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local STATUS = "StringSkyString"

local BASE_SPEED = 100
local LEVELS_PER_SPEED = 25
-- How long the string is shown; the pull itself is 0.3 s (Effects.Status.StringSkyString).
local STRING_SECONDS = 0.4

local SkyString = Ability.extend()

SkyString.Debounce = 0.5

function SkyString:CanBegin(): boolean
	return not self.Entity:IsRooted()
end

function SkyString:OnBegin(input)
	local entity = self.Entity
	local direction = input.AimPosition - entity.Root.Position
	if direction.Magnitude < 0.5 then
		return
	end
	direction = direction.Unit

	local speed = BASE_SPEED + self:GetLevel("Sniper") / LEVELS_PER_SPEED * self:GetAffinity("Sniper")
	-- The string alternates between the right and the left shoulder.
	self.Side = if self.Side == 1 then -1 else 1

	-- "<dx>|<dy>|<dz>|<speed>|<side>|<colors>"
	entity:SetStatus(
		STATUS,
		string.format(
			"%.3f|%.3f|%.3f|%.3f|%d|%s",
			direction.X,
			direction.Y,
			direction.Z,
			speed,
			self.Side,
			self:GetColorString()
		),
		STRING_SECONDS,
		true
	)
end

function SkyString:OnInterrupt()
	self.Entity:ClearStatus(STATUS)
end

return SkyString
