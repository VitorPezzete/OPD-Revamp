--!strict
--[[
	Quake fruit - Seismic Wave.
	params: { Size: number (side of the blast cube, studs), Force: number (crack length
	          scale), RightHand: boolean, Haki: boolean, Colors: string, Caster: Model }

	`origin` is the centre of the blast. A shock bubble swells there to Size studs in
	0.25 s and vanishes, with the explosion sound; cracks open beside the caster's
	punching hand with the "Quake Crack" sound.

	Template: the legacy ReplicatedStorage.Resources.Seismic part, looked for in
	Assets.Models.Fruits.Quake, Assets.Models.Fruits._Shared and ReplicatedStorage.Resources;
	a plain force-field ball is drawn when it cannot be found.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local playCrack = require(script.Parent.QuakeCrack)

local SWELL_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Linear)
local START_SIZE = Vector3.new(1, 1, 1)
local EXPLOSION_SECONDS = 3
local HAND_OFFSET = 2

local function findTemplate(): BasePart?
	local quake = EffectAssets.FindFruit("Quake")
	local shared = EffectAssets.FindFruit("_Shared")
	local resources = ReplicatedStorage:FindFirstChild("Resources")
	local found = (quake and quake:FindFirstChild("Seismic", true))
		or (shared and shared:FindFirstChild("Seismic", true))
		or (resources and resources:FindFirstChild("Seismic", true))
	return if found and found:IsA("BasePart") then found else nil
end

local function playExplosion(position: Vector3)
	local definition = (SoundConfig :: any).SFX["To-Organize"].Explosion
	if not definition then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain

	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, EXPLOSION_SECONDS)
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local size: number = if type(params.Size) == "number" then params.Size else 0
	local colors = if type(params.Colors) == "string" then params.Colors else ""
	local primary = FruitColor.Parse(colors)

	-- Cracks beside the punching hand, facing sideways.
	local caster = params.Caster
	local root = if typeof(caster) == "Instance" then caster:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local side = if params.RightHand then 1 else -1
		playCrack(root.Position, {
			CFrame = root.CFrame * CFrame.new(HAND_OFFSET * side, 0.5, 0) * CFrame.Angles(0, math.rad(90 * side), 0),
			Force = if type(params.Force) == "number" then params.Force else 1,
			Haki = params.Haki,
			Colors = colors,
			Sound = true,
		})
	end

	if size <= 0 then
		return
	end
	playExplosion(origin)

	local template = findTemplate()
	local bubble: BasePart
	if template then
		bubble = template:Clone()
		for _, descendant in bubble:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
	else
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Material = Enum.Material.ForceField
		ball.Color = Color3.fromRGB(255, 255, 255)
		ball.CastShadow = false
		bubble = ball
	end
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	if primary then
		bubble.Color = primary
	end
	bubble.Size = START_SIZE
	bubble.CFrame = CFrame.new(origin)
	bubble.Parent = World.Effects()

	TweenService:Create(bubble, SWELL_INFO, { Size = Vector3.new(size, size, size) }):Play()
	Debris:AddItem(bubble, SWELL_INFO.Time)
end
