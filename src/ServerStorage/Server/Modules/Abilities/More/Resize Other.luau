--!strict
--[[
	More fruit - Resize Other: for 0.5 s the user's hand resizes every character it
	touches (players and NPCs) to
		1 + 2 * (melee level / cap) * defense affinity      times its size.
	Characters that are already resized, or that have observation haki on, are skipped.
	They stay that way until Restore All, or until the user dies or loses the fruit
	(Passives/More).

	The legacy hit test was a Touched connection on a ball 1.25 studs across welded to
	the right hand (one stud under the arm's centre). Here the same ball is tested where
	the hand is, every 0.05 s over the same half second; ball and offset grow with the
	user's own size, as the welded ball did.
	The key is locked for 1 s after a use (the legacy client lock).

	Legacy problems fixed here:
	- The size was stored in the CASTER's Mored.Quantity instead of the victim's, so a
	  resized victim's bigger sword hitbox used a stale or zero value.
	- The list of victims was one table per script and the Died connection was only made
	  after the first use; victims stayed giant if the user lost the fruit or left.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local MoreScale = require(script.Parent.MoreScale)

local OBSERVATION_STATUS = "UsingObs"

local WINDOW = 0.5
local TICK = 0.05
local HAND = "Right Arm"
local HAND_OFFSET = 1
local BALL_RADIUS = 0.625

local ResizeOther = Ability.extend()

ResizeOther.Debounce = 1

function ResizeOther:OnBegin()
	local entity = self.Entity
	local size = MoreScale.GetSize(self:GetLevelScale("Melee"), self:GetAffinity("Defense"))

	self.Run = (self.Run or 0) + 1
	local run = self.Run

	self:PlayEffect("MoreResizeOther", entity.Root.Position, { Duration = WINDOW })

	local deadline = os.clock() + WINDOW
	local function step()
		if self.Run ~= run or entity.Dead then
			return
		end

		local scale = entity.Model:GetScale()
		local arm = entity.Model:FindFirstChild(HAND)
		local center = if arm and arm:IsA("BasePart")
			then (arm.CFrame * CFrame.new(0, -HAND_OFFSET * scale, 0)).Position
			else entity.Root.Position
		for _, target in Hitbox.Sphere(center, BALL_RADIUS * scale, entity) do
			if not MoreScale.IsResized(target) and not target:HasStatus(OBSERVATION_STATUS) then
				MoreScale.Apply(target, size, entity)
			end
		end

		if os.clock() < deadline then
			task.delay(TICK, step)
		end
	end
	step()
end

function ResizeOther:OnInterrupt()
	-- Ends the touch window. Victims already resized are released by Restore All or the passive.
	self.Run = (self.Run or 0) + 1
end

return ResizeOther
