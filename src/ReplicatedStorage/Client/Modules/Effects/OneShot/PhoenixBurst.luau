--!strict
--[[
	Phoenix fruit - Phoenix Burst: the beam and the three rings where it lands.
	origin: start of the beam.
	params: { Target: Vector3 (end of the beam), Percent: number (charge 0-1),
	          Affinity: number (sniper affinity), Haki: boolean, Colors: string,
	          Caster: Model }

	Template: ReplicatedStorage.Assets.Models.Fruits.Phoenix.Power3.MeshPart, cloned four
	times with the legacy sizes (c = Percent, a = Affinity, d = beam length), each with
	its Y axis on the beam:
	- ring at d:        (clamp(40ca, 15, 100), clamp(6.096c, 3, 12), same as X)
	- ring at d / 1.1:  (clamp(25ca, 7, 60),   clamp(4c, 1, 8),      same as X)
	- ring at d / 1.15: (clamp(10ca, 2, 20),   clamp(2c, 1, 4),      same as X)
	- beam at d / 2:    (clamp(2ca, 1, 20),    d,                    clamp(2c, 1, 20))
	They stay 0.5 s, fade over 1 s and are removed. Dark with armament haki; legacy did
	not apply the fruit colors to them, neither does this.

	The caster's own client also plays the release clip (FruitAnims.PhoenixWingRelease,
	speed 16).
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local HOLD_TIME = 0.5
local FADE_TIME = 1
local REMOVE_AFTER = 2.25
local RELEASE_SPEED = 16

local function playRelease(character: any)
	if typeof(character) ~= "Instance" or character ~= Players.LocalPlayer.Character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local sharedClips = (AnimationConfig :: any).FruitAnims
	local animationId = if type(sharedClips) == "table" then sharedClips.PhoenixWingRelease else nil
	if not animator or type(animationId) ~= "string" then
		return
	end

	Animations.Play(animator, animationId, 0.1, 1, RELEASE_SPEED)
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	playRelease(params.Caster)

	local target = params.Target
	if typeof(target) ~= "Vector3" then
		return
	end
	local distance = (target - origin).Magnitude
	if distance < 0.05 then
		return
	end

	local template = EffectAssets.FindFruit("Phoenix", "Power3", "MeshPart")
	if not template or not template:IsA("BasePart") then
		return
	end

	local c: number = if type(params.Percent) == "number" then params.Percent else 1
	local a: number = if type(params.Affinity) == "number" then params.Affinity else 1
	local frame = CFrame.lookAt(origin, target)
	local upright = CFrame.Angles(math.rad(90), 0, 0)

	local ringOne = math.clamp(40 * c * a, 15, 100)
	local ringTwo = math.clamp(25 * c * a, 7, 60)
	local ringThree = math.clamp(10 * c * a, 2, 20)
	local pieces = {
		{ Size = Vector3.new(ringOne, math.clamp(6.096 * c, 3, 12), ringOne), Offset = distance },
		{ Size = Vector3.new(ringTwo, math.clamp(4 * c, 1, 8), ringTwo), Offset = distance / 1.1 },
		{ Size = Vector3.new(ringThree, math.clamp(2 * c, 1, 4), ringThree), Offset = distance / 1.15 },
		{
			Size = Vector3.new(math.clamp(2 * c * a, 1, 20), distance, math.clamp(2 * c, 1, 20)),
			Offset = distance / 2,
		},
	}

	local parts: { BasePart } = {}
	for _, piece in pieces do
		local part = template:Clone()
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = piece.Size
		part.CFrame = frame * CFrame.new(0, 0, -piece.Offset) * upright
		if params.Haki then
			part.Color = HAKI_COLOR
		end
		for _, descendant in part:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		part.Parent = World.Effects()
		Debris:AddItem(part, REMOVE_AFTER)
		table.insert(parts, part)
	end

	task.delay(HOLD_TIME, function()
		local info = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear)
		for _, part in parts do
			TweenService:Create(part, info, { Transparency = 1 }):Play()
		end
	end)
end
