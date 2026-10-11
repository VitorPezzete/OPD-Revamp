--!strict
--[[
	World events - a player who accepted the invitation blinks white until the event
	starts (a few seconds). The legacy server ran one blinking loop per accepted player.
]]
local BLINK_SECONDS = 0.5

return function(character: Model, _value: any, _isLocal: boolean): () -> ()
	local highlight = Instance.new("Highlight")
	highlight.Name = "EventHL"
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor = Color3.fromRGB(235, 235, 235)
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Parent = character

	local running = true
	task.spawn(function()
		local visible = false
		while running do
			highlight.FillTransparency = if visible then 0.5 else 1
			highlight.OutlineTransparency = if visible then 0.1 else 1
			visible = not visible
			task.wait(BLINK_SECONDS)
		end
	end)

	return function()
		running = false
		highlight:Destroy()
	end
end
