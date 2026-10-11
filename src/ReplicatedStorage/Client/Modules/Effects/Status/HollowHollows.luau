--!strict
--[[
	Hollow fruit - the ghosts hovering before they are sent, for both Negative Hollow
	(status "HollowHollows") and Mini-Hollow (status "HollowMinis", whose module simply
	returns this one: everything that differs follows from the kind in the status value).

	Status value (on the caster):
	  hovering  "<kind>|<seed>|<colors>"
	  sent      "<kind>|<seed>|<colors>|<speed>|<reach>|<x>|<y>|<z>" (the target's position)
	Attribute "<status>State" (read here, not an effect): one entry per ghost so far,
	";"-separated after a leading ";": "x,y,z,yaw" where it appeared, "" for the same
	place as the last written one, "x" once it has been used up.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Hollow.Power3.Hollow   (kind "Hollow")
	           ReplicatedStorage.Assets.Models.Fruits.Hollow.Power5.HollowMini (kind "Mini")
	Both are small rigs with Head / Torso / Left Arm / Right Arm painted with the
	fruit's first color.

	Purely cosmetic. Each ghost comes out of the place the server gives, half
	transparent for half a second, and drifts to its own spot like the legacy
	BodyPosition did (an exponential approach at 5 per second): within 10 studs and 3-7
	up for hollows, within 3 studs and 1-2 up for minis, facing the way the caster
	faced. The spots come from Random.new(seed), drawn in the same order as the server.

	The clones are driven by an AnimationController instead of their Humanoid: a
	Humanoid keeps its torso and head solid, and the legacy ghosts collided with nothing.

	When the status goes (expired, interrupted) the ghosts go. When it turns into the
	"sent" value they are handed, where they are, to OneShot.HollowSwarm, which flies
	them at the character standing where the server says the target is.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local fly = require(script.Parent.Parent.OneShot.HollowSwarm)

local PAINTED = { "Head", "Torso", "Left Arm", "Right Arm" }
local DRIFT_RATE = 5
local MAX_GHOSTS = 60
local APPEAR_TRANSPARENCY = 0.5
local APPEAR_SECONDS = 0.5
-- A handed-over batch nobody flew (the sent value never reached this client) is removed.
local HANDOVER_SECONDS = 1
-- How far from the server's point the target may be on this client.
local TARGET_SEARCH = 25

type Ghost = {
	Model: Model,
	Position: Vector3,
	Goal: Vector3,
	Facing: CFrame,
}

-- Ghosts of a hover that ended on a send, waiting for the run of the "sent" value.
local handover: { [Model]: { [string]: { Ghost } } } = {}

local function noop() end

local function destroyAll(ghosts: { [number]: Ghost })
	for _, ghost in ghosts do
		ghost.Model:Destroy()
	end
end

local function take(character: Model, kind: string): { Ghost }?
	local owned = handover[character]
	local ghosts = owned and owned[kind]
	if owned and ghosts then
		owned[kind] = nil
		if next(owned) == nil then
			handover[character] = nil
		end
	end
	return ghosts
end

-- The character closest to where the server saw the target.
local function findTarget(position: Vector3, caster: Model): Model?
	local alive = World.AliveRoot()
	if not alive then
		return nil
	end

	local closest: Model? = nil
	local closestDistance = TARGET_SEARCH
	for _, folder in alive:GetChildren() do
		for _, model in folder:GetChildren() do
			local root = model:FindFirstChild("HumanoidRootPart")
			if model ~= caster and model:IsA("Model") and root and root:IsA("BasePart") then
				local distance = (root.Position - position).Magnitude
				if distance < closestDistance then
					closest, closestDistance = model, distance
				end
			end
		end
	end
	return closest
end

local function launch(character: Model, kind: string, fields: { string })
	local ghosts = take(character, kind)
	if not ghosts then
		return
	end

	local speed, reach = tonumber(fields[4]), tonumber(fields[5])
	local x, y, z = tonumber(fields[6]), tonumber(fields[7]), tonumber(fields[8])
	local target = if x and y and z then findTarget(Vector3.new(x, y, z), character) else nil
	if not speed or not reach or not target then
		destroyAll(ghosts)
		return
	end
	fly(Vector3.zero, { Kind = kind, Ghosts = ghosts, Target = target, Speed = speed, Reach = reach })
end

return function(character: Model, value: any): () -> ()
	local fields = EffectAssets.Unpack(value)
	local kind = fields[1]
	local isMini = kind == "Mini"
	local seed = tonumber(fields[2])
	if not kind or not seed then
		return noop
	end
	if fields[4] then
		launch(character, kind, fields)
		return noop
	end

	local statusName = if isMini then "HollowMinis" else "HollowHollows"
	local template = if isMini
		then EffectAssets.FindFruit("Hollow", "Power5", "HollowMini")
		else EffectAssets.FindFruit("Hollow", "Power3", "Hollow")
	if not template or not template:IsA("Model") then
		return noop
	end

	local primary = FruitColor.Parse(fields[3] or "")
	local animationId = if isMini
		then AnimationConfig.Fruits.Hollow.MiniHollow5State1
		else AnimationConfig.Fruits.Hollow.Hollow3State1
	local radius = if isMini then 3 else 10
	local low, high = if isMini then 1 else 3, if isMini then 2 else 7

	local random = Random.new(seed)
	local offsets: { Vector3 } = {}
	local ghosts: { [number]: Ghost } = {}
	local gone: { [number]: boolean } = {}
	local started = false

	local function spawnGhost(index: number, origin: Vector3, yaw: number, settled: boolean)
		local model = template:Clone()
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			model:Destroy()
			gone[index] = true
			return
		end
		model.PrimaryPart = root

		local shown: { BasePart } = {}
		for _, descendant in model:GetDescendants() do
			if
				descendant:IsA("BodyMover")
				or descendant:IsA("Constraint")
				or descendant:IsA("LuaSourceContainer")
				or descendant:IsA("Humanoid")
			then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.Massless = true
				if descendant ~= root then
					table.insert(shown, descendant)
				end
			end
		end
		root.Anchored = true

		if primary then
			for _, partName in PAINTED do
				local part = model:FindFirstChild(partName)
				if part and part:IsA("BasePart") then
					part.Color = primary
				end
			end
		end

		local facing = CFrame.Angles(0, math.rad(yaw), 0)
		local goal = origin + offsets[index]
		local position = if settled then goal else origin
		model:PivotTo(CFrame.new(position) * facing)
		model.Parent = World.Effects()

		local controller = Instance.new("AnimationController")
		local animator = Instance.new("Animator")
		animator.Parent = controller
		controller.Parent = model
		local track = Animations.Get(animator, animationId)
		track.Looped = true
		track:Play()

		if not settled then
			for _, part in shown do
				local authored = part.Transparency
				part.Transparency = math.max(authored, APPEAR_TRANSPARENCY)
				TweenService:Create(part, TweenInfo.new(APPEAR_SECONDS), { Transparency = authored }):Play()
			end
		end

		ghosts[index] = { Model = model, Position = position, Goal = goal, Facing = facing }
	end

	local function sync()
		local state = character:GetAttribute(statusName .. "State")
		if type(state) ~= "string" then
			return
		end

		-- The first entry is the empty one before the leading separator.
		local entries = string.split(state, ";")
		local count = math.min(#entries - 1, MAX_GHOSTS)
		-- More than one ghost out when the effect starts: it joined a hover under way.
		local settled = not started and count > 1
		started = true

		local origin: Vector3? = nil
		local yaw = 0
		for index = 1, count do
			if not offsets[index] then
				local x = random:NextInteger(-radius, radius)
				local y = random:NextInteger(low, high)
				local z = random:NextInteger(-radius, radius)
				offsets[index] = Vector3.new(x, y, z)
			end

			local entry = entries[index + 1]
			if entry == "x" then
				gone[index] = true
				local ghost = ghosts[index]
				if ghost then
					ghosts[index] = nil
					ghost.Model:Destroy()
				end
				continue
			end

			if entry ~= "" then
				local numbers = string.split(entry, ",")
				local x, y, z = tonumber(numbers[1]), tonumber(numbers[2]), tonumber(numbers[3])
				if x and y and z then
					origin = Vector3.new(x, y, z)
					yaw = tonumber(numbers[4]) or 0
				end
			end
			if origin and not ghosts[index] and not gone[index] then
				spawnGhost(index, origin, yaw, settled)
			end
		end
	end

	local stateConnection = character:GetAttributeChangedSignal(statusName .. "State"):Connect(sync)
	sync()

	local heartbeat = RunService.Heartbeat:Connect(function(deltaTime: number)
		local alpha = 1 - math.exp(-DRIFT_RATE * deltaTime)
		for _, ghost in ghosts do
			if (ghost.Goal - ghost.Position).Magnitude > 0.01 then
				ghost.Position = ghost.Position:Lerp(ghost.Goal, alpha)
				ghost.Model:PivotTo(CFrame.new(ghost.Position) * ghost.Facing)
			end
		end
	end)

	return function()
		stateConnection:Disconnect()
		heartbeat:Disconnect()

		local current = EffectAssets.Unpack(character:GetAttribute(statusName))
		if current[4] == nil or tonumber(current[2]) ~= seed then
			destroyAll(ghosts)
			return
		end

		-- Sent: the run of the new value picks them up right after this cleanup.
		local list: { Ghost } = {}
		for _, ghost in ghosts do
			table.insert(list, ghost)
		end
		local owned = handover[character]
		if not owned then
			owned = {}
			handover[character] = owned
		end
		local stale = owned[kind]
		if stale then
			destroyAll(stale)
		end
		owned[kind] = list
		task.delay(HANDOVER_SECONDS, function()
			local waiting = handover[character]
			if waiting and waiting[kind] == list then
				take(character, kind)
				destroyAll(list)
			end
		end)
	end
end
