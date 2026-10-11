--!strict
--[[
	Dark fruit - Dark Vortex.
	params: { CFrame: CFrame, Size: number, ShrinkRate: number, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Dark.Power2.Vortex (a MeshPart with
	"HollowSphere1", "MeshPart" and "MeshPartEffect" parts inside).

	`origin` is the centre of the vortex and `CFrame` its placement (the caster's
	orientation when it opened). Everything is anchored there; the hollow shell starts
	`Size` studs wide and collapses by `ShrinkRate` studs per second, then the vortex
	lingers for a second, as in the legacy game.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local SHELL_NAME = "HollowSphere1"
local MIN_SIZE = Vector3.new(0.1, 0.1, 0.1)
local LINGER = 1

return function(origin: Vector3, params: { [string]: any }?)
	local template = EffectAssets.FindFruit("Dark", "Power2", "Vortex")
	if not params or not template or not template:IsA("BasePart") then
		return
	end
	local size: number = if type(params.Size) == "number" then math.max(params.Size, 0.1) else 100
	local shrinkRate: number = if type(params.ShrinkRate) == "number" and params.ShrinkRate > 0 then params.ShrinkRate else 70

	local vortex = template:Clone()
	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local placement: CFrame = if typeof(params.CFrame) == "CFrame" then params.CFrame else CFrame.new(origin)

	local parts: { BasePart } = { vortex }
	for _, descendant in vortex:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		elseif descendant:IsA("ParticleEmitter") and primary and secondary then
			descendant.Color = FruitColor.ToSequence(primary, secondary)
		end
	end
	for _, part in parts do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CFrame = placement
		-- The legacy script painted the inner parts and left the outer mesh as authored.
		if primary and part ~= vortex then
			part.Color = primary
		end
	end

	local duration = math.max(size / shrinkRate, 0.03)
	local shell = vortex:FindFirstChild(SHELL_NAME)
	if shell and shell:IsA("BasePart") then
		shell.Size = Vector3.new(size, size, size)
		TweenService:Create(shell, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = MIN_SIZE }):Play()
		Debris:AddItem(shell, duration)
	end

	vortex.Parent = World.Effects()
	Debris:AddItem(vortex, duration + LINGER)
end
