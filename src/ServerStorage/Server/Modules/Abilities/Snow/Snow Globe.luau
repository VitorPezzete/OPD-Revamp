--!strict
--[[
	Snow fruit - Snow Globe (toggle): a dome of snow around the spot where it was cast.

	The globe is the Snow user's territory: Snow Boulders grow while inside it and Snow
	Ring can be raised anywhere inside it. It ends when toggled again, when the caster
	walks out of it (checked every 0.5 s) or on interrupt. 5 s between two presses,
	raising or removing it (the legacy client lock). Stuns do not end it
	(KeepThroughStun): the legacy globe only went away on the toggle, on leaving it and
	on death.

	Radius = 250 * defense affinity * (sniper level / cap) + 0.25 studs. Yes, sniper level
	although the requirement is on defense: that is what the legacy formula used.

	The server owns the state: the replicated status "SnowGlobe" carries
	"<x>,<y>,<z>|<radius>|<colors>", read by the sibling abilities (SnowShared.GetGlobe)
	and drawn by Effects.Status.SnowGlobe, which also turns the map inside the dome to
	snow on every client (the legacy server recolored the parts themselves).

	The frozen sea. The legacy globe also carried a solid disc of snow of its own
	diameter, 2 studs thick, lying at the fixed height Y = 211: the sea surface. Inside
	the globe everyone walks on the sea. It is something characters stand on, so it is a
	real server part, like the Snow Ring wall: one anchored cylinder, removed with the
	globe.

	Not reproduced: the legacy server moved every map part inside the dome (and the
	disc) to a "Snow" collision group that only stopped colliding with itself, i.e. with
	the head and torso of a Snow Body and with a Snow Ring. Characters were still stopped
	by their root part, so nothing an honest player could see came out of it.

	Legacy problems fixed here:
	- The death / respawn cleanup was connected after a `while globe` loop, so it was
	  never connected; a second copy of the cleanup lived in a Script inside the globe.
	- "Is the caster still inside" used script-level state shared with every other power.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)
local SnowShared = require(script.Parent.SnowShared)

local STATUS = SnowShared.GlobeStatus

local RADIUS_PER_SCALE = 250
local RADIUS_PADDING = 0.25
local LEAVE_CHECK = 0.5
-- The legacy disc was centered on Y = 211, the sea surface.
local FLOOR_HEIGHT = WorldConfig.SeaLevel
local FLOOR_THICKNESS = 2
local DEFAULT_COLOR = Color3.fromRGB(248, 248, 248)

local SnowGlobe = Ability.extend()

SnowGlobe.Debounce = 5
SnowGlobe.KeepThroughStun = true

local function createFloor(center: Vector3, radius: number, color: Color3): BasePart
	local floor = Instance.new("Part")
	floor.Name = "SnowGlobeFloor"
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(FLOOR_THICKNESS, radius * 2, radius * 2)
	floor.CFrame = CFrame.new(center.X, FLOOR_HEIGHT, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	floor.Anchored = true
	floor.Material = Enum.Material.Plastic
	floor.Color = color
	floor.Parent = World.Abilities()
	return floor
end

function SnowGlobe:OnBegin()
	local entity = self.Entity

	if self.Active then
		self:OnInterrupt()
		return
	end

	local radius = RADIUS_PER_SCALE * self:GetAffinity("Defense") * self:GetLevelScale("Sniper") + RADIUS_PADDING
	local center = entity.Root.Position

	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	self.Floor = createFloor(center, radius, FruitColor.Parse(self:GetColorString()) or DEFAULT_COLOR)
	entity:SetStatus(
		STATUS,
		string.format("%.1f,%.1f,%.1f|%.2f|%s", center.X, center.Y, center.Z, radius, self:GetColorString()),
		nil,
		true
	)

	-- The legacy loop looked first and waited after.
	local function check()
		if self.Run ~= run or not self.Active then
			return
		end
		if (entity.Root.Position - center).Magnitude > radius then
			self:OnInterrupt()
			return
		end
		task.delay(LEAVE_CHECK, check)
	end
	check()
end

function SnowGlobe:OnInterrupt()
	self.Active = false
	self.Run = (self.Run or 0) + 1
	local floor: BasePart? = self.Floor
	if floor then
		floor:Destroy()
		self.Floor = nil
	end
	self.Entity:ClearStatus(STATUS)
end

return SnowGlobe
