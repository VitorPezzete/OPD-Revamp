--!strict
--[[
	The Tool the local character is holding, as a Fusion value that follows equips,
	unequips and respawns. For the small prompts that belong to the item in hand.

		local held = HeldTool.observe(scope)      -- Fusion.Value<Tool?>
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

type Scope = Fusion.Scope<typeof(Fusion)>

local HeldTool = {}

function HeldTool.observe(scope: Scope): Fusion.Value<Tool?>
	local player = Players.LocalPlayer
	local held: Fusion.Value<Tool?> = scope:Value(nil :: Tool?)
	local connections: { RBXScriptConnection } = {}

	local function bind(character: Model)
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)

		local function refresh(child: Instance)
			if child:IsA("Tool") then
				held:set(character:FindFirstChildOfClass("Tool"))
			end
		end
		table.insert(connections, character.ChildAdded:Connect(refresh))
		table.insert(connections, character.ChildRemoved:Connect(refresh))
		held:set(character:FindFirstChildOfClass("Tool"))
	end

	table.insert(scope, player.CharacterAdded:Connect(bind))
	table.insert(scope, function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	if player.Character then
		bind(player.Character)
	end
	return held
end

return HeldTool
