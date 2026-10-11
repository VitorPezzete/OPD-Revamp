--!strict
--[[
	The quake boss of the raids (legacy ServerStorage.Boss.Normal.QuakeBoss, AI_Quake).
	It hunts with Shave teleports and lunges (see _RaidShared) and shatters the air, the
	ground and, once it is hurt, the sea. Below 65 % health it turns to haki: every
	attack becomes Haki damage and is doubled. Below 45 % it starts raising tsunamis.

	Its attacks used the levels written in the script, not the ones of the model's Config
	folder: Defense 850, Sniper 650, affinity 1.7 (d, s below are level / 500).

	Every think, in this order (as the legacy loop did):
	- target closer than 3.14 studs, stomp recharging   Shave 45 studs away
	- target more than 65 studs above or below,
	  or 100 to 200 studs away                          lunge at it
	- target further than 14 studs                      Shave towards it
	- further than 12 studs, seismic ready              Seismic Wave
	- 5 to 300 studs, tsunami ready, health <= 45 %     Tsunami
	- 3.14 to 25 studs, stomp ready                     Quake Stomp (only with ground
	                                                    within 10 studs under it)
	- otherwise                                         walk at the target
	The distance is the one measured before the Shave, as in the legacy loop.

	Seismic Wave  0.5 s wind-up, then the air bursts in a cube of 4 * k studs around
	              where the target stands, k = (1.5 * 98 + 1) / 10 * 0.004 * 650 * 1.7
	              (a 262 stud cube). Everyone inside is stunned 0.25 s, slammed down at
	              125 * 1.7 * s * 0.98 studs/s (271) for 0.25 s and takes
	              2100 * 0.98 * 1.7 * s (4548), with no falloff. Cooldown 6.5 s.
	Tsunami       0.5 s wind-up, then two walls of water, the Tsunami model scaled by
	              k = 6.25 * 0.004 * 850 * 1.7 (36.1), rise 88 * k studs (3179) to either
	              side of the boss and close on it in k / d seconds (21.25) while rising
	              by their own height; they then cross and run twice as far in the same
	              time while sinking back. 7500 * 1.7 * d (21675) once per wall.
	              Cooldown 125 s.
	Quake Stomp   0.6 s wind-up, then a shock ball drops under the boss: everyone within
	              50 * 1.7 studs (85) takes 1600 * 1.7 * d * 50 / 60 (3853) and is thrown
	              away, slightly upward, at 65 * 1.7^2 * d studs/s (319) for 0.2 s.
	              Cooldown 12 s.
	Nothing here can be dodged.

	Legacy problems fixed here:
	- The bubble, the walls, the ball and the rocks were server parts with server tweens;
	  each wall had a thread querying the whole map every 0.1 s for 53 s.
	- A wall only looked at where it was every 0.1 s; whatever it crossed in between is
	  covered now (each check spans the distance since the previous one).
	- The stomp's damage waited on Tween.Completed of the ball.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local QuakeShared = require(ServerStorage.Server.Modules.Abilities.Quake._Shared)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local BossTypes = require(ServerStorage.Server.Types.BossTypes)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Shared = require(script.Parent._RaidShared)

type CharacterEntity = CharacterEntity.CharacterEntity

local LEVEL_CAP = 500
local AFFINITY = 1.7
local DEFENSE_LEVEL = 850
local DEFENSE = DEFENSE_LEVEL / LEVEL_CAP
local SNIPER_LEVEL = 650
local SNIPER = SNIPER_LEVEL / LEVEL_CAP

-- Walk speed of the legacy model's Humanoid; its Config.WalkSpeed (85) was never applied.
local WALK_SPEED = 25.2
local HAKI_HEALTH_FRACTION = 0.65
-- The legacy defaults: white, with brown as the second color.
local COLORS = "255,255,255,139,80,55"

local RETREAT_BELOW_DISTANCE = math.pi
local DASH_HEIGHT = 65
local DASH_MIN_DISTANCE = 100
local DASH_MAX_DISTANCE = 200

local SEISMIC_CHARGE = 98
local SEISMIC_FACTOR = (1.5 * SEISMIC_CHARGE + 1) / 10 * 0.004 * SNIPER_LEVEL * AFFINITY
local SEISMIC = {
	MinRange = 12,
	Cooldown = 6.5,
	ChargeTime = 0.5,
	Recover = 0.25,
	Side = 4 * SEISMIC_FACTOR,
	CrackForce = SEISMIC_FACTOR / 5,
	Damage = 2100 * SEISMIC_CHARGE / 100 * AFFINITY * SNIPER,
	Stun = 0.25,
	SlamSpeed = 125 * AFFINITY * SNIPER * SEISMIC_CHARGE / 100,
	SlamSeconds = 0.25,
	-- MaxForce of the legacy mover on each axis, per unit of mass of the target.
	SlamForce = 1e7,
	SlamPower = 1250,
	EffectMargin = 400,
}

local TSUNAMI_SCALE = (0.425 * 1000 / 100 + 2) * 0.004 * DEFENSE_LEVEL * AFFINITY
local TSUNAMI = {
	MinRange = 5,
	MaxRange = 300,
	HealthFraction = 0.45,
	Cooldown = 125,
	ChargeTime = 0.5,
	Scale = TSUNAMI_SCALE,
	-- Studs from the boss to where a wall rises, and seconds it takes to reach the boss.
	LegDistance = 88 * TSUNAMI_SCALE,
	LegTime = TSUNAMI_SCALE / DEFENSE,
	-- After crossing, a wall covers this many times LegDistance in another LegTime.
	SecondLegFactor = 2,
	Damage = 7500 * AFFINITY * DEFENSE,
	-- Size of the Tsunami model, for a place without it.
	FallbackSize = Vector3.new(72, 16, 24),
	EffectMargin = 1000,
}

local MAX_PART_SIZE = Vector3.new(2048, 2048, 2048)

local STOMP_CHARGE = 50
local STOMP = {
	MinRange = math.pi,
	MaxRange = 25,
	Cooldown = 12,
	ChargeTime = 0.6,
	GroundProbe = 10,
	BallOffset = 5,
	BallSpeed = 200,
	Radius = STOMP_CHARGE * AFFINITY,
	Damage = 1600 * AFFINITY * DEFENSE * STOMP_CHARGE / 60,
	Push = 65 * AFFINITY ^ 2 * DEFENSE,
	PushLift = 0.25,
	PushSeconds = 0.2,
	-- The legacy mover: 1e5 on every axis whatever the target weighs, default P.
	PushForce = Vector3.new(1e5, 1e5, 1e5),
	PushPower = 1250,
}

type Wall = {
	Start: number,
	From: Vector3,
	Direction: Vector3,
	Size: Vector3,
	Swept: number,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	Hit: { [CharacterEntity]: boolean },
}

local QuakeBoss = {}
QuakeBoss.__index = QuakeBoss

type Self = typeof(setmetatable(
	{} :: {
		Handle: BossTypes.BossHandle,
		Entity: CharacterEntity,
		Mover: Shared.Mover,
		Timeline: Shared.Timeline,
		Tracks: { [string]: AnimationTrack },
		Haki: boolean,

		-- The legacy loop yielded inside its skills: nothing is decided before BusyUntil.
		BusyUntil: number,
		SeismicReady: number,
		TsunamiReady: number,
		StompReady: number,

		Walls: { Wall },
	},
	QuakeBoss
))

function QuakeBoss.new(handle: BossTypes.BossHandle): Self
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

		BusyUntil = 0,
		SeismicReady = 0,
		TsunamiReady = 0,
		StompReady = 0,

		Walls = {},
	}, QuakeBoss)
