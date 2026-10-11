--!strict
--[[
	Snow fruit - Snow Pellet: the burst. Sent by the server when the snowball touches a
	character or its 2 s of flight are up.

	origin: where it burst.
	params: { Id: string, Size: number (diameter the burst swells to: ten ball
	          diameters), Haki: boolean, Colors: string }

	The flying ball drawn by OneShot.SnowPellet ("SnowPellet_<Id>" in the effects folder)
	is moved to the burst point and swells while fading out over 0.5 s, then is removed
	1 s after the burst; if this client never drew it, a fresh copy of the ball template
	(Assets.Models.Fruits.Snow.Power3.Snow4) is used, or a plain ball without it. As in
	the legacy game the drawing is the same whatever the radius that was actually hit
	(ten diameters on a character, one when the time ran out).
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local SWELL_TIME = 0.5
local REMOVE_AFTER = 1
local DEFAULT_COLOR = Color3.fromRGB(248, 248, 248)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

local function createBall(haki: boolean, colors: any): BasePart
	local primary, secondary = FruitColor.Parse(if type(colors) == "string" then colors else "")

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

	local emitter = ball:FindFirstChild("SnowTrigger", true)
	if haki then
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
	return ball
end

return function(origin: Vector3, params: { [string]: any }?)
	local size = params and params.Size
	if not params or type(size) ~= "number" or size <= 0 then
		return
	end

	local ball: BasePart
	local existing = World.Effects():FindFirstChild(`SnowPellet_{tostring(params.Id)}`)
	if existing and existing:IsA("BasePart") then
		ball = existing
	else
		local created = createBall(params.Haki == true, params.Colors)
		created.Size = Vector3.new(size / 10, size / 10, size / 10)
		created.Anchored = true
		created.CanCollide = false
		created.CanQuery = false
		created.CanTouch = false
		created.Parent = World.Effects()
		ball = created
	end

	-- Renaming it also stops the flight loop of OneShot.SnowPellet.
	ball.Name = "SnowPelletBurst"
	ball.CFrame = CFrame.new(origin)

	TweenService:Create(ball, TweenInfo.new(SWELL_TIME), {
		Size = Vector3.new(size, size, size),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, REMOVE_AFTER)
end
