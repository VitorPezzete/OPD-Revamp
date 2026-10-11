--!strict
--[[
	Client side of the world systems that need a prompt.

	- World event invitation: WorldEventService.Invite opens the shared confirmation
	  dialog (screen "ConfirmationEvent"); the answer goes back through Respond, the only
	  thing this client ever tells the server about events. The dialog closes when the
	  invitation expires. The KOTH scoreboard is its own screen (UI.Screens.KOTH).
	- Altar: AltarService.Offer opens the "LegendaryGui" screen.

	Team and waiting highlights are status effects (Effects.Status.EventTeam / EventQueued).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local INVITE_SCREEN = "ConfirmationEvent"
local LEGENDARY_SCREEN = "LegendaryGui"

local WorldEventController = Knit.CreateController({
	Name = "WorldEventController",
})

local UIController

-- Identifies the invitation currently on screen, so a late timer or a later, unrelated
-- confirmation dialog is never closed by mistake.
local inviteToken = 0
local inviteShown = false

local function closeInvite()
	if inviteShown then
		inviteShown = false
		UIController:Close(INVITE_SCREEN)
	end
end

function WorldEventController:KnitInit()
	UIController = Knit.GetController("UIController")
end

function WorldEventController:KnitStart()
	local worldEvents = Knit.GetService("WorldEventService")

	worldEvents.Invite:Connect(function(text: unknown, seconds: unknown)
		if type(text) ~= "string" then
			return
		end

		inviteToken += 1
		local token = inviteToken
		local function answer(accept: boolean)
			if token == inviteToken then
				inviteShown = false
				worldEvents.Respond:Fire(accept)
			end
		end

		-- An invitation lasts seconds and comes once an hour: it replaces whatever
		-- confirmation was open.
		UIController:Close(INVITE_SCREEN)
		UIController:Open(INVITE_SCREEN, {
			Text = text,
			OnConfirm = function()
				answer(true)
			end,
			OnDecline = function()
				answer(false)
			end,
		})
		inviteShown = UIController:IsOpen(INVITE_SCREEN)

		task.delay(if type(seconds) == "number" then seconds else 15, function()
			if token == inviteToken then
				closeInvite()
			end
		end)
	end)

	worldEvents.InviteClosed:Connect(closeInvite)

	local ok, altar = pcall(Knit.GetService, "AltarService")
	if ok and altar then
		altar.Offer:Connect(function()
			UIController:Open(LEGENDARY_SCREEN)
		end)
	end
end

return WorldEventController
