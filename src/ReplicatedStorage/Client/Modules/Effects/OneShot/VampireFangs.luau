--!strict
--[[
	Vampire fruit - Sanguine Vampiris: two giant fangs snap shut in front of the caster.

	origin: the caster's root position.
	params: { Direction: Vector3 (flat unit), Scale: number, Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Vampire.Power1.VampireTeeth (a
	mesh part). Custom colors paint the fangs with the second color.

	Same motion as the legacy server tween: the upper fang starts 5 studs above the
	caster and the lower 5 below, tilted 20 degrees, and both close in 0.2 s on a point
	8 studs ahead. They then fade out (the legacy fade was cut short by an immediate
	Destroy; here it is allowed to play).
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local OPEN_OFFSET = 5
local BITE_DISTANCE = 8
local LOOK_DISTANCE = 50
local TILT = math.rad(20)
local CLOSE_TIME = 0.2
local HOLD_TIME = 0.3
local FADE_TIME = 0.5

return function(origin: Vector3, params: { [string]: any }?)
	local direction = params and params.Direction
	if not params or typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-3 then
		return
	end
	local scale: number = if type(params.Scale) == "number" then math.clamp(params.Scale, 0.1, 10) else 1

	local template = EffectAssets.FindFruit("Vampire", "Power1", "VampireTeeth")
	if not template or not template:IsA("BasePart") then
		return
	end

	local _, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local unit = direction.Unit
	local lookAt = origin + unit * LOOK_DISTANCE
	local closedHeight = template.Size.Y * scale * 0.2

	-- { vertical side, extra rotation }: the lower fang is the upper one turned over.
	local fangs = {
		{ Side = 1, Rotation = CFrame.Angles(TILT, 0, 0) },
		{ Side = -1, Rotation = CFrame.Angles(-TILT, 0, math.rad(180)) },
	}
	for _, fang in fangs do
		local part = template:Clone()
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = template.Size * scale
		if secondary then
			part.Color = secondary
		end

		local open = origin + Vector3.new(0, OPEN_OFFSET * fang.Side, 0)
		local closed = origin + unit * BITE_DISTANCE + Vector3.new(0, closedHeight * fang.Side, 0)
		part.CFrame = CFrame.lookAt(open, lookAt) * fang.Rotation
		part.Parent = World.Effects()

		TweenService:Create(part, TweenInfo.new(CLOSE_TIME), {
			CFrame = CFrame.lookAt(closed, lookAt) * fang.Rotation,
		}):Play()
		task.delay(HOLD_TIME, function()
			if part.Parent then
				TweenService:Create(part, TweenInfo.new(FADE_TIME), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(part, HOLD_TIME + FADE_TIME)
	end
end
