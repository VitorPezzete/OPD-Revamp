--!strict
--[[
	String fruit - Bird Cage (charged, three presses): a spherical cage of strings.

	1. Hold and release: the cage appears around the point where the charge started (the
	   hand that wove it; hands alternate, right first). While the key is held a pole of
	   string grows up and down from that point, 1000 * defense affinity *
	   (defense level / cap) studs long after the full 20 s; it stays as the cage's axis.
	   Charge: 25 per second held, 4 to 500 (20 s for a full charge).
	   Radius: 512 * defense affinity * (defense level / cap) * charge / 500 studs.
	2. Press and release again: the cage shrinks, its radius losing 3.33 studs per
	   second (the legacy tween: diameter / 6.67 seconds down to a 2 stud ball),
	   dragging everyone inside towards the centre.
	3. Press and release again: the cage is removed.
	Steps 2 and 3 happen on the RELEASE of the key, as in legacy (the server acted on the
	"StopCharging" message of every press).

	The cage stands until its third step or its user's death: a stun or a seal does not
	remove it (it was a server model nothing else touched), and nothing limits how long
	it lasts - the largest one takes more than five minutes just to shrink.

	While the cage stands:
	- every other character inside carries the replicated "StringInsideCage" status
	  (refreshed every tick, 1 s long). Its owner-side effect keeps the character inside
	  the sphere, and it is the flag other systems read (the legacy Shave refused to
	  work with InsideCage set);
	- whoever touches the strings (within 3 studs of the shell, from either side) takes
	  100 * (defense level / cap) * affinity ^ affinity damage every 0.1 s, "Special",
	  not dodgeable. Armament haki at the start of the charge doubles it and makes
	  it "Haki".

	The barrier that stops characters is the one server-created part of the fruit: an
	invisible, anchored clone of Assets.Models.Fruits.String.Power5.Cage.StringCageBarrier,
	resized on the tick. Its collision is left as authored. Everything visible is drawn
	by the clients: the growing pole from the "StringBirdCageCharging" status of the
	user (Effects.Status.StringBirdCageCharging), the cage and its axis from the
	"StringBirdCage" status (Effects.Status.StringBirdCage). The legacy pole was a solid
	server part; it is only drawn now.

	About `Charge = 9999999` in the legacy instance data: it is not a maximum. The
	server stored the charge start time in that NumberValue and overwrote it with
	9999999 after each release, so that a release without a press computed a negative
	hold and fell to the minimum charge. The value saved in the place is that same
	sentinel. The real limits are the 4 to 500 clamp above.

	Legacy problems fixed here:
	- The barrier's Touched event dealt the damage, with a 0.1 s per-character lock:
	  the real rate depended on physics noise. It is one hit per 0.1 s tick, the rate
	  of that lock, for as long as the character is at the strings.
	- A `while cage exists` loop walked every player twice a second, and the cage
	  state (charging, shrinking, haki) lived in script-level variables. The inside
	  flag is still refreshed twice a second.
	- Only players were flagged as inside; NPCs are flagged too.
]]
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local World = require(ReplicatedStorage.Shared.Util.World)

type Cage = {
	Center: Vector3,
	Radius: number,
	-- Workspace:GetServerTimeNow() when the shrink started, 0 while it stands still.
	ShrinkStart: number,
	Created: number,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	Haki: boolean,
	-- Geometry fields shared by both replicated statuses.
	Packed: string,
	-- "<length>|<thickness>|<width>" of the axis pole when the charge was released.
	Pole: string,
	Part: BasePart?,
	-- Ticks left before the inside flags are refreshed.
	InsideIn: number,
}

