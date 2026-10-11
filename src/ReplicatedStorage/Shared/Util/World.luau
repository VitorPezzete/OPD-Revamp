--!strict
--[[
	Where things are in the Workspace. The one place that knows the layout:

		Workspace.Map.Islands.<Island>      static islands (chests, bowls, boards inside them)
		Workspace.Map.{Trees, Barrels, Sea, Firepits, Other}
		Workspace.Map.Merchants             merchant models
		Workspace.Alive.{Players, NPCs, Bosses}   every living character, by class
		Workspace.Instances.<Container>     everything the server spawns while running
		Workspace.Instances.Effects         every visual a client draws (never replicated)

	Map, Alive and Instances are authored in the place (the server creates what is missing
	of the last two). Lookups never throw: a missing container warns once and returns nil
	so the caller can degrade.

	Server and client both use it. On the client the `Wait*` variants cover instances that
	may not have replicated yet.
]]
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

export type AliveKind = "Players" | "NPCs" | "Bosses"

local MAP = "Map"
local ALIVE = "Alive"
local RUNTIME = "Instances"
local EFFECTS = "Effects"
local MERCHANTS = "Merchants"
-- Folders of Alive that hold non-player characters.
local NPC_KINDS: { AliveKind } = { "NPCs", "Bosses" }
local ALIVE_KINDS: { AliveKind } = { "Players", "NPCs", "Bosses" }

local isServer = RunService:IsServer()
local warned: { [string]: boolean } = {}

local World = {}

World.NpcKinds = NPC_KINDS
World.AliveKinds = ALIVE_KINDS

local function warnOnce(message: string)
	if not warned[message] then
		warned[message] = true
		warn(`[World] {message}`)
	end
end

-- The server owns the layout: a container the place lacks is created instead of failing.
local function ensure(parent: Instance, name: string): Instance?
	local found = parent:FindFirstChild(name)
	if not found and isServer then
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		return folder
	end
	return found
end

function World.Map(): Instance?
	local map = Workspace:FindFirstChild(MAP)
	if not map then
		warnOnce(`Workspace.{MAP} not found`)
	end
	return map
end

-- Workspace.Map.<name>: "Islands", "Trees", "Barrels", "Sea", "Firepits", "Other".
function World.Find(name: string): Instance?
	local map = World.Map()
	local found = map and map:FindFirstChild(name)
	if map and not found then
		warnOnce(`Workspace.{MAP}.{name} not found`)
	end
	return found
end

function World.Islands(): Instance?
	return World.Find("Islands")
end

function World.Island(name: string): Instance?
	local islands = World.Islands()
	return islands and islands:FindFirstChild(name)
end

-- Follows `path` below Workspace.Map ("Islands", "Island11", "Folder", ...). No warning.
function World.Resolve(path: { string }): Instance?
	local current: Instance? = Workspace:FindFirstChild(MAP)
	for _, name in path do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

-- Client: same as Resolve, waiting up to `timeout` seconds in total for replication.
function World.WaitResolve(path: { string }, timeout: number?): Instance?
	local deadline = os.clock() + (timeout or 30)
	local current: Instance? = Workspace:WaitForChild(MAP, timeout or 30)
	for _, name in path do
		if not current then
			return nil
		end
		current = current:WaitForChild(name, math.max(0.1, deadline - os.clock()))
	end
	return current
end

-- The sea parts (Workspace.Map.Sea.Water0.Model.Water).
function World.SeaParts(): { BasePart }
	local parts: { BasePart } = {}
	local sea = World.Find("Sea")
	if sea then
		for _, descendant in sea:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Name == "Water" then
				table.insert(parts, descendant)
			end
		end
	end
	return parts
end

-- Workspace.Map.Merchants.
function World.Merchants(): Instance?
	local map = Workspace:FindFirstChild(MAP)
	return map and map:FindFirstChild(MERCHANTS)
end

-- Client: the same, waiting up to `timeout` seconds for it to replicate.
function World.WaitMerchants(timeout: number?): Instance?
	return World.WaitResolve({ MERCHANTS }, timeout)
end

--[[
	Workspace.Alive.<kind>. Never nil on the server (created when the place lacks it); on
	the client it is nil until it has replicated: use WaitAlive there.
]]
function World.Alive(kind: AliveKind): Instance?
	local alive = ensure(Workspace, ALIVE)
	return alive and ensure(alive, kind)
