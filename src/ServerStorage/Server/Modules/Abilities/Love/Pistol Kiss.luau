--!strict
--[[
	Love fruit - Pistol Kiss (hold): a burst of instant kisses fired at the mouse.

	With s = sniper affinity * (sniper level / cap):
	- One shot every 0.2 s while the key is held, at most
	  ceil(10 * (sniper level / cap) * sniper affinity of the SECOND fruit slot) shots
	  per burst, whichever slot holds Love (the legacy client compared an Instance with
	  a string there and always took the second slot); 5 s cooldown from the end of the
	  burst.
	- Each shot is a ray from the right hand towards the aim point, up to 200 * affinity
	  studs. Where it stops, everyone inside a cube of 10 * s studs is petrified for
	  10 * s seconds (see _Shared). No damage.

	The first shot uses the aim of the key press. The following ones are requested by the
	owner's client (Effects.Status.LovePistol sends the mouse position as the ability's
	secondary input, phase 3); the pacing, the shot count and the ray are decided here.

	Legacy problems fixed here:
	- The shot count was computed on the client.
	- The server accepted any number of "StopCharging" requests: the 0.25 s debounce was
	  only applied to a branch that never ran, so an exploiter could petrify at will.
	- The ray was walked in 2 stud steps and the hit box came from GetPartBoundsInBox
	  over the whole map.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Love = require(script.Parent._Shared)

local STATUS = "LovePistol"
local EFFECT = "LovePistol"

local SHOT_INTERVAL = 0.2
-- Tolerance for network jitter between two client requests.
local SHOT_SLACK = 0.04
local MAX_SHOTS = 10
local COOLDOWN = 5
local RANGE = 200
local AREA_SIZE = 10
local STUN_TIME = 10

local PistolKiss = Ability.extend()

local function finish(self: any)
	if self.Active then
		self.LastEnd = os.clock()
		self:StartCooldown(COOLDOWN)
	end
	self:OnInterrupt()
end

local function shoot(self: any, aim: Vector3)
	local entity = self.Entity
	local affinity: number = self:GetAffinity("Sniper")
	local scale = affinity * self:GetLevelScale("Sniper")

	local root = entity.Root
	local arm = entity.Model:FindFirstChild("Right Arm")
	local origin = (if arm and arm:IsA("BasePart") then arm.Position else root.Position) + root.CFrame.LookVector
	local direction = aim - origin
	direction = if direction.Magnitude > 0.05 then direction.Unit else root.CFrame.LookVector

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	local reach = RANGE * affinity
	local result = Workspace:Raycast(origin, direction * reach, params)
	local hitPosition = if result then result.Position else origin + direction * reach

	local size = AREA_SIZE * scale
	for _, target in Hitbox.Box(CFrame.new(hitPosition), Vector3.new(size, size, size), entity) do
		Love.Stun(self, target, STUN_TIME * scale)
	end

	self:PlayEffect(EFFECT, origin, { Target = hitPosition, Scale = affinity })

	self.LastShot = os.clock()
	self.Shots += 1
	if self.Shots >= self.MaxShots then
		finish(self)
	end
end

function PistolKiss:CanBegin(): boolean
	return not self.Active and os.clock() - (self.LastEnd or -COOLDOWN) >= COOLDOWN
end

function PistolKiss:OnBegin(input)
	local context = self.Context
	local burstAffinity: number = context.Data.Data.Affinities.DF2.Sniper

	self.Active = true
	self.Shots = 0
	self.MaxShots = math.max(1, math.ceil(MAX_SHOTS * self:GetLevelScale("Sniper") * burstAffinity))

	self.Run = (self.Run or 0) + 1
	local run = self.Run

	-- "<fruit slot>|<ability slot>|<interval>": how the owner's client asks for the next shots.
	self.Entity:SetStatus(STATUS, `{context.FruitSlot}|{context.Definition.Slot}|{SHOT_INTERVAL}`, nil, true)

	-- A client that stops asking without releasing the key must not keep the burst open.
	task.delay(self.MaxShots * SHOT_INTERVAL + 2, function()
		if self.Run == run and self.Active then
			finish(self)
		end
	end)

	shoot(self, input.AimPosition)
end

function PistolKiss:OnAction(input)
	if os.clock() - (self.LastShot or 0) < SHOT_INTERVAL - SHOT_SLACK then
		return
	end
	shoot(self, input.AimPosition)
end

function PistolKiss:OnEnd()
	if self.Active then
		finish(self)
	end
end

function PistolKiss:OnInterrupt()
	self.Active = false
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return PistolKiss
