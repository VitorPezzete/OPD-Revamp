--!strict
--[[
	Deathmatch: everyone who accepted is healed and dropped in the colosseum; the last
	one alive wins a roll of the standard reward table and is sent back to the world.
	After five minutes sudden death drains everybody until one is left.

	Dying or leaving eliminates. The dead respawn in the lobby like any other death.
]]
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local WorldEventArena = require(ServerStorage.Server.Modules.WorldEventArena)
local WorldEventTypes = require(ServerStorage.Server.Types.WorldEventTypes)

type Context = WorldEventTypes.Context

local Deathmatch = {}

function Deathmatch.Start(context: Context): (() -> ())?
	local config = context.Config
	local map = context.LoadMap()
	local spawns = if map then WorldEventArena.GetSpawns(map) else {}
	if #spawns == 0 then
		warn("[Deathmatch] arena map or its Spawns are missing")
		context.Finish()
		return nil
	end

	local fighters: { Player } = {}
	local startedAt: number? = nil
	local suddenDeath = false

	local function resolve()
		if context.IsFinished() or not startedAt or #fighters > 1 then
			return
		end
		local winner = fighters[1]
		if winner then
			context.Reward(winner)
			context.ReturnToWorld(winner)
		end
		context.Finish()
	end

	local function eliminate(player: Player)
		local index = table.find(fighters, player)
		if index then
			table.remove(fighters, index)
			resolve()
		end
	end

	context.Track(Players.PlayerRemoving:Connect(eliminate))

	-- The map needs a moment to reach the clients before anyone is dropped on it.
	task.delay(config.PrepareSeconds, function()
		if context.IsFinished() then
			return
		end

		for _, player in context.Participants do
			local entity = context.GetFighter(player)
			if not entity then
				continue
			end
			context.Place(player, WorldEventArena.RandomSpawn(spawns), true)
			table.insert(fighters, player)
			context.Track(entity.Died:Connect(function()
				eliminate(player)
			end))
		end

		if #fighters < 2 then
			-- Everyone else died or left during the invitation: nothing to fight over.
			context.Notify(fighters, "Deathmatch cancelled: not enough fighters.")
			for _, player in fighters do
				context.ReturnToWorld(player)
			end
			context.Finish()
			return
		end

		startedAt = os.clock()
		context.Notify(fighters, "Deathmatch! Last one standing wins.")
	end)

	context.OnTick(function()
		if not startedAt then
			return
		end
		if not suddenDeath and os.clock() - startedAt >= config.SuddenDeathAfter then
			suddenDeath = true
			context.Notify(fighters, "Sudden death!")
		end
		if suddenDeath then
			WorldEventArena.SuddenDeath(context, fighters, config.SuddenDeathDamage)
		end
	end)

	return nil
end

return Deathmatch
