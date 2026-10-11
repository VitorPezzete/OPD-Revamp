--!strict
--[[
	Hobby fruit - Transform: for half a second the user's hand turns whoever it touches
	into a toy.

	A toy has its powers sealed for as long as it stays a toy (until Revert, or until the
	Hobby user dies, leaves or loses the fruit), is drawn as a half-size toy by every
	client, and obeys Command / Target. Players keep walking freely until they receive
	their first order. Cannot be transformed: a target with observation haki on, a
	target that is already a toy.

	Reach: for 0.5 s, checked every 0.1 s, a sphere around the swinging hand (the legacy
	ball was 1.25 studs across, welded on the hand: the victim had to be within arm's
	reach), and never further than 15 studs from the user. Cooldown 1 s.

	Legacy problems fixed here ("Hobby Exploits"):
	- Everything hung on a Touched connection of a ball welded to an arm the client
	  chose; the reach is now a server query around the server position of the user.
	- Victims were shrunk and made transparent by the server part by part, and restored
	  with "transparency 0 on everything", which un-hid parts that were meant to be
	  invisible. The toy look is now a client effect of the HobbyToy status.
	- One `diedconn` per script: only the first death of the user ever freed the toys.
	  Freeing them is now the fruit's passive cleanup (death, leaving, fruit removed).
	- A `while Hobbied` loop per toy re-set its DF_Disabled flag four times a second.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Toys = require(script.Parent._Toys)

local WINDOW = 0.5
local CHECKS = 6
-- Center of the hand's reach ahead of the root, and its radius.
local REACH_FORWARD = 1
local REACH_RADIUS = 2
local MAX_DISTANCE = 15

local Transform = Ability.extend()

Transform.Debounce = 1

function Transform:OnBegin()
	local entity = self.Entity
	local colors = self:GetColorString()

	self.Run = (self.Run or 0) + 1
	local run = self.Run

	self:PlayEffect("HobbyTransform", entity.Root.Position, { Duration = WINDOW })

	local checks = 0
	local function reach()
		if self.Run ~= run or entity.Dead then
			return
		end

		local root = entity.Root
		local center = root.Position + root.CFrame.LookVector * REACH_FORWARD
		for _, target in Hitbox.Sphere(center, REACH_RADIUS, entity) do
			if (target.Root.Position - root.Position).Magnitude <= MAX_DISTANCE then
				Toys.Transform(entity, target, colors)
			end
		end

		checks += 1
		if checks < CHECKS then
			task.delay(WINDOW / (CHECKS - 1), reach)
		end
	end
	reach()
end

function Transform:OnInterrupt()
	-- Ends the reach window. Existing toys are not freed by a stun or a seal: that is
	-- Revert and the passive's job.
	self.Run = (self.Run or 0) + 1
end

return Transform
