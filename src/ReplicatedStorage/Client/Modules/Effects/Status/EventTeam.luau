--!strict
--[[
	World events - team highlight (KOTH teams, Crew Wars crews). The status value is the
	team's Color3. The legacy server parented a Highlight to every participant; each
	client draws its own now.
]]
local WHITE = Color3.fromRGB(255, 255, 255)

return function(character: Model, value: any, _isLocal: boolean): () -> ()
	local highlight = Instance.new("Highlight")
	highlight.Name = "TeamHL"
	highlight.FillColor = if typeof(value) == "Color3" then value else WHITE
	highlight.OutlineColor = WHITE
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.Parent = character

	return function()
		highlight:Destroy()
	end
end
