--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

return function(context: any): string
	local servers = Knit.GetService("PrivateServerService"):GetActiveServers()
	for _, server in servers do
		context:Reply(`{server.Code}  {server.Owner} ({server.OwnerId})  {server.Players} player(s)`)
	end
	return `{#servers} private server(s).`
end
