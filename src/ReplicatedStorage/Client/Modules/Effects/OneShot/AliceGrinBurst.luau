--!strict
--[[
	Alice fruit - Cheshire's Grin: the blast over a victim's head, three seconds after
	the cat appeared.
	params: { Size: number (diameter) }   (plus Caster, Colors)

	No template: a ball that swells from nothing to the blast size while fading, as the
	legacy server-made part did (a default part: grey plastic, never the fruit's colors).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local GROW_TIME = 0.5
-- Color of a part nobody painted ("Medium stone grey").
local COLOR = Color3.fromRGB(163, 162, 165)

return function(origin: Vector3, params: { [string]: any }?)
	local size = params and params.Size
	if type(size) ~= "number" or size <= 0 then
		return
	end

	local ball = Instance.new("Part")
	ball.Name = "AliceGrinBurst"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Plastic
	ball.Color = COLOR
	ball.Size = Vector3.new(0.1, 0.1, 0.1)
	ball.Position = origin
	ball.Parent = World.Effects()
	Debris:AddItem(ball, GROW_TIME + 0.5)

	TweenService:Create(ball, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
		Size = Vector3.new(size, size, size),
		Transparency = 1,
	}):Play()
end
