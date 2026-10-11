--!strict
--[[
	Gas fruit - Gastille: the beam and the explosion. Purely cosmetic; the server finds
	where the beam stops and who the explosion hits.

	origin: the caster's mouth.
	params: { Target: Vector3 (where the beam stopped), Diameter: number (of the
	          explosion), Haki: boolean, Caster: Model, Colors: string }

	No template: like the legacy effect it is a neon beam 0.8 studs thick from the mouth
	to the target and a neon ball of the explosion's diameter, both shown for 0.4s.
	Color: dark with armament haki, else the fruit's second custom color, else light blue.
	The caster's own client also plays the breath release animation.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local BEAM_THICKNESS = 0.8
local SHOW_SECONDS = 0.4
local DEFAULT_COLOR = Color3.fromRGB(108, 160, 255)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local RELEASE_FADE = 0.1
local RELEASE_SPEED = 32

local function neonPart(color: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

local function playRelease(caster: Model)
	local humanoid = caster:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	Animations.Play(animator, AnimationConfig.FruitAnims.BreathRelease, RELEASE_FADE, 1, RELEASE_SPEED)
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local target = params.Target
	local diameter = params.Diameter
	if typeof(target) ~= "Vector3" or type(diameter) ~= "number" then
		return
	end

	local caster = params.Caster
	if typeof(caster) == "Instance" and caster:IsA("Model") and caster == Players.LocalPlayer.Character then
		playRelease(caster)
	end

	local color = DEFAULT_COLOR
	if params.Haki then
		color = HAKI_COLOR
	else
		local _, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
		color = secondary or DEFAULT_COLOR
	end

	local distance = (target - origin).Magnitude
	if distance > 0.05 then
		local beam = neonPart(color)
		beam.Size = Vector3.new(BEAM_THICKNESS, BEAM_THICKNESS, distance)
		beam.CFrame = CFrame.lookAt(origin, target) * CFrame.new(0, 0, -distance / 2)
		beam.Parent = World.Effects()
		Debris:AddItem(beam, SHOW_SECONDS)
	end

	if diameter > 0 then
		local ball = neonPart(color)
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(diameter, diameter, diameter)
		ball.CFrame = CFrame.new(target)
		ball.Parent = World.Effects()
		Debris:AddItem(ball, SHOW_SECONDS)
	end
end
