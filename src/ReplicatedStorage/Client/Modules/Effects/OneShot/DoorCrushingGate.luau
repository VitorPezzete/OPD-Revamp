--!strict
--[[
	Door fruit - Crushing Gate: two gates on either side of the area sliding together and
	slamming shut. The server tests the hit when they meet (after Delay).
	params: { CFrame: CFrame, Size: Vector3, Delay: number, Colors: string, Caster: Model }
	        CFrame / Size = the crushed box; the gates close along its X axis.

	Plain parts: the legacy Door fruit has no models (see OneShot.DoorPanel).
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local DEFAULT_COLOR = Color3.fromRGB(105, 64, 40)
local THICKNESS = 1.5
-- How far outside the box each gate starts.
local START_GAP = 6
local HOLD_TIME = 0.5
local FADE_TIME = 0.3

local function playSlam(parent: Instance)
	local group = (SoundConfig :: any).SFX
	local sounds = group and group["To-Organize"]
	local definition = sounds and sounds.DoorClosing
	if not definition then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.Speed or 1
	sound.RollOffMaxDistance = 200
	sound.Parent = parent
	sound:Play()
end

return function(_origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.CFrame) ~= "CFrame" or typeof(params.Size) ~= "Vector3" then
		return
	end
	local cframe: CFrame = params.CFrame
	local size: Vector3 = params.Size
	local closeTime: number = if type(params.Delay) == "number" then math.max(params.Delay, 0.05) else 0.4
	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")

	local lifetime = closeTime + HOLD_TIME + FADE_TIME
	local gates: { BasePart } = {}

	for _, side in { -1, 1 } do
		local gate = Instance.new("Part")
		gate.Name = "DoorGate"
		gate.Size = Vector3.new(THICKNESS, size.Y, size.Z)
		gate.Material = Enum.Material.Wood
		gate.Color = primary or DEFAULT_COLOR
		gate.Anchored = true
		gate.CanCollide = false
		gate.CanQuery = false
		gate.CanTouch = false
		gate.CFrame = cframe * CFrame.new(side * (size.X / 2 + START_GAP), 0, 0)
		gate.Parent = World.Effects()

		TweenService:Create(gate, TweenInfo.new(closeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = cframe * CFrame.new(side * THICKNESS / 2, 0, 0),
		}):Play()

		table.insert(gates, gate)
		Debris:AddItem(gate, lifetime + 0.05)
	end

	task.delay(closeTime, function()
		if gates[1].Parent then
			playSlam(gates[1])
		end
	end)
	task.delay(closeTime + HOLD_TIME, function()
		for _, gate in gates do
			if gate.Parent then
				TweenService:Create(gate, TweenInfo.new(FADE_TIME), { Transparency = 1 }):Play()
			end
		end
	end)
end
