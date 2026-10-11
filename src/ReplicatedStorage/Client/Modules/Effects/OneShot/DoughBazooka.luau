--!strict
--[[
	Dough fruit - Dough Bazooka: two mochi rings open above the user and each fires an arm
	at the aim point.
	params: { Factor: number (f), Aim: Vector3, Haki: boolean, Colors: string, Caster: Model }
	Templates: ReplicatedStorage.Assets.Models.Fruits.Dough.Effects.Common.Donut (the ring,
	a MeshPart) and .Arm (a 4x4x4 part).

	Timeline of each ring, the source's (everything scales with f):
	- the ring appears at a tenth of its size 15 studs to one side, 20 above and 10 behind
	  the user, facing the aim point, and grows to 4 * f times its size in 1 * f s (Quad)
	  while turning half a turn;
	- the arm (2 * f times as thick as the template) shoots from it to the aim point in
	  0.125 * f s, thinning to 80 %: this is when the server hits;
	- after 1 * f s it pulls back in 0.25 * f s, thickening to 120 %, and is removed;
	- the ring shrinks to 0.05 * f of its size in 0.5 * f s, turning back, and is removed.
	Custom colors: ring = second, arm = first; the arm is haki-dark with armament haki.
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
local RING_OFFSETS = { CFrame.new(15, 20, 10), CFrame.new(-15, 20, 10) }
local SOUND_OFFSET = Vector3.new(0, 10, 5)

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
	if not params then
		return
	end
	local factor, aim = params.Factor, params.Aim
	if type(factor) ~= "number" or factor <= 0 or typeof(aim) ~= "Vector3" then
		return
	end

	local caster = params.Caster
	local root = if typeof(caster) == "Instance" then caster:FindFirstChild("HumanoidRootPart") else nil
	local rootCFrame = if root and root:IsA("BasePart") then root.CFrame else CFrame.new(origin)

	playAt("MochiFormating", rootCFrame.Position + SOUND_OFFSET, 2.5)

	local ringTemplate = EffectAssets.FindFruit("Dough", "Effects", "Common", "Donut")
	local armTemplate = EffectAssets.FindFruit("Dough", "Effects", "Common", "Arm")
	if not ringTemplate or not ringTemplate:IsA("BasePart") or not armTemplate or not armTemplate:IsA("BasePart") then
		return
	end
	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local parent = World.Effects()

	for _, offset in RING_OFFSETS do
		task.spawn(function()
			local ring = ringTemplate:Clone()
			prepare(ring)
			ring.Size = ringTemplate.Size * 0.1
			if secondary then
				ring.Color = secondary
			end
			ring.CFrame = CFrame.lookAt((rootCFrame * offset).Position, aim)
			ring.Parent = parent
			-- Never left behind, whatever happens to the steps below.
			Debris:AddItem(ring, 4 * factor + 5)

			if not tween(ring, 1 * factor, Enum.EasingStyle.Quad, {
				Size = ring.Size * 40 * factor,
				CFrame = ring.CFrame * CFrame.Angles(0, 0, math.pi),
			}) then
				return
			end

			local arm = armTemplate:Clone()
			prepare(arm)
			arm.CFrame = ring.CFrame
			arm.Size = Vector3.new(armTemplate.Size.X * 2 * factor, armTemplate.Size.Y * 2 * factor, 0)
			if primary then
				arm.Color = primary
			end
			if params.Haki then
				arm.Color = HAKI_COLOR
			end
			arm.Parent = parent
			Debris:AddItem(arm, 2 * factor + 5)

			local length = (ring.Position - aim).Magnitude
			playAt("MochiArm", ring.Position, 0.75)
			if not tween(arm, 0.125 * factor, Enum.EasingStyle.Linear, {
				Size = Vector3.new(arm.Size.X * 0.8, arm.Size.Y * 0.8, length),
				CFrame = arm.CFrame * CFrame.new(0, 0, -length / 2),
			}) then
				return
			end

			playAt("MochiBazookaHit", aim, 1.25)
			task.wait(1 * factor)

			playAt("MochiArmBack", ring.Position, 0.75)
			if arm.Parent then
				tween(arm, 0.25 * factor, Enum.EasingStyle.Linear, {
					Size = Vector3.new(arm.Size.X * 1.2, arm.Size.Y * 1.2, 0),
					CFrame = arm.CFrame * CFrame.new(0, 0, length / 2),
				})
			end
			arm:Destroy()

			if ring.Parent then
				tween(ring, 0.5 * factor, Enum.EasingStyle.Quad, {
					Size = ring.Size * 0.05 * factor,
					CFrame = ring.CFrame * CFrame.Angles(0, 0, -math.pi),
				})
			end
			ring:Destroy()
		end)
	end
end
