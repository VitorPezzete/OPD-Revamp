--!strict
--[[
	Loads a menu this client does not have the code of.

	Some menus are not part of the client: the server keeps their modules and, for a
	player who may have one, puts a copy in that player's PlayerGui and answers GetAccess
	with where it is. This module asks, waits for the copy and runs it. It knows nothing
	else about the menu: what it is, what it shows and how it opens are all in the copy
	and in the server's answer.

		MenuLoader.Load(service)    -- service: the remote mirror that answers GetAccess

	A client that is answered nil (every ordinary player) loads nothing.
]]
local Players = game:GetService("Players")

local MenuLoader = {}

-- Seconds the copy is given to arrive.
local ARRIVAL_SECONDS = 30
local ENTRY_MODULE = "Main"

local function run(service: any, access: { [string]: any })
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", ARRIVAL_SECONDS)
	local container = playerGui and playerGui:WaitForChild(access.Module, ARRIVAL_SECONDS)
	local entry = container and container:WaitForChild(ENTRY_MODULE, ARRIVAL_SECONDS)
	if not entry or not entry:IsA("ModuleScript") then
		return
	end
	local start = (require :: any)(entry)
	if type(start) == "function" then
		start(service, access)
	end
end

function MenuLoader.Load(service: any)
	service
		:GetAccess()
		:andThen(function(access: any)
			if type(access) == "table" and type(access.Module) == "string" then
				run(service, access)
			end
		end)
		:catch(warn)
end

return MenuLoader
