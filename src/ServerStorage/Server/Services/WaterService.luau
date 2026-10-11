--!strict
--[[
	The sea hurts devil fruit users.

	A spawned player who has eaten a fruit (either slot) and whose root is at or below
	the sea surface loses 10% of max health every 0.23 s, unless seated (boats). The
	damage goes through CombatService as an "Environment" hit tagged "Water", so fruit
	rules that react to hits still apply (a Phoenix user falls into its egg instead of
	dying and the sea then chips the egg), and DamageModifiers.WaterTrueDamage makes it
	ignore resistances and shields, as the legacy direct subtraction did.

	The legacy script ran this on Heartbeat for every player, looking the data folder,
	the character and five children up by name each frame. Here it is one loop at the
	damage interval over the player entities. Its hard-coded list of immune user names
	is not reproduced.

	Nothing sealed fruit powers in water in the legacy game, and nothing does here.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

local WATER = MovementConfig.Water
local SURFACE = WorldConfig.SeaLevel + WATER.Margin
local NO_FRUIT = "None"

local WaterService = Knit.CreateService({
	Name = "WaterService",
	Client = {},
})

local DataService
local CharacterService
local CombatService

-- Whether a character's root is in the sea. Seats and flight are the caller's business.
function WaterService:IsInWater(entity: CharacterEntity): boolean
	return entity.Root.Position.Y <= SURFACE
end

local function step()
	for _, player in Players:GetPlayers() do
		local entity = CharacterService:GetPlayerEntity(player)
		if not entity or entity.Dead or not entity.Spawned or entity.Root.Position.Y > SURFACE then
			continue
		end
		if entity.Humanoid.Sit then
			continue
		end

		local data = DataService:GetData(player)
		if not data then
			continue
		end
		local fruits = data.Data.DevilFruits
		if fruits.Slot1.Name == NO_FRUIT and fruits.Slot2.Name == NO_FRUIT then
			continue
		end

		CombatService:Damage({
			Target = entity,
			Attacker = nil,
			Amount = entity.MaxHealth * WATER.DamageFraction,
			Trait = "Special",
			Style = "Environment",
			Dodgeable = false,
			Tag = WATER.Tag,
		})
	end
end

function WaterService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	CombatService = Knit.GetService("CombatService")
end

function WaterService:KnitStart()
	task.spawn(function()
		while true do
			task.wait(WATER.DamageInterval)
			step()
		end
	end)
end

return WaterService
