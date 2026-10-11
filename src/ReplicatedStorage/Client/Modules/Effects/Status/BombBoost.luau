--!strict
--[[
	Bomb fruit - Bomb Boost: the launch.
	Status value: "<vx>|<vy>|<vz>|<cast number>" (studs per second; the number only makes
	two equal launches differ).

	Owner only. The character turns towards where it is thrown, as the legacy client
	turned it on release. The throw itself is the server's held push (the legacy
	BodyVelocity: force 4,000,000, 0.1 s), sent through CharacterService:ApplyImpulse.
]]
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local fields = EffectAssets.Unpack(value)
	local x, y, z = tonumber(fields[1]), tonumber(fields[2]), tonumber(fields[3])
	local root = character:FindFirstChild("HumanoidRootPart")
	if not x or not y or not z or not root or not root:IsA("BasePart") then
		return noop
	end

	local velocity = Vector3.new(x, y, z)
	local speed = velocity.Magnitude
	if speed ~= speed or speed < 1e-3 then
		return noop
	end
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	if flat.Magnitude > 1e-3 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end

	return noop
end
