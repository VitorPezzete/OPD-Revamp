--!strict
--[[
	Dough fruit - Torque Mochi, on its user, from the press until 1.1 s after the spin ends.
	Status value: the fruit color string.
	Second attribute on the same character, DoughTorqueRelease (seconds charged): appears
	when the spin ends and starts the finale below.

	Templates under ReplicatedStorage.Assets.Models.Fruits.Dough.Effects["Torque Mochi"]:
	Arm, Head (with its Smoke emitter and welded Spike parts), Haki (with Smoke),
	VFX["Rotation Effect" | "Spin Down" | Impact | Shockwave | RumblePart] and
	Particles[Crater | Rocks].

	Everyone, the source's "TorqueMochi" client effect step by step:
	- the arm (first fruit color) grows out of the right hand from 2 to 30 studs in 0.2 s;
	  the ball appears at its end and grows from 2 to 9 studs in 0.2 s, turns haki-dark with
	  its spikes and the haki sleeve, with smoke and "Mochi Haki 2"; the arm then stretches
	  to 150 studs over 9.5 s. Arm, ball and sleeve follow the right arm every frame, so the
	  swing is the user's animation.
	- while spinning: a "Rotation Effect" disc on the user every 0.415 s, turning half a
	  turn and fading, 450 * c studs wide with c = clamp(seconds + 3, 3, 10) / 10, and
	  "Mochi Swing" after each.
	- finale (DoughTorqueRelease), with c from the seconds the server charged: "Mochi
	  Cinematic Boom"; at 0.85 s the arm pulls back to 5 studs in 0.25 s; at 1.1 s the arm
	  is removed, "Mochi Impact", and the Spin Down column, the Impact ball (0.125 s
	  later), the crater and rocks on the ground under the user, and the Shockwave ring
	  (0.25 s after that); at 1.6 s "Mochi Haki Rumbles" and two volleys, a second apart,
	  of up to 10 * c jagged lightning lines (second fruit color) above the place.
	The model holding arm, ball and sleeve is named "DoughTorqueArm_<user id>" in the
	effects folder: Effects.Status.DoughTorqueCaught looks its Head up to pin a victim.

	Owner only: the TorqueMochiBegan clip, TorqueMochiRotate from 0.5 s, and TorqueMochiEnd
	at the release.

	Source leak fixed: the Impact ball and the Shockwave ring were never removed (the
	script passed the wrong variable to Debris); they are removed a second after fading.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local RELEASE_ATTRIBUTE = "DoughTorqueRelease"
local MODEL_PREFIX = "DoughTorqueArm_"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local HAKI_FLASH = Color3.fromRGB(255, 255, 255)

local ARM_START = 2
local ARM_SHORT = 30
local ARM_LONG = 150
local ARM_END = 5
local ARM_STRETCH_TIME = 9.5
local HEAD_START = 2
local HEAD_SIZE = 9
local GROW_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad)
local SWING_INFO = TweenInfo.new(0.415, Enum.EasingStyle.Linear)
local SWING_SIZE = 450
local ARM_ROTATION = CFrame.Angles(math.rad(-90), 0, math.rad(45))
local ROTATE_AFTER = 0.5
local PULL_BACK_AT = 0.85
local PULL_BACK_TIME = 0.25
local END_DELAY = 1.1
local FINALE_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
local RUMBLE_SIZE = 25
local RUMBLE_TIME = 0.05

local function makeSound(name: string, parent: Instance?, position: Vector3?, lifetime: number?)
	local definition = (SoundConfig :: any).Fruits.Dough[name]
	if not definition then
		return
	end
	local holder: Instance
	if parent then
		holder = parent
	else
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position or Vector3.zero
		attachment.Parent = Workspace.Terrain
		Debris:AddItem(attachment, lifetime or 5)
		holder = attachment
	end
	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Parent = holder
	sound:Play()
	if parent and lifetime then
		Debris:AddItem(sound, lifetime)
	end
end

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function cloneVfx(folder: Instance?, name: string): BasePart?
	local vfx = folder and folder:FindFirstChild("VFX")
	local template = vfx and vfx:FindFirstChild(name)
	if not template or not template:IsA("BasePart") then
		return nil
	end
	local part = template:Clone()
	prepare(part)
	return part
end

local function emit(parent: Instance?, name: string, count: number)
	local emitter = parent and parent:FindFirstChild(name)
	if emitter and emitter:IsA("ParticleEmitter") then
		emitter:Emit(count)
	end
end

-- One volley of jagged lines above `origin` (the source's `rumbles`).
local function rumbles(folder: Instance?, origin: Vector3, factor: number, color: Color3?)
	local size, seconds = RUMBLE_SIZE, RUMBLE_TIME
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Linear)
	local parent = World.Effects()
	local thin = Vector3.new(size / 50, size / 50, 0)
	local full = Vector3.new(size / 50, size / 50, size * factor)
	local half = CFrame.new(0, 0, -(size / 2) * factor)

	local function segment(cframe: CFrame): BasePart?
		local part = cloneVfx(folder, "RumblePart")
		if not part then
			return nil
		end
		part.CFrame = cframe
		if color then
			part.Color = color
		end
		part.Parent = parent
		Debris:AddItem(part, seconds * 10 + 5)
		return part
	end
	local function bend(): CFrame
		return CFrame.Angles(math.random(-45, 45), math.random(-45, 45), math.random(-45, 45))
	end

	for _ = 1, math.clamp(10 * factor, 2, 10) do
		task.spawn(function()
			local point = origin
				+ Vector3.new(math.random(-150, 150) * factor, math.random(100, 150) * factor, math.random(-150, 150) * factor)

			local first = segment(CFrame.lookAt(point, origin))
			if not first then
				return
			end
			TweenService:Create(first, info, { Size = full }):Play()
			task.wait(seconds)

			local second = segment(first.CFrame * half * bend())
			if not second then
				return
			end
			TweenService:Create(second, info, { Size = full, CFrame = second.CFrame * half }):Play()
			task.wait(seconds)

			local third = segment(second.CFrame * half * bend())
			if not third then
				return
			end
			TweenService:Create(third, info, { Size = full, CFrame = third.CFrame * half }):Play()
			task.wait(seconds)

			TweenService:Create(first, info, { Size = thin, CFrame = first.CFrame * half }):Play()
			task.wait(seconds)

			TweenService:Create(second, info, { Size = thin, CFrame = second.CFrame * half }):Play()
			first:Destroy()
			task.wait(seconds)

			second:Destroy()
			TweenService:Create(third, info, { Size = thin, CFrame = third.CFrame * half }):Play()
			task.wait(seconds)

			third:Destroy()
		end)
	end
end

-- Everything that happens from 1.1 s after the spin ended, around `origin`.
local function finale(folder: Instance?, character: Model, origin: Vector3, factor: number, color: Color3?)
	local parent = World.Effects()

	task.spawn(function()
		local column = cloneVfx(folder, "Spin Down")
		if column then
			column.Size *= factor
			column.Position = origin + Vector3.new(0, 100 * factor, 0)
			column.Parent = parent
			Debris:AddItem(column, 1)
			TweenService:Create(column, FINALE_INFO, {
				CFrame = column.CFrame * CFrame.new(0, -100 * factor, 0) * CFrame.Angles(0, math.pi, 0),
				Transparency = 1,
			}):Play()
		end

		task.wait(0.125)

		local impact = cloneVfx(folder, "Impact")
		if impact then
			impact.Size *= factor * 0.2
			impact.Position = origin + Vector3.new(0, impact.Size.Y / 2, 0)
			impact.Parent = parent
			Debris:AddItem(impact, 1.5)
			TweenService:Create(impact, FINALE_INFO, {
				Size = impact.Size * 5,
				CFrame = impact.CFrame * CFrame.new(0, impact.Size.Y * 5 / 2, 0) * CFrame.Angles(0, -math.pi, 0),
				Transparency = 1,
			}):Play()
		end

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { character }
		local ground = Workspace:Raycast(origin + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), rayParams)
		local particles = folder and folder:FindFirstChild("Particles")
		if ground and particles then
			local attachment = Instance.new("Attachment")
			attachment.WorldPosition = ground.Position
			attachment.Parent = Workspace.Terrain
			Debris:AddItem(attachment, 10)

			local crater = particles:FindFirstChild("Crater")
			if crater and crater:IsA("ParticleEmitter") then
				local emitter = crater:Clone()
				emitter.Parent = attachment
				emitter.Size = NumberSequence.new(50 * factor, 150 * factor)
				emitter:Emit(1)
			end
			local rocks = particles:FindFirstChild("Rocks")
			if rocks and rocks:IsA("ParticleEmitter") then
				local emitter = rocks:Clone()
				emitter.Parent = attachment
				emitter.Size = NumberSequence.new(5 * factor, 5 * factor)
				emitter.Speed = NumberRange.new(250 * factor, 250 * factor)
				emitter:Emit(10 * factor)
			end
		end

		task.wait(0.25)

		local ring = cloneVfx(folder, "Shockwave")
		if ring then
			ring.Size *= factor * 0.5
			ring.Position = origin + Vector3.new(0, 150 / 2 * factor, 0)
			ring.Parent = parent
			Debris:AddItem(ring, 1.5)
			TweenService:Create(ring, FINALE_INFO, {
				Size = ring.Size * 2,
				CFrame = ring.CFrame * CFrame.Angles(0, -math.pi, 0),
				Transparency = 1,
			}):Play()
		end
	end)

	makeSound("MochiImpact", nil, origin, 7.5)
	task.wait(0.5)
	makeSound("MochiHakiRumbles", nil, origin, 2)
	rumbles(folder, origin, factor, color)
	task.wait(1)
	rumbles(folder, origin, factor, color)
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
	local rightArm = character:FindFirstChild("Right Arm")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not rightArm or not rightArm:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return function() end
	end

	local folder = EffectAssets.FindFruit("Dough", "Effects", "Torque Mochi")
	local began = os.clock()
	local alive = true
	local rotating = true

	local owner = Players:GetPlayerFromCharacter(character)
	local model = Instance.new("Model")
	model.Name = MODEL_PREFIX .. (if owner then tostring(owner.UserId) else character.Name)
	model.Parent = World.Effects()

	local arm: BasePart? = nil
	local head: BasePart? = nil
	local sleeve: BasePart? = nil
	local stretch: Tween? = nil

	local armTemplate = folder and folder:FindFirstChild("Arm")
	if armTemplate and armTemplate:IsA("BasePart") then
		local created = armTemplate:Clone()
		prepare(created)
		created.Size = Vector3.new(created.Size.X, created.Size.Y, ARM_START)
		if primary then
			created.Color = primary
		end
		created.Parent = model
		arm = created
		makeSound("MochiFormating", created, nil, 2.5)
	end

	local function follow()
		if not arm or not rightArm.Parent then
			return
		end
		arm.CFrame = rightArm.CFrame * CFrame.new(0, -(arm.Size.Z / 2 + 1), 0) * ARM_ROTATION
		if head then
			head.CFrame = arm.CFrame * CFrame.new(0, 0, -(arm.Size.Z / 2))
		end
		if sleeve then
			sleeve.CFrame = arm.CFrame * CFrame.new(0, 0, -(arm.Size.Z / 2) + sleeve.Size.Z / 2)
		end
	end
	follow()
	local renderStepped = RunService.RenderStepped:Connect(follow)

	-- The build-up, then the swing discs for as long as the spin lasts.
	task.spawn(function()
		local growing = arm
		if not growing then
			return
		end
		local grow = TweenService:Create(growing, GROW_INFO, { Size = Vector3.new(growing.Size.X, growing.Size.Y, ARM_SHORT) })
		grow:Play()
		grow.Completed:Wait()
		if not alive then
			return
		end

		local headTemplate = folder and folder:FindFirstChild("Head")
		local ball: BasePart? = nil
		if headTemplate and headTemplate:IsA("BasePart") then
			ball = headTemplate:Clone()
		end
		if ball then
			-- The spikes stay welded to the ball (unanchored), so they follow it.
			ball.Anchored = true
			ball.CanCollide = false
			ball.CanQuery = false
			ball.CanTouch = false
			for _, spike in ball:GetChildren() do
				if spike:IsA("BasePart") then
					spike.Anchored = false
					spike.CanCollide = false
					spike.CanQuery = false
					spike.CanTouch = false
					spike.Massless = true
				end
			end
			ball.Size = Vector3.new(HEAD_START, HEAD_START, HEAD_START)
			ball.Parent = model
			head = ball
			follow()

			local swell = TweenService:Create(ball, GROW_INFO, { Size = Vector3.new(HEAD_SIZE, HEAD_SIZE, HEAD_SIZE) })
			swell:Play()
			swell.Completed:Wait()
			if not alive then
				return
			end

			emit(ball, "Smoke", 5)
			ball.Material = Enum.Material.Neon
			ball.Color = HAKI_FLASH

			local sleeveTemplate = folder and folder:FindFirstChild("Haki")
			if sleeveTemplate and sleeveTemplate:IsA("BasePart") then
				local created = sleeveTemplate:Clone()
				prepare(created)
				created.Transparency = 0
				created.Parent = model
				sleeve = created
				emit(created, "Smoke", 2)
			end

			makeSound("MochiHaki2", ball, nil, 2.5)
			emit(ball, "Smoke", 5)

			-- The source went from the white flash to haki-dark without a pause.
			ball.Material = Enum.Material.SmoothPlastic
			ball.Color = HAKI_COLOR
			if sleeve then
				sleeve.Material = Enum.Material.SmoothPlastic
				sleeve.Color = HAKI_COLOR
			end
			for _, spike in ball:GetChildren() do
				if spike:IsA("BasePart") then
					spike.Transparency = 0
					spike.Material = Enum.Material.SmoothPlastic
					spike.Color = HAKI_COLOR
				end
			end
		end

		if rotating then
			local stretching = TweenService:Create(growing, TweenInfo.new(ARM_STRETCH_TIME, Enum.EasingStyle.Linear), {
				Size = Vector3.new(growing.Size.X, growing.Size.Y, ARM_LONG),
			})
			stretching:Play()
			stretch = stretching
		end

		while rotating and alive and character.Parent do
			local factor = math.clamp(os.clock() - began + 3, 3, 10) / 10
			local disc = cloneVfx(folder, "Rotation Effect")
			if not disc then
				task.wait(SWING_INFO.Time)
			else
				disc.CFrame = root.CFrame
				disc.Size = Vector3.new(SWING_SIZE * factor, disc.Size.Y * factor, SWING_SIZE * factor)
				disc.Parent = World.Effects()
				Debris:AddItem(disc, SWING_INFO.Time + 1)
				local swing = TweenService:Create(disc, SWING_INFO, {
					CFrame = disc.CFrame * CFrame.Angles(0, -math.pi, 0),
					Transparency = 1,
				})
				swing:Play()
				swing.Completed:Wait()
				disc:Destroy()
			end
			if root.Parent then
				makeSound("MochiSwing", root, nil, 1)
			end
		end
	end)

	-- Owner: the three clips.
	local animator = if isLocal then Animations.FindAnimator(character) else nil
	local anims = (AnimationConfig :: any).Fruits.Dough
	local beganTrack: AnimationTrack? = nil
	local rotateTrack: AnimationTrack? = nil
	if animator then
		beganTrack = Animations.Play(animator, anims.TorqueMochiBegan)
		task.delay(ROTATE_AFTER, function()
			if alive and rotating then
				rotateTrack = Animations.Play(animator, anims.TorqueMochiRotate)
			end
		end)
	end

	local released = false
	local function release()
		local charge = character:GetAttribute(RELEASE_ATTRIBUTE)
		if released or type(charge) ~= "number" then
			return
		end
		released = true
		rotating = false

		if stretch then
			stretch:Cancel()
			stretch = nil
		end
		if rotateTrack then
			rotateTrack:Stop()
		end
		if animator then
			Animations.Play(animator, anims.TorqueMochiEnd)
		end

		local origin = root.Position
		local factor = math.clamp(charge + 3, 3, 10) / 10
		makeSound("MochiCinematicBoom", nil, origin, 4)

		task.delay(PULL_BACK_AT, function()
			if alive and arm and arm.Parent then
				TweenService:Create(arm, TweenInfo.new(PULL_BACK_TIME, Enum.EasingStyle.Linear), {
					Size = Vector3.new(arm.Size.X, arm.Size.Y, ARM_END),
				}):Play()
			end
		end)

		-- Not tied to the status any more: it is cleared at the very moment this starts.
		task.delay(END_DELAY, function()
			model:Destroy()
			finale(folder, character, origin, factor, secondary)
		end)
	end
	local releaseConnection = character:GetAttributeChangedSignal(RELEASE_ATTRIBUTE):Connect(release)
	release()

	return function()
		alive = false
		rotating = false
		releaseConnection:Disconnect()
		renderStepped:Disconnect()
		if stretch then
			stretch:Cancel()
		end
		if beganTrack then
			beganTrack:Stop()
		end
		if rotateTrack then
			rotateTrack:Stop()
		end
		-- After a release the finale removes the arm itself, a moment later at most.
		if not released then
			model:Destroy()
		end
	end
end
