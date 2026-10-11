--!strict
--[[
	The local player's crew, kept between openings of the crew screen, and crew invites.

		CrewController:GetCrew() -> CrewView?            CrewController.Changed (view?)
		CrewController:GetInvite() -> Invite?            CrewController.InviteChanged (invite?)
		CrewController:AnswerInvite(accept)

	An invite can arrive at any time. With the crew screen open, the screen shows it (the
	legacy confirm frame); otherwise the shared confirmation dialog does. Either way the
	answer is only yes or no: the server remembers which crew invited.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

export type MemberView = { UserId: number, Name: string, Role: string }
export type CrewView = {
	Id: string,
	Name: string,
	ImageId: string,
	Level: number,
	XP: number,
	MemberLimit: number,
	Members: { MemberView },
}
export type Invite = { CrewName: string, From: string, Expires: number }

local CREW_SCREEN = "CrewGui"
local DIALOG_SCREEN = "ConfirmationEvent"

local CrewController = Knit.CreateController({
	Name = "CrewController",
})

CrewController.Changed = Signal.new()
CrewController.InviteChanged = Signal.new()

local CrewService
local UIController

local crew: CrewView? = nil
local invite: Invite? = nil

local function setCrew(view: unknown)
	crew = if type(view) == "table" then view :: any else nil
	CrewController.Changed:Fire(crew)
end

local function setInvite(value: Invite?)
	invite = value
	CrewController.InviteChanged:Fire(value)
end

function CrewController:GetCrew(): CrewView?
	return crew
end

function CrewController:GetInvite(): Invite?
	if invite and invite.Expires < os.clock() then
		invite = nil
	end
	return invite
end

function CrewController:AnswerInvite(accept: boolean)
	if not invite then
		return
	end
	setInvite(nil)
	CrewService.RespondInvite:Fire(accept)
end

local function onInvited(crewName: unknown, from: unknown, seconds: unknown)
	if type(crewName) ~= "string" then
		return
	end

	local received: Invite = {
		CrewName = crewName,
		From = if type(from) == "string" then from else "",
		Expires = os.clock() + (if type(seconds) == "number" then seconds else 60),
	}
	setInvite(received)

	if not UIController:IsOpen(CREW_SCREEN) then
		UIController:Open(DIALOG_SCREEN, {
			Text = `Do you want to join the {crewName} crew?`,
			OnConfirm = function()
				if invite == received then
					CrewController:AnswerInvite(true)
				end
			end,
			OnDecline = function()
				if invite == received then
					CrewController:AnswerInvite(false)
				end
			end,
		})
	end
end

function CrewController:KnitInit()
	UIController = Knit.GetController("UIController")
end

function CrewController:KnitStart()
	CrewService = Knit.GetService("CrewService")
	CrewService.Updated:Connect(setCrew)
	CrewService.Invited:Connect(onInvited)

	-- The first Updated may have been sent before this controller was listening.
	CrewService:GetCrew()
		:andThen(function(view: unknown)
			if crew == nil and type(view) == "table" then
				setCrew(view)
			end
		end)
		:catch(warn)
end

return CrewController
