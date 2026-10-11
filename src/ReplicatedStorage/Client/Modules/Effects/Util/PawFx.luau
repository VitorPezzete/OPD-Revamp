--!strict
--[[
	Paw fruit - helpers shared by its effect modules (Effects.OneShot.Paw* and
	Effects.Status.Paw*). NOT an effect: it returns a table and the server never plays
	"PawFx". It sits here only because the porting brief allows no new file in
	Effects/Util, where it belongs (move it there and fix the requires when convenient).

	Assets (ReplicatedStorage.Assets.Models.Fruits.Paw):
	- PawModel: the paw-shaped union (1.5 x 1.5 x 0.5).
	- Power2.Shockwave: the ring a Pad Cannon paw leaves where it starts.
	- Effects.<Group>.Particles.<Name> / Effects.UrsusShock.Meshes.<Name>.
	Everything degrades to nothing when an asset is missing.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local FRUIT = "Paw"
local PHASE_ACTION = 3
-- Ten a second, as the other aimed salvos do; well inside the input budget.
local AIM_INTERVAL = 0.1
-- How far along the camera ray the streamed aim point is put (see PawFx.StreamAim).
local AIM_DISTANCE = 500

local PawFx = {}

PawFx.HAKI_COLOR = Color3.fromRGB(25, 12, 25)
PawFx.Anims = (AnimationConfig :: any).Fruits.Paw
-- Depth of a paw for a width of 2: every source size is (2, 2, 1.333) times something.
PawFx.DEPTH = 1.333

-- Paws in flight, by the id the server gave them: what ends each one.
local flights: { [number]: () -> () } = {}

-- The saved fruit colors, nil for "None": the source only recoloured when there were any.
function PawFx.Colors(saved: any): (Color3?, Color3?)
	return FruitColor.Parse(if type(saved) == "string" then saved else "")
end

-- (2, 2, 1.333) * scale: the proportions of every paw of the fruit.
function PawFx.Size(scale: number): Vector3
	return Vector3.new(2 * scale, 2 * scale, PawFx.DEPTH * scale)
end

-- A neon paw, anchored and out of every query. Nil when the model is missing.
function PawFx.NewPaw(size: Vector3, color: Color3?, transparency: number): BasePart?
	local template = EffectAssets.FindFruit(FRUIT, "PawModel")
	if not template or not template:IsA("BasePart") then
		return nil
	end
	local paw = template:Clone()
	for _, descendant in paw:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	paw.Anchored = true
	paw.CanCollide = false
	paw.CanQuery = false
	paw.CanTouch = false
	paw.Massless = true
	paw.CastShadow = false
	paw.Material = Enum.Material.Neon
	paw.Transparency = transparency
	paw.Size = size
	if color then
		paw.Color = color
	end
	return paw
end

-- A clone of Effects.<group>.Particles.<name>, tinted when a color is given.
function PawFx.Emitter(group: string, name: string, color: Color3?): ParticleEmitter?
	local template = EffectAssets.FindFruit(FRUIT, "Effects", group, "Particles", name)
	if not template or not template:IsA("ParticleEmitter") then
		return nil
	end
	local emitter = template:Clone()
	if color then
		emitter.Color = ColorSequence.new(color)
	end
	return emitter
end

-- An attachment in the world that removes itself (and what it carries) after `seconds`.
function PawFx.Anchor(cframe: CFrame, seconds: number): Attachment
	local attachment = Instance.new("Attachment")
	attachment.WorldCFrame = cframe
	attachment.Parent = Workspace.Terrain
	Debris:AddItem(attachment, seconds)
	return attachment
end

-- A sound of SoundConfig.Fruits.Paw under `parent`, playing. `seconds` removes it.
function PawFx.Sound(name: string, parent: Instance, seconds: number?): Sound?
	local definition = (SoundConfig :: any).Fruits.Paw[name]
	if not definition then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Looped = definition.Looped == true
	sound.Parent = parent
	sound:Play()
	if seconds then
		Debris:AddItem(sound, seconds)
	end
	return sound
end

-- The same at a point of the world; the sound is cut after `seconds`, as in the source.
function PawFx.SoundAt(name: string, position: Vector3, seconds: number)
	PawFx.Sound(name, PawFx.Anchor(CFrame.new(position), seconds))
end

function PawFx.IsLocalCharacter(character: any): boolean
	return typeof(character) == "Instance" and Players.LocalPlayer.Character == character
end

-- Registers what ends the flight `id`; it also ends by itself after `seconds`.
function PawFx.TrackFlight(id: any, seconds: number, stop: () -> ())
	local ended = false
	local function finish()
		if ended then
			return
		end
		ended = true
		if type(id) == "number" and flights[id] == finish then
			flights[id] = nil
		end
		stop()
	end
	if type(id) == "number" then
		flights[id] = finish
	end
	task.delay(seconds, finish)
end

-- Ends the flight `id` now (the server said where it stopped).
function PawFx.EndFlight(id: any)
	local finish = if type(id) == "number" then flights[id] else nil
	if finish then
		finish()
	end
end

-- CFrame at `position` looking along `direction`, whatever the direction.
function PawFx.Facing(position: Vector3, direction: Vector3): CFrame
	if direction.Magnitude < 1e-3 then
		return CFrame.new(position)
	end
	local unit = direction.Unit
	local up = if math.abs(unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(position, position + unit, up)
end

--[[
	Owner only: the character keeps facing the point it aims at, on the horizontal plane
	(the source "P1Looker" render step). Nothing while seated. Returns what stops it.
]]
function PawFx.FaceAim(character: Model): () -> ()
	local inputController = Knit.GetController("InputController")
	local connection = RunService.RenderStepped:Connect(function()
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Sit then
			return
		end
		local aim: Vector3 = inputController:GetAimPosition()
		local position = root.Position
		local flat = Vector3.new(aim.X, position.Y, aim.Z)
		if (flat - position).Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(position, flat)
		end
	end)
	return function()
		connection:Disconnect()
	end
end

--[[
	Owner only: streams the aim of Pad Cannon as the ability's secondary input (phase 3).
	The source fired its paws along the camera ray (the look vector of the mouse CFrame),
	not towards the point under the cursor. The server only takes a point, so the point
	sent is the root position moved AIM_DISTANCE studs along that ray: root -> point is the
	ray's direction. Returns what stops it.
]]
function PawFx.StreamAim(character: Model, fruitSlot: number, abilitySlot: number): () -> ()
	local abilityService = Knit.GetService("AbilityService")
	local inputController = Knit.GetController("InputController")
	local sinceSent = AIM_INTERVAL

	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceSent += deltaTime
		local root = character.PrimaryPart
		local camera = Workspace.CurrentCamera
		if sinceSent < AIM_INTERVAL or not root or not camera then
			return
		end
		local aim: Vector3 = inputController:GetAimPosition()
		local ray = aim - camera.CFrame.Position
		if ray.Magnitude < 1e-3 then
			return
		end
		sinceSent = 0
		abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, root.Position + ray.Unit * AIM_DISTANCE)
	end)
	return function()
		connection:Disconnect()
	end
end

-- Owner only: the wind-up clip, then the held one when it ends. Returns what stops both.
function PawFx.PlayCharge(character: Model, windUpId: string, heldId: string?): () -> ()
	local animator = Animations.FindAnimator(character)
	if not animator then
		return function() end
	end

	local windUp = Animations.Get(animator, windUpId)
	local held = if heldId then Animations.Get(animator, heldId) else nil
	local active = true
	local stopped: RBXScriptConnection? = nil
	if held then
		stopped = windUp.Stopped:Connect(function()
			if active then
				held:Play()
			end
		end)
	end
	windUp:Play()

	return function()
		active = false
		if stopped then
			stopped:Disconnect()
		end
		windUp:Stop()
		if held then
			held:Stop()
		end
	end
end

-- Owner only: a release clip, at the speed the source gave it.
function PawFx.PlayRelease(character: Model, animationId: string, speed: number)
	local animator = Animations.FindAnimator(character)
	if animator then
		Animations.Play(animator, animationId, 0.1, 1, speed)
	end
end

-- Where clients parent what they draw.
function PawFx.Parent(): Instance
	return World.Effects()
end

return PawFx
