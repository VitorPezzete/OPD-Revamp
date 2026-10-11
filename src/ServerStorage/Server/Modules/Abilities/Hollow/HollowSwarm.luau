--!strict
--[[
	Hollow fruit - base of the two "summon ghosts, then send them" abilities
	(Negative Hollow and Mini-Hollow). NOT an ability itself: `HollowSwarm.extend(config)`
	returns the ability class, and each ability file only supplies its numbers and what
	happens on contact / on arrival.

	First press - create: ghosts appear one by one (config.SpawnInterval), each where
	the caster is at that moment (or the projected ghost body while Projection is on),
	up to floor(config.AmountBase * (sniper level / cap) * sniper affinity). Each drifts
	to its own spot (a whole number of studs: +-HoverRadius on X and Z, HoverLow to
	HoverHigh up) and hovers there, facing the way the caster faced.
	Second press - send: the ghosts that exist fly at one target and config.OnArrive
	runs when they get within config.Reach studs of it. Ghosts with no target vanish.

	Server model: no ghost instance exists, only one record per ghost (where it
	appeared, where it hovers).
	- Hovering: one bounded tick (0.25 s, or the spawn interval while ghosts are still
	  appearing) adds the ghosts that are due and tests the characters nearby against
	  the path each ghost covered since the last tick: the drift is the legacy
	  BodyPosition (P 10000, D 2000), an exponential approach at 5 per second. A ghost
	  is touched like its legacy root part was; config.OnContact decides what happens.
	- Flying: the whole group is one point (the middle of the ghosts) homing on the
	  target ten times a second, for at most FLIGHT_LIFETIME seconds. All the legacy
	  ghosts of one send picked the same closest target anyway, unless they were spread
	  far apart. A character other than the target that the flying group runs into is
	  touched like by a hovering ghost (config.OnContact), one ghost per tick: the
	  legacy ghosts kept their Touched connections while they flew.

	As in the legacy game hovering ghosts stay until they are sent or used up (or the
	caster dies, is sealed or loses the fruit), and neither they nor the ghosts in flight
	are stopped by a stun of the caster; the key itself does nothing while stunned.
	Clients draw everything from the caster's attributes (Effects.Status.HollowHollows /
	HollowMinis, which hand the ghosts to Effects.OneShot.HollowSwarm for the flight):

	  <Status>       hovering: "<kind>|<seed>|<colors>"
	                 sent:     "<kind>|<seed>|<colors>|<speed>|<reach>|<x>|<y>|<z>"
	                 (the target's position; kept FLIGHT_NOTICE seconds, then removed)
	  <Status>State  one entry per ghost so far, ";"-separated: "x,y,z,yaw" where it
	                 appeared, "" for the same place as the last written one, "x" once
	                 it is used up.
	The spots come from Random.new(seed), three NextInteger per ghost in order (X, Y, Z),
	here and on the clients.

	Legacy problems fixed here:
	- "usinghollows" / "spawninghollows" were per-player tables but the animation track
	  and target variables were script globals shared by every ghost.
	- Every ghost was a Humanoid model with Touched connections on each part, a
	  BodyVelocity and a Heartbeat connection; a ghost whose target left never stopped.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local HollowNegative = require(script.Parent.HollowNegative)

type CharacterEntity = CharacterEntity.CharacterEntity

export type Flight = {
	Target: CharacterEntity,
	Speed: number,
	-- Free for the ability: read back in OnArrive.
	Power: number,
}

export type Config = {
	-- Replicated status on the caster while ghosts hover.
	Status: string,
	-- Which model the clients use: "Hollow" or "Mini".
	Kind: string,
	AmountBase: number,
	SpawnInterval: number,
	-- A ghost's spot relative to where it appeared, in whole studs.
	HoverRadius: number,
	HoverLow: number,
	HoverHigh: number,
	-- Radius of what a character has to walk into (the ghost's 2x2x1 root part, plus
	-- the arms and head of the big ones).
	TouchRadius: number,
	-- Seconds after a create / after a send before the next create.
	CreateCooldown: number,
	SendCooldown: number,
	-- true: the second press is a charge and the ghosts leave on release.
	Charged: boolean,
	Reach: number,
	-- A character touching a hovering ghost. Return true to use that ghost up; false
	-- leaves it and ends the character's test for this tick.
	OnContact: (self: any, target: CharacterEntity) -> boolean,
	-- Picks the target of a send. `charge` is nil for uncharged abilities.
	PickTarget: (self: any, origin: Vector3, aim: Vector3, charge: number?) -> Flight?,
	OnArrive: (self: any, flight: Flight, count: number) -> (),
}

type Ghost = {
	Origin: Vector3,
	Goal: Vector3,
	-- Degrees, the caster's facing when it appeared.
	Yaw: number,
	SpawnedAt: number,
	-- Where the last contact test left it.
	Last: Vector3,
	Gone: boolean,
}

local HOVER_TICK = 0.25
local DRIFT_RATE = 5
local FLIGHT_TICK = 0.1
local FLIGHT_LIFETIME = 20
-- How long the "sent" value stays on the caster for the clients to see.
local FLIGHT_NOTICE = 0.5

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 15

-- Same value as Hitbox: characters are spheres of this radius around their root.
local BODY_RADIUS = 2.5
-- Ghosts appearing closer than this to the last written place share its entry.
local SAME_PLACE = 0.5
local SAME_YAW = 10

local HollowSwarm = {}

HollowSwarm.ChargeMax = CHARGE_MAX

local function isGone(target: CharacterEntity): boolean
	return target.Dead or not target.Spawned or target.Model.Parent == nil
end

local function positionAt(ghost: Ghost, now: number): Vector3
	return ghost.Origin:Lerp(ghost.Goal, 1 - math.exp(-DRIFT_RATE * (now - ghost.SpawnedAt)))
end

local function distanceToSegment(point: Vector3, from: Vector3, to: Vector3): number
	local segment = to - from
	local lengthSquared = segment:Dot(segment)
	local along = if lengthSquared > 1e-4 then math.clamp((point - from):Dot(segment) / lengthSquared, 0, 1) else 0
	return (from + segment * along - point).Magnitude
end

function HollowSwarm.extend(config: Config): any
	local Swarm = Ability.extend()
	local stateStatus = config.Status .. "State"

	Swarm.KeepThroughStun = true

	function Swarm:CanBegin(): boolean
		return not self.Entity:HasStatus("Stunned")
	end

	-- Ghosts out right now: spawned so far, minus the ones used up by contact.
	function Swarm:Count(): number
		local count = 0
		if self.Hovering then
			for _, ghost: Ghost in self.Ghosts do
				if not ghost.Gone then
					count += 1
				end
			end
		end
		return count
	end

	function Swarm:Replicate()
		local entries: { string } = {}
		local written: Ghost? = nil
		for index, ghost: Ghost in self.Ghosts do
			if ghost.Gone then
				entries[index] = "x"
			elseif
				written
				and (ghost.Origin - written.Origin).Magnitude < SAME_PLACE
				and math.abs(ghost.Yaw - written.Yaw) < SAME_YAW
			then
				entries[index] = ""
			else
				written = ghost
				local origin = ghost.Origin
				entries[index] = string.format("%.1f,%.1f,%.1f,%d", origin.X, origin.Y, origin.Z, ghost.Yaw)
			end
		end
		-- A leading separator keeps the value from ever being an empty string.
		self.Entity:SetStatus(stateStatus, ";" .. table.concat(entries, ";"), nil, true)
	end

	-- Reports how long until a new batch can be created again, if that is still ahead.
	function Swarm:ReportCreateCooldown()
		local now = os.clock()
		local remaining = math.max(
			self.LastCreate + config.CreateCooldown - now,
			(self.LastSend or -math.huge) + config.SendCooldown - now
		)
		if remaining > 0 then
			self:StartCooldown(remaining)
		end
	end

	-- `keepStatus` leaves the main status for Send to turn into the flight notice.
	function Swarm:StopHover(keepStatus: boolean?)
		self.Hovering = false
		self.Active = false
		self.HoverRun = (self.HoverRun or 0) + 1
		self.Entity:ClearStatus(stateStatus)
		if not keepStatus then
			self.Entity:ClearStatus(config.Status)
		end
	end

	-- Adds the ghosts whose time has come. True if any appeared.
	function Swarm:SpawnDue(now: number): boolean
		local ghosts: { Ghost } = self.Ghosts
		local due = math.min(self.Amount, math.floor((now - self.CreatedAt) / config.SpawnInterval) + 1)
		if #ghosts >= due then
			return false
		end

		local entity = self.Entity
		local origin = HollowNegative.GetOrigin(entity)
		local _, yaw = entity.Root.CFrame:ToOrientation()
		local random: Random = self.Random
		while #ghosts < due do
			local x = random:NextInteger(-config.HoverRadius, config.HoverRadius)
			local y = random:NextInteger(config.HoverLow, config.HoverHigh)
			local z = random:NextInteger(-config.HoverRadius, config.HoverRadius)
			table.insert(ghosts, {
				Origin = origin,
				Goal = origin + Vector3.new(x, y, z),
				Yaw = math.round(math.deg(yaw)),
				SpawnedAt = now,
				Last = origin,
				Gone = false,
			})
		end
		return true
	end

	-- Tests the characters nearby against the path of every ghost since the last test.
	-- True if a ghost was used up.
	function Swarm:Touch(now: number): boolean
		local ghosts: { Ghost } = self.Ghosts
		local positions: { [number]: Vector3 } = {}
		local low: Vector3? = nil
		local high: Vector3? = nil
		for index, ghost in ghosts do
			if not ghost.Gone then
				local position = positionAt(ghost, now)
				positions[index] = position
				low = if low then low:Min(position, ghost.Last) else position:Min(ghost.Last)
				high = if high then high:Max(position, ghost.Last) else position:Max(ghost.Last)
			end
		end
		if not low or not high then
			return false
		end

		local reach = config.TouchRadius + BODY_RADIUS
		local consumed = false
		local center = (low + high) / 2
		for _, target in Hitbox.Sphere(center, (high - low).Magnitude / 2 + config.TouchRadius, self.Entity) do
			local point = target.Root.Position
			for index, position in positions do
				local ghost = ghosts[index]
				if target.Dead then
					break
				end
				if not ghost.Gone and distanceToSegment(point, ghost.Last, position) <= reach then
					if not config.OnContact(self, target) then
						break
					end
					ghost.Gone = true
					consumed = true
				end
			end
		end

		for index, position in positions do
			ghosts[index].Last = position
		end
		return consumed
	end

	function Swarm:Create(amount: number)
		local entity = self.Entity
		local seed = math.random(1, 2 ^ 31 - 1)

		self.Hovering = true
		self.Active = true
		self.Amount = amount
		self.Ghosts = {}
		self.Seed = seed
		self.Random = Random.new(seed)
		self.CreatedAt = os.clock()
		self.LastCreate = self.CreatedAt
		entity:SetStatus(config.Status, string.format("%s|%d|%s", config.Kind, seed, self:GetColorString()), nil, true)

		self.HoverRun = (self.HoverRun or 0) + 1
		local run = self.HoverRun
		local function tick()
			if self.HoverRun ~= run then
				return
			end
			local now = os.clock()
			local changed = self:SpawnDue(now)
			if self:Touch(now) then
				changed = true
			end
			-- An interrupt raised by a contact (the caster killed by a reflect) ends it.
			if self.HoverRun ~= run then
				return
			end

			local spawning = #self.Ghosts < self.Amount
			if not spawning and self:Count() <= 0 then
				-- Every ghost that was going to appear has been used up.
				self:StopHover()
				self:ReportCreateCooldown()
				return
			end
			if changed then
				self:Replicate()
			end
			task.delay(if spawning then math.min(HOVER_TICK, config.SpawnInterval) else HOVER_TICK, tick)
		end
		tick()
	end

	function Swarm:Send(aim: Vector3, charge: number?)
		local entity = self.Entity
		local now = os.clock()
		local count = 0
		local sum = Vector3.zero
		for _, ghost: Ghost in self.Ghosts do
			if not ghost.Gone then
				count += 1
				sum += positionAt(ghost, now)
			end
		end

		self:StopHover(true)
		self.LastSend = now
		self:ReportCreateCooldown()

		local origin = if count > 0 then sum / count else entity.Root.Position
		local flight: Flight? = if count > 0 then config.PickTarget(self, origin, aim, charge) else nil
		if not flight then
			entity:ClearStatus(config.Status)
			return
		end
		local target = flight.Target

		local goal = target.Root.Position
		entity:SetStatus(
			config.Status,
			string.format(
				"%s|%d|%s|%.2f|%.2f|%.1f|%.1f|%.1f",
				config.Kind,
				self.Seed,
				self:GetColorString(),
				flight.Speed,
				config.Reach,
				goal.X,
				goal.Y,
				goal.Z
			),
			FLIGHT_NOTICE,
			true
		)

		local epoch = self.Epoch or 0
		local position = origin
		local ticks = 0
		local lastTick = FLIGHT_LIFETIME / FLIGHT_TICK
		local function step()
			if (self.Epoch or 0) ~= epoch or ticks > lastTick or isGone(target) or entity.Dead then
				return
			end

			local offset = target.Root.Position - position
			local distance = offset.Magnitude
			if distance < config.Reach then
				config.OnArrive(self, flight, count)
				return
			end

			-- Whoever stands in the way is touched; a ghost used up does not arrive.
			for _, bystander in Hitbox.Sphere(position, config.TouchRadius, entity) do
				if bystander ~= target and config.OnContact(self, bystander) then
					count -= 1
					if count <= 0 then
						return
					end
				end
			end
			if (self.Epoch or 0) ~= epoch then
				return
			end

			position += offset.Unit * math.min(flight.Speed * FLIGHT_TICK, distance)
			ticks += 1
			task.delay(FLIGHT_TICK, step)
		end
		step()
	end

	function Swarm:OnBegin(input: Ability.AbilityInput)
		if self.Hovering then
			if config.Charged then
				self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
			else
				self:Send(input.AimPosition, nil)
			end
			return
		end

		local now = os.clock()
		if now - (self.LastCreate or -math.huge) < config.CreateCooldown then
			return
		end
		if now - (self.LastSend or -math.huge) < config.SendCooldown then
			return
		end

		local amount = math.floor(config.AmountBase * self:GetLevelScale("Sniper") * self:GetAffinity("Sniper"))
		if amount >= 1 then
			self:Create(amount)
		end
	end

	function Swarm:OnEnd(input: Ability.AbilityInput)
		-- Only a press made while ghosts hover starts a charge, so the release of the
		-- press that created them falls through here.
		local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
		if charge and self.Hovering then
			self:Send(input.AimPosition, charge)
		end
	end

	function Swarm:OnInterrupt()
		self.ChargeStart = nil
		-- Stops the ghosts already in flight.
		self.Epoch = (self.Epoch or 0) + 1
		self:StopHover()
	end

	return Swarm
end

return HollowSwarm
