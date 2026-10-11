--!strict
--[[
	Yamato gate: a traveller fades out while it sinks into the gate and is visible again
	when the status ends (the server has moved it by then). Status value: height of the
	gate (unused here), for the 2 s of the trip.

	Legacy anchored every part on the server, lifted the model into the gate with a
	tweened CFrameValue and hid each part as it crossed the disc. The fade here is local
	to each client (LocalTransparencyModifier), so nothing has to be restored on the
	server and accessories are covered too.
]]
local RunService = game:GetService("RunService")

local FADE = 1.5

return function(character: Model, _value: any, _isLocal: boolean): () -> ()
	local parts: { BasePart } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	local started = os.clock()
	-- Every frame: the camera scripts also write this property on the local character.
	local connection = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - started) / FADE, 0, 1)
		for _, part in parts do
			part.LocalTransparencyModifier = alpha
		end
	end)

	return function()
		connection:Disconnect()
		for _, part in parts do
			part.LocalTransparencyModifier = 0
		end
	end
end
