--!strict
--[[
	Applies server-requested physics to the local character (knockback, launches).
	The server cannot push a player-owned character directly, so it tells the owner.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Push = require(ReplicatedStorage.Shared.Util.Push)

local MovementController = Knit.CreateController({
	Name = "MovementController",
})

function MovementController:KnitStart()
	Knit.GetService("CharacterService").Impulse:Connect(function(velocity: Vector3, duration: any, maxForce: any, power: any)
		local character = Players.LocalPlayer.Character
		local root = character and character.PrimaryPart
		if not root or typeof(velocity) ~= "Vector3" then
			return
		end
		Push.Apply(
			root,
			velocity,
			if type(duration) == "number" then duration else nil,
			if typeof(maxForce) == "Vector3" then maxForce else nil,
			if type(power) == "number" then power else nil
		)
	end)
end

return MovementController
