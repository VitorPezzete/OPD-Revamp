--!strict
--[[
	Barrier fruit - Prison placement ghost. While the Prison key is held the owner sees
	where the cage will land: (distance) studs from the root towards the mouse, turned
	to face the character. Only the owner draws it; where the cage really lands is
	computed by the server from the aim point sent with the key release.

	Status value: "<sx>|<sy>|<sz>|<distance>|<fruit colors>".
	Template: the cage union of Assets.Models.Fruits._Shared (the legacy
	ReplicatedStorage.Resources.BarrierPrison, see findPrison), 0.8 transparent; a plain
	box of the same size otherwise.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(170, 170, 220)
local GHOST_TRANSPARENCY = 0.8

local function noop() end

-- _Shared holds two parts called BarrierPrison: the cage is the union that takes a color
-- (same choice as Effects.Status.BarrierConstruct and the server).
local function findPrison(): Instance?
	local own = EffectAssets.FindFruit("Barrier", "Power3", "BarrierPrison")
	if own then
		return own
	end

	local shared = EffectAssets.FindFruit("_Shared")
	local fallback: Instance? = nil
	if shared then
		for _, child in shared:GetChildren() do
			if child.Name == "BarrierPrison" and child:IsA("BasePart") then
				if child:IsA("PartOperation") and child.UsePartColor then
					return child
				end
				fallback = fallback or child
			end
		end
	end
	return fallback
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local fields = EffectAssets.Unpack(value)
	local sizeX, sizeY, sizeZ = tonumber(fields[1]), tonumber(fields[2]), tonumber(fields[3])
	local distance = tonumber(fields[4])
	if not sizeX or not sizeY or not sizeZ or not distance then
		return noop
	end
	-- The legacy ghost was only repainted when the user had a saved color.
	local saved = FruitColor.Parse(fields[5] or "")

	local found = findPrison()
	local ghost: BasePart
	if found and found:IsA("BasePart") then
		ghost = found:Clone()
		if saved then
			ghost.Color = saved
		end
	else
		ghost = Instance.new("Part")
		ghost.Color = saved or DEFAULT_COLOR
	end
	ghost.Name = "BarrierPrisonGhost"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.CastShadow = false
	ghost.Transparency = GHOST_TRANSPARENCY
	ghost.Size = Vector3.new(sizeX, sizeY, sizeZ)

	local mouse = Players.LocalPlayer:GetMouse()

	local function place()
		local root = character.PrimaryPart
		if not root then
			return
		end

		local rootPosition = root.Position
		local offset = mouse.Hit.Position - rootPosition
		local direction = if offset.Magnitude > 1e-3 then offset.Unit else root.CFrame.LookVector
		local position = rootPosition + direction * distance
		local facing = Vector3.new(rootPosition.X - position.X, 0, rootPosition.Z - position.Z)
		ghost.CFrame = if facing.Magnitude > 1e-3
			then CFrame.lookAt(position, position + facing)
			else CFrame.new(position)
	end

	place()
	ghost.Parent = World.Effects()
	local connection = RunService.RenderStepped:Connect(place)

	return function()
		connection:Disconnect()
		ghost:Destroy()
	end
end