end

function World.WaitAlive(kind: AliveKind, timeout: number?): Instance?
	if isServer then
		return World.Alive(kind)
	end
	local alive = Workspace:WaitForChild(ALIVE, timeout or 60)
	local folder = alive and alive:WaitForChild(kind, timeout or 60)
	if not folder then
		warnOnce(`Workspace.{ALIVE}.{kind} not found`)
	end
	return folder
end

-- The folders that hold non-player characters (ordinary enemies and bosses).
function World.NpcFolders(): { Instance }
	local folders: { Instance } = {}
	for _, kind in NPC_KINDS do
		local folder = World.Alive(kind)
		if folder then
			table.insert(folders, folder)
		end
	end
	return folders
end

-- Every non-player character model currently alive in the world.
function World.GetNpcs(): { Instance }
	local models: { Instance } = {}
	for _, folder in World.NpcFolders() do
		for _, child in folder:GetChildren() do
			table.insert(models, child)
		end
	end
	return models
end

--[[
	Client: calls `onAdded` for every current and future child of Alive.NPCs and
	Alive.Bosses, `onRemoved` when one leaves. Yields until the folders have replicated,
	so call it from its own thread. Returns the connections.
]]
function World.ObserveNpcs(onAdded: (Instance) -> (), onRemoved: ((Instance) -> ())?): { RBXScriptConnection }
	local connections: { RBXScriptConnection } = {}
	for _, kind in NPC_KINDS do
		local folder = World.WaitAlive(kind)
		if not folder then
			continue
		end
		table.insert(connections, folder.ChildAdded:Connect(onAdded))
		if onRemoved then
			table.insert(connections, folder.ChildRemoved:Connect(onRemoved))
		end
		for _, child in folder:GetChildren() do
			task.spawn(onAdded, child)
		end
	end
	return connections
end

-- Workspace.Alive itself: one instance that covers every character in a raycast filter.
function World.AliveRoot(): Instance?
	return ensure(Workspace, ALIVE)
end

-- True for a model parented in Workspace.Alive (any class).
function World.IsAlive(model: Instance): boolean
	local alive = Workspace:FindFirstChild(ALIVE)
	return alive ~= nil and model:IsDescendantOf(alive)
end

-- Workspace.Instances: parent of everything spawned by code. Nil only on a client that has
-- not received it yet.
function World.Runtime(): Instance?
	return ensure(Workspace, RUNTIME)
end

--[[
	Workspace.Instances.<name>. The server creates it on first use; a client gets nil until
	the server has (pass a timeout to wait for it).
]]
function World.RuntimeFolder(name: string, timeout: number?): Instance?
	local runtime = World.Runtime()
	if not runtime and timeout then
		runtime = Workspace:WaitForChild(RUNTIME, timeout)
	end
	if not runtime then
		return nil
	end
	local folder = ensure(runtime, name)
	if not folder and timeout then
		folder = runtime:WaitForChild(name, timeout)
	end
	return folder
end

--[[
	Workspace.Instances.Effects: where a client parents the visuals it draws (they exist on
	that client only). The folder comes from the server; until it has replicated a visual
	goes straight into the Workspace instead of being lost.
]]
local effects: Instance? = nil
function World.Effects(): Instance
	local current = effects
	if current and current.Parent then
		return current
	end
	local found = World.RuntimeFolder(EFFECTS)
	effects = found
	return found or Workspace
end

-- Workspace.Instances.Drops: Tools lying on the ground (fruits, boxes, dropped items).
function World.Drops(): Instance
	return World.RuntimeFolder("Drops") or Workspace
end

-- True for a Tool that is on the ground (in Drops, or dropped by the engine in Workspace).
function World.IsOnGround(tool: Instance): boolean
	local parent = tool.Parent
	return parent ~= nil and (parent == Workspace or parent == World.Drops())
end

-- Workspace.Instances.Abilities: solid parts abilities leave in the world (walls, roads, cages).
function World.Abilities(): Instance
	return World.RuntimeFolder("Abilities") or Workspace
end

-- Parent for a loose runtime instance (never nil on the server).
function World.RuntimeParent(): Instance
	return World.Runtime() or Workspace
end

return World
