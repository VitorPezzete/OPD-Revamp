--!strict
--[[
	Door fruit - a door that appears in the air, swings open and fades. Used by Door
	Strike (the door that hits), Escape Door (entry and exit doors).
	params: { CFrame: CFrame, Colors: string, Caster: Model }
	        CFrame = centre of the closed door; it opens towards its LookVector.

	The Door fruit has no models in the legacy game (it was never built), so the door is
	made of plain parts here. Replace with a real asset when one exists.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local SIZE = Vector3.new(5, 8, 0.4)
local DEFAULT_COLOR = Color3.fromRGB(105, 64, 40)
local KNOB_COLOR = Color3.fromRGB(239, 184, 56)
local OPEN_ANGLE = math.rad(110)
local OPEN_TIME = 0.2
local HOLD_TIME = 0.6
local FADE_TIME = 0.3

local function playSound(parent: Instance)
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
	sound.RollOffMaxDistance = 150
	sound.Parent = parent
	sound:Play()
end

return function(origin: Vector3, params: { [string]: any }?)
	local cframe: CFrame = if params and typeof(params.CFrame) == "CFrame" then params.CFrame else CFrame.new(origin)
	local primary = FruitColor.Parse(if params and type(params.Colors) == "string" then params.Colors else "")

	local door = Instance.new("Part")
	door.Name = "DoorPanel"
	door.Size = SIZE
	door.Material = Enum.Material.Wood
	door.Color = primary or DEFAULT_COLOR
	door.Anchored = true
	door.CanCollide = false
	door.CanQuery = false
	door.CanTouch = false
	door.CFrame = cframe

	local knob = Instance.new("Part")
	knob.Name = "Knob"
	knob.Shape = Enum.PartType.Ball
	knob.Size = Vector3.new(0.6, 0.6, 0.6)
	knob.Material = Enum.Material.Metal
	knob.Color = KNOB_COLOR
	knob.Anchored = false
	knob.Massless = true
	knob.CanCollide = false
	knob.CanQuery = false
	knob.CanTouch = false
	knob.CFrame = cframe * CFrame.new(SIZE.X / 2 - 0.7, 0, -SIZE.Z / 2 - 0.2)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = door
	weld.Part1 = knob
	weld.Parent = knob
	knob.Parent = door

	door.Parent = World.Effects()
	playSound(door)

	-- Hinged on its left edge, swinging forwards.
	local hinge = cframe * CFrame.new(-SIZE.X / 2, 0, 0)
	local opened = hinge * CFrame.Angles(0, -OPEN_ANGLE, 0) * CFrame.new(SIZE.X / 2, 0, 0)
	TweenService:Create(door, TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = opened,
	}):Play()

	task.delay(OPEN_TIME + HOLD_TIME, function()
		if door.Parent then
			local fade = TweenInfo.new(FADE_TIME)
			TweenService:Create(door, fade, { Transparency = 1 }):Play()
			TweenService:Create(knob, fade, { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(door, OPEN_TIME + HOLD_TIME + FADE_TIME + 0.05)
end
