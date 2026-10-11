--!strict
--[[
	The boss of the endless raid (legacy ServerStorage.Boss.Endless.RandomBoss, AI_Global
	with two random flags of its Fruits folder switched on by the raid spawner). All of
	its behaviour is the shared engine, Bosses/_Global; this module only picks the fruits.

	Two different fruits among Candy, Sand, Quake, Magma, Plasma, Flare and Smelt are
	rolled every time it spawns. The engine publishes them on the model as the
	"BossFruits" attribute ("Sand,Candy", in the order it lets them act), which clients
	can read.

	A spawner that wants to choose them sets the same attribute on the template before
	it is spawned (EnemyService clones the template, attributes included): names that are
	not fruits of the engine are ignored and missing ones are rolled.

	Its health is not decided here: the raid passes the Defense level of the wave to
	EnemyService:SpawnEvent (legacy: 40000 * (1 + 0.25 * wave / 10)).
]]
local ServerStorage = game:GetService("ServerStorage")

local BossTypes = require(ServerStorage.Server.Types.BossTypes)
local Global = require(script.Parent._Global)

-- Walk speed of the legacy model's Humanoid.
local WALK_SPEED = 30
local FRUIT_COUNT = 2
local ATTRIBUTE = "BossFruits"

local random = Random.new()

local function pickFruits(model: Model): { string }
	local pool = table.clone(Global.Rollable)
	local picked: { string } = {}

	local preset = model:GetAttribute(ATTRIBUTE)
	if type(preset) == "string" then
		for _, name in string.split(preset, ",") do
			local index = table.find(pool, name)
			if index and #picked < FRUIT_COUNT then
				table.remove(pool, index)
				table.insert(picked, name)
			end
		end
	end

	while #picked < FRUIT_COUNT and #pool > 0 do
		table.insert(picked, table.remove(pool, random:NextInteger(1, #pool)) :: string)
	end
	return picked
end

local RandomBoss = {}

function RandomBoss.new(handle: BossTypes.BossHandle)
	return Global.new(handle, { Fruits = pickFruits(handle.Entity.Model), WalkSpeed = WALK_SPEED })
end

return RandomBoss
