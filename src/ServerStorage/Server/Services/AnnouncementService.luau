--!strict
--[[
	Cross-server announcements ("Servers will now restart.").

	The legacy script republished a Workspace StringValue through MessagingService and
	mirrored incoming messages back into it. Here an announcement is published once and
	every server (this one included) shows what it receives through NotifyService.

		AnnouncementService:Publish("Servers will now restart.")   -- admin tooling, server only

	There is no client entry point: players cannot announce.
]]
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local TOPIC = "GameAnnouncements"
-- Legacy banner time.
local DURATION = 10
local MAX_LENGTH = 200

local AnnouncementService = Knit.CreateService({
	Name = "AnnouncementService",
	Client = {},
})

local NotifyService

local function show(text: unknown)
	if type(text) ~= "string" or text == "" then
		return
	end
	NotifyService:Broadcast(string.sub(text, 1, MAX_LENGTH), "Announcement", DURATION)
end

function AnnouncementService:Publish(text: string)
	if text == "" then
		return
	end
	task.spawn(function()
		local ok = pcall(MessagingService.PublishAsync, MessagingService, TOPIC, string.sub(text, 1, MAX_LENGTH))
		if not ok then
			-- Messaging is down (or Studio): at least this server sees it.
			show(text)
		end
	end)
end

function AnnouncementService:KnitInit()
	NotifyService = Knit.GetService("NotifyService")
end

function AnnouncementService:KnitStart()
	task.spawn(function()
		local ok, problem = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message: { Data: unknown })
				show(message.Data)
			end)
		end)
		if not ok then
			warn(`[Announcement] could not subscribe to {TOPIC}: {problem}`)
		end
	end)
end

return AnnouncementService
