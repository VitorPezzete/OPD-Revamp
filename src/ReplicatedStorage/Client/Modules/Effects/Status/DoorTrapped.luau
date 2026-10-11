--!strict
--[[
	Door fruit - Dimensional Trap: four doors closed around a trapped character for as
	long as it carries the "DoorTrapped" status. The status value is the caster's saved
	color string ("None" keeps the wood color).

	The victim is rooted by the server, so the doors are anchored where it stood. They do
	not collide. Plain parts: the legacy Door fruit has no models (see OneShot.DoorPanel).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local SIZE = Vector3.new(5, 8, 0.4)
local DEFAULT_COLOR = Color3.fromRGB(105, 64, 40)
local DISTANCE = SIZE.X / 2
local APPEAR_TIME = 0.15
local TRANSPARENCY = 0.15

local function noop() end

return function(character: Model, value: any): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return noop
	end

	local primary = FruitColor.Parse(if type(value) == "string" then value else "")
	local center = CFrame.new(root.Position)

	local doors: { BasePart } = {}
	for index = 0, 3 do
		local door = Instance.new("Part")
		door.Name = "DoorTrap"
		door.Size = SIZE
		door.Material = Enum.Material.Wood
		door.Color = primary or DEFAULT_COLOR
		door.Transparency = 1
		door.Anchored = true
		door.CanCollide = false
		door.CanQuery = false
		door.CanTouch = false
		door.CFrame = center * CFrame.Angles(0, index * math.pi / 2, 0) * CFrame.new(0, 0, -DISTANCE)
		door.Parent = World.Effects()

		TweenService:Create(door, TweenInfo.new(APPEAR_TIME), { Transparency = TRANSPARENCY }):Play()
		table.insert(doors, door)
	end

	return function()
		for _, door in doors do
			door:Destroy()
		end
	end
end
