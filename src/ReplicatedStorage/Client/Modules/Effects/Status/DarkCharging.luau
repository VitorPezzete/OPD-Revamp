--!strict
--[[
	Dark fruit - Dark Charge while absorbing: darkness swirling on the head, torso and
	each limb. Status value: the fruit color string.
	Template: ReplicatedStorage.Assets.Models.Fruits.Dark.Power1.DarkChargePart (a part
	with a "DarkVortex" emitter).

	Owner only: the legacy guide, a flat black disc under the feet that widens as hits
	are swallowed. Its diameter is the replicated DarkChargeGuide attribute (computed by
	the server from the charge); it is always black, whatever the fruit colors.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

local GUIDE_ATTRIBUTE = "DarkChargeGuide"
local GUIDE_THICKNESS = 0.1
local GUIDE_TRANSPARENCY = 0.7
-- Below the root: just above the ground the character stands on.
local GUIDE_DROP = 2.9
local GUIDE_ROTATION = CFrame.Angles(0, 0, math.rad(90))

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")

	local created: { Instance } = {}
	local connections: { RBXScriptConnection } = {}

	local template = EffectAssets.FindFruit("Dark", "Power1", "DarkChargePart")
	if template and template:IsA("BasePart") then
		for _, limbName in LIMBS do
			local limb = character:FindFirstChild(limbName)
			if not limb or not limb:IsA("BasePart") then
				continue
			end

			local part = template:Clone()
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.CFrame = limb.CFrame
			if primary and secondary then
				for _, descendant in part:GetDescendants() do
					if descendant:IsA("ParticleEmitter") then
						descendant.Color = FruitColor.ToSequence(primary, secondary)
					end
				end
			end

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = limb
			weld.Parent = part

			part.Parent = limb
			table.insert(created, part)
		end
	end

	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if isLocal and foundRoot and foundRoot:IsA("BasePart") then
		local root: BasePart = foundRoot

		local disc = Instance.new("Part")
		disc.Name = "DarkChargeGuide"
		disc.Shape = Enum.PartType.Cylinder
		disc.Color = Color3.new(0, 0, 0)
		disc.Transparency = GUIDE_TRANSPARENCY
		disc.Anchored = true
		disc.CanCollide = false
		disc.CanQuery = false
		disc.CanTouch = false
		table.insert(created, disc)

		local function resize()
			local diameter = character:GetAttribute(GUIDE_ATTRIBUTE)
			if type(diameter) == "number" and diameter > 0 then
				disc.Size = Vector3.new(GUIDE_THICKNESS, diameter, diameter)
				disc.Parent = World.Effects()
			else
				disc.Parent = nil
			end
		end

		local function follow()
			local position = root.Position
			disc.CFrame = CFrame.new(position.X, position.Y - GUIDE_DROP, position.Z) * GUIDE_ROTATION
		end

		follow()
		resize()
		table.insert(connections, character:GetAttributeChangedSignal(GUIDE_ATTRIBUTE):Connect(resize))
		table.insert(connections, RunService.RenderStepped:Connect(follow))
	end

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, instance in created do
			instance:Destroy()
		end
	end
end
