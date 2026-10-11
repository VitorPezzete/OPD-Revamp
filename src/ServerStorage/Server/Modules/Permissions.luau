--!strict
--[[
	The single answer to "may this player do that?". Every privileged action of the
	game (console commands, staff exemptions, private-server staff rules) asks here;
	nothing else keeps its own id list.

		Permissions.GetRole(userId)             -> "None" | "Tester" | "Mod" | "Admin" | "Owner"
		Permissions.Has(player, "Mod")          -> role is Mod or above
		Permissions.IsStaff(player | userId)    -> Mod or above
		Permissions.CanTarget(executor, userId) -> executor strictly outranks the target
		Permissions.Resolve(player)             -> role, after the group rank was fetched (yields)

	Legacy bugs this replaces:
	- `if permission == "Owner" or "Mod"` (always true): any player could global-kick.
	- Checks made by the client GUI only, or after `repeat wait()` loops.
	- Three copies of the id lists that had drifted apart.
]]
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local AdminConfig = require(ServerStorage.Server.Configs.AdminConfig)

export type Role = AdminConfig.Role

local Permissions = {}

local LEVELS = AdminConfig.RoleLevels
local STAFF_LEVEL = LEVELS.Mod

local roleByUserId: { [number]: Role } = {}
-- Group roles of the players in this server; false when the lookup failed or matched nothing.
local groupRoles: { [number]: Role | false } = {}
local resolving: { [number]: boolean } = {}

local baseRole: Role = if table.find(AdminConfig.TesterPlaceIds, game.PlaceId) then "Tester" else "None"

local function highest(a: Role, b: Role): Role
	return if LEVELS[b] > LEVELS[a] then b else a
end

local function assign(userIds: { number }, role: Role)
	for _, userId in userIds do
		roleByUserId[userId] = highest(roleByUserId[userId] or "None", role)
	end
end

assign(AdminConfig.Moderators, "Mod")
assign(AdminConfig.Admins, "Admin")
assign(AdminConfig.Owners, "Owner")

local function usesGroup(): boolean
	return AdminConfig.Group.Id ~= 0 and #AdminConfig.Group.Ranks > 0
end

local function fetchGroupRole(player: Player): Role | false
	local ok, rank = pcall(function(): number
		return (player :: any):GetRankInGroupAsync(AdminConfig.Group.Id)
	end)
	if not ok or type(rank) ~= "number" then
		return false
	end

	local role: Role = "None"
	for _, entry in AdminConfig.Group.Ranks do
		if rank >= entry.MinRank then
			role = highest(role, entry.Role)
		end
	end
	return if role == "None" then false else role
end

function Permissions.GetRole(userId: number): Role
	local role = highest(baseRole, roleByUserId[userId] or "None")
	local groupRole = groupRoles[userId]
	if groupRole then
		role = highest(role, groupRole)
	end
	return role
end

function Permissions.GetLevel(userId: number): number
	return LEVELS[Permissions.GetRole(userId)]
end

function Permissions.Has(player: Player, role: Role): boolean
	return Permissions.GetLevel(player.UserId) >= LEVELS[role]
end

function Permissions.IsStaff(subject: Player | number): boolean
	local userId = if type(subject) == "number" then subject else subject.UserId
	return Permissions.GetLevel(userId) >= STAFF_LEVEL
end

-- Staff can only act on someone they outrank: a moderator cannot kick, ban or edit an
-- owner or another moderator, and nobody can do it to an owner.
function Permissions.CanTarget(executor: Player, targetUserId: number): boolean
	return Permissions.GetLevel(executor.UserId) > Permissions.GetLevel(targetUserId)
end

-- Role once the group lookup is done. Yields on the first call for a player.
function Permissions.Resolve(player: Player): Role
	local userId = player.UserId
	if usesGroup() and groupRoles[userId] == nil then
		if resolving[userId] then
			repeat
				task.wait()
			until not resolving[userId]
		else
			resolving[userId] = true
			local role = fetchGroupRole(player)
			if player.Parent == Players then
				groupRoles[userId] = role
			end
			resolving[userId] = nil
		end
	end
	return Permissions.GetRole(userId)
end

Players.PlayerAdded:Connect(function(player: Player)
	Permissions.Resolve(player)
end)
Players.PlayerRemoving:Connect(function(player: Player)
	groupRoles[player.UserId] = nil
end)
for _, player in Players:GetPlayers() do
	task.spawn(Permissions.Resolve, player)
end

return Permissions
