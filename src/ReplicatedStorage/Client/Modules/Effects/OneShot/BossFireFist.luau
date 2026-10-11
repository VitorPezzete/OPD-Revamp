--!strict
--[[
	Fire boss - Fire Fist: a fist far larger than a player's, a cube of `Size` studs.
	params: { Direction: Vector3, Speed: number, Range: number, Size: number,
	          Haki: boolean, Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Flare.Power2["Fire Fist"] (a part
	with a "Fire" emitter).

	Unlike a player's fist it is not stopped by the map: the legacy boss fist was a part
	pushed by a BodyVelocity that flew through everything for 6 seconds, and the server
	sweeps it the same way.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
-- Past this the fist is out of sight; no need to keep it for its whole flight.
local MAX_VISIBLE_DISTANCE = 1500

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local direction = params.Direction
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-3 then
		return
	end
	local speed: number = if type(params.Speed) == "number" and params.Speed > 0 then params.Speed else 500
	local range: number = if type(params.Range) == "number" then params.Range else 3000
	local size: number = if type(params.Size) == "number" then params.Size else 57.6

	local template = EffectAssets.FindFruit("Flare", "Power2", "Fire Fist")
	if not template or not template:IsA("BasePart") then
		return
	end

	local fist = template:Clone()
	fist.Anchored = true
	fist.CanCollide = false
	fist.CanQuery = false
	fist.CanTouch = false
	fist.Size = Vector3.new(size, size, size)

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	if params.Haki then
		primary, secondary = HAKI_COLOR, HAKI_COLOR
	end
	if primary then
		fist.Color = primary
	end
	for _, descendant in fist:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") and primary and secondary then
			descendant.Color = FruitColor.ToSequence(primary, secondary)
		end
	end

	local unit = direction.Unit
	local distance = math.min(range, MAX_VISIBLE_DISTANCE)
	local duration = distance / speed
	local rotation = CFrame.lookAt(origin, origin + unit).Rotation
	fist.CFrame = rotation + origin
	fist.Parent = World.Effects()

	TweenService:Create(fist, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = rotation + (origin + unit * distance),
	}):Play()
	Debris:AddItem(fist, duration)
end
