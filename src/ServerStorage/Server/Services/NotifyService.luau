--!strict
--[[
	Short text feedback from the server to players ("Not enough Beri", "Quest complete",
	server-wide announcements). Services call it instead of each owning a message remote;
	the client decides how each kind is shown.

		NotifyService:Send(player, "Not enough Beri", "Error")
		NotifyService:Broadcast("A fruit has spawned!", "Announcement")
		NotifyService:BroadcastChat("Countdown: 3", Color3.fromRGB(255, 255, 0))

	The last one is a line in the chat window (legacy Connections.Client_Message), for what
	the legacy game answered there: the chat commands.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

export type Kind = "Info" | "Success" | "Error" | "Announcement"

local NotifyService = Knit.CreateService({
	Name = "NotifyService",
	Client = {
		-- (text: string, kind: Kind, duration: number)
		Message = Knit.CreateSignal(),
		-- (text: string, color: Color3) shown as a system line in the chat (ChatController)
		Chat = Knit.CreateSignal(),
	},
})

local DEFAULT_DURATION = 4
local CHAT_COLOR = Color3.fromRGB(255, 255, 255)

function NotifyService:Send(player: Player, text: string, kind: Kind?, duration: number?)
	NotifyService.Client.Message:Fire(player, text, kind or "Info", duration or DEFAULT_DURATION)
end

function NotifyService:Broadcast(text: string, kind: Kind?, duration: number?)
	NotifyService.Client.Message:FireAll(text, kind or "Announcement", duration or DEFAULT_DURATION)
end

-- A line in the chat of one player only.
function NotifyService:SendChat(player: Player, text: string, color: Color3?)
	NotifyService.Client.Chat:Fire(player, text, color or CHAT_COLOR)
end

function NotifyService:BroadcastChat(text: string, color: Color3?)
	NotifyService.Client.Chat:FireAll(text, color or CHAT_COLOR)
end

return NotifyService