local STATUS = "StringBirdCage"
local CHARGE_STATUS = "StringBirdCageCharging"
local INSIDE_STATUS = "StringInsideCage"
local DAMAGE_TAG = "BirdCage"
local HAKI_STATUS = "Haki"
local STUN_STATUS = "Stunned"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 500
local MAX_RADIUS = 512
local MIN_RADIUS = 1
local SHRINK_RATE = 10 / 3
local BASE_DAMAGE = 100
local HAKI_MULTIPLIER = 2
local SHELL_THICKNESS = 3
local TICK = 0.1
local INSIDE_TICKS = 5
local INSIDE_SECONDS = 1
local FRUIT_NAME = "String"
-- The pole woven while charging grows from START to FULL over the full charge.
local POLE_START = Vector3.new(0.1, 2, 3)
local POLE_FULL_LENGTH = 1000
local POLE_FULL_THICKNESS = 2.5
local POLE_FULL_WIDTH = 5

local BirdCage = Ability.extend()

-- The cage stood through stuns in the legacy game; death, seals and fruit loss remove it.
BirdCage.KeepThroughStun = true

local function getRadius(cage: Cage): number
	if cage.ShrinkStart <= 0 then
		return cage.Radius
	end
	return math.max(MIN_RADIUS, cage.Radius - SHRINK_RATE * (Workspace:GetServerTimeNow() - cage.ShrinkStart))
end

local function pack(cage: Cage): string
	local center = cage.Center
	return string.format(
		"%.1f|%.1f|%.1f|%.1f|%.2f|%.3f",
		center.X,
		center.Y,
		center.Z,
		cage.Radius,
		cage.ShrinkStart,
		SHRINK_RATE
	)
end

local function createBarrier(center: Vector3, radius: number): BasePart?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", "String", "Power5", "Cage", "StringCageBarrier" } do
		current = current and current:FindFirstChild(name)
	end
	if not current or not current:IsA("BasePart") then
		return nil
	end

	local part = current:Clone()
	for _, descendant in part:GetDescendants() do
		if not descendant:IsA("DataModelMesh") then
			descendant:Destroy()
		end
	end
	part.Name = "StringCageBarrier"
	part.Anchored = true
	part.Transparency = 1
	part.CastShadow = false
	-- Rays (aim, projectiles) and Touched listeners ignore it; only bodies collide.
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.one * (radius * 2)
	part.Position = center
	part.Parent = World.Abilities()
	return part
end

-- Each call is one gesture of the user: its client waves the next hand.
local function publish(self: any, cage: Cage)
	cage.Packed = pack(cage)
	local hand = if self.UseLeft then "Left" else "Right"
	self.UseLeft = not self.UseLeft
	-- "<x>|<y>|<z>|<radius>|<shrink start>|<shrink rate>|<haki 0/1>|<colors>|<hand>|<pole length>|<thickness>|<width>"
	self.Entity:SetStatus(
		STATUS,
		`{cage.Packed}|{if cage.Haki then 1 else 0}|{self:GetColorString()}|{hand}|{cage.Pole}`,
		nil,
		true
	)
end

local function removeCage(self: any)
	local cage: Cage? = self.Cage
	if not cage then
		return
	end
	self.Cage = nil
	local part = cage.Part
	if part then
		part:Destroy()
	end
	self.Entity:ClearStatus(STATUS)
end

local function startTick(self: any, cage: Cage)
	local entity = self.Entity

	local function tick()
		if self.Cage ~= cage then
			return
		end
		if entity.Dead or entity.Model.Parent == nil then
			removeCage(self)
			return
		end

		local radius = getRadius(cage)
		local part = cage.Part
		if part and cage.ShrinkStart > 0 then
			part.Size = Vector3.one * (radius * 2)
		end

		cage.InsideIn -= 1
		local flag = cage.InsideIn <= 0
		if flag then
			cage.InsideIn = INSIDE_TICKS
		end

		for _, target in Hitbox.Sphere(cage.Center, radius + SHELL_THICKNESS, entity) do
			local distance = (target.Root.Position - cage.Center).Magnitude
			if flag and distance <= radius then
				target:SetStatus(INSIDE_STATUS, cage.Packed, INSIDE_SECONDS, true)
			end
			if math.abs(distance - radius) <= SHELL_THICKNESS then
				self:Damage(target, cage.Damage, cage.Trait, DAMAGE_TAG, false)
			end
		end
		task.delay(TICK, tick)
	end
	task.delay(TICK, tick)
