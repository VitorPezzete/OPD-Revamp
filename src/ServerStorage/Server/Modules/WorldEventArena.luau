--!strict
--[[
	Pieces shared by the events fought in the colosseum map (Deathmatch, Crew Wars):
	its spawn parts and the sudden death that ends a match nobody is winning.
]]
local ServerStorage = game:GetService("ServerStorage")

local WorldEventTypes = require(ServerStorage.Server.Types.WorldEventTypes)

type Context = WorldEventTypes.Context

local WorldEventArena = {}

local random = Random.new()

-- The parts of <map>.Spawns.
function WorldEventArena.GetSpawns(map: Instance): { BasePart }
	local spawns: { BasePart } = {}
	local folder = map:FindFirstChild("Spawns")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(spawns, child)
			end
		end
	end
	return spawns
end

function WorldEventArena.RandomSpawn(spawns: { BasePart }): BasePart
	return spawns[random:NextInteger(1, #spawns)]
end

function WorldEventArena.GetCenter(spawns: { BasePart }): Vector3
	local sum = Vector3.zero
	for _, spawn in spawns do
		sum += spawn.Position
	end
	return sum / math.max(1, #spawns)
end

--[[
	One second of sudden death: raw health loss, no attacker, no mitigation (it is not
	a hit, so it bypasses CombatService on purpose). `fighters` may shrink while this
	runs, since a death removes its player from the caller's list.
]]
function WorldEventArena.SuddenDeath(context: Context, fighters: { Player }, damage: number)
	for _, player in table.clone(fighters) do
		if context.IsFinished() then
			return
		end
		local entity = context.GetFighter(player)
		if entity then
			entity:TakeDamage(damage)
		end
	end
end

return WorldEventArena
