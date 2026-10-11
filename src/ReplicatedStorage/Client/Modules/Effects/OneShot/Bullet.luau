--!strict
--[[
	Visual for a server-simulated projectile: a small anchored ball tweened along the
	same origin / direction / speed the server is casting. Purely cosmetic, so it never
	collides and removes itself.
	params: { Direction: Vector3, Speed: number, Range: number }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

return function(origin: Vector3, params: { [string]: any }?)
	local direction: Vector3? = params and params.Direction
	local speed: number = (params and params.Speed) or 300
	local range: number = (params and params.Range) or 300
	if typeof(direction) ~= "Vector3" or speed <= 0 then
		return
	end

	-- Stop the visual at the first wall so it does not fly through geometry.
	local result = Workspace:Raycast(origin, direction.Unit * range)
	local distance = if result then (result.Position - origin).Magnitude else range
	local duration = distance / speed

	local bullet = Instance.new("Part")
	bullet.Shape = Enum.PartType.Ball
	bullet.Size = Vector3.new(0.35, 0.35, 0.35)
	bullet.Material = Enum.Material.Rock
	bullet.Color = Color3.fromRGB(99, 95, 98)
	bullet.Anchored = true
	bullet.CanCollide = false
	bullet.CanQuery = false
	bullet.CanTouch = false
	bullet.CFrame = CFrame.new(origin)
	bullet.Parent = World.Effects()

	TweenService:Create(bullet, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(origin + direction.Unit * distance),
	}):Play()
	Debris:AddItem(bullet, duration + 0.05)
end
