--!strict
--[[
	Walking through the tools of the backpack with a gamepad: the actions "ToolNext" and
	"ToolPrevious" of InputController (rebindable, Settings > Keybinds > Controller).

	Why the game does it itself. The engine walks through its hotbar with L1 / R1, and
	only while nothing else takes those buttons. The Advanced layout uses L1 for the second
	fruit's menu and R1 for the special attack, which left one direction at best, behind
	the engine's own delay, and no way to put a tool away; and InputController takes L1 and
	R1 away from the engine whenever an action is bound to them. So both layouts have their
	own two actions (Classic: R1 / L1, the engine's buttons; Advanced: D-pad up / down),
	and the engine's walk only still happens on L1 / R1 if the player leaves them unbound.

	The walk goes round a ring: empty hands, then each tool in the order the hotbar shows
	them. Next from the last tool - or Previous from the first - puts the tool away, which
	is how a gamepad unequips.

	The order is the order in which the tools reached the player, which is the hotbar's:
	a tool keeps its place while it moves between the backpack and the hands, and loses it
	when it is in neither any more. It is kept from the two ChildAdded signals; nothing
	runs per frame.

	Equipping is the engine's own Humanoid:EquipTool / UnequipTools on the local character,
	what its hotbar does: the server sees an ordinary equip. Nothing happens while the
	hotbar is hidden (no character, or a screen that hides it): what cannot be seen is not
	changed blind.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local NEXT_ACTION = "ToolNext"
local PREVIOUS_ACTION = "ToolPrevious"
local BACKPACK_CLASS = "Backpack"

local ToolCycleController = Knit.CreateController({
	Name = "ToolCycleController",
})

local InputController

local localPlayer = Players.LocalPlayer

-- The tools the player has, in the order they arrived.
local order: { Tool } = {}
local backpack: Instance? = nil
local backpackConnection: RBXScriptConnection? = nil
local characterConnection: RBXScriptConnection? = nil

local function isOwned(tool: Tool): boolean
	local parent = tool.Parent
	return parent ~= nil and (parent == backpack or parent == localPlayer.Character)
end

local function track(child: Instance)
	if child:IsA("Tool") and not table.find(order, child) then
		table.insert(order, child)
	end
end

-- Drops the tools that are neither in the backpack nor in the hands any more.
local function prune()
	for index = #order, 1, -1 do
		if not isOwned(order[index]) then
			table.remove(order, index)
		end
	end
end

local function bindBackpack(container: Instance?)
	if backpackConnection then
		backpackConnection:Disconnect()
		backpackConnection = nil
	end
	backpack = container
	if container then
		for _, child in container:GetChildren() do
			track(child)
		end
		backpackConnection = container.ChildAdded:Connect(track)
	end
end

local function bindCharacter(character: Model?)
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
	if character then
		for _, child in character:GetChildren() do
			track(child)
		end
		characterConnection = character.ChildAdded:Connect(track)
	end
end

local function isHotbarShown(): boolean
	local ok, shown = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack)
	return ok and shown == true
end

-- One step round the ring (1: next, -1: previous).
local function step(direction: number)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or not isHotbarShown() then
		return
	end

	prune()
	local count = #order
	if count == 0 then
		return
	end

	-- 0 is empty hands; 1..count are the tools.
	local equipped = character:FindFirstChildOfClass("Tool")
	local index = if equipped then table.find(order, equipped) or 0 else 0
	local target = (index + direction) % (count + 1)
	if target == 0 then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(order[target])
	end
end

function ToolCycleController:KnitInit()
	InputController = Knit.GetController("InputController")
end

function ToolCycleController:KnitStart()
	-- The backpack is replaced with every character.
	bindBackpack(localPlayer:FindFirstChildOfClass(BACKPACK_CLASS))
	localPlayer.ChildAdded:Connect(function(child: Instance)
		if child:IsA(BACKPACK_CLASS) then
			bindBackpack(child)
		end
	end)
	bindCharacter(localPlayer.Character)
	localPlayer.CharacterAdded:Connect(bindCharacter)
	localPlayer.CharacterRemoving:Connect(function()
		bindCharacter(nil)
	end)

	InputController:OnAction(NEXT_ACTION, function(phase: string)
		if phase == "Begin" then
			step(1)
		end
	end)
	InputController:OnAction(PREVIOUS_ACTION, function(phase: string)
		if phase == "Begin" then
			step(-1)
		end
	end)
end

return ToolCycleController
