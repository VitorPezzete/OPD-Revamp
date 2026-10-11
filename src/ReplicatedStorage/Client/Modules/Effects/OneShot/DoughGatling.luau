--!strict
--[[
	Dough fruit - one punch of Mochi Gatling: a mochi ring opens in the air and fires an arm
	at the aim point.
	params: { Factor: number (f), Haki: boolean, Colors: string }; `origin` is the aim point.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Dough.Effects.Common.Donut and .Arm.

	The source's timeline:
	- the ring appears at a twentieth of its size at a random point 50 to 75 studs above
	  the aim point and up to 75 studs to each side (every client rolls its own, as in the
	  source), facing it, and grows to 1.5 * f times its size in 0.5 * f s (Quad) while
	  turning half a turn;
	- the arm (f / 1.5 times as thick as the template) shoots to the aim point in
	  0.025 * f s, thinning to 80 %;
	- 0.25 s later it pulls back in 0.25 * f s, thickening to 120 %, and is removed;
	- the ring shrinks to 0.05 * f of its size in 0.25 * f s, turning back, and is removed.
	Custom colors: ring = second, arm = first; the arm is haki-dark with armament haki.
	(The server's hit is 0.525 s after the ring opens, whatever f is.)
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local HOLD = 0.25

local function playAt(name: string, position: Vector3, lifetime: number)
	local definition = (SoundConfig :: any).Fruits.Dough[name]
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
	Debris:AddItem(holder, lifetime)
end

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- Plays a tween and waits for it; false when the part is gone.
local function tween(part: BasePart, seconds: number, style: Enum.EasingStyle, goal: { [string]: any }): boolean
	local animation = TweenService:Create(part, TweenInfo.new(seconds, style), goal)
	animation:Play()
	animation.Completed:Wait()
	return part.Parent ~= nil
end

return function(origin: Vector3, params: { [string]: any }?)
	local factor = params and params.Factor
	if not params or type(factor) ~= "number" or factor <= 0 then
		return
	end
	local aim = origin
	local point = aim + Vector3.new(math.random(-75, 75), math.random(50, 75), math.random(-75, 75))

	playAt("MochiFormating", point, 2.5)

	local ringTemplate = EffectAssets.FindFruit("Dough", "Effects", "Common", "Donut")
	local armTemplate = EffectAssets.FindFruit("Dough", "Effects", "Common", "Arm")
	if not ringTemplate or not ringTemplate:IsA("BasePart") or not armTemplate or not armTemplate:IsA("BasePart") then
		return
	end
	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local parent = World.Effects()

	local ring = ringTemplate:Clone()
	prepare(ring)
	ring.Size = ringTemplate.Size * 0.05
	ring.CFrame = CFrame.lookAt(point, aim)
	if secondary then
		ring.Color = secondary
	end
	ring.Parent = parent
	-- Never left behind, whatever happens to the steps below.
	Debris:AddItem(ring, 2 * factor + 5)

	if not tween(ring, 0.5 * factor, Enum.EasingStyle.Quad, {
		Size = ring.Size * 30 * factor,
		CFrame = ring.CFrame * CFrame.Angles(0, 0, math.pi),
	}) then
		return
	end

	local arm = armTemplate:Clone()
	prepare(arm)
	arm.CFrame = ring.CFrame
	arm.Size = Vector3.new(armTemplate.Size.X / 1.5 * factor, armTemplate.Size.Y / 1.5 * factor, 0)
	if primary then
		arm.Color = primary
	end
	if params.Haki then
		arm.Color = HAKI_COLOR
	end
	arm.Parent = parent
	Debris:AddItem(arm, factor + 5)

	local length = (ring.Position - aim).Magnitude
	playAt("MochiArm", ring.Position, 0.75)
	if not tween(arm, 0.025 * factor, Enum.EasingStyle.Linear, {
		Size = Vector3.new(arm.Size.X * 0.8, arm.Size.Y * 0.8, length),
		CFrame = arm.CFrame * CFrame.new(0, 0, -length / 2),
	}) then
		return
	end

	task.wait(HOLD)

	playAt("MochiArmBack", ring.Position, 0.75)
	if arm.Parent then
		tween(arm, 0.25 * factor, Enum.EasingStyle.Linear, {
			Size = Vector3.new(arm.Size.X * 1.2, arm.Size.Y * 1.2, 0),
			CFrame = arm.CFrame * CFrame.new(0, 0, length / 2),
		})
	end
	arm:Destroy()

	if ring.Parent then
		tween(ring, 0.25 * factor, Enum.EasingStyle.Quad, {
			Size = ring.Size * 0.05 * factor,
			CFrame = ring.CFrame * CFrame.Angles(0, 0, -math.pi),
		})
	end
	ring:Destroy()
end
