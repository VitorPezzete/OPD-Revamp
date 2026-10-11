--!strict
--[[
	Rumble fruit - Rumble Staff, one swing: the swing sound at the user and, on every
	third swing, the staff turning once in the hand.
	origin: the user's position. params: { Swing: number (1, 2 or 3), Caster: Model,
	Local: boolean? }

	The server announces every swing it accepts, so everyone around hears and sees it (the
	legacy server played both). The owner's client does not wait for the announcement:
	Effects.Status.RumbleStaff calls this module directly at the click, with Local = true,
	and the announcement of its own swing is ignored here.

	The staff is the part Effects.Status.RumbleStaff welded on the right arm ("Grip"
	weld). The spin turns that weld around the arm's axis, 25 degrees a frame, then puts
	it back (legacy third swing).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)

local ARM_NAME = "Right Arm"
local STAFF_NAME = "RumbleStaff"
local WELD_NAME = "Grip"
local SPIN_SWING = 3
local SPIN_STEP = 25

local spinning: { [Weld]: boolean } = {}

local function playSwingSound(parent: Instance)
	local sfx = (SoundConfig :: any).SFX
	local group = sfx and sfx["To-Organize"]
	local definition = group and group.Rotation
	if not definition then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume or 0.5
	sound.PlaybackSpeed = definition.Speed or 1
	sound.PlayOnRemove = true
	sound.Parent = parent
	sound:Destroy()
end

local function spin(weld: Weld)
	if spinning[weld] then
		return
	end
	spinning[weld] = true

	local rest = weld.C0
	task.spawn(function()
		for angle = 0, 360, SPIN_STEP do
			if not weld.Parent then
				break
			end
			weld.C0 = CFrame.Angles(0, math.rad(angle), 0) * rest
			task.wait()
		end
		if weld.Parent then
			weld.C0 = rest
		end
		spinning[weld] = nil
	end)
end

return function(_origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	if not params or typeof(caster) ~= "Instance" then
		return
	end
	if caster == Players.LocalPlayer.Character and params.Local ~= true then
		return
	end

	local root = caster:FindFirstChild("HumanoidRootPart")
	if root then
		playSwingSound(root)
	end

	if params.Swing ~= SPIN_SWING then
		return
	end
	local arm = caster:FindFirstChild(ARM_NAME)
	local staff = arm and arm:FindFirstChild(STAFF_NAME)
	local weld = staff and staff:FindFirstChild(WELD_NAME)
	if weld and weld:IsA("Weld") then
		spin(weld)
	end
end
