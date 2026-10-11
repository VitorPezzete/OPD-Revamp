--!strict
--[[
	Luck fruit - Golden Casino. Status value (on the caster):
		"x,y,z|diameter|hidden|colors"
	where x,y,z is where the casino was opened, hidden is 1 once Fortune's Purge has
	burst the skull, and colors is the fruit color string.

	Template: ReplicatedStorage.Assets.Models.Fruits.Luck.Power6.Skull - the giant skull
	(MeshPart) with "Inside" and the room shell "Room" (which holds a second "Room").
	The room grows to the casino's diameter in half a second and the skull spins in the
	middle. Everything is anchored at the cast position: it does not follow the caster.

	When the value changes to hidden the effect restarts: the room is rebuilt at full
	size without its skull.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local ROOM_COLOR = Color3.fromRGB(234, 255, 0)
local GROW_TIME = 0.5
-- Radians per second, drawn again every frame: the legacy skull lurched as it spun.
local SPIN_MIN = 3
local SPIN_MAX = 10
local INSIDE_TRANSPARENCY = 0.3

local function noop() end

local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

return function(_character: Model, value: any): () -> ()
	local fields = EffectAssets.Unpack(value)
	local coordinates = string.split(fields[1] or "", ",")
	local x, y, z = tonumber(coordinates[1]), tonumber(coordinates[2]), tonumber(coordinates[3])
	local diameter = tonumber(fields[2])
	if not x or not y or not z or not diameter or diameter <= 0 then
		return noop
	end
	local position = Vector3.new(x, y, z)
	local hidden = fields[3] == "1"

	local template = EffectAssets.FindFruit("Luck", "Power6", "Skull")
	if not template or not template:IsA("BasePart") then
		return noop
	end

	local skull = template:Clone()
	ghost(skull)
	for _, descendant in skull:GetDescendants() do
		if descendant:IsA("BasePart") then
			ghost(descendant)
		end
	end
	-- Everything is anchored, so PivotTo is what keeps the pieces together.
	skull:PivotTo(CFrame.new(position) * skull.CFrame.Rotation)

	local inside = skull:FindFirstChild("Inside")
	if inside and inside:IsA("BasePart") then
		inside.Transparency = if hidden then 1 else INSIDE_TRANSPARENCY
	end
	if hidden then
		skull.Transparency = 1
	end

	local roomColor = EffectAssets.Colors(fields[4], ROOM_COLOR, ROOM_COLOR)
	local full = Vector3.new(diameter, diameter, diameter)
	local grow = TweenInfo.new(GROW_TIME, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

	local room = skull:FindFirstChild("Room")
	local shells: { BasePart } = {}
	if room and room:IsA("BasePart") then
		table.insert(shells, room)
		local inner = room:FindFirstChild("Room")
		if inner and inner:IsA("BasePart") then
			table.insert(shells, inner)
		end
	end
	for _, shell in shells do
		shell.Color = roomColor
		shell.Position = position
		if hidden then
			shell.Size = full
		else
			shell.Size = Vector3.zero
			TweenService:Create(shell, grow, { Size = full }):Play()
		end
	end

	skull.Parent = World.Effects()

	local connection: RBXScriptConnection? = nil
	if not hidden then
		local angle = 0
		connection = RunService.Heartbeat:Connect(function(deltaTime: number)
			angle += math.random(SPIN_MIN, SPIN_MAX) * deltaTime
			skull:PivotTo(CFrame.new(position) * CFrame.Angles(0, angle, 0))
		end)
	end

	return function()
		if connection then
			connection:Disconnect()
		end
		skull:Destroy()
	end
end
