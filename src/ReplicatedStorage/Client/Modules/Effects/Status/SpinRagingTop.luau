--!strict
--[[
	Spin fruit - Raging Top.
	Status value: "<spin speed in degrees per second>|<fruit color string>".

	Everyone: the melee trail on each arm.
	Template: ReplicatedStorage.Assets.Models.Weapons.Melee.MeleePart (an invisible part
	with the white punch Trail), welded to the centre of the arm as the legacy server
	did. It keeps its authored look: the legacy game never applied the fruit colors to it.
	Owner only: the spin. The character stops turning with the camera and is rotated
	around its vertical axis by a constraint; walking is untouched.

	The legacy server rotated a BodyGyro on the head every Heartbeat.
]]
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local ARMS = { "Right Arm", "Left Arm" }
local DEFAULT_DEGREES_PER_SECOND = 1000
local SPIN_TORQUE = 4000000

local function parseValue(value: any): (number, string)
	if type(value) ~= "string" then
		return DEFAULT_DEGREES_PER_SECOND, ""
	end
	local speed, colors = string.match(value, "^(%d+)|(.*)$")
	return tonumber(speed) or DEFAULT_DEGREES_PER_SECOND, (colors or "") :: string
end

local function addTrail(arm: BasePart, template: BasePart, created: { Instance })
	local part = template:Clone()
	part.Name = "SpinRagingTopTrail"
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end

	local weld = Instance.new("Weld")
	weld.Part0 = arm
	weld.Part1 = part
	weld.Parent = part

	part.Parent = arm
	table.insert(created, part)
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local degreesPerSecond = parseValue(value)

	local created: { Instance } = {}
	local template = EffectAssets.Find("Models", "Weapons", "Melee", "MeleePart")
	if template and template:IsA("BasePart") then
		for _, armName in ARMS do
			local arm = character:FindFirstChild(armName)
			if arm and arm:IsA("BasePart") then
				addTrail(arm, template, created)
			end
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local previousAutoRotate: boolean? = nil

	if isLocal and humanoid and root and root:IsA("BasePart") then
		previousAutoRotate = humanoid.AutoRotate
		humanoid.AutoRotate = false

		local attachment = Instance.new("Attachment")
		attachment.Name = "SpinRagingTop"
		attachment.Parent = root

		local spin = Instance.new("AngularVelocity")
		spin.Attachment0 = attachment
		spin.RelativeTo = Enum.ActuatorRelativeTo.World
		-- The legacy spin was clockwise seen from above (negative Y).
		spin.AngularVelocity = Vector3.new(0, -math.rad(degreesPerSecond), 0)
		spin.MaxTorque = SPIN_TORQUE
		spin.Parent = attachment

		table.insert(created, attachment)
	end

	return function()
		for _, instance in created do
			instance:Destroy()
		end
		if humanoid and previousAutoRotate ~= nil then
			humanoid.AutoRotate = previousAutoRotate
		end
	end
end
