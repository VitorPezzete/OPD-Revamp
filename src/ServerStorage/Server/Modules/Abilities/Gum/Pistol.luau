--!strict
--[[
	Gum fruit - Pistol (Jet Pistol in 2nd Gear): one arm stretches towards the aim point
	and punches the first thing in its way. Arms alternate.

	Reach and damage: see _Shared (reach = melee level * affinity, damage =
	L / 4 + L / 4 * affinity, Melee / Haki x2).

	                 punch time   cooldown   melee level
	Pistol             0.25 s      0.45 s        25
	Jet Pistol         0.10 s      0.10 s       125

	The arm reaches whatever is in its way in one punch time, whatever the distance. The
	user is pinned for the whole punch (3.5 punch times + 0.1 s: out, hold, back) and
	Gatling cannot start, or go on, until the arm is back (legacy CanUseGatling).

	Legacy problems fixed here:
	- The gear, and so the speed and cooldown, came from the client.
	- The cooldown, the current hand and the "can use Gatling" flag were script-level
	  variables written from inside yielding handlers.
	- The server asked for melee 50 although the move unlocks at 25.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

local ROOT = "GumPistol"
local JET_LEVEL = 125

local PUNCH_TIME = 0.25
local COOLDOWN = 0.45
local JET_PUNCH_TIME = 0.1
local JET_COOLDOWN = 0.1

local Pistol = Ability.extend()

-- The framework debounce must not be longer than the Jet cooldown.
Pistol.Debounce = JET_COOLDOWN

function Pistol:CanBegin(): boolean
	local entity = self.Entity
	return not Shared.IsBusy(entity) and not entity.Humanoid.Sit and Shared.MeetsGearLevel(self, JET_LEVEL)
end

function Pistol:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local jet = Shared.IsSecondGear(entity)
	local punchTime = if jet then JET_PUNCH_TIME else PUNCH_TIME

	local cooldown = if jet then JET_COOLDOWN else COOLDOWN
	Shared.SetBusy(entity, cooldown)
	self:StartCooldown(cooldown)

	Shared.MarkMove(entity)
	self.UseLeft = not self.UseLeft
	local busyTime = punchTime * 3.5 + 0.1
	Shared.Hold(self, ROOT, busyTime)
	Shared.SetArmsOut(entity, busyTime)
	Shared.Punch(self, input.AimPosition, {
		Hand = if self.UseLeft then "Left" else "Right",
		Time = punchTime,
		Hold = punchTime + 0.1,
		Face = true,
	})
end

function Pistol:OnInterrupt()
	Shared.Release(self, ROOT)
end

return Pistol
