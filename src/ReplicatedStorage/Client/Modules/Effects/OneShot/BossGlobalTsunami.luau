--!strict
--[[
	Raid bosses (Bosses/_Global) - Quake: the two walls of water.
	params: { Right: Vector3 (the boss's flat right vector at the release),
	          Size: Vector3 (wall size, already scaled by the server),
	          LegDistance: number, LegTime: number, SeaLevel: number,
	          Scale: number (size factor, used for the cracks), Haki: boolean,
	          Colors: string, Caster: Model? (the boss) }

	`origin` is where the boss stood. One wall starts LegDistance studs to its right and
	the other as far to its left, their tops at sea level; each crosses `origin` in
	LegTime seconds while rising by its own height. This is where the boss differs from a
	player's Tsunami (QuakeTsunami): its walls then leave twice as fast, another
	2 * LegDistance in LegTime, and sink by one height only. It is the path the server
	sweeps for hits, recomputed from the clock every frame.

	Template: the legacy ReplicatedStorage.Resources.Tsunami part, looked for in
	Assets.Models.Fruits.Quake, Assets.Models.Fruits._Shared and ReplicatedStorage.Resources;
	a plain translucent block of the same size is drawn when it cannot be found.
	The walls are always sea blue, as the legacy boss painted them.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local World = require(ReplicatedStorage.Shared.Util.World)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local playCrack = require(script.Parent.QuakeCrack)

local WALL_COLOR = Color3.fromRGB(128, 187, 219)
local FALLBACK_TRANSPARENCY = 0.35
local CRACK_OFFSET = 3

local function findTemplate(): BasePart?
	local found = EffectAssets.FindFruit("Quake", "Tsunami") or EffectAssets.FindFruit("_Shared", "Tsunami")
	if not found then
		local quake = EffectAssets.FindFruit("Quake")
		local shared = EffectAssets.FindFruit("_Shared")
		local resources = ReplicatedStorage:FindFirstChild("Resources")
		found = (quake and quake:FindFirstChild("Tsunami", true))
			or (shared and shared:FindFirstChild("Tsunami", true))
			or (resources and resources:FindFirstChild("Tsunami", true))
	end
	return if found and found:IsA("BasePart") then found else nil
end

local function newWall(size: Vector3): BasePart
	local template = findTemplate()
	local wall: BasePart
	if template then
		wall = template:Clone()
		for _, descendant in wall:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("Sound") then
				descendant:Destroy()
			end
		end
	else
		local block = Instance.new("Part")
		block.Material = Enum.Material.Glass
		block.Transparency = FALLBACK_TRANSPARENCY
		block.CastShadow = false
		wall = block
	end
	wall.Color = WALL_COLOR
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanQuery = false
	wall.CanTouch = false
	wall.Size = size
	return wall
end

return function(origin: Vector3, params: { [string]: any }?)
	if
		not params
		or typeof(params.Right) ~= "Vector3"
		or typeof(params.Size) ~= "Vector3"
		or type(params.LegDistance) ~= "number"
		or type(params.LegTime) ~= "number"
		or params.LegTime <= 0
	then
		return
	end
	local right: Vector3 = params.Right
	local size: Vector3 = params.Size
	local legDistance: number = params.LegDistance
	local legTime: number = params.LegTime
	local seaLevel: number = if type(params.SeaLevel) == "number" then params.SeaLevel else origin.Y
	local scale: number = if type(params.Scale) == "number" then params.Scale else 1

	-- Cracks beside both hands, facing sideways (the boss's frame at the release).
	local frame = CFrame.fromMatrix(origin, right, Vector3.yAxis)
	for _, side in { CRACK_OFFSET, -CRACK_OFFSET } do
		playCrack(origin, {
			CFrame = frame * CFrame.new(side, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0),
			Force = scale,
			Haki = params.Haki,
			Colors = if type(params.Colors) == "string" then params.Colors else "",
		})
	end

	local walls: { { Part: BasePart, From: Vector3, Direction: Vector3 } } = {}
	for _, side in { 1, -1 } do
		local wall = newWall(size)
		wall.Parent = World.Effects()
		table.insert(walls, {
			Part = wall,
			From = origin + right * (legDistance * side),
			Direction = right * -side,
		})
	end

	-- The walls go with the boss: the server stops sweeping when it dies or is removed.
	local caster: Model? = if typeof(params.Caster) == "Instance" and params.Caster:IsA("Model") then params.Caster else nil
	local humanoid = caster and caster:FindFirstChildOfClass("Humanoid")

	local height = size.Y
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		-- 0 at the start, 1 over the boss, 2 at the end.
		local alpha = (os.clock() - started) / legTime
		local ended = caster ~= nil and (not caster.Parent or (humanoid ~= nil and humanoid.Health <= 0))
		if alpha >= 2 or ended then
			connection:Disconnect()
			for _, wall in walls do
				wall.Part:Destroy()
			end
			return
		end

		local distance = if alpha <= 1 then legDistance * alpha else legDistance * (1 + 2 * (alpha - 1))
		local centerY = if alpha <= 1
			then seaLevel - height / 2 + height * alpha
			else seaLevel + height / 2 - height * (alpha - 1)
		for _, wall in walls do
			local flat = wall.From + wall.Direction * distance
			local center = Vector3.new(flat.X, centerY, flat.Z)
			wall.Part.CFrame = CFrame.lookAt(center, center + wall.Direction)
		end
	end)
end
