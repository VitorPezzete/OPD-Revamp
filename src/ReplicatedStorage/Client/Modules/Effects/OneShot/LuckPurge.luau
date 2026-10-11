--!strict
--[[
	Luck fruit - Fortune's Purge inside the Golden Casino: the giant skull bursts.
	origin: centre of the casino.   params: { Size: number (diameter) }   (plus Caster, Colors)
	Template: ReplicatedStorage.Assets.Models.Fruits.Luck.Power6.Skull (the casino's
	skull; its "Room" shell and "Inside" are not used here).

	The skull swells, solid, to the casino's full diameter in one second and is then
	gone at once, as in the legacy game. The casino's own skull is hidden at the same
	moment by the LuckCasino status.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local LIFETIME = 1

return function(origin: Vector3, params: { [string]: any }?)
	local size = params and params.Size
	if type(size) ~= "number" or size <= 0 then
		return
	end

	local template = EffectAssets.FindFruit("Luck", "Power6", "Skull")
	if not template or not template:IsA("BasePart") then
		return
	end

	local skull = template:Clone()
	skull:ClearAllChildren()
	skull.Anchored = true
	skull.CanCollide = false
	skull.CanQuery = false
	skull.CanTouch = false
	skull.Position = origin
	skull.Parent = World.Effects()
	Debris:AddItem(skull, LIFETIME)

	TweenService:Create(skull, TweenInfo.new(LIFETIME, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
		Size = Vector3.new(size, size, size),
	}):Play()
end
