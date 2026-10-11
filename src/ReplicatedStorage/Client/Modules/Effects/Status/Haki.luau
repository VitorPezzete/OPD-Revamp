--!strict
--[[
	Armament haki: a dark shell over each limb while the status is active.
	Template: ReplicatedStorage.Assets.Models.Fruits._Shared.Haki (a small part with a BlockMesh).

	The shell is a welded local clone, sized a little larger than the limb it covers: at
	the exact size the two surfaces share a plane and flicker through each other. The real
	limb is never touched, so turning haki off can never leave a limb invisible (the
	legacy server code did, whenever a limb was missing mid-loop).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LIMBS = { "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local FLASH_TIME = 0.2
local FLASH_COLOR = Color3.fromRGB(255, 255, 255)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
-- Studs the shell sticks out of the limb on every side.
local SHELL_MARGIN = 0.01

local function noop() end

return function(character: Model): () -> ()
	local models = ReplicatedStorage.Assets:FindFirstChild("Models")
	local fruits = models and models:FindFirstChild("Fruits")
	local shared = fruits and fruits:FindFirstChild("_Shared")
	local template = shared and shared:FindFirstChild("Haki")
	if not template or not template:IsA("BasePart") then
		return noop
	end

	local shells: { BasePart } = {}
	local limbs: { BasePart } = {}
	for _, limbName in LIMBS do
		local limb = character:FindFirstChild(limbName)
		if limb and limb:IsA("BasePart") then
			local shell = template:Clone()
			shell.Name = "HakiShell"
			shell.Anchored = false
			shell.CanCollide = false
			shell.CanQuery = false
			shell.CanTouch = false
			shell.Massless = true
			-- The template is a small part drawn through a BlockMesh: what is seen is the
			-- part's size times the mesh's scale, so the mesh is what gets fitted to the limb.
			local wanted = limb.Size + Vector3.one * (SHELL_MARGIN * 2)
			local mesh = shell:FindFirstChildWhichIsA("DataModelMesh")
			if mesh then
				mesh.Scale = wanted / shell.Size
			else
				shell.Size = wanted
			end
			shell.CFrame = limb.CFrame
			shell.Color = FLASH_COLOR
			shell.Material = Enum.Material.Neon

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = limb
			weld.Part1 = shell
			weld.Parent = shell
			shell.Parent = limb

			table.insert(shells, shell)
			table.insert(limbs, limb)
		end
	end

	local active = true
	task.delay(FLASH_TIME, function()
		if not active then
			return
		end
		for _, shell in shells do
			shell.Color = HAKI_COLOR
			shell.Material = Enum.Material.SmoothPlastic
		end
	end)

	return function()
		active = false
		for _, shell in shells do
			shell:Destroy()
		end
	end
end
