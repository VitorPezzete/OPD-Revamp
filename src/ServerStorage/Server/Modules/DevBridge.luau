--!strict
--[[
	Studio-only test hook. Tools that run outside the game's script context (command
	bar, plugins, the Studio MCP) get their own copy of every module, so they cannot
	reach the running Knit services. This BindableFunction is the way in:

		ServerStorage.DevBridge:Invoke("Call", "FruitService", "EatFruit", player, "Slip", scores, false)
		ServerStorage.DevBridge:Invoke("State", player)
		ServerStorage.DevBridge:Invoke("CallOn", "StatusService", "ApplyStun", player, 0.25, "Test")
		ServerStorage.DevBridge:Invoke("Entity", player, "SetStatus", "QuakeStomped", true, 0.18, true)

	An entity is a table with a metatable and does not survive the trip through a
	BindableFunction, so it cannot be fetched and handed back: "CallOn" calls a service
	method with the player's entity as its first argument, and "Entity" calls a method of
	the entity itself.

	Never created outside Studio.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Optional = require(ReplicatedStorage.Shared.Util.Optional)

local DevBridge = {}

local function describeState(player: Player): { [string]: any }
	local data = Knit.GetService("DataService"):GetData(player)
	-- A place without characters (PlaceManifest) has no entity to describe.
	local CharacterService = Optional.Service("CharacterService")
	local entity = CharacterService and CharacterService:GetPlayerEntity(player)
	local state: { [string]: any } = { DataLoaded = data ~= nil, HasEntity = entity ~= nil }

	if data then
		state.Fruit1 = data.Data.DevilFruits.Slot1.Name
		state.Fruit2 = data.Data.DevilFruits.Slot2.Name
		state.Beri = data.Data.Economy.Beri
		state.MeleeLevel = data.Data.Skills.Melee.Level
		state.MeleeExp = data.Data.Skills.Melee.Exp
		state.DefenseExp = data.Data.Skills.Defense.Exp
	end
	if entity then
		state.Health = entity.Health
		state.MaxHealth = entity.MaxHealth
		state.Shield = entity.Shield
		state.Spawned = entity.Spawned
		state.Dead = entity.Dead
		state.WalkSpeed = entity.Humanoid.WalkSpeed
		-- What keeps the character from walking: the named roots, and whether it is stunned.
		state.Rooted = entity:IsRooted()
		local roots: { string } = {}
		for name in (entity :: any)._roots do
			table.insert(roots, name)
		end
		table.sort(roots)
		state.Roots = roots
		state.Stunned = entity:HasStatus("Stunned")
	end
	return state
end

function DevBridge.Start()
	if not RunService:IsStudio() then
		return
	end

	local bridge = Instance.new("BindableFunction")
	bridge.Name = "DevBridge"
	bridge.OnInvoke = function(action: string, ...: any): ...any
		if action == "State" then
			return describeState(...)
		elseif action == "Call" then
			local serviceName: string, method: string = ...
			local service = Knit.GetService(serviceName)
			return service[method](service, select(3, ...))
		elseif action == "CallOn" then
			local serviceName: string, method: string, player: Player = ...
			local entity = Knit.GetService("CharacterService"):GetPlayerEntity(player)
			if not entity then
				return nil
			end
			local service = Knit.GetService(serviceName)
			return service[method](service, entity, select(4, ...))
		elseif action == "Entity" then
			local player: Player, method: string = ...
			local entity = Knit.GetService("CharacterService"):GetPlayerEntity(player)
			if not entity then
				return nil
			end
			return (entity :: any)[method](entity, select(3, ...))
		elseif action == "SetData" then
			local player: Player, path: string, value: any = ...
			local data = Knit.GetService("DataService"):GetData(player)
			if data then
				data:Set(path, value)
			end
			return data ~= nil
		end
		return nil
	end
	bridge.Parent = ServerStorage
end

return DevBridge
