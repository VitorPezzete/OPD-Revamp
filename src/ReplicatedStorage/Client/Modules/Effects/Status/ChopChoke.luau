--!strict
--[[
	Chop fruit - Chop Choke: the left arm is away, so it is hidden on the body for as
	long as the status is set. The flying arm is drawn by Effects.OneShot.ChopChoke.

	Hidden with the local modifier (reapplied every frame, since the camera scripts
	rewrite it on the local character), never with Transparency: when the status ends
	there is no original value to restore and the arm cannot stay invisible. The legacy
	server unplugged the shoulder joint instead.
]]
local RunService = game:GetService("RunService")

local LIMB = "Left Arm"

local function noop() end

return function(character: Model): () -> ()
	local found = character:FindFirstChild(LIMB)
	if not found then
		return noop
	end
	local limb: Instance = found

	local function setHidden(amount: number)
		if limb:IsA("BasePart") then
			limb.LocalTransparencyModifier = amount
		end
		-- Covers decals and whatever is welded inside the arm (haki shell, hot shell).
		for _, descendant in limb:GetDescendants() do
			if descendant:IsA("BasePart") or descendant:IsA("Decal") then
				(descendant :: any).LocalTransparencyModifier = amount
			end
		end
	end

	local connection = RunService.RenderStepped:Connect(function()
		setHidden(1)
	end)
	setHidden(1)

	return function()
		connection:Disconnect()
		setHidden(0)
	end
end