end

function QuakeBoss._trait(self: Self): (CombatTypes.DamageTrait, number)
	if self.Haki then
		return "Haki", Shared.HAKI_MULTIPLIER
	end
	return "Special", 1
end

function QuakeBoss._play(self: Self, name: string)
	local track = self.Tracks[name]
	if track then
		track:Play()
	end
end

function QuakeBoss._stop(self: Self, name: string)
	local track = self.Tracks[name]
	if track then
		track:Stop()
	end
end

function QuakeBoss._effect(self: Self, name: string, origin: Vector3, params: { [string]: any }, colors: string, radius: number?)
	params.Haki = self.Haki
	params.Colors = if self.Haki then Shared.HAKI_COLORS else colors
	params.Caster = self.Entity.Model
	Knit.GetService("EffectService"):Play(name, origin, params, radius)
end

function QuakeBoss._seismic(self: Self, target: CharacterEntity, now: number)
	local entity = self.Entity
	self.BusyUntil = now + SEISMIC.ChargeTime + SEISMIC.Recover
	Shared.Face(entity, target.Root.Position)
	self:_play("Charge")

	Shared.After(self.Timeline, now + SEISMIC.ChargeTime, function(at: number)
		self:_stop("Charge")
		if target.Dead or not target.Spawned then
			self.BusyUntil = at
			return
		end
		self:_play("Release")
		self.SeismicReady = at + SEISMIC.Recover + SEISMIC.Cooldown
		Shared.After(self.Timeline, at + SEISMIC.Recover, function()
			self:_stop("Release")
		end)

		local center = target.Root.Position
		local side = SEISMIC.Side
		local trait, multiplier = self:_trait()
		local slam = Vector3.new(0, -SEISMIC.SlamSpeed, 0)
		local characters = Knit.GetService("CharacterService")

		for _, victim in Shared.Players(Hitbox.Box(CFrame.new(center), Vector3.new(side, side, side), entity)) do
			Shared.Stun(victim, SEISMIC.Stun, "QuakeBossSeismic")
			if victim.Humanoid.Sit then
				victim.Humanoid.Sit = false
			end
			local force = SEISMIC.SlamForce * victim.Root.AssemblyMass
			characters:ApplyImpulse(victim, slam, SEISMIC.SlamSeconds, Vector3.new(force, force, force), SEISMIC.SlamPower)
			Shared.Damage(entity, victim, SEISMIC.Damage * multiplier, trait, false)
		end

		-- The blast can be far from the boss, whose fist cracks the air in the same effect.
		local reach = (center - entity.Root.Position).Magnitude + SEISMIC.EffectMargin
		self:_effect("QuakeSeismic", center, {
			Size = side,
			Force = SEISMIC.CrackForce,
			RightHand = true,
		}, COLORS, reach)
	end)
