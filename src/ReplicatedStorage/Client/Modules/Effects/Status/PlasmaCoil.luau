--!strict
--[[
	Plasma fruit - Plasma Coil: the plasma sphere floating above the user while the
	status is active, and the idle sparks it throws. Status value: the fruit color string.

	Template: ReplicatedStorage.Assets.Models.Fruits.Plasma.Power2.PlasmaArcSphere (a part
	with SphereA / SphereB shells and an Attachment holding Particles / Particles2).
	It is welded to the root and rises from the body to 10 studs above it in one second.
	Dark with armament haki, first fruit color otherwise.

	Every 0.25 s one to three sparks leave the sphere in random directions (10 to 30
	studs). The arcs to the victims are the PlasmaCoilArc one-shot.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local drawBolt = require(script.Parent.Parent.OneShot.PlasmaBolt)

local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local DEFAULT_COLOR = Color3.fromRGB(221, 117, 255)
local RISE_HEIGHT = 10
local RISE_TIME = 1
local SPARK_INTERVAL = 0.25
local SPARK_LIFE = 0.7

local function noop() end

local function randomUnit(): Vector3
	local direction = Vector3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
	return if direction.Magnitude < 1 then Vector3.yAxis else direction.Unit
end

return function(character: Model, value: any): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	local template = EffectAssets.FindFruit("Plasma", "Power2", "PlasmaArcSphere")
	if not root or not root:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return noop
	end

	local primary = FruitColor.Parse(if type(value) == "string" then value else "")

	local sphere = template:Clone()
	local shells: { [BasePart]: Color3 } = {}
	local emitters: { [ParticleEmitter]: ColorSequence } = {}
	sphere.Anchored = false
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CanTouch = false
	sphere.Massless = true
	for _, descendant in sphere:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			shells[descendant] = descendant.Color
		elseif descendant:IsA("ParticleEmitter") then
			emitters[descendant] = descendant.Color
		end
	end

	local function currentColor(): Color3?
		if character:GetAttribute(HAKI_ATTRIBUTE) then
			return HAKI_COLOR
		end
		return primary
	end

	local function paint()
		local color = currentColor()
		for shell, authored in shells do
			shell.Color = color or authored
		end
		for emitter, authored in emitters do
			emitter.Color = if color then ColorSequence.new(color) else authored
		end
	end

	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = sphere
	weld.Parent = sphere

	paint()
	local hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)
	sphere.CFrame = root.CFrame
	sphere.Parent = root
	TweenService:Create(weld, TweenInfo.new(RISE_TIME), { C0 = CFrame.new(0, RISE_HEIGHT, 0) }):Play()

	local alive = true
	task.spawn(function()
		while alive do
			task.wait(SPARK_INTERVAL)
			if not alive then
				break
			end
			local from = sphere.Position
			for _ = 1, math.random(1, 3) do
				drawBolt(from, {
					Target = from + randomUnit() * math.random(10, 30),
					Color = currentColor() or DEFAULT_COLOR,
					Thickness = 0.5,
					Life = SPARK_LIFE,
					Shrink = SPARK_LIFE,
				})
			end
		end
	end)

	return function()
		alive = false
		hakiConnection:Disconnect()
		sphere:Destroy()
	end
end