end

-- KeepThroughStun lets presses through; the legacy client sent nothing while stunned.
function BirdCage:CanBegin(): boolean
	return not self.Entity:HasStatus(STUN_STATUS)
end

function BirdCage:OnBegin()
	local entity = self.Entity
	if self.Cage then
		-- The step itself happens on the release (OnEnd).
		self.StepArmed = true
		return
	end
	if self.ChargeStart then
		return
	end

	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	-- The cage forms around the hand that started weaving it, wherever the user goes next.
	local hand = if self.UseLeft then "Left" else "Right"
	local arm = entity.Model:FindFirstChild(`{hand} Arm`)
	local center: Vector3 = if arm and arm:IsA("BasePart") then arm.Position else entity.Root.Position
	self.Center = center
	self.ChargeHaki = entity:HasStatus(HAKI_STATUS)

	-- "<x>|<y>|<z>|<full length>|<full thickness>|<haki 0/1>|<colors>|<hand>"
	local affinity: number = self:GetAffinity("Defense")
	entity:SetStatus(
		CHARGE_STATUS,
		string.format(
			"%.1f|%.1f|%.1f|%.1f|%.2f|%d|%s|%s",
			center.X,
			center.Y,
			center.Z,
			POLE_FULL_LENGTH * affinity * self:GetLevelScale("Defense"),
			POLE_FULL_THICKNESS * affinity,
			if self.ChargeHaki then 1 else 0,
			self:GetColorString(),
			hand
		),
		nil,
		true
	)
end

function BirdCage:OnEnd()
	local standing: Cage? = self.Cage
	if standing then
		if self.StepArmed then
			self.StepArmed = false
			if standing.ShrinkStart <= 0 then
				standing.ShrinkStart = Workspace:GetServerTimeNow()
				publish(self, standing)
			else
				removeCage(self)
			end
		end
		return
	end

	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end

	local entity = self.Entity
	entity:ClearStatus(CHARGE_STATUS)
	-- KeepThroughStun keeps the charge alive; a stunned user still cannot finish it.
	if self.Cage or entity:HasStatus(STUN_STATUS) then
		return
	end

	local affinity: number = self:GetAffinity("Defense")
	local levelScale: number = self:GetLevelScale("Defense")
	local radius = MAX_RADIUS * affinity * levelScale * charge / CHARGE_MAX
	if radius <= MIN_RADIUS then
		return
	end

	local haki: boolean = self.ChargeHaki == true
	local damage = BASE_DAMAGE * levelScale * affinity ^ affinity
	if haki then
		damage *= HAKI_MULTIPLIER
	end

	-- The pole stops growing where the charge was released.
	local pole = POLE_START:Lerp(
		Vector3.new(POLE_FULL_LENGTH * affinity * levelScale, POLE_FULL_THICKNESS * affinity, POLE_FULL_WIDTH),
		charge / CHARGE_MAX
	)

	local center: Vector3 = self.Center
	local cage: Cage = {
		Center = center,
		Radius = radius,
		ShrinkStart = 0,
		Created = os.clock(),
		Damage = damage,
		Trait = if haki then "Haki" else "Special",
		Haki = haki,
		Packed = "",
		Pole = string.format("%.1f|%.2f|%.2f", pole.X, pole.Y, pole.Z),
		Part = createBarrier(center, radius),
		InsideIn = 0,
	}
	self.Cage = cage
	publish(self, cage)
	startTick(self, cage)
end

function BirdCage:OnInterrupt()
	local entity = self.Entity
	self.ChargeStart = nil
	self.StepArmed = false
	entity:ClearStatus(CHARGE_STATUS)
	-- A seal only ends the charge: a standing cage stays (see the header).
	if
		not entity.Dead
		and entity.Model.Parent ~= nil
		and entity:HasStatus(AbilityConfig.Status.AbilitiesDisabled)
		and self.Services.Fruit:HasFruit(self.Player, FRUIT_NAME)
	then
		return
	end
	removeCage(self)
end

return BirdCage
