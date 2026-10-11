--!strict
--[[
	Vampire fruit - Hypnosis: every player this vampire has bitten (Sanguine Vampiris),
	wherever it is, is stunned for 4 seconds with the hypnosis spirals on its head.
	Cooldown 15 s, started even when nobody is bitten (as before).

	What the legacy script did, and what its victims really went through:
	- `StunEvent:Fire(character, 4)`: the ordinary stun. Powers off, controls off, and
	  the walk speed script set WalkSpeed to 0 for as long as it lasted;
	- the server took network ownership of the victim and called
	  `Humanoid:MoveTo(vampire position)` every frame while it was more than 2 studs
	  away. With a walk speed of 0 that moves nobody: the victim only TURNS to face the
	  vampire and stands there. (An earlier version of this file made the victim walk to
	  the vampire, which is what the code reads like but not what happened.)

	So: StatusService:ApplyStun for the 4 seconds (same stun as everywhere else, it only
	ever extends a running one, like the legacy stun timer) plus the timed, replicated
	VampireHypnotized status ("<vampire user id>|<fruit colors>"). The spirals and the
	turn towards the vampire are Effects.Status.VampireHypnotized: the victim's own
	client asks its humanoid to move towards the vampire, exactly the request the legacy
	server made, and the stun's zero walk speed turns it into a turn on the spot.

	Legacy problems fixed here:
	- One Heartbeat connection per victim, never disconnected if the vampire died first
	  (it then indexed a destroyed character every frame).
	- Network ownership of the victim was taken, and handed back after 4 s even if
	  something else had taken it meanwhile.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local VampireShared = require(script.Parent.VampireShared)

local STATUS = "VampireHypnotized"
local COOLDOWN = 15
local DURATION = 4

local Hypnosis = Ability.extend()

function Hypnosis:CanBegin(): boolean
	return os.clock() - (self.LastCast or 0) >= COOLDOWN
end

function Hypnosis:OnBegin()
	local entity = self.Entity
	self.LastCast = os.clock()
	self:StartCooldown(COOLDOWN)

	local value = `{self.Player.UserId}|{self:GetColorString()}`
	for _, victim in VampireShared.GetBitten(entity) do
		self.Services.Status:ApplyStun(victim, DURATION)
		victim:SetStatus(STATUS, value, DURATION, true)
	end
end

return Hypnosis
