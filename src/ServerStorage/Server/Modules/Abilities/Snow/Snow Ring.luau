--!strict
--[[
	Snow fruit - Snow Ring (hold to aim, release to raise): a tall hollow ring of snow.

	With size = 60 * defense affinity * (defense level / cap), read when the key goes down:
	- The ring is `size` tall and `size / 2` wide. Released while aiming inside the
	  caster's Snow Globe it rises at the aim point (center 3 studs above it); otherwise
	  it rises around the caster.
	- It starts with only its top 1.5 studs out of the ground and rises to its place
	  during 1 s (plus or minus 0.15 studs, the legacy random offset), then stands until
	  10 s after the release.
	- One ring per user. Pressing the key again while one stands takes that ring back:
	  it disappears from where it stood and becomes the one being aimed.

	The snow zone. Every 0.5 s everyone inside the ring's cylinder (radius size / 4
	around its axis, half length size / 2 along it, no further than size / 2 from its
	center) gets SnowTouched: 500 every 0.5 s, 10 times (flat numbers). The legacy zone
	was a Script inside the ring part, and it ran from the moment the part existed: the
	key press. While the key is held the (then invisible) ring lies where the caster
	stood when pressing, on its side, its axis along the caster's left-right, and it
	already snows everyone inside; that is reproduced. After the release the zone is the
	standing ring, following it as it rises.

	The ring is a wall other players collide with, so it is a real server part: one
	anchored clone of Assets.Models.Fruits.Snow.Power6.SnowRing (a union: its hollow
	shape cannot be built from plain parts), destroyed after 10 s and in OnInterrupt. Its
	rise is a server tween, because the wall has to be where everyone collides with it.
	Without the template there is no wall, only the snow zone. While the key is held the
	owner's client shows a preview (Effects.Status.SnowRingAiming).

	No cooldown (the legacy one was commented out), and stuns neither cancel the aim nor
	remove a standing ring (KeepThroughStun).

	Not reproduced: the legacy "Snow" / "Haki" collision groups of the ring. "Snow" only
	stopped colliding with itself (the head and torso of a Snow Body, whose root part
	was stopped anyway); what "Haki" collided with is not in the dump.

	Legacy problems fixed here:
	- The release position came straight from the client, any distance away.
	- The 10 s removal compared CFrames to guess whether the ring had been re-aimed.
	- The zone was a Script inside the part scanning every part in range.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local SnowShared = require(script.Parent.SnowShared)
local World = require(ReplicatedStorage.Shared.Util.World)

type CharacterEntity = CharacterEntity.CharacterEntity

local AIM_STATUS = "SnowRingAiming"

local SIZE = 60
local DURATION = 10
local ZONE_TICK = 0.5
local DOT_DAMAGE = 500
local DOT_HITS = 10
local RISE_ABOVE_AIM = 3
local RISE_TIME = 1
-- Legacy: math.random(-15, 15) / 100 studs added to the rise.
local RISE_JITTER = 15
-- How much of the ring shows before it rises.
local BURIED_TOP = 1.5
local DEFAULT_COLOR = Color3.fromRGB(248, 248, 248)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
-- The union's long axis is X; this stands it upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local SnowRing = Ability.extend()

SnowRing.Debounce = 0
SnowRing.KeepThroughStun = true

local function getSize(self: any): number
	return SIZE * self:GetAffinity("Defense") * self:GetLevelScale("Defense")
end

local function createWall(): BasePart?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", "Snow", "Power6", "SnowRing" } do
		current = current and current:FindFirstChild(name)
	end
	if not current or not current:IsA("BasePart") then
		return nil
	end

	local wall = current:Clone()
	-- The template still carries the legacy zone Script.
	for _, descendant in wall:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	wall.Name = "SnowRing"
	wall.Anchored = true
	wall.CanTouch = false
	return wall
end

-- The legacy test, part by part: the ring's axis is its X.
local function isInside(cframe: CFrame, size: number, target: CharacterEntity): boolean
	local radius = size / 4
	local halfLength = size / 2
	for _, part in target.Model:GetChildren() do
		if part:IsA("BasePart") then
			local offset = cframe:PointToObjectSpace(part.Position)
			if
				math.abs(offset.X) <= halfLength + part.Size.X / 2
				and math.sqrt(offset.Y * offset.Y + offset.Z * offset.Z) <= radius
			then
				return true
			end
		end
	end
	return false
end

local function zone(self: any, run: number)
	if self.ZoneRun ~= run then
		return
	end

	local wall: BasePart? = self.Wall
	local cframe: CFrame = if wall and wall.Parent then wall.CFrame else self.ZoneCFrame
	local size: number = self.Size
	for _, target in Hitbox.Sphere(cframe.Position, size / 2, self.Entity) do
		if isInside(cframe, size, target) then
			SnowShared.Touch(self, target, DOT_DAMAGE, DOT_HITS)
		end
	end
	task.delay(ZONE_TICK, zone, self, run)
end

local function stopRise(self: any)
	local tween: Tween? = self.Rise
	if tween then
		tween:Cancel()
		self.Rise = nil
	end
end

local function removeRing(self: any)
	self.RingRun = (self.RingRun or 0) + 1
	self.ZoneRun = (self.ZoneRun or 0) + 1
	self.ZoneActive = false
	stopRise(self)
	local wall: BasePart? = self.Wall
	if wall then
		wall:Destroy()
		self.Wall = nil
	end
end

function SnowRing:OnBegin()
	local entity = self.Entity

	local size = getSize(self)
	if size <= 0 then
		return
	end

	self.Aiming = true
	self.Size = size
	-- A ring still standing is no longer removed by its own 10 s: it is this one now.
	self.RingRun = (self.RingRun or 0) + 1

	local cframe = entity.Root.CFrame
	self.ZoneCFrame = cframe
	local wall: BasePart? = self.Wall
	if wall then
		stopRise(self)
		wall.Transparency = 1
		wall.CanCollide = false
		wall.Size = Vector3.new(size, size / 2, size / 2)
		wall.CFrame = cframe
	end

	if not self.ZoneActive then
		self.ZoneActive = true
		self.ZoneRun = (self.ZoneRun or 0) + 1
		task.delay(ZONE_TICK, zone, self, self.ZoneRun)
	end

	entity:SetStatus(AIM_STATUS, string.format("%.2f|%s", size, self:GetColorString()), nil, true)
end

function SnowRing:OnEnd(input: Ability.AbilityInput)
	if not self.Aiming then
		return
	end
	self.Aiming = false

	local entity = self.Entity
	entity:ClearStatus(AIM_STATUS)

	local size: number = self.Size
	local center = entity.Root.Position
	local globeCenter, globeRadius = SnowShared.GetGlobe(entity)
	if globeCenter and globeRadius and (input.AimPosition - globeCenter).Magnitude <= globeRadius then
		center = input.AimPosition + Vector3.new(0, RISE_ABOVE_AIM, 0)
	end
	local start = CFrame.new(center - Vector3.new(0, RISE_ABOVE_AIM + size / 2 - BURIED_TOP, 0)) * UPRIGHT
	local jitter = math.random(-RISE_JITTER, RISE_JITTER) / 100
	local standing = CFrame.new(center + Vector3.new(0, jitter, 0)) * UPRIGHT

	local color = FruitColor.Parse(self:GetColorString()) or DEFAULT_COLOR
	if self.Services.Haki:IsArmamentActive(entity) then
		color = HAKI_COLOR
	end

	local wall: BasePart? = self.Wall or createWall()
	self.Wall = wall
	self.ZoneCFrame = standing
	if wall then
		wall.Color = color
		wall.Transparency = 0
		wall.CanCollide = true
		wall.Size = Vector3.new(size, size / 2, size / 2)
		wall.CFrame = start
		wall.Parent = World.Abilities()
		local rise = TweenService:Create(wall, TweenInfo.new(RISE_TIME), { CFrame = standing })
		self.Rise = rise
		rise:Play()
	end

	self.RingRun = (self.RingRun or 0) + 1
	local run = self.RingRun
	task.delay(DURATION, function()
		if self.RingRun == run then
			removeRing(self)
		end
	end)
end

function SnowRing:OnInterrupt()
	self.Aiming = false
	self.Entity:ClearStatus(AIM_STATUS)
	removeRing(self)
end

return SnowRing
