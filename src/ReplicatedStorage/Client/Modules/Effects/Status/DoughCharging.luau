--!strict
--[[
	Dough fruit - Burning Mochi or Dough Bazooka while it is being charged.
	Status value: "Burning|<1 when armament haki was on at the press, else 0>|<colors>"
	              or "Bazooka".

	Burning Mochi, everyone: the burning fist on the right arm. A copy of
	ReplicatedStorage.Assets.Models.Fruits.Dough.Power1.Arm (a Model: Top, Fist, Cover and
	the glowing Hot part, which carries the particles and is the part the others are welded
	to), placed half a stud below the arm's centre and welded to it. Custom colors: Top,
	Fist, Cover and the Mochi particles take the first, Hot and both fires the second.
	With haki, Top and Fist flash white neon for 0.25 s, puff smoke and go haki-dark.
	Sounds on it: "Mochi Formating" once, "Mochi Burning" and "Mochi Spining" looping.
	The thrown fist is another copy, drawn by Effects.OneShot.DoughBurningMochi.

	Owner only, both abilities: the character keeps facing the mouse (the source's
	"P1Looker" render step), except when seated. Burning Mochi also plays the ChargeRight
	clip, followed by the LoopRight one for as long as the charge lasts.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local ARM_OFFSET = CFrame.new(0, -0.5, 0) * CFrame.Angles(0, math.rad(-90), math.rad(180))
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local HAKI_FLASH = Color3.fromRGB(255, 255, 255)
local HAKI_FLASH_TIME = 0.25

local function addSound(name: string, parent: Instance, lifetime: number?)
	local definition = (SoundConfig :: any).Fruits.Dough[name]
	if not definition then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Looped = definition.Looped == true
	sound.Parent = parent
	sound:Play()
	if lifetime then
		Debris:AddItem(sound, lifetime)
	end
end

local function tint(emitter: Instance?, color: Color3)
	if emitter and emitter:IsA("ParticleEmitter") then
		emitter.Color = ColorSequence.new(color)
	end
end

local function paint(part: Instance?, color: Color3, material: Enum.Material?)
	if part and part:IsA("BasePart") then
		part.Color = color
		if material then
			part.Material = material
		end
	end
end

local function addFist(character: Model, haki: boolean, colors: string): Model?
	local template = EffectAssets.FindFruit("Dough", "Power1", "Arm")
	local rightArm = character:FindFirstChild("Right Arm")
	if not template or not template:IsA("Model") or not rightArm or not rightArm:IsA("BasePart") then
		return nil
	end

	local fist = template:Clone()
	local core = fist.PrimaryPart or fist:FindFirstChild("Hot")
	if not core or not core:IsA("BasePart") then
		fist:Destroy()
		return nil
	end
	for _, descendant in fist:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end

	local top, knuckles = fist:FindFirstChild("Top"), fist:FindFirstChild("Fist")
	local primary, secondary = FruitColor.Parse(colors)
	if primary and secondary then
		paint(top, primary)
		paint(knuckles, primary)
		paint(fist:FindFirstChild("Cover"), primary)
		paint(core, secondary)
		tint(core:FindFirstChild("Mochi"), primary)
		tint(core:FindFirstChild("Fire"), secondary)
		local launch = core:FindFirstChild("LaunchEffects")
		tint(launch and launch:FindFirstChild("Fire"), secondary)
	end

	-- The source placed the model by its primary part, not by its pivot.
	fist:PivotTo(rightArm.CFrame * ARM_OFFSET * core.CFrame:ToObjectSpace(fist:GetPivot()))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = core
	weld.Part1 = rightArm
	weld.Parent = core
	fist.Parent = character

	local mochi = core:FindFirstChild("Mochi")
	if mochi and mochi:IsA("ParticleEmitter") then
		mochi:Emit(5)
	end
	addSound("MochiFormating", core, 2)
	addSound("MochiBurning", core)
	addSound("MochiSpining", core)

	if haki then
		paint(top, HAKI_FLASH, Enum.Material.Neon)
		paint(knuckles, HAKI_FLASH, Enum.Material.Neon)
		addSound("MochiHaki2", core, 2.5)
		task.delay(HAKI_FLASH_TIME, function()
			if not fist.Parent then
				return
			end
			local smoke = top and top:FindFirstChild("Smoke")
			if smoke and smoke:IsA("ParticleEmitter") then
				smoke:Emit(5)
			end
			paint(top, HAKI_COLOR, Enum.Material.SmoothPlastic)
			paint(knuckles, HAKI_COLOR, Enum.Material.SmoothPlastic)
		end)
	end
	return fist
end

-- Turns the local character toward the mouse every frame. Returns its cleanup.
local function faceMouse(character: Model): (() -> ())?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end

	local mouse = Players.LocalPlayer:GetMouse()
	local connection = RunService.RenderStepped:Connect(function()
		if humanoid.Sit then
			return
		end
		local position = root.Position
		local aim = mouse.Hit.Position
		local flat = Vector3.new(aim.X, position.Y, aim.Z)
		if (flat - position).Magnitude > 0.05 then
			root.CFrame = CFrame.lookAt(position, flat)
		end
	end)

	return function()
		connection:Disconnect()
	end
end

-- ChargeRight, then LoopRight once it has played. Returns its cleanup.
local function playCharge(character: Model): (() -> ())?
	local animator = Animations.FindAnimator(character)
	if not animator then
		return nil
	end
	local anims = (AnimationConfig :: any).Fruits.Dough
	local running = true
	local charge = Animations.Play(animator, anims.ChargeRight)
	local loop: AnimationTrack? = nil
	local stopped = charge.Stopped:Once(function()
		if running then
			loop = Animations.Play(animator, anims.LoopRight)
		end
	end)

	return function()
		running = false
		stopped:Disconnect()
		charge:Stop()
		if loop then
			loop:Stop()
		end
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local burning = fields[1] == "Burning"

	local fist = if burning then addFist(character, fields[2] == "1", fields[3] or "") else nil
	local stopFacing = if isLocal then faceMouse(character) else nil
	local stopClips = if isLocal and burning then playCharge(character) else nil

	return function()
		if stopFacing then
			stopFacing()
		end
		if stopClips then
			stopClips()
		end
		if fist then
			fist:Destroy()
		end
	end
end
