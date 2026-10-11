--!strict
--[[
	Alice fruit - the brief translucent sphere that shows the reach of Cheshire's Grin
	and Looking Glass.
	params: { Radius: number }   (plus Caster, Colors)

	No template: the legacy server created a plain 0.7-transparent ball for half a
	second (a default part: grey plastic, never the fruit's colors), which then simply
	disappeared.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local LIFETIME = 0.5
-- Color of a part nobody painted ("Medium stone grey").
local COLOR = Color3.fromRGB(163, 162, 165)

return function(origin: Vector3, params: { [string]: any }?)
	local radius = params and params.Radius
	if type(radius) ~= "number" or radius <= 0 then
		return
	end

	local ball = Instance.new("Part")
	ball.Name = "AlicePulse"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Plastic
	ball.Color = COLOR
	ball.Transparency = 0.7
	ball.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	ball.Position = origin
	ball.Parent = World.Effects()
	Debris:AddItem(ball, LIFETIME)
end
