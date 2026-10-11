--!strict
--[[
	Spin fruit - Spinning Punch: one quick punch. It deals no damage.

	The legacy ability never hit anything: the LocalScript sent the part its arm touched,
	but the server script has no "SpinPower3" branch, so the message was dropped. What a
	press did do was ground the copter and lock it for 3 seconds (the flight disabler ran
	before anything else), and that is all this does besides the animation.

	The LocalScript also threw on its first use (it loaded FruitAnims.Punch, which does
	not exist) and never worked again; the punch clip of the fruit (FruitAnims.SpinPunch)
	is played instead, at the 8x speed the script asked for.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local SpinningPunch = Ability.extend()

-- Legacy: the punch animation (played 8x faster) plus 0.6 s before it could be reused.
SpinningPunch.Debounce = 1

function SpinningPunch:OnBegin()
	local entity = self.Entity

	-- The grounding is AbilityService's (Modules.FlightLock), on the press itself.
	self:PlayEffect("SpinSpinningPunch", entity.Root.Position)
end

return SpinningPunch
