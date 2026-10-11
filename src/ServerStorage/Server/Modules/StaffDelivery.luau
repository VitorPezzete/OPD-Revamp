--!strict
--[[
	Hands the code of a staff menu to one player, and to nobody else.

	The menus are client code (they draw with Iris and read the local input), but what
	they contain is a description of everything staff can do: tab names, action names,
	ranges, texts. Kept under ReplicatedStorage they reached every client, and an
	exploiter could read them. They live in ServerStorage.Server.StaffClient instead,
	which is never replicated:

		StaffClient.<Bundle>.Main      returns function(service, access): builds the menu
		StaffClient.<Bundle>.<others>  whatever Main requires from its own folder

	StaffDelivery.Give(player, "Mod") clones the bundle's ModuleScripts into a ScreenGui
	of that player's PlayerGui and returns the ScreenGui's name. A PlayerGui replicates
	only to its owner, so no other client ever receives the copies; the ScreenGui is
	disabled, holds no interface and has ResetOnSpawn off, so it outlives the character.
	Its name is random: the client learns it from the server's answer and nothing in the
	client's own code says what to look for.

	This module authorises nothing. Its callers (AdminService, DevService) decide who may
	have a menu before they call it.
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local StaffDelivery = {}

local SOURCE_FOLDER = "StaffClient"
local ENTRY_MODULE = "Main"
local PLAYER_GUI_WAIT = 10

local delivered: { [Player]: { [string]: ScreenGui } } = {}

-- The name of the container, or nil when the bundle does not exist or the player left.
function StaffDelivery.Give(player: Player, bundle: string): string?
	local source = ServerStorage.Server:FindFirstChild(SOURCE_FOLDER)
	local folder = source and source:FindFirstChild(bundle)
	if not folder or not folder:FindFirstChild(ENTRY_MODULE) then
		warn(`[StaffDelivery] there is no bundle "{bundle}"`)
		return nil
	end

	local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", PLAYER_GUI_WAIT)
	if not playerGui or player.Parent ~= Players then
		return nil
	end

	-- Looked up after the wait above: a second request made meanwhile reuses the first copy.
	local given = delivered[player]
	if not given then
		given = {}
		delivered[player] = given
	end
	local existing = given[bundle]
	if existing and existing.Parent == playerGui then
		return existing.Name
	end

	local container = Instance.new("ScreenGui")
	container.Name = HttpService:GenerateGUID(false)
	container.ResetOnSpawn = false
	container.Enabled = false
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			child:Clone().Parent = container
		end
	end
	-- Parented last, complete: the client receives the modules together with the container.
	container.Parent = playerGui
	given[bundle] = container
	return container.Name
end

Players.PlayerRemoving:Connect(function(player: Player)
	delivered[player] = nil
end)

return StaffDelivery
