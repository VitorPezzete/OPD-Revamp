--!strict
--[[
	Quake fruit - Tsunami, the two walls of water.
	params: { Right: Vector3 (the caster's flat right vector at the release),
	          Size: Vector3 (wall size, already scaled by the server),
	          LegDistance: number, LegTime: number, SeaLevel: number, Delay: number,
	          Scale: number (size factor, used for the cracks), Haki: boolean,
	          Colors: string, Caster: Model }

	`origin` is where the caster stood. After Delay seconds one wall starts LegDistance
	studs to the caster's right and the other as far to the left, their tops at sea
	level; each crosses `origin` in LegTime seconds while rising by its own height, then
	goes on for another LegDistance while sinking two heights. This is the path the
	server sweeps for hits, so it is recomputed from the clock every frame instead of
	being tweened.

	Template: the legacy ReplicatedStorage.Resources.Tsunami part, looked for in
	Assets.Models.Fruits.Quake, Assets.Models.Fruits._Shared and ReplicatedStorage.Resources.
	When it cannot be found a plain translucent block of the same size is drawn.
	The wall takes the fruit's second color, as in the legacy game.

	Sounds: "Quake Tsunami Release" on the caster, the "Quake Tsunami" loop on each wall,
	"Quake Tsunami Collision" when they meet.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local playCrack = require(script.Parent.QuakeCrack)

local DEFAULT_COLOR = Color3.fromRGB(135, 168, 227)
local FALLBACK_TRANSPARENCY = 0.35
local CRACK_OFFSET = 3
local RELEASE_SOUND_SECONDS = 6.5
local COLLISION_SOUND_SECONDS = 4

local function newSound(name: string, parent: Instance): Sound?
	local definition = (SoundConfig :: any).SFX.Elemental.Quake[name]
	if not definition then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.Looped = definition.Looped == true
	sound.PlaybackSpeed = definition.Speed or 1
	sound.RollOffMaxDistance = 2000
	sound.Parent = parent
	sound:Play()
	return sound
end

local function playAt(name: string, position: Vector3, seconds: number)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain
	newSound(name, holder)
	Debris:AddItem(holder, seconds)
end

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

local function newWall(size: Vector3, color: Color3?): BasePart
	local template = findTemplate()
	local wall: BasePart
	if template then
		wall = template:Clone()
		for _, descendant in wall:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("Sound") then
				descendant:Destroy()
			end
		end
		if color then
			wall.Color = color
		end
	else
		local block = Instance.new("Part")
		block.Material = Enum.Material.Glass
		block.Transparency = FALLBACK_TRANSPARENCY
		block.Color = color or DEFAULT_COLOR
		block.CastShadow = false
		wall = block
	end
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
	local releaseDelay: number = if type(params.Delay) == "number" then params.Delay else 0
	local scale: number = if type(params.Scale) == "number" then params.Scale else 1
	local colors = if type(params.Colors) == "string" then params.Colors else ""
	local _, secondary = FruitColor.Parse(colors)

	playAt("Quake Tsunami Release", origin, RELEASE_SOUND_SECONDS)
	if releaseDelay > 0 then
		task.wait(releaseDelay)
	end

	-- Cracks beside both hands, facing sideways (the caster's frame at the release).
	local frame = CFrame.fromMatrix(origin, right, Vector3.yAxis)
	for _, side in { CRACK_OFFSET, -CRACK_OFFSET } do
		playCrack(origin, {
			CFrame = frame * CFrame.new(side, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0),
			Force = scale,
			Haki = params.Haki,
			Colors = colors,
		})
	end

	local walls: { { Part: BasePart, From: Vector3, Direction: Vector3 } } = {}
	for _, side in { 1, -1 } do
		local wall = newWall(size, secondary)
		wall.Parent = World.Effects()
		newSound("Quake Tsunami", wall)
		table.insert(walls, {
			Part = wall,
			From = origin + right * (legDistance * side),
			Direction = right * -side,
		})
	end

	local height = size.Y
	local started = os.clock()
	local collided = false
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local alpha = (os.clock() - started) / legTime
		if alpha >= 2 then
			connection:Disconnect()
			for _, wall in walls do
				wall.Part:Destroy()
			end
			return
		end

		if alpha >= 1 and not collided then
			collided = true
			playAt("Quake Tsunami Collision", origin, COLLISION_SOUND_SECONDS)
		end

		local centerY = if alpha <= 1
			then seaLevel - height / 2 + height * alpha
			else seaLevel + height / 2 - 2 * height * (alpha - 1)
		for _, wall in walls do
			local flat = wall.From + wall.Direction * (legDistance * alpha)
			local center = Vector3.new(flat.X, centerY, flat.Z)
			wall.Part.CFrame = CFrame.lookAt(center, center + wall.Direction)
		end
	end)
end
