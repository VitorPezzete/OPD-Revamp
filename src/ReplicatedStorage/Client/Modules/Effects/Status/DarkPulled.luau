--!strict
--[[
	Dark fruit - a character being dragged into a Dark Vortex or a Black Hole.
	Status value: "x|y|z|forceX|forceY|forceZ|P|D": the point it is dragged to and the
	MaxForce, P and D of the BodyPosition the legacy server used. The server times the
	status.

	Victim only: players simulate their own character, so the pull the legacy server did
	with a BodyPosition inside the victim's root runs on the victim's client, with the
	very same mover. NPCs get theirs from the server and never get this status.
]]
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

-- Used when the value carries no mover (the Dark Vortex one).
local DEFAULT_FORCE = 1e8
local DEFAULT_P = 10000
local DEFAULT_D = 1000

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

	local pull = Instance.new("BodyPosition")
	pull.Name = "DarkPull"
	pull.MaxForce = Vector3.new(
		tonumber(fields[4]) or DEFAULT_FORCE,
		tonumber(fields[5]) or DEFAULT_FORCE,
		tonumber(fields[6]) or DEFAULT_FORCE
	)
	pull.P = tonumber(fields[7]) or DEFAULT_P
	pull.D = tonumber(fields[8]) or DEFAULT_D
	pull.Position = Vector3.new(x, y, z)
	pull.Parent = root

	return function()
		pull:Destroy()
	end
end
