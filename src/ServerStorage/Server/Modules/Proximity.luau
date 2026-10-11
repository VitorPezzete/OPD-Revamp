--!strict
--[[
	Distance checks for requests that only make sense next to something in the world
	(buying from a merchant, opening a chest). The client only says "I want X from
	merchant Y"; the server confirms the character is actually standing there.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Util.World)

local Proximity = {}

local DEFAULT_RANGE = 30

local function getPosition(target: Instance): Vector3?
	if target:IsA("BasePart") then
		return target.Position
	elseif target:IsA("Model") then
		return target:GetPivot().Position
	elseif target:IsA("Attachment") then
		return target.WorldPosition
	end
	return nil
end

function Proximity.IsNear(player: Player, target: Instance?, range: number?): boolean
	local character = player.Character
	local root = character and character.PrimaryPart
	local position = target and getPosition(target)
	if not root or not position then
		return false
	end
	return (root.Position - position).Magnitude <= (range or DEFAULT_RANGE)
end

-- Workspace.Map.Merchants.<name>, checked for proximity. Returns the model when the player is near it.
function Proximity.GetMerchant(player: Player, name: unknown, range: number?): Model?
	if type(name) ~= "string" then
		return nil
	end
	local folder = World.Merchants()
	local merchant = folder and folder:FindFirstChild(name)
	if merchant and merchant:IsA("Model") and Proximity.IsNear(player, merchant, range) then
		return merchant
	end
	return nil
end

return Proximity
