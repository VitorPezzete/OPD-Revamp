--!strict
--[[
	Sand fruit - Sand Spike: a spike of sand bursts out of the ground at the aim point.

	With k = sniper affinity * (sniper level / cap):
	- the aim point must be within 150 studs of the caster (further presses do nothing
	  and do not use the 0.25 s debounce);
	- the spike is the SandSpike model scaled by k, centred on the aim point and tilted
	  by up to 35 degrees on two axes (rolled here so server and clients agree);
	- everyone it touches during its first second takes 600 * k, Special, once, not
	  dodgeable; armament haki at cast time doubles it and makes it Haki;
	- the spike itself stays for 6 seconds: after the first one it only stands in the
	  way (the clients make it solid, as the legacy part was).

	Legacy problems fixed here:
	- The spike was a server part with a Touched connection; it only "touched" parts
	  that moved into it. The hit is a box query now, sampled every 0.1 s of that second.
	- The affinity, the animation index and the animation track were script-level
	  variables shared between presses.
	- The haki state was read again on every touch; it is fixed at cast time.

	The server reads the template size from the asset in ReplicatedStorage to size its
	box; FALLBACK_SIZE is that size, for a place without the asset.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Shared = require(script.Parent._Shared)

local EFFECT = "SandSpike"
local DAMAGE_TAG = "SandSpike"

local MAX_RANGE = 150
local DAMAGE = 600
local HAKI_MULTIPLIER = 2
local MAX_TILT_DEGREES = 35
local FALLBACK_SIZE = Vector3.new(49, 140, 49)

-- The spike grows in 0.1 s and hurts until it is 1 s old.
local GROW_TIME = 0.1
local SAMPLE_INTERVAL = 0.1
local SAMPLES = 10
local ANIMATIONS = 4

type Spike = {
	CFrame: CFrame,
	Size: Vector3,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	Hit: { [any]: boolean },
}

local SandSpike = Ability.extend()

local function sample(self: any, spike: Spike, epoch: number, remaining: number)
	if (self.Epoch or 0) ~= epoch or self.Entity.Dead then
		return
	end

	for _, target in Hitbox.Box(spike.CFrame, spike.Size, self.Entity) do
		if not spike.Hit[target] then
			spike.Hit[target] = true
			self:Damage(target, spike.Damage, spike.Trait, DAMAGE_TAG, false)
		end
	end

	if remaining > 1 then
		task.delay(SAMPLE_INTERVAL, sample, self, spike, epoch, remaining - 1)
	end
end

function SandSpike:CanBegin(input: Ability.AbilityInput): boolean
	return (input.AimPosition - self.Entity.Root.Position).Magnitude <= MAX_RANGE
end

function SandSpike:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity

	local scale = self:GetAffinity("Sniper") * self:GetLevelScale("Sniper")
	local haki = self.Services.Haki:IsArmamentActive(entity)

	local tiltX = math.rad(math.random(-MAX_TILT_DEGREES, MAX_TILT_DEGREES))
	local tiltZ = math.rad(math.random(-MAX_TILT_DEGREES, MAX_TILT_DEGREES))
	local spike: Spike = {
		CFrame = CFrame.new(input.AimPosition) * CFrame.Angles(tiltX, 0, tiltZ),
		Size = Shared.TemplateSize(FALLBACK_SIZE, "Power2", "SandSpike") * scale,
		Damage = DAMAGE * scale * (if haki then HAKI_MULTIPLIER else 1),
		Trait = if haki then "Haki" else "Special",
		Hit = {},
	}

	-- The casting animation cycles through the four legacy clips.
	self.Animation = ((self.Animation or 0) % ANIMATIONS) + 1

	self:PlayEffect(EFFECT, input.AimPosition, {
		CFrame = spike.CFrame,
		Scale = scale,
		Haki = haki,
		Animation = self.Animation,
	})

	task.delay(GROW_TIME, sample, self, spike, self.Epoch or 0, SAMPLES)
end

function SandSpike:OnInterrupt()
	-- Spikes still inside their damaging second stop hurting.
	self.Epoch = (self.Epoch or 0) + 1
end

return SandSpike
