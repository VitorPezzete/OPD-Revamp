--!strict
--[[
	Developer commands on private servers: the "Private server" section of the World tab.
	All of the work is Server.Services.PrivateServerService's; this module only picks the
	target and words the answer.

	A private server costs Robux twice (a Roblox private server, or the 30 days product
	behind the code servers), so neither could be tried without paying. From here:

		PrivateSimulate()         this server behaves as the target's private server:
		                          progression and rewards off, VIP and aura token claims,
		                          owner-only purchases and removals, client attributes
		PrivateStopSimulating()   back to what the server really is
		PrivateGrant()            30 days of code server for the target, through the
		                          function a purchase calls: Generate and Join then work
		PrivateRevoke()           ends the target's subscription and retires its code
		PrivateStatus()           the target's code and days left, read from the store

	None takes an argument: the target DevService resolved is the owner, or the player
	whose subscription is touched. The simulation is for the whole server, whoever asked.

	The subscription commands write the live stores, so they do nothing in Studio (the
	stores are not opened there) and the service is absent from the places that do not
	load private servers (PlaceManifest). Handlers yield on the stores and trust their
	caller (see DevKit).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Optional = require(ReplicatedStorage.Shared.Util.Optional)

local DevKit = require(ServerStorage.Server.Modules.DevKit)

local NOT_LOADED = "this place does not load private servers"
local NO_STORES = "the private server stores are not opened here (Studio): try it on a live server"

local handlers: { [string]: DevKit.Handler } = {}

local function describeUser(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	return if player then `{player.Name} ({DevKit.Whole(userId)})` else DevKit.Whole(userId)
end

function handlers.PrivateSimulate(_developer, target)
	local PrivateServerService = Optional.Service("PrivateServerService")
	if not PrivateServerService then
		return false, NOT_LOADED
	end
	local ok, message = PrivateServerService:Simulate(target.UserId)
	return ok, if ok then `simulating the private server of {describeUser(target.UserId)}` else message
end

function handlers.PrivateStopSimulating(_developer, _target)
	local PrivateServerService = Optional.Service("PrivateServerService")
	if not PrivateServerService then
		return false, NOT_LOADED
	end
	return PrivateServerService:Simulate(nil)
end

function handlers.PrivateGrant(developer, target)
	local PrivateServerService = Optional.Service("PrivateServerService")
	if not PrivateServerService then
		return false, NOT_LOADED
	end
	if not PrivateServerService:Describe().Stores then
		return false, NO_STORES
	end
	-- The code, when the target had none, is generated after the answer: the target's
	-- private server screen receives it, and PrivateStatus reads it back.
	if not PrivateServerService:GrantSubscription(target, developer) then
		return false, "the subscription store did not answer"
	end
	return true, `{target.Name}: 30 more days of private server`
end

function handlers.PrivateRevoke(developer, target)
	local PrivateServerService = Optional.Service("PrivateServerService")
	if not PrivateServerService then
		return false, NOT_LOADED
	end
	return PrivateServerService:RevokeSubscription(target, developer)
end

function handlers.PrivateStatus(_developer, target)
	local PrivateServerService = Optional.Service("PrivateServerService")
	if not PrivateServerService then
		return false, NOT_LOADED
	end
	if not PrivateServerService:Describe().Stores then
		return false, NO_STORES
	end
	local status = PrivateServerService:GetSubscriptionStatus(target)
	if not status then
		return false, "the subscription store did not answer"
	end
	return true, `{target.Name}: {status.DaysLeft} days left, code {status.Code or "none"}`
end

-- The same for every target, and kept in memory: false where there are no private servers.
local function getState(_target: Player): { [string]: any }
	local PrivateServerService = Optional.Service("PrivateServerService")
	if not PrivateServerService then
		return { PrivateServer = false }
	end

	local description = PrivateServerService:Describe()
	return {
		PrivateServer = {
			Private = description.Private,
			Owner = if description.Private then describeUser(description.OwnerId) else "",
			Simulated = description.Simulated,
			Kind = description.Kind,
			RealOwner = if description.Kind ~= "Public" then describeUser(description.RealOwnerId) else "",
			Code = description.Code or "",
			Stores = description.Stores,
		},
	}
end

return {
	Handlers = handlers,
	-- Each of these is DataStore requests on the live subscription and code stores.
	Costs = {
		PrivateGrant = 5,
		PrivateRevoke = 5,
		PrivateStatus = 2,
	},
	GetState = getState,
} :: DevKit.CommandModule
