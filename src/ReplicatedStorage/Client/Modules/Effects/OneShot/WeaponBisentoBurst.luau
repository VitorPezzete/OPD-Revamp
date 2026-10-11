--!strict
--[[
	Bisento special: the burst of the quake bubble. The legacy "Seismic" template
	(ReplicatedStorage.Resources.Seismic), half transparent, grows to the side of the
	damage cube in 0.25 s; a force-field ball when the template is missing.
	params: { Side: number, Haki: boolean }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

return function(origin: Vector3, params: { [string]: any }?)
	local side: number = (params and params.Side) or 10
	local color = if params and params.Haki then WeaponFx.HakiColor else Color3.fromRGB(255, 255, 255)

	local template = WeaponFx.FindAsset("Seismic")
	local seismic: BasePart
	if template and template:IsA("BasePart") then
		seismic = template:Clone() :: BasePart
		WeaponFx.Neutralize(seismic)
		seismic.Parent = World.Effects()
		Debris:AddItem(seismic, 0.3)
	else
		seismic = WeaponFx.Part({ Shape = Enum.PartType.Ball, Size = Vector3.one, Material = Enum.Material.ForceField }, 0.3)
	end
	seismic.CFrame = CFrame.new(origin)
	seismic.Transparency = 0.5
	seismic.Color = color

	WeaponFx.Tween(seismic, 0.25, { Size = Vector3.new(side, side, side) })
end
