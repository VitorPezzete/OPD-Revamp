--!strict
--[[
	Paw fruit - Pad Cannon: one paw of the salvo and its impact. Cosmetic copy of a
	server-simulated projectile, which goes through walls and ends on the first character
	or after 5 s; the server says where.

	params, Phase = "Fly" (origin = where the paw starts):
		{ Id, Direction: Vector3, Speed, Range, Factor, Haki: boolean, Colors, Caster }
	  A paw of 6 f x 6 f x 4 f studs, neon, 0.75 transparency, flying straight. Where it
	  starts, facing the same way: one particle of Power2.Shockwave sized 1 f -> 15 f, and
	  the "Release #2" sound (cut after 0.5 s, as in the source).
	params, Phase = "Impact" (origin = where it ended):
		{ Id, Factor, Haki, Colors }
	  The paw goes; one particle of PadCannonImpact "Collision #1" and the "Collision" sound.

	Colors: dark with haki; otherwise the first fruit color for the paw and its ring, the
	second for the impact; what the assets carry when the fruit has none.
]]
local TweenService = game:GetService("TweenService")

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local PawFx = require(script.Parent.Parent.Util.PawFx)

local TRANSPARENCY = 0.75
-- (2 * 3) f wide: PawFx.Size takes the multiple of (2, 2, 1.333).
local PAW_SCALE = 3
local RING_START = 1
local RING_END = 15
local RING_SECONDS = 1
local RELEASE_SOUND_SECONDS = 0.5
local IMPACT_SECONDS = 1
-- A paw whose impact never arrives goes this long after the end of its flight.
local FLIGHT_GRACE = 0.25

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
	local factor: number = if type(params.Factor) == "number" then math.max(params.Factor, 0.01) else 1
	local primary = colors(params)
	local unit = direction.Unit
	local startCFrame = PawFx.Facing(origin, unit)

	local anchor = PawFx.Anchor(startCFrame, RING_SECONDS)
	local template = EffectAssets.FindFruit("Paw", "Power2", "Shockwave")
	if template and template:IsA("ParticleEmitter") then
		local ring = template:Clone()
		ring.Size = NumberSequence.new(RING_START * factor, RING_END * factor)
		if primary then
			ring.Color = ColorSequence.new(primary)
		end
		ring.Parent = anchor
		ring:Emit(1)
	end
	PawFx.SoundAt("Release2", origin, RELEASE_SOUND_SECONDS)

	local paw = PawFx.NewPaw(PawFx.Size(PAW_SCALE * factor), primary, TRANSPARENCY)
	if not paw then
		return
	end
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

local function impact(position: Vector3, params: { [string]: any })
	PawFx.EndFlight(params.Id)

	local _, secondary = colors(params)
	PawFx.SoundAt("Collision", position, IMPACT_SECONDS)
	local collision = PawFx.Emitter("PadCannonImpact", "Collision #1", secondary)
	if collision then
		collision.Parent = PawFx.Anchor(CFrame.new(position), IMPACT_SECONDS)
		collision:Emit(1)
	end
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	if params.Phase == "Impact" then
		impact(origin, params)
	else
		fly(origin, params)
	end
end
