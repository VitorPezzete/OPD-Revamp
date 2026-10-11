--!strict
--[[
	Paw fruit - Ursus Shock: the giant paw once thrown, and its burst. Cosmetic copies of a
	server-simulated projectile; the server says where it stopped.

	params, Phase = "Fly" (origin = centre of the paw when it leaves):
		{ Id, Direction: Vector3, Speed, Range, Factor, Colors, Caster }
	  A paw of 75 f x 75 f x 50 f studs, neon, 0.75 transparency, flying straight. An
	  attachment one paw depth in front of it carries the AirResistance emitter (rate
	  12.5 f, size 0 -> 100 f, speed -150 f, first to second fruit color). "Release #1"
	  plays where it left. The caster's own client plays the SunPos2 clip.
	params, Phase = "Burst" (origin = where it stopped):
		{ Id, Direction, Factor, Colors }
	  A paw of 2 f x 2 f x 1.333 f swells to 150 f x 150 f x 200 f in 0.25 s (elastic)
	  while turning half a turn, shrinks back in 0.25 s, and is replaced by the Explosion
	  sphere (f -> 250 f studs in 0.45 s, then fading in 1 s, first color) and the Ring
	  (1.5 f x 0.15 f -> 375 f x 37.5 f in 0.45 s, fading, second color), with the
	  explosion sound.
	Meshes: Effects.UrsusShock.Meshes.Explosion / Ring.

	No haki tint: the source never darkened this power.
]]
local TweenService = game:GetService("TweenService")

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local PawFx = require(script.Parent.Parent.Util.PawFx)

local TRANSPARENCY = 0.75
local PAW_SCALE = 37.5
-- A paw whose burst never arrives goes this long after the end of its flight.
local FLIGHT_GRACE = 0.5
local RELEASE_ANIMATION_SPEED = 1

local SWELL_TIME = 0.25
local SWELL_SIZE = Vector3.new(150, 150, 133.333 * 1.5)
local BLAST_TIME = 0.45
local BLAST_FADE = 1
local SPHERE_SIZE = 250
local RING_START = Vector3.new(1.5, 0.15, 1.5)
local RING_END = Vector3.new(375, 37.5, 375)
local EXPLOSION_SOUND_SECONDS = 3

local function mesh(name: string, size: Vector3, cframe: CFrame, color: Color3?): BasePart?
	local template = EffectAssets.FindFruit("Paw", "Effects", "UrsusShock", "Meshes", name)
	if not template or not template:IsA("BasePart") then
		return nil
	end
	local part = template:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	if color then
		part.Color = color
	end
	part.Parent = PawFx.Parent()
	return part
end

local function fly(origin: Vector3, params: { [string]: any })
	local direction = params.Direction
	local speed, range = params.Speed, params.Range
	if typeof(direction) ~= "Vector3" or type(speed) ~= "number" or type(range) ~= "number" then
		return
	end
	if direction.Magnitude < 1e-3 or speed <= 0 or range <= 0 then
		return
	end
	local factor: number = if type(params.Factor) == "number" then math.max(params.Factor, 0.001) else 1
	local primary, secondary = PawFx.Colors(params.Colors)
	local unit = direction.Unit

	local caster = params.Caster
	if PawFx.IsLocalCharacter(caster) then
		PawFx.PlayRelease(caster :: Model, PawFx.Anims.SunPos2, RELEASE_ANIMATION_SPEED)
	end
	PawFx.SoundAt("Release1", origin, 1)

	local paw = PawFx.NewPaw(PawFx.Size(PAW_SCALE * factor), primary, TRANSPARENCY)
	if not paw then
		return
	end
	local front = Instance.new("Attachment")
	front.CFrame = CFrame.new(0, 0, -paw.Size.Z)
	front.Parent = paw
	local air = PawFx.Emitter("UrsusShock", "AirResistance")
	if air then
		air.Rate = 12.5 * factor
		air.Size = NumberSequence.new(0, 100 * factor)
		air.Speed = NumberRange.new(-150 * factor, -150 * factor)
		if primary and secondary then
			air.Color = ColorSequence.new(primary, secondary)
		end
		air.Parent = front
	end

	local startCFrame = PawFx.Facing(origin, unit)
	local duration = range / speed
	paw.CFrame = startCFrame
	paw.Parent = PawFx.Parent()
	local tween = TweenService:Create(paw, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = startCFrame + unit * range,
	})
	tween:Play()

	PawFx.TrackFlight(params.Id, duration + FLIGHT_GRACE, function()
		tween:Cancel()
		paw:Destroy()
	end)
end

local function burst(position: Vector3, params: { [string]: any })
	PawFx.EndFlight(params.Id)

	local factor: number = if type(params.Factor) == "number" then math.max(params.Factor, 0.001) else 1
	local direction: Vector3 = if typeof(params.Direction) == "Vector3" then params.Direction else Vector3.zAxis
	local primary, secondary = PawFx.Colors(params.Colors)
	local pawCFrame = PawFx.Facing(position, direction)

	local paw = PawFx.NewPaw(PawFx.Size(factor), primary, TRANSPARENCY)
	if paw then
		paw.CFrame = pawCFrame
		paw.Parent = PawFx.Parent()

		local elastic = TweenInfo.new(SWELL_TIME, Enum.EasingStyle.Elastic)
		TweenService:Create(paw, elastic, {
			Size = SWELL_SIZE * factor,
			CFrame = pawCFrame * CFrame.Angles(0, math.pi, 0),
		}):Play()
		task.wait(SWELL_TIME)
		-- Half a turn back: the paw ends as it started.
		TweenService:Create(paw, elastic, { Size = PawFx.Size(factor), CFrame = pawCFrame }):Play()
		task.wait(SWELL_TIME)
		paw:Destroy()
	else
		task.wait(SWELL_TIME * 2)
	end

	local sphere = mesh("Explosion", Vector3.one * factor, pawCFrame, primary)
	local ring = mesh("Ring", RING_START * factor, pawCFrame, secondary)
	PawFx.SoundAt("ExplosionSmall", position, EXPLOSION_SOUND_SECONDS)

	local quad = TweenInfo.new(BLAST_TIME, Enum.EasingStyle.Quad)
	if ring then
		TweenService:Create(ring, quad, {
			Size = RING_END * factor,
			CFrame = pawCFrame * CFrame.Angles(0, math.pi, 0),
			Transparency = 1,
		}):Play()
	end
	if sphere then
		TweenService:Create(sphere, quad, { Size = Vector3.one * (SPHERE_SIZE * factor) }):Play()
	end
	task.wait(BLAST_TIME)
	if sphere then
		TweenService:Create(sphere, TweenInfo.new(BLAST_FADE, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
	end
	task.wait(BLAST_FADE)
	if sphere then
		sphere:Destroy()
	end
	if ring then
		ring:Destroy()
	end
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	if params.Phase == "Burst" then
		burst(origin, params)
	else
		fly(origin, params)
	end
end
