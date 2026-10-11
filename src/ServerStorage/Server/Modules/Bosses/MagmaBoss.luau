--!strict
--[[
	The magma boss of the raids (legacy ServerStorage.Boss.Normal.MagmaBoss, AI_Magma).
	It hunts with Shave teleports (see _RaidShared), lands behind its target and burns it:
	a pool under its feet, a body of magma, a huge fist and a rain of magma. Below 65 %
	health it turns to haki: every attack becomes Haki damage and is doubled.

	Its attacks used the levels written in the script, not the ones of the model's Config
	folder: Melee 800, Defense 700, Sniper 600, affinity 1.8 (m, d, s below are level / 500).

	Every think, in this order (as the legacy loop did):
	- target closer than 4 studs, pool recharging    Shave 45 studs away
	- target 4 to 11 studs above, 2 to 5 below,
	  or more than 65 above                          lunge at it
	- target more than 5 studs above, fist ready     Great Eruption
	- target further than 14 studs                   Shave towards it
	- closer than 5 studs, pool ready                Magma Pool
	- closer than 40 studs                           Magma Body (once; it never goes out)
	- further than 15 studs, fist ready              Great Eruption
	- 25 to 100 studs, flow ready                    Magma Flow
	- otherwise                                      walk at the target
	The distance is the one measured before the Shave, as in the legacy loop: that is the
	only way the fist and the flow are ever picked, since a target within 40 studs stops
	the chain at Magma Body. For the same reason the boss never walks at a target closer
	than 40 studs: it waits for its next Shave. Kept.

	Great Eruption 0.5 s wind-up, then a ball of 30.6 * 1.8 * m studs (88) thrown from the
	               right arm at 450 studs/s with 25 studs/s of lift; it flies through
	               everything and falls with gravity for 5 s.
	               clamp(1500 * 1.8 * m, 180, 7200) = 4320, and the victim's healing is
	               cut by 80 % for 15 regen ticks. Cooldown 5 s.
	Magma Body     whoever touches the boss takes 130 * d * 1.8 (327.6), at most every 0.5 s.
	Magma Pool     0.5 s wind-up; a pool under the boss grows to 450 * d * 1.8 studs
	               (1134) in 13 s and shrinks back in 9 s; 560 * d * 1.8 / 2 (705.6) every
	               0.5 s to whoever stands in it. Cooldown 27 s.
	Magma Flow     the player's Magma Flow with s * 1.8 (2.16) as its factor: 15 rows of
	               blobs, each burning for 400 * s * 1.8 (864) every 0.25 s, 10 times.
	               Cooldown 10 s.
	Nothing here can be dodged.

	Legacy problems fixed here:
	- The fist, the pool and every blob were server parts, each with its own thread or
	  Heartbeat connection querying the whole map. They are numbers advanced by Think;
	  clients draw them with the player fruit's effects.
	- The body's damage came from Touched on every part of the model, with its cooldown
	  kept as an attribute on the victim.
	- The pool and the blobs outlived the boss (harmless, their threads died with it).
	  They end with it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local BossTypes = require(ServerStorage.Server.Types.BossTypes)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Shared = require(script.Parent._RaidShared)

type CharacterEntity = CharacterEntity.CharacterEntity

local LEVEL_CAP = 500
local AFFINITY = 1.8
local MELEE = 800 / LEVEL_CAP
local DEFENSE = 700 / LEVEL_CAP
local SNIPER = 600 / LEVEL_CAP

-- Guess: the dumped model's Humanoid was saved mid-slow (12.6); the other raid bosses
-- walk at 18. Its Config.WalkSpeed (85) was never applied.
local WALK_SPEED = 18
local HAKI_HEALTH_FRACTION = 0.65
-- The legacy defaults of the fruit: red, with brown as the second color.
local COLORS = "255,0,0,139,80,55"
local BODY_STATUS = "MagmaBody"

local RETREAT_BELOW_DISTANCE = 4

local ERUPTION = {
	MinRange = 15,
	HeightTrigger = 5,
	Cooldown = 5,
	ChargeTime = 0.5,
	Recover = 0.5,
	Speed = 450,
	Lift = 25,
	Lifetime = 5,
	Scale = AFFINITY * MELEE,
	Damage = math.clamp(1500 * AFFINITY * MELEE, 100 * AFFINITY, 4000 * AFFINITY),
	AntiHealFraction = 0.8,
	AntiHealHits = 15,
	-- The legacy fist had no drag. The client effect (MagmaEruption) needs one above
	-- zero; with this one the flight is 0.25 % shorter after 5 s. Server and clients
	-- follow the same curve.
	Drag = 1e-3,
	-- Size of the "Great Eruption" asset, when it cannot be read.
	FallbackSize = Vector3.new(30.6, 30.6, 30.6),
	EffectRadius = 1500,
}

local BODY = {
	Range = 40,
	Damage = 130 * DEFENSE * AFFINITY,
	Cooldown = 0.5,
	-- Around the root, on top of the body allowance of Hitbox: about arm's reach.
	Reach = 2,
}

local POOL = {
	Range = 5,
	Cooldown = 27,
	WindUp = 0.5,
	Diameter = 450 * DEFENSE * AFFINITY,
	GrowTime = 13,
	ShrinkTime = 9,
	Damage = 560 * DEFENSE * AFFINITY / 2,
	Interval = 0.5,
	GroundOffset = 3,
	-- The pool part breathed between 1 and 7 studs thick; the thickest is used.
	Thickness = 7,
	EffectMargin = 400,
}

local FLOW = {
	MinRange = 25,
	MaxRange = 100,
	Cooldown = 10,
	Recover = 0.8,
	Factor = AFFINITY * SNIPER,
	Damage = 400 * AFFINITY * SNIPER,
	Hits = 10,
	Interval = 0.25,
	StartSize = Vector3.new(10, 3, 10),
	EndSize = Vector3.new(15, 4, 15),
	GrowTime = 2.5,
	EffectRadius = 700,
}

-- Layout of Magma Flow, shared with Effects.OneShot.MagmaFlow (see `layout`).
local ROWS = 15
local ROW_SPACING = 20
local SPREAD_PER_ROW = 15 / 4
local MIN_DELAY = 1 / 60
local FLOOR_PROBE = 50

type Fist = {
	Start: number,
	Origin: Vector3,
	Direction: Vector3,
	Speed: number,
	Gravity: number,
	Last: Vector3,
	Radius: number,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	Hit: { [CharacterEntity]: boolean },
}

type Pool = {
	Start: number,
	Center: Vector3,
	NextHit: number,
}

type Blob = {
	Center: Vector3,
	NextHit: number,
	Start: number,
	HitsLeft: number,
}

type Flow = {
	Blobs: { Blob },
	Damage: number,
	Trait: CombatTypes.DamageTrait,
}

local MagmaBoss = {}
MagmaBoss.__index = MagmaBoss

type Self = typeof(setmetatable(
	{} :: {
		Handle: BossTypes.BossHandle,
		Entity: CharacterEntity,
		Mover: Shared.Mover,
		Timeline: Shared.Timeline,
		Tracks: { [string]: AnimationTrack },
		Haki: boolean,
		BodyOn: boolean,

		-- The legacy loop yielded inside its skills: nothing is decided before BusyUntil.
		BusyUntil: number,
		EruptionReady: number,
		PoolReady: number,
		FlowReady: number,

		Fists: { Fist },
		Pools: { Pool },
		Flows: { Flow },
		NextBurn: { [CharacterEntity]: number },
	},
	MagmaBoss
))

local function getFistSize(): Vector3
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", "Magma", "Power1", "Great Eruption" } do
		current = if current then current:FindFirstChild(name) else nil
	end
	return if current and current:IsA("BasePart") then current.Size else ERUPTION.FallbackSize
end

-- The curve Effects.OneShot.MagmaEruption draws.
local function fistPosition(fist: Fist, age: number): Vector3
	local drag = ERUPTION.Drag
	local decayed = 1 - math.exp(-drag * age)
	return fist.Origin
		+ fist.Direction * (fist.Speed / drag * decayed)
		- Vector3.yAxis * (fist.Gravity / drag * (age - decayed / drag))
end

-- Flat landing targets and spawn delays of every blob. Keep identical to the one in
-- Abilities/Magma/Magma Flow and Effects.OneShot.MagmaFlow: clients rebuild it from the seed.
local function layout(seed: number, origin: Vector3, direction: Vector3): { { Point: Vector3, Delay: number } }
	local rng = Random.new(seed)
	local result = {}
	local delay = 0
	for row = 1, ROWS do
		local count = rng:NextInteger(math.floor(1 + row / 3), row)
		local spread = math.floor(SPREAD_PER_ROW * row)
		for _ = 1, count do
			local x = rng:NextInteger(-spread, spread)
			local z = rng:NextInteger(-spread, spread)
			table.insert(result, {
				Point = origin + direction * (row * ROW_SPACING) + Vector3.new(x, 0, z),
				Delay = delay,
			})
			delay += math.max(rng:NextInteger(10 // row, 25 // row) / 100, MIN_DELAY)
		end
	end
	return result
end

function MagmaBoss.new(handle: BossTypes.BossHandle): Self
	local entity = handle.Entity
	entity:SetBaseWalkSpeed(WALK_SPEED)

	local config: any = AnimationConfig
	local fruitAnims: { [string]: string } = config.FruitAnims or {}
	local tracks = Shared.LoadTracks(entity, {
		Charge = fruitAnims.Punch1RightCharge,
		-- The legacy script released with the "charged" hold clip, not with the punch.
		Release = fruitAnims.Punch1RightCharged,
		Dash = config.Dash,
	})

	return setmetatable({
		Handle = handle,
		Entity = entity,
		Mover = Shared.NewMover(handle, tracks.Dash),
		Timeline = {},
		Tracks = tracks,
		Haki = false,
		BodyOn = false,

		BusyUntil = 0,
		EruptionReady = 0,
		PoolReady = 0,
		FlowReady = 0,

		Fists = {},
		Pools = {},
		Flows = {},
		NextBurn = setmetatable({}, { __mode = "k" }) :: any,
	}, MagmaBoss)
end

function MagmaBoss._colors(self: Self): string
	return if self.Haki then Shared.HAKI_COLORS else COLORS
end

function MagmaBoss._trait(self: Self): (CombatTypes.DamageTrait, number)
	if self.Haki then
		return "Haki", Shared.HAKI_MULTIPLIER
	end
	return "Special", 1
end

function MagmaBoss._play(self: Self, name: string)
	local track = self.Tracks[name]
	if track then
		track:Play()
	end
end

function MagmaBoss._stop(self: Self, name: string)
	local track = self.Tracks[name]
	if track then
		track:Stop()
	end
end

function MagmaBoss._effect(self: Self, name: string, origin: Vector3, params: { [string]: any }, radius: number?)
	params.Haki = self.Haki
	params.Colors = COLORS
	params.Caster = self.Entity.Model
	Knit.GetService("EffectService"):Play(name, origin, params, radius)
end

function MagmaBoss._eruption(self: Self, target: CharacterEntity, now: number)
	local entity = self.Entity
	self.BusyUntil = now + ERUPTION.ChargeTime + ERUPTION.Recover
	self.Handle.Halt()
	Shared.Face(entity, target.Root.Position)
	self:_play("Charge")

	Shared.After(self.Timeline, now + ERUPTION.ChargeTime, function(at: number)
		self:_stop("Charge")
		if target.Dead or not target.Spawned then
			self.BusyUntil = at
			return
		end
		Shared.Face(entity, target.Root.Position)
		self:_play("Release")
		self.EruptionReady = at + ERUPTION.Cooldown
		Shared.After(self.Timeline, at + ERUPTION.Recover, function()
			self:_stop("Release")
		end)

		local origin = Shared.LimbCFrame(entity, "Right Arm").Position
		local aim = target.Root.Position - origin
		aim = if aim.Magnitude > 0.05 then aim.Unit else entity.Root.CFrame.LookVector
		local velocity = aim * ERUPTION.Speed + Vector3.new(0, ERUPTION.Lift, 0)

		local size = getFistSize()
		local trait, multiplier = self:_trait()
		local gravity = Workspace.Gravity
		table.insert(self.Fists, {
			Start = at,
			Origin = origin,
			Direction = velocity.Unit,
			Speed = velocity.Magnitude,
			Gravity = gravity,
			Last = origin,
			Radius = math.max(size.X, size.Y, size.Z) * ERUPTION.Scale / 2,
			Damage = ERUPTION.Damage * multiplier,
			Trait = trait,
			Hit = {},
		})
		self:_effect("MagmaEruption", origin, {
			Direction = velocity.Unit,
			Speed = velocity.Magnitude,
			Drag = ERUPTION.Drag,
			Gravity = gravity,
			Lifetime = ERUPTION.Lifetime,
			Percent = 1,
			Multiplier = ERUPTION.Scale,
			Hand = "Right",
		}, ERUPTION.EffectRadius)
	end)
end

function MagmaBoss._updateFists(self: Self, now: number)
	local entity = self.Entity
	for index = #self.Fists, 1, -1 do
		local fist = self.Fists[index]
		local age = math.min(now - fist.Start, ERUPTION.Lifetime)
		local position = fistPosition(fist, age)

		-- Sample the stretch flown since the last think so the ball cannot skip anyone.
		local from = fist.Last
		local samples = math.max(1, math.ceil((position - from).Magnitude / fist.Radius))
		for sample = 1, samples do
			local point = from:Lerp(position, sample / samples)
			for _, target in Shared.Players(Hitbox.Sphere(point, fist.Radius, entity)) do
				if not fist.Hit[target] then
					fist.Hit[target] = true
					if Shared.Damage(entity, target, fist.Damage, fist.Trait, false) > 0 then
						target.AntiHealFraction = math.max(target.AntiHealFraction, ERUPTION.AntiHealFraction)
						target.AntiHealHits = math.max(target.AntiHealHits, ERUPTION.AntiHealHits)
					end
				end
			end
		end
		fist.Last = position

		if age >= ERUPTION.Lifetime then
			table.remove(self.Fists, index)
		end
	end
end

function MagmaBoss._body(self: Self)
	self.BodyOn = true
	-- Flames and body tint of the player's Magma Body.
	self.Entity:SetStatus(BODY_STATUS, self:_colors(), nil, true)
end

function MagmaBoss._burnTouch(self: Self, now: number)
	local entity = self.Entity
	local trait, multiplier = self:_trait()
	for _, target in Shared.Players(Hitbox.Sphere(entity.Root.Position, BODY.Reach, entity)) do
		if now >= (self.NextBurn[target] or 0) then
			self.NextBurn[target] = now + BODY.Cooldown
			Shared.Damage(entity, target, BODY.Damage * multiplier, trait, false)
		end
	end
end

function MagmaBoss._pool(self: Self, now: number)
	local entity = self.Entity
	self.BusyUntil = now + POOL.WindUp
	self.Handle.Halt()

	Shared.After(self.Timeline, now + POOL.WindUp, function(at: number)
		self.PoolReady = at + POOL.Cooldown
		local center = entity.Root.Position - Vector3.new(0, POOL.GroundOffset, 0)
		table.insert(self.Pools, { Start = at, Center = center, NextHit = at })
		self:_effect("MagmaPool", center, {
			Diameter = POOL.Diameter,
			GrowTime = POOL.GrowTime,
			ShrinkTime = POOL.ShrinkTime,
		}, POOL.Diameter / 2 + POOL.EffectMargin)
	end)
end

function MagmaBoss._updatePools(self: Self, now: number)
	local entity = self.Entity
	for index = #self.Pools, 1, -1 do
		local pool = self.Pools[index]
		local elapsed = now - pool.Start
		if elapsed >= POOL.GrowTime + POOL.ShrinkTime then
			table.remove(self.Pools, index)
			continue
		end
		if now < pool.NextHit then
			continue
		end
		pool.NextHit = now + POOL.Interval

		local alpha = if elapsed <= POOL.GrowTime
			then elapsed / POOL.GrowTime
			else 1 - (elapsed - POOL.GrowTime) / POOL.ShrinkTime
		local side = POOL.Diameter * alpha
		if side <= 0 then
			continue
		end
		-- The legacy check was the bounding box of the lying cylinder: a square.
		-- The haki state is read on every tick, as the legacy pool did.
		local trait, multiplier = self:_trait()
		local box = Vector3.new(side, POOL.Thickness, side)
		for _, target in Shared.Players(Hitbox.Box(CFrame.new(pool.Center), box, entity)) do
			Shared.Damage(entity, target, POOL.Damage * multiplier, trait, false)
		end
	end
end

function MagmaBoss._flow(self: Self, target: CharacterEntity, now: number)
	local entity = self.Entity
	self.BusyUntil = now + FLOW.Recover
	self.FlowReady = now + FLOW.Cooldown
	self.Handle.Halt()
	Shared.Face(entity, target.Root.Position)

	local origin = entity.Root.Position
	local direction = target.Root.Position - origin
	direction = if direction.Magnitude > 0.05 then direction.Unit else entity.Root.CFrame.LookVector
	local seed = math.random(1, 2 ^ 30)

	-- Blobs land on the map, never on characters (clients ignore them the same way).
	local ignored: { Instance } = {}
	for model in Knit.GetService("CharacterService"):GetEntities() do
		table.insert(ignored, model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored

	local blobs: { Blob } = {}
	for _, entry in layout(seed, origin, direction) do
		local result = Workspace:Raycast(
			entry.Point + Vector3.new(0, FLOOR_PROBE, 0),
			Vector3.new(0, -2 * FLOOR_PROBE, 0),
			params
		)
		-- With no ground under it a blob cools on the sea and hurts nobody.
		if result then
			local start = now + entry.Delay
			table.insert(blobs, { Center = result.Position, Start = start, NextHit = start, HitsLeft = FLOW.Hits })
		end
	end

	self:_effect("MagmaFlow", origin, {
		Direction = direction,
		Seed = seed,
		Factor = FLOW.Factor,
	}, FLOW.EffectRadius)

	if #blobs > 0 then
		local trait, multiplier = self:_trait()
		table.insert(self.Flows, { Blobs = blobs, Damage = FLOW.Damage * multiplier, Trait = trait })
	end
end

function MagmaBoss._updateFlows(self: Self, now: number)
	local entity = self.Entity
	for flowIndex = #self.Flows, 1, -1 do
		local flow = self.Flows[flowIndex]
		local blobs = flow.Blobs
		for index = #blobs, 1, -1 do
			local blob = blobs[index]
			if now < blob.NextHit then
				continue
			end
			blob.NextHit = now + FLOW.Interval
			blob.HitsLeft -= 1

			-- Quint "out" easing of the legacy size tween.
			local alpha = 1 - (1 - math.min((now - blob.Start) / FLOW.GrowTime, 1)) ^ 5
			local box = FLOW.StartSize:Lerp(FLOW.EndSize, alpha) * FLOW.Factor
			for _, target in Shared.Players(Hitbox.Box(CFrame.new(blob.Center), box, entity)) do
				Shared.Damage(entity, target, flow.Damage, flow.Trait, false)
			end

			if blob.HitsLeft <= 0 then
				table.remove(blobs, index)
			end
		end
		if #blobs == 0 then
			table.remove(self.Flows, flowIndex)
		end
	end
end

function MagmaBoss.Think(self: Self, target: CharacterEntity?, distance: number, now: number)
	local entity = self.Entity
	-- A model destroyed without a death leaves EnemyService thinking for it: end here,
	-- before anything already scheduled lands.
	if Shared.Gone(entity) then
		(self :: any):Destroy()
		return
	end
	Shared.RunDue(self.Timeline, now)
	self:_updateFists(now)
	self:_updatePools(now)
	self:_updateFlows(now)
	if entity.Dead then
		return
	end
	self.Mover:Update(target, now)

	if not self.Haki and entity:GetHealthRatio() < HAKI_HEALTH_FRACTION then
		self.Haki = true
		if self.BodyOn then
			entity:SetStatus(BODY_STATUS, Shared.HAKI_COLORS, nil, true)
		end
	end
	if self.BodyOn then
		self:_burnTouch(now)
	end

	-- A stun does not stop it: the legacy AI never looked at one.
	if now < self.BusyUntil or not target then
		return
	end

	local mover = self.Mover
	local height = target.Root.Position.Y - entity.Root.Position.Y

	if distance < RETREAT_BELOW_DISTANCE and now < self.PoolReady then
		mover:ShaveAway(target, now)
	end
	if (height > 4 and height < 11) or (height < -2 and height > -5) or height > 65 then
		mover:Dash(target, now)
	end
	if height > ERUPTION.HeightTrigger and now >= self.EruptionReady then
		self:_eruption(target, now)
		return
	end
	mover:ShaveTowards(target, distance, now)

	if distance < POOL.Range and now > self.PoolReady then
		self:_pool(now)
	elseif distance < BODY.Range then
		if not self.BodyOn then
			self:_body()
		end
	elseif distance > ERUPTION.MinRange and now > self.EruptionReady then
		self:_eruption(target, now)
	elseif distance > FLOW.MinRange and distance < FLOW.MaxRange and now > self.FlowReady then
		self:_flow(target, now)
	elseif entity:IsRooted() then
		-- Rooted it cannot walk; everything above still happened.
		self.Handle.Halt()
	else
		self.Handle.Navigate(target.Root.Position)
	end
end

function MagmaBoss.Destroy(self: Self)
	table.clear(self.Timeline)
	self.Mover:Destroy()
	table.clear(self.Fists)
	table.clear(self.Pools)
	table.clear(self.Flows)
	table.clear(self.NextBurn)

	self.BodyOn = false
	self.Entity:ClearStatus(BODY_STATUS)
	for _, track in self.Tracks do
		track:Stop()
	end
	table.clear(self.Tracks)
end

return MagmaBoss
