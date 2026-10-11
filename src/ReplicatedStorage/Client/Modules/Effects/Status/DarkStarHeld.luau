--!strict
--[[
	Dark fruit - a character tied to a flying Dark Star.
	Status value: "ox|oy|oz|dx|dy|dz|speed|duration": where the star left from, its
	direction, its speed and how long it flies. The server times the status.

	Victim only: the legacy server tied the victim's root to the star with a 1 stud
	rope. Players simulate their own character, so the victim's client follows the same
	straight path instead (the clock starts when the status arrives). NPCs are pushed
	along by the server and never get this status.
]]
local RunService = game:GetService("RunService")

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HOLD_FORCE = 1000000
local HOLD_RESPONSIVENESS = 80

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local fields = EffectAssets.Unpack(value)
	local numbers: { number } = {}
	for index = 1, 8 do
		local parsed = tonumber(fields[index])
		if not parsed then
			return noop
		end
		numbers[index] = parsed
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return noop
	end

	local origin = Vector3.new(numbers[1], numbers[2], numbers[3])
	local direction = Vector3.new(numbers[4], numbers[5], numbers[6])
	local speed, duration = numbers[7], numbers[8]

	local attachment = Instance.new("Attachment")
	attachment.Name = "DarkStarHold"
	attachment.Parent = root

	local hold = Instance.new("AlignPosition")
	hold.Mode = Enum.PositionAlignmentMode.OneAttachment
	hold.Attachment0 = attachment
	hold.Position = origin
	hold.MaxForce = HOLD_FORCE
	hold.Responsiveness = HOLD_RESPONSIVENESS
	hold.Parent = attachment

	local started = os.clock()
	local connection = RunService.Heartbeat:Connect(function()
		local elapsed = math.min(os.clock() - started, duration)
		hold.Position = origin + direction * speed * elapsed
	end)

	return function()
		connection:Disconnect()
		attachment:Destroy()
	end
end
