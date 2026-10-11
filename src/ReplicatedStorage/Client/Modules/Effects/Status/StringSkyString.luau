--!strict
--[[
	String fruit - Sky String: the 0.3 s pull. The server sets this timed status (0.4 s,
	how long the legacy server kept the string) and removes it; the movement itself
	belongs to the owner's client, which times its own 0.3 s like the legacy LocalScript.

	Status value: "<dx>|<dy>|<dz>|<speed>|<side 1/-1>|<fruit colors>".

	Everyone: a string from the user's shoulder to a point high in the sky, ahead and to
	one side (the legacy offsets: 50 * side, 400, -250 from the root). It is the legacy
	rope: a copy of ReplicatedStorage.Assets.Models.Fruits._Shared.String (a thin
	RopeConstraint, off-white unless the fruit has custom colors) stretched between two
	copies of _Shared.WeldablePart welded to the root. Without the templates the same
	rope is built from scratch.
	Owner only, exactly the legacy sequence: the humanoid goes to the Ragdoll state, a
	BodyVelocity (MaxForce 40000000 on every axis, default P) carries the root along the
	direction at the given speed for 0.3 s, then the mover and the string are removed
	and the humanoid gets up.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local THICKNESS = 0.05
local DEFAULT_COLOR = Color3.fromRGB(248, 248, 248)
local PULL_FORCE = 40000000
local PULL_SECONDS = 0.3

local function noop() end

-- An invisible, massless point welded to the root at `offset`, and its attachment.
local function addPoint(root: BasePart, offset: Vector3): (BasePart, Attachment)
	local point: BasePart
	local template = EffectAssets.FindFruit("_Shared", "WeldablePart")
	if template and template:IsA("BasePart") then
		point = template:Clone()
	else
		local plain = Instance.new("Part")
		plain.Size = Vector3.new(0.05, 0.05, 0.05)
		plain.Transparency = 1
		point = plain
	end
	point.Anchored = false
	point.CanCollide = false
	point.CanQuery = false
	point.CanTouch = false
	point.Massless = true

	local attachment: Attachment
	local authored = point:FindFirstChildOfClass("Attachment")
	if authored then
		attachment = authored
	else
		local added = Instance.new("Attachment")
		added.Parent = point
		attachment = added
	end

	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = point
	weld.C0 = CFrame.new(offset)
	weld.Parent = point

	point.CFrame = root.CFrame * CFrame.new(offset)
	point.Parent = root
	return point, attachment
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local dx, dy, dz = tonumber(fields[1]), tonumber(fields[2]), tonumber(fields[3])
	local speed = tonumber(fields[4])
	local side = tonumber(fields[5]) or 1
	local root = character.PrimaryPart
	if not dx or not dy or not dz or not speed or not root then
		return noop
	end
	local direction = Vector3.new(dx, dy, dz)
	local color = FruitColor.Parse(fields[6] or "")

	local created: { Instance } = {}

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if isLocal and humanoid then
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude > 0.05 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end

	local nearOffset = Vector3.new(side, 0, 0)
	local farOffset = Vector3.new(50 * side, 400, -250)
	local near, nearAttachment = addPoint(root, nearOffset)
	local far, farAttachment = addPoint(root, farOffset)
	table.insert(created, near)
	table.insert(created, far)

	local rope: RopeConstraint
	local template = EffectAssets.FindFruit("_Shared", "String")
	if template and template:IsA("RopeConstraint") then
		rope = template:Clone()
	else
		local plain = Instance.new("RopeConstraint")
		plain.Thickness = THICKNESS
		plain.Color = BrickColor.new(DEFAULT_COLOR)
		rope = plain
	end
	if color then
		rope.Color = BrickColor.new(color)
	end
	rope.Visible = true
	rope.Length = (farOffset - nearOffset).Magnitude
	rope.Attachment0 = nearAttachment
	rope.Attachment1 = farAttachment
	rope.Parent = far

	local ended = false
	local function finish()
		if ended then
			return
		end
		ended = true
		for _, instance in created do
			instance:Destroy()
		end
		if isLocal and humanoid and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end

	if isLocal and humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)

		local pull = Instance.new("BodyVelocity")
		pull.Name = "StringSkyPull"
		pull.MaxForce = Vector3.new(PULL_FORCE, PULL_FORCE, PULL_FORCE)
		pull.Velocity = direction * speed
		pull.Parent = root
		table.insert(created, pull)

		task.delay(PULL_SECONDS, finish)
	end

	return finish
end