end

function QuakeBoss._tsunami(self: Self, target: CharacterEntity, now: number)
	local entity = self.Entity
	self.BusyUntil = now + TSUNAMI.ChargeTime
	self.Handle.Halt()
	Shared.Face(entity, target.Root.Position)
	self:_play("Charge")

	Shared.After(self.Timeline, now + TSUNAMI.ChargeTime, function(at: number)
		self:_stop("Charge")
		self.TsunamiReady = at + TSUNAMI.Cooldown

		local template = QuakeShared.FindResource("Tsunami")
		-- No part is larger than 2048 studs: the legacy wall, and the one clients draw,
		-- stop there, and so must the box that hurts.
		local size = ((if template then template.Size else TSUNAMI.FallbackSize) * TSUNAMI.Scale):Min(MAX_PART_SIZE)
		local position = entity.Root.Position
		local right = entity.Root.CFrame.RightVector * Vector3.new(1, 0, 1)
		right = if right.Magnitude > 0.05 then right.Unit else Vector3.xAxis

		local trait, multiplier = self:_trait()
		for _, side in { 1, -1 } do
			table.insert(self.Walls, {
				Start = at,
				From = position + right * (TSUNAMI.LegDistance * side),
				Direction = right * -side,
				Size = size,
				Swept = 0,
				Damage = TSUNAMI.Damage * multiplier,
				Trait = trait,
				Hit = {},
			})
		end

		-- The walls keep the color of water whatever the boss's colors are.
		self:_effect("BossQuakeTsunami", position, {
			Right = right,
			Size = size,
			LegDistance = TSUNAMI.LegDistance,
			LegTime = TSUNAMI.LegTime,
			SecondLegFactor = TSUNAMI.SecondLegFactor,
			SeaLevel = WorldConfig.SeaLevel,
			Scale = TSUNAMI.Scale,
		}, COLORS, TSUNAMI.LegDistance * (1 + TSUNAMI.SecondLegFactor) + TSUNAMI.EffectMargin)
	end)
end

-- Each wall as a box covering what it swept since the last think.
function QuakeBoss._updateWalls(self: Self, now: number)
	local entity = self.Entity
	local sea = WorldConfig.SeaLevel
	for index = #self.Walls, 1, -1 do
		local wall = self.Walls[index]
		-- 0 at the start, 1 over the boss, 2 at the end.
		local alpha = math.clamp((now - wall.Start) / TSUNAMI.LegTime, 0, 2)
		local height = wall.Size.Y
		local distance: number
		local centerY: number
		if alpha <= 1 then
			distance = TSUNAMI.LegDistance * alpha
			centerY = sea - height / 2 + height * alpha
		else
			distance = TSUNAMI.LegDistance * (1 + TSUNAMI.SecondLegFactor * (alpha - 1))
			centerY = sea + height / 2 - height * (alpha - 1)
		end

		local swept = distance - wall.Swept
		local flat = wall.From + wall.Direction * ((distance + wall.Swept) / 2)
		local center = Vector3.new(flat.X, centerY, flat.Z)
		local size = Vector3.new(wall.Size.X, height, wall.Size.Z + swept)
		wall.Swept = distance

		for _, target in Shared.Players(Hitbox.Box(CFrame.lookAt(center, center + wall.Direction), size, entity)) do
			if not wall.Hit[target] then
				wall.Hit[target] = true
				Shared.Damage(entity, target, wall.Damage, wall.Trait, false)
			end
		end

		if alpha >= 2 then
			table.remove(self.Walls, index)
		end
	end
