--!strict
--[[
	Raid bosses (Bosses/_Global): the line the boss throws at a player it was chasing
	when that player dies, as a chat bubble over its head (legacy Chat:Chat on the server).
	params: { Model: Model (the boss), Text: string }
]]
local TextChatService = game:GetService("TextChatService")

local MAX_LENGTH = 100

return function(_origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Model) ~= "Instance" or type(params.Text) ~= "string" then
		return
	end
	local head = (params.Model :: Instance):FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	-- Bubble chat may be off in this place: the taunt is then simply not shown.
	pcall(function()
		TextChatService:DisplayBubble(head, string.sub(params.Text, 1, MAX_LENGTH))
	end)
end
