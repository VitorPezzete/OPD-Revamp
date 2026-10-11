--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local PlaceManifest = require(ReplicatedStorage.Shared.Configs.PlaceManifest)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local NetworkConfig = require(ServerStorage.Server.Configs.NetworkConfig)

-- Global flood guard: every remote call, of any service, spends from the same per-player budget.
local globalLimiter = RateLimiter.new(NetworkConfig.GlobalBurst, NetworkConfig.GlobalRefillPerSecond)

Players.PlayerRemoving:Connect(function(player: Player)
	globalLimiter:Forget(player)
end)

-- Before any player can join, in every place: nobody gets a body they did not ask for
-- (CharacterService hands them out, and a place without it has no bodies at all).
Players.CharacterAutoLoads = false

-- Only the services of this place (PlaceManifest): requiring a service module is what
-- creates the service, so one that is not required has no remotes and runs nothing.
local servicesFolder = ServerStorage.Server.Services
PlaceManifest.Verify("Services", PlaceManifest.NamesIn(servicesFolder))
for _, module in PlaceManifest.Modules("Services", servicesFolder) do
	(require :: any)(module)
end

Knit.Start({
	Middleware = {
		Inbound = {
			function(player: Player): boolean
				return globalLimiter:Consume(player)
			end,
		},
	},
})
	:andThen(function()
		require(ServerStorage.Server.Modules.DevBridge).Start()
	end)
	:catch(warn)
