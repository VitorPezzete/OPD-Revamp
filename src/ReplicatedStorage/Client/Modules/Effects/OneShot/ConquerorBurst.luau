--!strict
--[[
	Conqueror's Haki - the burst.
	params: { Caster: Model, Color: Color3, Stage: number (1-3) }

	`origin` is where the caster stood; the waves follow the caster while it is there.
	- stages 1 and 2: for 3.2 s a sphere leaves the caster every 0.1 s and swells to 65;
	- stage 3: for 7.4 s, every 0.15 s, swelling to 250;
	- from stage 2: dust at the caster's feet with every wave, and for 3.2 s flames of
	  the caster's colour on its head (they stay where the head was after the first second);
	- the burst sound, once.
	Timings: ConquerorConfig.Visual. Templates: HakiBall, HaoEmit (emitter "150"), Haohaki.

	The place this came from also shook the camera of everyone around and played a pose
	on the caster; this project has no camera shake and that animation never existed.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConquerorConfig = require(ReplicatedStorage.Shared.Configs.ConquerorConfig)
local World = require(ReplicatedStorage.Shared.Util.World)
local ConquerorFx = require(script.Parent.Parent.Util.ConquerorFx)

local VISUAL = ConquerorConfig.Visual
local DEFAULT_COLOR = ConquerorConfig.Palette[1]
local DUST_EMITTER = "150"
local DUST_COUNT = 25
local DUST_DROP = Vector3.new(0, 3, 0)
-- Seconds the flames follow the head, and seconds their last particles are left to die.
local FIRE_FOLLOW = 1
local FIRE_FADE = 2
local DUST_FADE = 3

local function headFire(caster: Model, color: Color3)
	local template = ConquerorFx.Asset("Haohaki")
	local head = caster:FindFirstChild("Head")
	if not template or not template:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return
	end

	local fire = template:Clone()
	fire.Anchored = false
	fire.CanCollide = false
	fire.CanQuery = false
	fire.CanTouch = false
	fire.Massless = true
	fire.CFrame = head.CFrame

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = fire
	weld.Parent = fire
	fire.Parent = World.Effects()

	local emitters = ConquerorFx.Emitters(fire, color)
	for _, emitter in emitters do
		emitter.Enabled = true
	end

	task.delay(FIRE_FOLLOW, function()
		fire.Anchored = true
		weld:Destroy()
	end)
	task.delay(VISUAL.FireSeconds, function()
		for _, emitter in emitters do
			emitter.Enabled = false
		end
		task.wait(FIRE_FADE)
		fire:Destroy()
	end)
end

-- The dust emitter on its own invisible stud, or nil when the template is not there.
local function newDust(position: Vector3): (Part?, ParticleEmitter?)
	local template = ConquerorFx.Asset("HaoEmit")
	local emitter = template and template:FindFirstChild(DUST_EMITTER, true)
	if not emitter or not emitter:IsA("ParticleEmitter") then
		return nil, nil
	end

	local holder = ConquerorFx.Holder(position - DUST_DROP)
	local dust = emitter:Clone()
	dust.Enabled = false
	dust.Parent = holder
	return holder, dust
end

return function(origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	local color = if params and typeof(params.Color) == "Color3" then params.Color else DEFAULT_COLOR
	local stage = if params and type(params.Stage) == "number" then params.Stage else 1
	local model: Model? = if typeof(caster) == "Instance" and caster:IsA("Model") then caster else nil
	local root = model and model:FindFirstChild("HumanoidRootPart")

	local waves = if stage >= 3 then VISUAL.GreatBurst else VISUAL.Burst
	ConquerorFx.PlaySound("Burst", origin)

	local dustHolder: Part?, dust: ParticleEmitter? = nil, nil
	if stage >= 2 then
		if model then
			headFire(model, color)
		end
		dustHolder, dust = newDust(origin)
	end

	local position = origin
	local endsAt = os.clock() + waves.Seconds
	while os.clock() < endsAt do
		if root and root:IsA("BasePart") and root:IsDescendantOf(game) then
			position = root.Position
		end
		ConquerorFx.Shockwave(position, waves.Scale)
		if dustHolder and dust then
			dustHolder.CFrame = CFrame.new(position - DUST_DROP)
			dust:Emit(DUST_COUNT)
		end
		task.wait(waves.Interval)
	end

	if dustHolder then
		task.wait(DUST_FADE)
		dustHolder:Destroy()
	end
end
