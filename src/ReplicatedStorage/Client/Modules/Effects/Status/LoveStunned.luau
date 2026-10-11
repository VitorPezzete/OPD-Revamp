--!strict
--[[
	Love fruit - petrified character (a victim, or the Love user inside its own Petrify):
	a stone shell over the head, torso and each limb for as long as the "LoveStunned"
	status lasts, and the pose it had when the stone set. Runs on players and NPC enemies.

	Status value: the Love user's fruit color string. As in the legacy scripts the stone
	of a player takes the second color and the stone of an NPC the first; without a
	custom color it keeps the grey slate of the templates.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Love.Stun.LovePart<Head|Torso|LArm|RArm|LLeg|RLeg>.

	The legacy game froze the pose by welding every limb to the root on the server. Here
	each client holds the joints where they were (Motor6D.Transform, rewritten after the
	Animator every step), so nothing is left on the character when the stone goes.

	Owner only: a petrified player is twice as heavy. The legacy script added a downward
	force equal to the character's weight for as long as the stone lasted, so a victim
	caught in the air drops at twice gravity and cannot jump as high.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local SHELLS: { [string]: string } = {
	Head = "LovePartHead",
	Torso = "LovePartTorso",
	["Left Arm"] = "LovePartLArm",
	["Right Arm"] = "LovePartRArm",
	["Left Leg"] = "LovePartLLeg",
	["Right Leg"] = "LovePartRLeg",
}

-- Holds every joint of the character in its current pose; returns how to let go.
local function freezePose(character: Model): () -> ()
	local poses: { [Motor6D]: CFrame } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			poses[descendant] = descendant.Transform
		end
	end

	local connection = RunService.Stepped:Connect(function()
		for joint, pose in poses do
			joint.Transform = pose
		end
	end)
	return function()
		connection:Disconnect()
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local release = freezePose(character)

	local weight: Attachment? = nil
	local root = character:FindFirstChild("HumanoidRootPart")
	if isLocal and root and root:IsA("BasePart") then
		local attachment = Instance.new("Attachment")
		attachment.Name = "LoveStunWeight"
		attachment.Parent = root
		local force = Instance.new("VectorForce")
		force.Attachment0 = attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		force.Force = Vector3.new(0, -root.AssemblyMass * Workspace.Gravity, 0)
		force.Parent = attachment
		weight = attachment
	end

	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
	local color = if Players:GetPlayerFromCharacter(character) then secondary else primary

	local shells: { BasePart } = {}
	local folder = EffectAssets.FindFruit("Love", "Stun")
	for limbName, templateName in SHELLS do
		local limb = character:FindFirstChild(limbName)
		local template = folder and folder:FindFirstChild(templateName)
		if not limb or not limb:IsA("BasePart") or not template or not template:IsA("BasePart") then
			continue
		end

		local shell = template:Clone()
		shell.Anchored = false
		shell.CanCollide = false
		shell.CanQuery = false
		shell.CanTouch = false
		shell.Massless = true
		shell.CFrame = limb.CFrame
		if color then
			shell.Color = color
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = shell
		weld.Part1 = limb
		weld.Parent = shell

		shell.Parent = limb
		table.insert(shells, shell)
	end

	return function()
		release()
		if weight then
			weight:Destroy()
		end

		for _, shell in shells do
			shell:Destroy()
		end
	end
end