end

function QuakeBoss._nearGround(self: Self): boolean
	local root = self.Entity.Root
	return Workspace:Raycast(root.Position, Vector3.new(0, -STOMP.GroundProbe, 0), self.Mover.Params) ~= nil
end

function QuakeBoss._stomp(self: Self, target: CharacterEntity, now: number)
	local entity = self.Entity
	self.BusyUntil = now + STOMP.ChargeTime
	self.Handle.Halt()
	Shared.Face(entity, target.Root.Position)
	self:_play("Charge")

	Shared.After(self.Timeline, now + STOMP.ChargeTime, function(at: number)
		self:_stop("Charge")
		self.StompReady = at + STOMP.Cooldown

		local root = entity.Root
		-- As the legacy script measured it: the floor point raised to where a root stands.
		local ground = Shared.Floor(root.Position, self.Mover.Params)
		local start = (root.CFrame * CFrame.new(0, -STOMP.BallOffset, 0)).Position
		local fallTime = (ground - start).Magnitude / STOMP.BallSpeed
		local trait, multiplier = self:_trait()
		local damage = STOMP.Damage * multiplier

		-- No colors: the rocks keep their own (the legacy boss painted them brown and
		-- the cracks white, which one fruit color string cannot say).
		self:_effect("QuakeStomp", start, {
			Ground = ground,
			FallTime = fallTime,
			Charge = STOMP_CHARGE,
			Percent = STOMP_CHARGE / 60,
			Affinity = AFFINITY,
			LevelScale = DEFENSE,
		}, "None")

		Shared.After(self.Timeline, at + fallTime, function()
			local characters = Knit.GetService("CharacterService")
			for _, victim in Shared.Players(Hitbox.Sphere(ground, STOMP.Radius, entity)) do
				-- The legacy call named no style: no resistance perk applies.
				Shared.Damage(entity, victim, damage, trait, false, "Plain")
				if victim.Dead then
					continue
				end
				local away = victim.Root.Position - ground
				local direction = Vector3.yAxis
				if away.Magnitude > 0.01 then
					local unit = away.Unit
					direction = Vector3.new(unit.X, STOMP.PushLift, unit.Z).Unit
				end
				characters:ApplyImpulse(victim, direction * STOMP.Push, STOMP.PushSeconds, STOMP.PushForce, STOMP.PushPower)
			end
		end)
	end)
end

function QuakeBoss.Think(self: Self, target: CharacterEntity?, distance: number, now: number)
	local entity = self.Entity
	-- A model destroyed without a death leaves EnemyService thinking for it: end here,
	-- before anything already scheduled lands.
	if Shared.Gone(entity) then
		(self :: any):Destroy()
		return
	end
	Shared.RunDue(self.Timeline, now)
	self:_updateWalls(now)
	if entity.Dead then
		return
	end
	self.Mover:Update(target, now)

	if not self.Haki and entity:GetHealthRatio() < HAKI_HEALTH_FRACTION then
		self.Haki = true
	end

	-- A stun does not stop it: the legacy AI never looked at one.
	if now < self.BusyUntil or not target then
		return
	end

	local mover = self.Mover
	local height = math.abs(target.Root.Position.Y - entity.Root.Position.Y)

	if distance < RETREAT_BELOW_DISTANCE and now < self.StompReady then
		mover:ShaveAway(target, now)
	end
	if height > DASH_HEIGHT or (distance > DASH_MIN_DISTANCE and distance < DASH_MAX_DISTANCE) then
		mover:Dash(target, now)
	end
	mover:ShaveTowards(target, distance, now)

	if distance > SEISMIC.MinRange and now > self.SeismicReady then
		self:_seismic(target, now)
	elseif
		distance > TSUNAMI.MinRange
		and distance < TSUNAMI.MaxRange
		and now > self.TsunamiReady
		and entity:GetHealthRatio() <= TSUNAMI.HealthFraction
	then
		self:_tsunami(target, now)
	elseif distance >= STOMP.MinRange and distance <= STOMP.MaxRange and now > self.StompReady then
		-- In the air the stomp is skipped, and so is the walk: the legacy chain ended here.
		if self:_nearGround() then
			self:_stomp(target, now)
		end
	elseif entity:IsRooted() then
		-- Rooted it cannot walk; everything above still happened.
		self.Handle.Halt()
	else
		self.Handle.Navigate(target.Root.Position)
	end
end

function QuakeBoss.Destroy(self: Self)
	table.clear(self.Timeline)
	self.Mover:Destroy()
	table.clear(self.Walls)
	for _, track in self.Tracks do
		track:Stop()
	end
	table.clear(self.Tracks)
end

return QuakeBoss
