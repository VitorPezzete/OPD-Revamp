--!strict
--[[
	Developer command that closes servers by version: the "Shut down servers" section of
	the menu's Server tab. All of the work is Server.Services.ServerPolicyService's; this
	module only reads the arguments.

		ShutdownVersion(version, seconds, reason?)

	Every server of the game whose VersionConfig.Version is `version` starts the shutdown
	countdown, with the reason shown to its players (filtered). "*" is every server,
	whatever its version. The menu's target has nothing to do with it and is ignored.

	Unlike the other developer commands this one reaches outside the server it is asked
	in, so it does not rely on DevService's gate alone: that gate lets everybody through
	in the development place and in Studio, and a baseplate must not be able to empty the
	live game. The Owner role is asked for again here, wherever the request comes from.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VersionConfig = require(ReplicatedStorage.Shared.Configs.VersionConfig)
local Optional = require(ReplicatedStorage.Shared.Util.Optional)
local DevKit = require(ServerStorage.Server.Modules.DevKit)
local Permissions = require(ServerStorage.Server.Modules.Permissions)

local REQUIRED_ROLE: Permissions.Role = "Owner"
-- The "version" that means every server (ServerPolicyService knows the same one).
local ALL_VERSIONS = "*"
local MIN_SECONDS = 10
local MAX_SECONDS = 3600
-- Bytes of a reason the menu may send; ServerPolicyService keeps fewer.
local MAX_REASON_LENGTH = 200

local handlers: { [string]: DevKit.Handler } = {}

function handlers.ShutdownVersion(developer, _target, versionArg, secondsArg, reasonArg)
	if not Permissions.Has(developer, REQUIRED_ROLE) then
		return false, "only an owner can shut down servers by version"
	end

	local version = DevKit.Name(versionArg)
	local seconds = DevKit.Integer(secondsArg, MIN_SECONDS, MAX_SECONDS)
	if not version or not seconds then
		return false, "invalid version or countdown"
	end
	local reason: string? = nil
	if reasonArg ~= nil then
		if type(reasonArg) ~= "string" or #reasonArg > MAX_REASON_LENGTH then
			return false, "invalid reason"
		end
		reason = reasonArg
	end

	-- Not in every place (PlaceManifest).
	local ServerPolicyService = Optional.Service("ServerPolicyService")
	if not ServerPolicyService then
		return false, "this place has no server policy service"
	end
	return ServerPolicyService:ShutdownVersion(developer, version, seconds, reason)
end

local function getCatalog(): { [string]: any }
	return {
		Shutdown = {
			Version = VersionConfig.Version,
			AllVersions = ALL_VERSIONS,
			MinSeconds = MIN_SECONDS,
			MaxSeconds = MAX_SECONDS,
			MaxReasonLength = MAX_REASON_LENGTH,
		},
	}
end

return {
	Handlers = handlers,
	-- A MessagingService publication and a text filter request, and it empties servers.
	Costs = {
		ShutdownVersion = 10,
	},
	GetCatalog = getCatalog,
} :: DevKit.CommandModule
