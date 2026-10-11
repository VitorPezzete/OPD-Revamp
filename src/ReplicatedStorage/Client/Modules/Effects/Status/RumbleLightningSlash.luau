--!strict
--[[
	Lightning Slash (damage boost read by DamageModifiers.RumbleLightningSlash): red
	sparks crackling around the body while the status lasts.

	Legacy: 100 sparks, one every 0.08 s, up to 3.75 studs from the root on each axis,
	0.1 thick, "Really red", each gone after 0.75 s. Here they simply last as long as the
	status does (the legacy flag lasted 10 s, the sparks 8).
]]
local startSparks = require(script.Parent.Parent.OneShot.RumbleSparks)

local COLOR = Color3.fromRGB(255, 0, 0)

local function noop() end

return function(character: Model): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return noop
	end

	return startSparks(root.Position, {
		Part = root,
		Range = 3.75,
		Count = math.huge,
		Interval = 0.08,
		Thickness = 0.1,
		Life = 0.75,
		Color = COLOR,
	})
end
