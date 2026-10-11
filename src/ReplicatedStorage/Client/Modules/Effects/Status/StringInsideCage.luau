--!strict
--[[
	String fruit - Bird Cage: a character inside someone's cage. The status is refreshed
	by the server every tick while the character is inside and lasts one second; it is
	also the "trapped" flag for the HUD and for movement powers that must refuse to work.

	Status value: "<x>|<y>|<z>|<radius>|<shrink start (server time, 0 = still)>|<shrink rate>".

	Owner only: the character is kept inside the sphere. The invisible barrier part of
	the server stops ordinary walking; this is what holds when the cage shrinks (an
	anchored part that is resized does not push anyone) or when the barrier asset is
	missing. A character more than 50 studs outside is left alone: it got there by a
	respawn or a teleport, and the status expires by itself.
]]
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

-- Distance kept from the strings, so the body does not sit inside the shell.
local MARGIN = 2
local MIN_RADIUS = 1
local MAX_PULL = 50

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local fields = EffectAssets.Unpack(value)
	local x, y, z = tonumber(fields[1]), tonumber(fields[2]), tonumber(fields[3])
	local startRadius = tonumber(fields[4])
	local shrinkStart = tonumber(fields[5]) or 0
	local shrinkRate = tonumber(fields[6]) or 0
	if not x or not y or not z or not startRadius then
		return noop
	end
	local center = Vector3.new(x, y, z)

	local connection = RunService.Heartbeat:Connect(function()
		local root = character.PrimaryPart
		if not root then
			return
		end

		local radius = startRadius
		if shrinkStart > 0 then
			radius = math.max(MIN_RADIUS, startRadius - shrinkRate * (Workspace:GetServerTimeNow() - shrinkStart))
		end
		local limit = math.max(radius - MARGIN, 0)

		local offset = root.Position - center
		local distance = offset.Magnitude
		if distance <= limit or distance - limit > MAX_PULL or distance < 1e-3 then
			return
		end

		local outward = offset.Unit
		root.CFrame = root.CFrame.Rotation + (center + outward * limit)

		local velocity = root.AssemblyLinearVelocity
		local escaping = velocity:Dot(outward)
		if escaping > 0 then
			root.AssemblyLinearVelocity = velocity - outward * escaping
		end
	end)

	return function()
		connection:Disconnect()
	end
end
