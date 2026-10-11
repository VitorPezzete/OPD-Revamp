--!strict
--[[
	Ice Dagger special: the homing ice blades. One appears every Interval seconds near
	the user (up to 6 studs to the side, 4 to 8 above), turns towards the target and
	flies at it; within 5 studs it bursts into five shards. A blade that has not arrived
	after Lifetime seconds, or whose target is gone, fades out.

	Purely cosmetic: the server tracks its own blade positions for the damage.
	params: { Caster: Model, Target: Model, Count: number, Interval: number,
	          Speed: number, Lifetime: number, Haki: boolean }
	Template: "IceDagger1" (legacy SwordModels); a glass wedge-shaped bar without it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

local ICE = Color3.fromRGB(128, 187, 219)
local HIT_DISTANCE = 5
local TURN = 0.15

local function shatter(position: Vector3, color: Color3)
	for _ = 1, 5 do
		local shard = WeaponFx.Part({
			Size = Vector3.new(0.5, 0.5, 0.5),
			Color = color,
			Material = Enum.Material.Neon,
			Anchored = false,
			CFrame = CFrame.new(position) * CFrame.Angles(math.random(), math.random(), math.random()),
		}, 0.4)
		shard.AssemblyLinearVelocity = Vector3.new(math.random(-30, 30), math.random(10, 40), math.random(-30, 30))
		WeaponFx.Tween(shard, 0.4, { Size = Vector3.zero })
	end
end

local function launch(casterRoot: BasePart, targetRoot: BasePart, speed: number, lifetime: number, color: Color3)
	local start = casterRoot.Position + Vector3.new(math.random(-6, 6), math.random(4, 8), math.random(-6, 6))

	local template = WeaponFx.FindAsset("IceDagger1")
	local blade: PVInstance
	if template and template:IsA("PVInstance") then
		blade = template:Clone() :: PVInstance
		WeaponFx.Neutralize(blade)
		local parts = blade:GetDescendants()
		table.insert(parts, blade)
		for _, part in parts do
			if part:IsA("BasePart") then
				part.Color = color
				part.Material = Enum.Material.Glass
			end
		end
		blade.Parent = World.Effects()
	else
		blade = WeaponFx.Part({ Size = Vector3.new(0.4, 0.4, 4), Color = color, Material = Enum.Material.Glass, Transparency = 0.45 })
	end

	local facing = CFrame.lookAt(start, targetRoot.Position + Vector3.new(0, 5, 0))
	blade:PivotTo(facing)
	local started = os.clock()

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		if targetRoot.Parent == nil or os.clock() - started >= lifetime then
			connection:Disconnect()
			blade:Destroy()
			return
		end
		if (facing.Position - targetRoot.Position).Magnitude < HIT_DISTANCE then
			connection:Disconnect()
			shatter(facing.Position, color)
			blade:Destroy()
			return
		end

		facing = facing:Lerp(CFrame.lookAt(facing.Position, targetRoot.Position), TURN)
		facing += facing.LookVector * speed * deltaTime
		blade:PivotTo(facing)
	end)
end

return function(_origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	local target = params and params.Target
	if typeof(caster) ~= "Instance" or typeof(target) ~= "Instance" then
		return
	end
	local casterRoot = caster:FindFirstChild("HumanoidRootPart")
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not casterRoot or not casterRoot:IsA("BasePart") or not targetRoot or not targetRoot:IsA("BasePart") then
		return
	end

	local params2 = params :: { [string]: any }
	local color = if params2.Haki then WeaponFx.HakiColor else ICE
	for _ = 1, params2.Count or 4 do
		if casterRoot.Parent == nil or targetRoot.Parent == nil then
			break
		end
		launch(casterRoot, targetRoot, params2.Speed or 95, params2.Lifetime or 6, color)
		task.wait(params2.Interval or 0.15)
	end
end
