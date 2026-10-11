--!strict
--[[
	Rumble fruit - El Thor, the quick beam (charge below 20).
	origin: the casting hand. params: { Target: Vector3 (where the beam ends), Colors, Caster }

	Templates (ReplicatedStorage.Assets.Models.Fruits.Rumble.Power2), laid out as the
	legacy server did:
	- RumbleThor  (long axis Z): the half of the beam next to the hand;
	- RumbleThor2 (long axis X): the half next to the impact;
	- RumbleThor3: the ball at the impact.
	All three swell from 0.1 to 15 studs thick in 0.05 s, hold, shrink back during the
	last 0.2 s and are gone after 0.6 s. First fruit color when the fruit has one.
	If none of the templates exists a plain thick bolt is drawn instead.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local drawBolt = require(script.Parent.RumbleBolt)

local THIN = 0.1
local THICK = 15
local SWELL_TIME = 0.05
local HOLD_TIME = 0.4
local SHRINK_TIME = 0.2

local function playShock(caster: any)
	local root = if typeof(caster) == "Instance" then caster:FindFirstChild("HumanoidRootPart") else nil
	local sfx = (SoundConfig :: any).SFX
	local group = sfx and sfx.Elemental and sfx.Elemental.Rumble
	local definition = group and group.Shock
	if not root or not definition then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume or 0.25
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 5)
end

return function(origin: Vector3, params: { [string]: any }?)
	local target = params and params.Target
	if not params or typeof(target) ~= "Vector3" then
		return
	end
	local length = (target - origin).Magnitude
	if length < 0.1 then
		return
	end

	playShock(params.Caster)

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	-- Looks from the impact back to the hand: -Z runs along the beam towards the hand.
	local frame = CFrame.lookAt(target, origin)

	local built = 0
	local function build(name: string, cframe: CFrame, thin: Vector3, thick: Vector3)
		local template = EffectAssets.FindFruit("Rumble", "Power2", name)
		if not template or not template:IsA("BasePart") then
			return
		end
		built += 1

		local part = template:Clone()
		for _, descendant in part:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		if primary then
			part.Color = primary
		end
		part.Size = thin
		part.CFrame = cframe
		part.Parent = World.Effects()

		local linear = Enum.EasingStyle.Linear
		TweenService:Create(part, TweenInfo.new(SWELL_TIME, linear), { Size = thick }):Play()
		task.delay(HOLD_TIME, function()
			TweenService:Create(part, TweenInfo.new(SHRINK_TIME, linear), { Size = thin }):Play()
		end)
		Debris:AddItem(part, HOLD_TIME + SHRINK_TIME)
	end

	local half = length / 2
	build(
		"RumbleThor",
		frame * CFrame.new(0, 0, -length / 1.35),
		Vector3.new(THIN, THIN, half),
		Vector3.new(THICK, THICK, half)
	)
	build(
		"RumbleThor2",
		frame * CFrame.new(0, 0, -length * 0.25) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(half, THIN, THIN),
		Vector3.new(half, THICK, THICK)
	)
	build(
		"RumbleThor3",
		frame * CFrame.new(0, 0, 0.1),
		Vector3.new(THIN, THIN, THIN),
		Vector3.new(THICK, THICK, THICK)
	)

	if built == 0 then
		drawBolt(origin, {
			Target = target,
			Color = primary,
			Thickness = 2,
			Jitter = 2,
			Life = HOLD_TIME + SHRINK_TIME,
			Shrink = true,
		})
	end
end
