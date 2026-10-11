--!strict
--[[
	Slash fruit - Slash Frenzy: slashes flying through the area for as long as the status
	is on the caster. Purely cosmetic: the server deals the cuts directly.

	Status value: "<radius>|<x>|<y>|<z>|<sword affinity>|<fruit colors>" while the area is
	the caster's Ope Room, "<radius>|F|||<sword affinity>|<fruit colors>" while it follows
	the caster (the area is then centred on the caster's root at every round).
	Templates: the slash meshes of ReplicatedStorage.Assets.Models.Fruits.Slash.Power2.

	Every 0.25 s, as the legacy server did:
	- two slashes (0.1 s apart) thrown at every character in the area from a random point
	  of it, at 2000 * affinity studs per second;
	- one or two more (a whole number between affinity and 2.5 * affinity, both floored)
	  between two random points, at 300-500 * affinity studs per second.
	Each slash lives 1 s. At most MAX_TARGETS characters are drawn per round.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local World = require(ReplicatedStorage.Shared.Util.World)

local ROUND = 0.25
local SECOND_CUT_DELAY = 0.1
local LIFETIME = 1
local TARGET_SPEED = 2000
local MIN_RANDOM_SPEED = 300
local MAX_RANDOM_SPEED = 500
local MAX_TARGETS = 12
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local SIDEWAYS = CFrame.Angles(0, math.rad(90), 0)

local random = Random.new()

local function getTemplates(): { BasePart }
	local templates: { BasePart } = {}
	local folder = EffectAssets.FindFruit("Slash", "Power2")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(templates, child)
			end
		end
	end
	return templates
end

local function getRoot(model: Instance?): BasePart?
	if not model or not model:IsA("Model") then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

return function(character: Model, value: any): () -> ()
	local fields = EffectAssets.Unpack(value)
	local radius = tonumber(fields[1])
	local x, y, z = tonumber(fields[2]), tonumber(fields[3]), tonumber(fields[4])
	local affinity = tonumber(fields[5]) or 1
	local primary = FruitColor.Parse(fields[6] or "")

	local templates = getTemplates()
	local follow = fields[2] == "F"
	if not radius or radius <= 0 or #templates == 0 or not (follow or (x and y and z)) then
		return function() end
	end

	local center = if follow then character:GetPivot().Position else Vector3.new(x :: number, y :: number, z :: number)
	local spread = radius / 1.25
	local active = true

	local function randomPoint(): Vector3
		return center
			+ Vector3.new(
				random:NextNumber(-spread, spread),
				random:NextNumber(-spread, spread),
				random:NextNumber(-spread, spread)
			)
	end

	local function throw(from: Vector3, to: Vector3, speed: number)
		local offset = to - from
		if not active or offset.Magnitude < 0.05 then
			return
		end

		local blade = templates[random:NextInteger(1, #templates)]:Clone()
		for _, descendant in blade:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("JointInstance") or descendant:IsA("BodyMover") then
				descendant:Destroy()
			end
		end
		blade.Anchored = true
		blade.CanCollide = false
		blade.CanQuery = false
		blade.CanTouch = false
		if character:GetAttribute(HAKI_ATTRIBUTE) then
			blade.Color = HAKI_COLOR
		elseif primary then
			blade.Color = primary
		end

		local unit = offset.Unit
		local up = if math.abs(unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
		local start = CFrame.lookAt(from, from + unit, up) * SIDEWAYS
		blade.CFrame = start
		blade.Parent = World.Effects()

		TweenService:Create(blade, TweenInfo.new(LIFETIME, Enum.EasingStyle.Linear), {
			CFrame = start + unit * speed * LIFETIME,
		}):Play()
		Debris:AddItem(blade, LIFETIME)
	end

	local function getTargets(): { BasePart }
		local targets: { BasePart } = {}
		local function consider(model: Instance?)
			if #targets >= MAX_TARGETS or model == character then
				return
			end
			local root = getRoot(model)
			if root and (root.Position - center).Magnitude <= radius then
				table.insert(targets, root)
			end
		end

		for _, player in Players:GetPlayers() do
			consider(player.Character)
		end
		for _, enemy in World.GetNpcs() do
			consider(enemy)
		end
		return targets
	end

	task.spawn(function()
		while active do
			task.wait(ROUND)
			if not active then
				break
			end
			if follow then
				local root = getRoot(character)
				if root then
					center = root.Position
				end
			end

			for _, root in getTargets() do
				throw(randomPoint(), root.Position, TARGET_SPEED * affinity)
				task.delay(SECOND_CUT_DELAY, function()
					if root.Parent then
						throw(randomPoint(), root.Position, TARGET_SPEED * affinity)
					end
				end)
			end

			local least = math.floor(affinity)
			local extra = random:NextInteger(least, math.max(least, math.floor(2.5 * affinity)))
			for _ = 1, extra do
				throw(randomPoint(), randomPoint(), random:NextNumber(MIN_RANDOM_SPEED, MAX_RANDOM_SPEED) * affinity)
			end
		end
	end)

	return function()
		active = false
	end
end
