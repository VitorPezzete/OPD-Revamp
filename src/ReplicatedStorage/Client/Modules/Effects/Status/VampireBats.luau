--!strict
--[[
	Vampire fruit - the raised bats circling their vampire.
	Status value: "<bat count>|<fruit color string>".

	On the server a bat is only a number; these models are the whole "summon". Each one
	orbits the character exactly like the legacy AI script moved it (a circle of 5 to 8
	studs, 3 to 5 studs up, bobbing, wings flapping), but here, per client, instead of
	one server Heartbeat per bat. While the vampire's attack mode is on (the
	VampireBatAttack attribute) they circle twice as fast.

	Template: ReplicatedStorage.Assets.Models.Fruits.Vampire.Power4.Bat - a model with
	Torso, Head, LeftWing and RightWing parts joined by motors named after the part they
	sit in. Its AI script is removed from the copy. Custom colors paint the four parts
	with the first color.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local MAX_BATS = 6
local ATTACK_ATTRIBUTE = "VampireBatAttack"
local ORBIT_RATE = 4
local ATTACK_RATE_MULTIPLIER = 2
local PAINTED: { [string]: boolean } = { Torso = true, Head = true, LeftWing = true, RightWing = true }

type Bat = {
	Model: Model,
	Torso: BasePart,
	LeftJoint: JointInstance?,
	RightJoint: JointInstance?,
	HeadJoint: JointInstance?,
	Radius: number,
	Height: number,
	OffsetX: number,
	OffsetY: number,
	OffsetZ: number,
}

local random = Random.new()

local function noop() end

local function findJoint(model: Model, partName: string): JointInstance?
	local part = model:FindFirstChild(partName)
	local joint = part and part:FindFirstChild(partName)
	return if joint and joint:IsA("JointInstance") then joint else nil
end

local function makeBat(template: Model, primary: Color3?): Bat?
	local model = template:Clone()
	local torso = model:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		model:Destroy()
		return nil
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = descendant == torso
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			if primary and PAINTED[descendant.Name] then
				descendant.Color = primary
			end
		end
	end

	return {
		Model = model,
		Torso = torso,
		LeftJoint = findJoint(model, "LeftWing"),
		RightJoint = findJoint(model, "RightWing"),
		HeadJoint = findJoint(model, "Head"),
		Radius = 5 + random:NextNumber() * 3,
		Height = 3 + random:NextNumber() * 2,
		OffsetX = random:NextNumber() * 10,
		OffsetY = random:NextNumber() * 5,
		OffsetZ = random:NextNumber() * 10,
	}
end

return function(character: Model, value: any): () -> ()
	local fields = EffectAssets.Unpack(value)
	local count = math.clamp(math.floor(tonumber(fields[1]) or 0), 0, MAX_BATS)
	local template = EffectAssets.FindFruit("Vampire", "Power4", "Bat")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if count == 0 or not template or not template:IsA("Model") or not foundRoot or not foundRoot:IsA("BasePart") then
		return noop
	end
	local root: BasePart = foundRoot

	local primary = FruitColor.Parse(fields[2] or "")
	local bats: { Bat } = {}
	for _ = 1, count do
		local bat = makeBat(template, primary)
		if bat then
			bat.Model.Parent = World.Effects()
			table.insert(bats, bat)
		end
	end

	local clock = 0
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		local rate = ORBIT_RATE * (if character:GetAttribute(ATTACK_ATTRIBUTE) then ATTACK_RATE_MULTIPLIER else 1)
		clock += deltaTime * rate

		local wingAngle = math.sin(clock * 6) * math.rad(40)
		local headBob = math.sin(clock * 0.5) * math.rad(10)
		local center = root.Position

		for _, bat in bats do
			if bat.LeftJoint then
				bat.LeftJoint.C0 = CFrame.new(-0.134, 0.134, 0) * CFrame.Angles(0, wingAngle, 0)
			end
			if bat.RightJoint then
				bat.RightJoint.C0 = CFrame.new(0.134, 0.134, 0) * CFrame.Angles(0, -wingAngle, 0)
			end
			if bat.HeadJoint then
				bat.HeadJoint.C0 = CFrame.new(0, 0.401, 0) * CFrame.Angles(headBob, 0, 0)
			end

			local offset = Vector3.new(
				math.sin(clock + bat.OffsetX) * bat.Radius,
				bat.Height + math.sin(clock * 2 + bat.OffsetY),
				math.cos(clock + bat.OffsetZ) * bat.Radius
			)
			bat.Torso.CFrame = CFrame.lookAt(center + offset, center)
		end
	end)

	return function()
		connection:Disconnect()
		for _, bat in bats do
			bat.Model:Destroy()
		end
	end
end
