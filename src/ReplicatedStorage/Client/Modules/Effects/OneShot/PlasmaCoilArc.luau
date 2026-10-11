--!strict
--[[
	Plasma fruit - Plasma Coil, one damage pulse: an arc from the sphere to every victim.
	origin: the sphere. params: { Targets: { Vector3 }, Haki: boolean, Size: number
	(sniper affinity), Thickness: number, Colors: string, Caster: Model }

	Each arc thins out on a 0.4 s tween but is removed after 0.2 s, half-way, as in the
	legacy game; a spark flashes for 0.1 s on its last segment
	(ReplicatedStorage.Assets.Models.Fruits.Plasma.Power2.PlasmaArcEnd, a part with a
	"Particles" emitter, scaled by Size).
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local drawBolt = require(script.Parent.PlasmaBolt)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local DEFAULT_COLOR = Color3.fromRGB(221, 117, 255)
local ARC_LIFE = 0.2
local ARC_SHRINK = 0.4
local FLASH_LIFE = 0.1
local MAX_TARGETS = 40

return function(origin: Vector3, params: { [string]: any }?)
	local targets = params and params.Targets
	if not params or type(targets) ~= "table" then
		return
	end

	local color = DEFAULT_COLOR
	if params.Haki then
		color = HAKI_COLOR
	elseif type(params.Colors) == "string" then
		color = FruitColor.Parse(params.Colors) or DEFAULT_COLOR
	end
	local size: number = if type(params.Size) == "number" then params.Size else 1
	local template = EffectAssets.FindFruit("Plasma", "Power2", "PlasmaArcEnd")

	for index, target in targets do
		if index > MAX_TARGETS then
			break
		end
		if typeof(target) ~= "Vector3" then
			continue
		end

		local last = drawBolt(origin, {
			Target = target,
			Color = color,
			Thickness = params.Thickness,
			Life = ARC_LIFE,
			Shrink = ARC_SHRINK,
			Linear = true,
		})

		if template and template:IsA("BasePart") then
			local flash = template:Clone()
			flash.Anchored = true
			flash.CanCollide = false
			flash.CanQuery = false
			flash.CanTouch = false
			flash.Size = template.Size * size
			flash.CFrame = last or CFrame.new(target)
			local particles = flash:FindFirstChild("Particles")
			if particles and particles:IsA("ParticleEmitter") then
				particles.Color = ColorSequence.new(color)
			end
			flash.Parent = World.Effects()
			Debris:AddItem(flash, FLASH_LIFE)
		end
	end
end
