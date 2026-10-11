--!strict
--[[
	Clear fruit invisibility, rendered locally.
	As in the legacy game the body vanishes for everyone, its owner included: every part,
	decal and texture goes fully transparent and the haki outlines (SelectionBox /
	SelectionSphere) are hidden. What the legacy server never touched stays visible and
	gives the user away: particles, beams, trails, lights and the billboards over the head.

	Nothing here touches real Transparency, so there is no original value to restore
	and nothing to get stuck: cleanup just zeroes the local modifiers.
]]
local RunService = game:GetService("RunService")

local RENDER_STEP_NAME = "InvisibleOwnerGhost"

local function isOutline(instance: Instance): boolean
	return instance:IsA("SelectionBox") or instance:IsA("SelectionSphere")
end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	local amount = 1
	local disabled: { [Instance]: boolean } = {}
	local faded: { [Instance]: boolean } = {}

	local function apply(instance: Instance)
		if instance:IsA("BasePart") or instance:IsA("Decal") then
			(instance :: any).LocalTransparencyModifier = amount
			faded[instance] = true
		elseif isOutline(instance) and (instance :: any).Visible then
			(instance :: any).Visible = false
			disabled[instance] = true
		end
	end

	for _, descendant in character:GetDescendants() do
		apply(descendant)
	end
	local addedConnection = character.DescendantAdded:Connect(apply)

	if isLocal then
		-- The camera scripts rewrite the local character's modifier when zooming,
		-- so it is reapplied right after them every frame.
		RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function()
			for instance in faded do
				(instance :: any).LocalTransparencyModifier = math.max((instance :: any).LocalTransparencyModifier, amount)
			end
		end)
	end

	return function()
		addedConnection:Disconnect()
		if isLocal then
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		end

		for instance in faded do
			(instance :: any).LocalTransparencyModifier = 0
		end
		for instance in disabled do
			(instance :: any).Visible = true
		end
	end
end
