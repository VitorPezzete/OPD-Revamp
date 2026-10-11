--!strict
--[[
	Client side of the raid lobby (RaidService).

	The server pushes the whole lobby state on every change and nil when this player is
	out of it; this controller keeps the last one and opens / closes the screens:

		TeleportingRaid   while in a lobby (it reads GetLobby and listens to Changed)
		InviteRaid        when an invitation arrives, for as long as it is valid

	The legacy server cloned those GUIs into PlayerGui and destroyed them itself.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

export type Member = { UserId: number, Name: string }
export type Lobby = {
	Quest: string,
	OwnerId: number,
	Members: { Member },
	-- Server time (Workspace:GetServerTimeNow) at which the party leaves.
	EndsAt: number,
	PartySize: number,
}

local LOBBY_SCREEN = "TeleportingRaid"
local INVITE_SCREEN = "InviteRaid"

local RaidController = Knit.CreateController({
	Name = "RaidController",
})

-- Fired with the new state (nil when the lobby is left).
RaidController.Changed = Signal.new()

local UIController
local RaidService

local lobby: Lobby? = nil
local inviteToken = 0

function RaidController:GetLobby(): Lobby?
	return lobby
end

function RaidController:Invite(target: Player)
	RaidService.Invite:Fire(target)
end

function RaidController:Kick(target: Player)
	RaidService.Kick:Fire(target)
end

function RaidController:Leave()
	RaidService.Leave:Fire()
end

function RaidController:Start()
	RaidService.Start:Fire()
end

-- Answers the pending invitation and takes its prompt down.
function RaidController:Respond(accept: boolean)
	inviteToken += 1
	UIController:Close(INVITE_SCREEN)
	RaidService.Respond:Fire(accept)
end

function RaidController:KnitInit()
	UIController = Knit.GetController("UIController")
end

function RaidController:KnitStart()
	RaidService = Knit.GetService("RaidService")

	RaidService.Lobby:Connect(function(state: Lobby?)
		lobby = if type(state) == "table" then state else nil
		if lobby then
			UIController:Close("LegendaryQuests")
			UIController:Close(INVITE_SCREEN)
			UIController:Open(LOBBY_SCREEN)
		else
			UIController:Close(LOBBY_SCREEN)
		end
		RaidController.Changed:Fire(lobby)
	end)

	RaidService.Invited:Connect(function(ownerName: string, questName: string, lifetime: number)
		inviteToken += 1
		local token = inviteToken
		-- A newer invitation replaces the one on screen.
		UIController:Close(INVITE_SCREEN)
		UIController:Open(INVITE_SCREEN, { Owner = ownerName, Quest = questName })
		task.delay(lifetime, function()
			if inviteToken == token then
				UIController:Close(INVITE_SCREEN)
			end
		end)
	end)
end

return RaidController
