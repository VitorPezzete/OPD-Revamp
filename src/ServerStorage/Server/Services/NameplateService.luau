--!strict
--[[
	Publishes what overhead nameplates need and no client can know by itself: the total
	level of each player, as the "Level" attribute of the character.

	The legacy level label was a LocalScript in the character, so players only ever saw
	their own level. Health and max health are already replicated by CharacterEntity.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)

local LEVEL_ATTRIBUTE = "Level"
-- The legacy label summed these five (Expertise is not part of the displayed level).
local SKILLS = { "Melee", "Defense", "Sniper", "Sword", "Haki" }

local NameplateService = Knit.CreateService({
	Name = "NameplateService",
	Client = {},
})

local DataService
local CharacterService

local function update(player: Player)
	local entity = CharacterService:GetPlayerEntity(player)
	local data = DataService:GetData(player)
	if not entity or not data then
		return
	end

	local total = 0
	for _, skill in SKILLS do
		local level = data:Get(`Skills.{skill}.Level`)
		if type(level) == "number" then
			total += level
		end
	end
	entity.Model:SetAttribute(LEVEL_ATTRIBUTE, total)
end

function NameplateService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
end

function NameplateService:KnitStart()
	DataService:ObserveData(function(player: Player, data: PlayerData.PlayerData)
		for _, skill in SKILLS do
			data:Observe(`Skills.{skill}.Level`, function()
				update(player)
			end)
		end
		update(player)
	end)

	CharacterService.EntityAdded:Connect(function(entity: CharacterEntity.CharacterEntity)
		if entity.Player then
			update(entity.Player)
		end
	end)
end

return NameplateService
