--!strict
--[[
	Vampire fruit - a soul left where a player or an enemy was killed. Only vampires see souls: the
	effect does nothing unless the local character carries the VampirePassive status.

	origin: where the soul floats.
	params: { Id: number, Duration: number }  - a soul appears for Duration seconds
	        { Id: number, Remove = true }      - that soul was taken (Necromancy)

	Template: ReplicatedStorage.Assets.Models.Fruits.Vampire.Power4.VampireSoul (a
	part). Necromancy needs the soul to be something the aim ray stops on, so the part
	stays queryable (and a plain glowing ball stands in if the template is missing).

	The server sends souls to the vampires only, wherever they are. A player who becomes
	a vampire afterwards does not see the souls already there (the server would still
	accept them).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PASSIVE_ATTRIBUTE = "VampirePassive"
local FALLBACK_COLOR = Color3.fromRGB(190, 170, 255)

local live: { [number]: Instance } = {}

local function makeSoul(): BasePart
	local template = EffectAssets.FindFruit("Vampire", "Power4", "VampireSoul")
	if template and template:IsA("BasePart") then
		return template:Clone()
	end

	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(3, 3, 3)
	ball.Material = Enum.Material.Neon
	ball.Color = FALLBACK_COLOR
	ball.Transparency = 0.3
	return ball
end

return function(origin: Vector3, params: { [string]: any }?)
	local id = params and params.Id
	if not params or type(id) ~= "number" then
		return
	end

	if params.Remove then
		local soul = live[id]
		if soul then
			live[id] = nil
			soul:Destroy()
		end
		return
	end

	local localPlayer = Players.LocalPlayer
	local character = localPlayer and localPlayer.Character
	if not character or not character:GetAttribute(PASSIVE_ATTRIBUTE) then
		return
	end
	local duration: number = if type(params.Duration) == "number" then params.Duration else 20

	local soul = makeSoul()
	soul.Name = "VampireSoul"
	soul.Anchored = true
	soul.CanCollide = false
	soul.CanTouch = false
	soul.CanQuery = true
	soul.CFrame = CFrame.new(origin)
	soul.Parent = World.Effects()

	live[id] = soul
	Debris:AddItem(soul, duration)
	task.delay(duration, function()
		if live[id] == soul then
			live[id] = nil
		end
	end)
end
