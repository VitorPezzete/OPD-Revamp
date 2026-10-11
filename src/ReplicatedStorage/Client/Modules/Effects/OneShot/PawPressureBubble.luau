--!strict
--[[
	Paw fruit - Pressure Bubble: the thrown paw and its burst. Cosmetic copies of a
	server-simulated projectile; the server says where it stopped.

	params, Phase = "Fly" (origin = where the server's paw starts):
		{ Id, Direction: Vector3, Speed, Range, Base (uncharged factor), Factor (charged),
		  Haki: boolean, Colors, Caster }
	  The paw that was in the hand flies: 2 b x 2 b x 1.333 b, neon, 0.75 transparency,
	  from the end of the caster's right arm, trailing the PressureBubble Shockwave emitter.
	  A second Shockwave (size 1 -> 25, opaque) is emitted once 10 studs ahead, and
	  "Release #1" plays where it left. The caster's own client plays BeamReleaseRight at
	  30 times its speed, as the source did.
	params, Phase = "Burst" (origin = where it stopped):
		{ Id, Direction, Factor, Haki, Colors }
	  The flying paw is replaced by one of 2 f x 2 f x 1.333 f that grows 50 times in 0.5 s
	  while turning half a turn, then fades in 1 s. 0.125 s in: Shockwave (0 -> 85 f) and
	  Shockwave2 (85 f), two particles each; 0.125 s later WhiteStars and Specks, sized and
	  sped by f. "Explosion" plays there.

	Colors: dark with haki; otherwise the first fruit color for the paws and the second
	for the particles, or what the assets carry when the fruit has none.
]]
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local PawFx = require(script.Parent.Parent.Util.PawFx)

local BUBBLE = "PressureBubble"
local EXPLOSION = "PressureBubbleExplosion"
local TRANSPARENCY = 0.75
local HAND_OFFSET = CFrame.new(0, -2, 0) * CFrame.Angles(math.rad(-90), 0, 0)
local RELEASE_ANIMATION_SPEED = 30
local RELEASE_RING_AHEAD = 10
-- A paw whose burst never arrives (the client was out of its range) goes this long after
-- the end of its flight.
local FLIGHT_GRACE = 0.5

local GROW_TIME = 0.5
local GROW_FACTOR = 50
local FADE_TIME = 1
local RING_DELAY = 0.125
local STARS_DELAY = 0.125
local RING_SIZE = 85
local BURST_LIFETIME = 7.5
local EXPLOSION_SOUND_SECONDS = 9

local function colors(params: { [string]: any }): (Color3?, Color3?)
	if params.Haki == true then
		return PawFx.HAKI_COLOR, PawFx.HAKI_COLOR
	end
	return PawFx.Colors(params.Colors)
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
	local base: number = if type(params.Base) == "number" then math.max(params.Base, 0.01) else 1
	local pawColor, particleColor = colors(params)
	local unit = direction.Unit

	-- From the hand that held it, when the caster is here to be seen.
	local start = origin
	local caster = params.Caster
	if typeof(caster) == "Instance" then
		local arm = caster:FindFirstChild("Right Arm")
		if arm and arm:IsA("BasePart") then
			start = (arm.CFrame * HAND_OFFSET).Position
		end
		if PawFx.IsLocalCharacter(caster) then
			PawFx.PlayRelease(caster :: Model, PawFx.Anims.BeamReleaseRight, RELEASE_ANIMATION_SPEED)
		end
	end

	PawFx.SoundAt("Release1", start, 1)

	local ahead = PawFx.Anchor(PawFx.Facing(start, unit) * CFrame.new(0, 0, -RELEASE_RING_AHEAD), 1)
	local ring = PawFx.Emitter(BUBBLE, "Shockwave", particleColor)
	if ring then
		ring.Enabled = false
		ring.Size = NumberSequence.new(1, 25)
		ring.Transparency = NumberSequence.new(0, 0)
		ring.Parent = ahead
		ring:Emit(1)
	end

	local paw = PawFx.NewPaw(PawFx.Size(base), pawColor, TRANSPARENCY)
	if not paw then
		return
	end
	local trail = PawFx.Emitter(BUBBLE, "Shockwave", particleColor)
	if trail then
		local attachment = Instance.new("Attachment")
		attachment.Parent = paw
		trail.Parent = attachment
	end

	local startCFrame = PawFx.Facing(start, unit)
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

	local factor: number = if type(params.Factor) == "number" then math.max(params.Factor, 0.01) else 1
	local direction: Vector3 = if typeof(params.Direction) == "Vector3" then params.Direction else Vector3.zAxis
	local pawColor, particleColor = colors(params)
	local pawCFrame = PawFx.Facing(position, direction)

	PawFx.SoundAt("Explosion", position, EXPLOSION_SOUND_SECONDS)
	local attachment = PawFx.Anchor(CFrame.new(position), BURST_LIFETIME)

	local paw = PawFx.NewPaw(PawFx.Size(factor), pawColor, TRANSPARENCY)
	if paw then
		paw.CFrame = pawCFrame
		paw.Parent = PawFx.Parent()
		Debris:AddItem(paw, BURST_LIFETIME)

		local grow = TweenService:Create(paw, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Quad), {
			Size = paw.Size * GROW_FACTOR,
			CFrame = pawCFrame * CFrame.Angles(0, math.pi, 0),
		})
		grow:Play()
		task.delay(GROW_TIME, function()
			if paw.Parent then
				TweenService:Create(paw, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
			end
		end)
	end

	task.wait(RING_DELAY)
	local shockwave = PawFx.Emitter(EXPLOSION, "Shockwave", particleColor)
	if shockwave then
		shockwave.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0, 0),
			NumberSequenceKeypoint.new(1, RING_SIZE * factor, 0),
		})
		shockwave.Parent = attachment
		shockwave:Emit(2)
	end
	local shockwave2 = PawFx.Emitter(EXPLOSION, "Shockwave2", particleColor)
	if shockwave2 then
		shockwave2.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, RING_SIZE * factor, 0),
			NumberSequenceKeypoint.new(1, RING_SIZE * factor, 0),
		})
		shockwave2.Parent = attachment
		shockwave2:Emit(2)
	end

	task.wait(STARS_DELAY)
	if not paw or not paw.Parent then
		return
	end
	local stars = PawFx.Emitter(EXPLOSION, "WhiteStars", particleColor)
	if stars then
		stars.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0, 0),
			NumberSequenceKeypoint.new(0.5, 15 * factor, 0),
			NumberSequenceKeypoint.new(1, 0, 0),
		})
		stars.Speed = NumberRange.new(250 * factor)
		stars.Drag = 50 * factor
		stars.Parent = paw
		stars:Emit(math.clamp(25 * factor, 5, 25))
	end
	local specks = PawFx.Emitter(EXPLOSION, "Specks", particleColor)
	if specks then
		specks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0, 0),
			NumberSequenceKeypoint.new(0.401, 5.69 * factor, 0.688),
			NumberSequenceKeypoint.new(0.67, 2.56 * factor, 0.0555),
			NumberSequenceKeypoint.new(1, 0, 0),
		})
		specks.Speed = NumberRange.new(30 * factor)
		specks.Drag = 2 * factor
		specks.Parent = paw
		specks:Emit(math.clamp(15 * factor, 3, 15))
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
