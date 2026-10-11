--!strict
--[[
	Yamato - only the user ids of YamatoConfig can use it: for anyone else neither the
	swing (2222 fixed damage, 99 sword exp per swing) nor the special does anything.

	Special (sword level 250, cooldown 2 s, works while sealed): opens a gate to the aim
	point; the user and everyone within 15 studs come out 7 studs above it two seconds
	later. See YamatoService for the gate itself and for typed destinations.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Optional = require(ReplicatedStorage.Shared.Util.Optional)
local YamatoConfig = require(ServerStorage.Server.Configs.YamatoConfig)
local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)

type WeaponContext = WeaponTypes.WeaponContext

local Yamato: WeaponTypes.WeaponBehaviour = {}

function Yamato.CanUse(context: WeaponContext): boolean
	return YamatoConfig.AllowedUserIds[context.Player.UserId] == true
end

function Yamato.Special(context: WeaponContext): boolean?
	-- The gates are a system of the open world: a place that does not load them
	-- (PlaceManifest) has no special, and the cooldown is given back.
	local YamatoService = Optional.Service("YamatoService")
	if not YamatoService then
		return false
	end
	local destination = context.Aim + Vector3.new(0, YamatoConfig.GateHeight, 0)
	return YamatoService:OpenGate(context.Entity, destination)
end

return Yamato
