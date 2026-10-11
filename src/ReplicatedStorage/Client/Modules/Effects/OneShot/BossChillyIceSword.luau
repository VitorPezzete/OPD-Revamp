--!strict
--[[
	Chilly boss - Ice Swords: one blade of ice that homes on a character.

	origin: where the blade appears (around the boss).
	params: { Target: Model, Look: Vector3 (first heading), Speed: number, Turn: number
	          (share of the turn towards the target made per 1/60 s), Duration: number,
	          HitRange: number, Haki: boolean, Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Chilly.Power1.ChillySword.

	The blade steers exactly as the server's own copy does (Bosses/ChillyBoss): every
	frame it turns part of the way towards the target's root and moves along its new
	heading. Within HitRange of the target it bursts into five shards (the server deals
	the damage); after Duration seconds, or when the target is gone, it fades in 0.3 s.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(128, 187, 219)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local FRAME_RATE = 60
local TRAIL_LIFETIME = 0.3
local TRAIL_TRANSPARENCY = NumberSequence.new(0, 1)
local FADE_TIME = 0.3
local SHARDS = 5
local SHARD_SIZE = Vector3.new(0.5, 0.5, 0.5)
local SHARD_TIME = 0.4

local random = Random.new()

local function burst(cframe: CFrame, color: Color3)
	for _ = 1, SHARDS do
		local shard = Instance.new("Part")
		shard.Size = SHARD_SIZE
		shard.Color = color
		shard.Material = Enum.Material.Neon
		shard.Anchored = false
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CFrame = cframe * CFrame.Angles(random:NextNumber(), random:NextNumber(), random:NextNumber())
		shard.Parent = World.Effects()
		shard.AssemblyLinearVelocity =
			Vector3.new(random:NextInteger(-30, 30), random:NextInteger(10, 40), random:NextInteger(-30, 30))
		TweenService:Create(shard, TweenInfo.new(SHARD_TIME), { Size = Vector3.zero }):Play()
		Debris:AddItem(shard, SHARD_TIME)
	end
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Target) ~= "Instance" or typeof(params.Look) ~= "Vector3" then
		return
	end
	local target: Instance = params.Target
	local look: Vector3 = params.Look
	local speed: number = if type(params.Speed) == "number" then params.Speed else 65
	local turn: number = if type(params.Turn) == "number" then math.clamp(params.Turn, 0, 1) else 0.15
	local duration: number = if type(params.Duration) == "number" then math.clamp(params.Duration, 0.1, 30) else 6
	local hitRange: number = if type(params.HitRange) == "number" then params.HitRange else 5

	local template = EffectAssets.FindFruit("Chilly", "Power1", "ChillySword")
	if not template or not template:IsA("BasePart") or look.Magnitude < 1e-3 then
		return
	end

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local color = if params.Haki then HAKI_COLOR else primary or DEFAULT_COLOR
	local trailColor = if params.Haki then HAKI_COLOR else secondary or DEFAULT_COLOR

	local blade = template:Clone()
	for _, descendant in blade:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Trail") then
			descendant:Destroy()
		end
	end
	blade.Color = color
	blade.Material = Enum.Material.Glass
	blade.Anchored = true
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false
	blade.CFrame = CFrame.lookAt(origin, origin + look)

	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, blade.Size.Y / 2, 0)
	top.Parent = blade
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -blade.Size.Y / 2, 0)
	bottom.Parent = blade

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(trailColor)
	trail.Transparency = TRAIL_TRANSPARENCY
	trail.Lifetime = TRAIL_LIFETIME
	trail.LightEmission = 0.8
	trail.Parent = blade

	blade.Parent = World.Effects()

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		if not blade.Parent then
			connection:Disconnect()
			return
		end

		local root = target:FindFirstChild("HumanoidRootPart")
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		local gone = not target.Parent or not root or not root:IsA("BasePart") or (humanoid ~= nil and humanoid.Health <= 0)
		if gone or os.clock() - started >= duration then
			connection:Disconnect()
			trail.Enabled = false
			TweenService:Create(blade, TweenInfo.new(FADE_TIME), { Transparency = 1 }):Play()
			Debris:AddItem(blade, FADE_TIME)
			return
		end

		local goal = (root :: BasePart).Position
		local current = blade.CFrame
		if (goal - current.Position).Magnitude > 1e-3 then
			-- The legacy turn was 15 % per frame; the same rate whatever the frame time.
			local alpha = 1 - (1 - turn) ^ (deltaTime * FRAME_RATE)
			current = current:Lerp(CFrame.lookAt(current.Position, goal), alpha)
		end
		current += current.LookVector * (speed * deltaTime)
		blade.CFrame = current

		if (current.Position - goal).Magnitude < hitRange then
			connection:Disconnect()
			burst(current, color)
			blade:Destroy()
		end
	end)
end
