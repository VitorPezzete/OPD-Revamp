--!strict
--[[
	Spawn point selection on the spawn screen ("<" and ">" around the Spawn button).

	The legacy client edited its own SpawnNumber value and then sent that number with the
	spawn request. Now the client only says "previous" or "next"; the server walks the
	saved SpawnNumber inside 1..SpawnCount (WorldConfig.Spawns), and
	CharacterService.RequestSpawn loads the character there.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

local SpawnSelectService = Knit.CreateService({
	Name = "SpawnSelectService",
	Client = {},
})

local DataService
local CharacterService

local limiter = RateLimiter.new(6, 4)

-- direction: 1 (next) or -1 (previous). Returns the selected spawn number, nil when refused.
function SpawnSelectService.Client:Cycle(player: Player, direction: unknown): number?
	if direction ~= 1 and direction ~= -1 then
		return nil
	end
	if not limiter:Consume(player) then
		return nil
	end

	local data = DataService:GetData(player)
	if not data then
		return nil
	end

	-- Only meaningful on the spawn screen, that is while the player has no character:
	-- once in the world the rotation belongs to the server.
	if not CharacterService:IsWaitingToSpawn(player) then
		return nil
	end

	local current = data:Get("SpawnNumber")
	if type(current) ~= "number" or current < 1 or current > WorldConfig.SpawnCount then
		current = 1
	end
	local selected = (math.floor(current) - 1 + (direction :: number)) % WorldConfig.SpawnCount + 1
	data:Set("SpawnNumber", selected)
	return selected
end

function SpawnSelectService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
end

function SpawnSelectService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		limiter:Forget(player)
	end)
end

return SpawnSelectService
