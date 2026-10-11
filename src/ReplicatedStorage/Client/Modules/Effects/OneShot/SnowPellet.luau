--!strict
--[[
	Snow fruit - Snow Pellet: the snowball in flight. Cosmetic copy of a server-simulated
	projectile, moved with the same arithmetic: launched at `Speed` along `Direction`
	and falling with gravity for `Duration` seconds. Without haki it passes through the
	map like the legacy ball (which collided with nothing); a haki ball was solid and
	stays where it meets the map.

	params: { Id: string, Direction: Vector3, Speed: number, Duration: number,
	          Gravity: number, Size: number (diameter), Haki: boolean,
	          Hand: "Right" | "Left", Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Snow.Power3.Snow4 (a part with a
	"SnowTrigger" emitter); a plain ball without it.

	The ball is parented to the effects folder as "SnowPellet_<Id>" so that the burst
	effect (OneShot.SnowPelletBurst), which arrives when the server decides the flight is
	over, can take it over wherever it is.

	The thrower's own client also turns the character towards the throw and plays the
	punch animation of the hand that charged, at 32 times its speed, a snap as in the
	legacy game (replicated by the Animator). The ball itself always leaves from the
	right arm (see Abilities.Snow["Snow Pellet"]).
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(248, 248, 248)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
-- Time left for the burst to arrive before an orphan ball is removed.
local LINGER = 1.5
-- Flight time when the server did not send one.
local DEFAULT_DURATION = 2
local PUNCH_FADE = 0.01
local PUNCH_SPEED = 32

local function playPunch(character: Model, left: boolean, direction: Vector3)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not animator then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if root and root:IsA("BasePart") and not humanoid.Sit and flat.Magnitude > 0.05 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end

	local anims = AnimationConfig.FruitAnims
	Animations.Play(
		animator,
		if left then anims.Punch1LeftPunch else anims.Punch1RightPunch,
		PUNCH_FADE,
		1,
		PUNCH_SPEED
	)
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end

	local direction = params.Direction
	local speed = params.Speed
	local size = params.Size
	if typeof(direction) ~= "Vector3" or type(speed) ~= "number" or type(size) ~= "number" then
		return
	end
	if direction.Magnitude < 1e-3 or speed <= 0 or size <= 0 then
		return
	end
	local duration: number = if type(params.Duration) == "number" then params.Duration else DEFAULT_DURATION
	local gravity = Vector3.new(0, -(if type(params.Gravity) == "number" then params.Gravity else Workspace.Gravity), 0)

	local caster = params.Caster
	if typeof(caster) == "Instance" and caster:IsA("Model") and caster == Players.LocalPlayer.Character then
		playPunch(caster, params.Hand == "Left", direction)
	end

	local ball: BasePart
	local template = EffectAssets.FindFruit("Snow", "Power3", "Snow4")
	if template and template:IsA("BasePart") then
		ball = template:Clone()
		for _, descendant in ball:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("JointInstance") then
				descendant:Destroy()
			end
		end
	else
		local plain = Instance.new("Part")
		plain.Shape = Enum.PartType.Ball
		plain.Color = DEFAULT_COLOR
		ball = plain
	end

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local emitter = ball:FindFirstChild("SnowTrigger", true)
	if params.Haki then
		ball.Color = HAKI_COLOR
		if emitter and emitter:IsA("ParticleEmitter") then
			emitter.Color = ColorSequence.new(HAKI_COLOR)
		end
	elseif primary and secondary then
		ball.Color = primary
		if emitter and emitter:IsA("ParticleEmitter") then
			emitter.Color = FruitColor.ToSequence(primary, secondary)
		end
	end

	local name = `SnowPellet_{tostring(params.Id)}`
	ball.Name = name
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Size = Vector3.new(size, size, size)
	ball.CFrame = CFrame.new(origin)
	ball.Parent = World.Effects()

	-- Only a haki ball meets the map.
	local raycastParams: RaycastParams? = nil
	if params.Haki then
		local created = RaycastParams.new()
		created.FilterType = Enum.RaycastFilterType.Exclude
		-- Characters never stop it: touching one is the burst, which the server decides.
		local excluded: { Instance } = { ball }
		local alive = World.AliveRoot()
		if alive then
			table.insert(excluded, alive)
		end
		if typeof(caster) == "Instance" then
			table.insert(excluded, caster)
		end
		created.FilterDescendantsInstances = excluded
		created.RespectCanCollide = true
		raycastParams = created
	end

	local velocity = direction.Unit * speed
	local elapsed = 0
	local position = origin
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		-- The burst renames the ball when it takes it over.
		if not ball.Parent or ball.Name ~= name then
			connection:Disconnect()
			return
		end

		elapsed = math.min(elapsed + deltaTime, duration)
		local nextPosition = origin + velocity * elapsed + gravity * (elapsed * elapsed / 2)
		if raycastParams then
			local step = nextPosition - position
			local result = if step.Magnitude > 1e-3
				then Workspace:Spherecast(position, size / 2, step, raycastParams)
				else nil
			if result then
				ball.CFrame = CFrame.new(position + step.Unit * result.Distance)
				connection:Disconnect()
				return
			end
		end
		position = nextPosition
		ball.CFrame = CFrame.new(position)
		if elapsed >= duration then
			connection:Disconnect()
		end
	end)
	Debris:AddItem(ball, duration + LINGER)
end
