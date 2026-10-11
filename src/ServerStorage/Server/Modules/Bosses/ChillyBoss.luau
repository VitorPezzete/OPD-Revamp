--!strict
--[[
	The ice boss of the raids (legacy ServerStorage.Boss.Normal.ChillyBoss, AI_Chilly).
	It carries an ice blade, hunts with Shave teleports (see _RaidShared) and has four
	skills; after a handful of them it kneels, worn out, for 5 s. Below 45 % health it
	turns to haki: skills become Haki damage and everything is doubled.

	Its attacks used the levels written in the script, not the ones of the model's Config
	folder: Melee 800, Sniper 600, Sword 450, affinity 1.8 (m, s, w below are level / 500).

	Every think, in this order (as the legacy loop did):
	- target closer than 2.14 studs                  Shave 45 studs away
	- target 4 to 11 studs above, 2 to 5 below,
	  or more than 65 above                          lunge at it
	- target further than 14 studs                   Shave towards it
	- target closer than 5 studs                     blade swing
	- 10 to 300 studs, wave ready                    Ice Wave
	- 15 to 130 studs, punch ready                   Freezing Punch
	- 1 to 100 studs, rain ready                     Sword Rain
	- 5 to 50 studs, swords ready                    Ice Swords
	- otherwise                                      walk at the target
	The distance is the one measured before the Shave, as in the legacy loop: a boss that
	has just landed behind its target still picks the skill of the range it came from.

	Blade swing    0.1 s wind-up, box 6 x 6 x 8 ahead of the right arm, 600 * 1.8 * w
	               (972), Sword, dodgeable; doubled with haki but still Sword. Every 0.6 s.
	Ice Wave       0.6 s charge, then five spikes 0.2 s apart: cube i has a side of
	               27 * 1.8 * s * i (58 to 292 studs) and hurts for 0.35 s. Each spike
	               freezes whoever it touches for 3.5 * s * 1.8 s (7.56) at 125 * s * 1.8
	               (270) per second, or, when the freeze does not take, deals 600 * 1.8
	               (1080). Stun 0.5 s. Cooldown 8 s.
	Freezing Punch 0.75 s charge, then an ice ball thrown at where the target will be in
	               half a second, 315 studs/s. It is a real physical part, as the player's
	               (Abilities/Chilly/Freezing Punch): it falls, bounces and rolls for 5 s.
	               350 * m * 1.8 (1008), dodgeable, then a freeze of 3.5 * m * 1.8 s
	               (10.08) at a quarter of that damage per second. Stun 0.5 s. Cooldown 6 s.
	Sword Rain     16 blades, one every 0.08 to 0.15 s, falling in 0.45 s from 45 studs
	               onto a random spot within 12 studs of where the target is at that
	               moment. 350 * 1.8 * w (567) within 8 studs, stun 0.4 s. Cooldown 15 s.
	Ice Swords     4 to 6 blades, 0.15 s apart, that home on the target at 65 studs/s for
	               6 s. 600 * 1.8 * w (972) at 5 studs, then a 2 s freeze at a tenth of
	               that per second. Cooldown 8 s.

	Freeze: the victim is stunned and takes its damage once a second, the first one at
	once. The boss can freeze only once every 12 s, and a victim cannot be frozen again
	until 12 s after it thawed. The ice shell is the player fruit's (status
	"ChillyPunched"); the legacy boss ignored the Quake / Luck immunity of the fruit.

	Kneeling: after 3 to 6 skills (4 to 8 from the second time on) it kneels for 5 s and
	does nothing.

	Legacy problems fixed here:
	- The spikes, the falling blades and the homing blades were server parts, each with
	  its own thread or Heartbeat connection. They are numbers advanced by Think; clients
	  draw them (ChillyIceWave, BossChillySwordRain, BossChillyIceSword).
	- The freeze ran in a thread of the boss script: a boss killed while someone was
	  frozen left that player unable to walk or jump for good. Victims thaw with the boss.
	- Ice Swords built the trail of each blade with Color3.fromRGB(<a Color3>), which
	  throws: the thread died on the first blade, before it was given its steering, so
	  the legacy skill only ever left one frozen blade hanging next to the boss and hurt
	  nobody. The skill is written as it was meant to work; SWORDS.Enabled = false gives
	  back the legacy result (the cooldown and the kneel count, no blades).
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local World = require(ReplicatedStorage.Shared.Util.World)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local BossTypes = require(ServerStorage.Server.Types.BossTypes)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Shared = require(script.Parent._RaidShared)

type CharacterEntity = CharacterEntity.CharacterEntity

local LEVEL_CAP = 500
local AFFINITY = 1.8
local MELEE = 800 / LEVEL_CAP
local SNIPER_LEVEL = 600
local SNIPER = SNIPER_LEVEL / LEVEL_CAP
local SWORD = 450 / LEVEL_CAP

-- Walk speed of the legacy model's Humanoid; its Config.WalkSpeed (85) was never applied.
local WALK_SPEED = 18
local HAKI_HEALTH_FRACTION = 0.45
-- The legacy default of the fruit: both colors the same pale blue.
local COLORS = "128,187,219,128,187,219"
local KNEEL_ANIMATION = "rbxassetid://78262245057660"
local KNEEL_ROOT = "ChillyBossKneel"
local KNEEL_TIME = 5

local RETREAT_BELOW_DISTANCE = 2.14159265359
local SWING_RANGE = 5

local SWING = {
	Interval = 0.6,
	WindUp = 0.1,
	Recover = 0.3,
	Damage = 600 * AFFINITY * SWORD,
	Size = Vector3.new(6, 6, 8),
	-- Right arm at rest (1.5 studs right of the root), then 3 studs ahead of it.
	Offset = CFrame.new(1.5, 0, -3),
	AnimationSpeed = 8,
}

local WAVE = {
	MinRange = 10,
	MaxRange = 300,
	Cooldown = 8,
	ChargeTime = 0.6,
	Count = 5,
	Interval = 0.2,
	Lifetime = 3,
	-- A spike is checked every 0.1 s for 0.35 s.
	Checks = 4,
	CheckInterval = 0.1,
	BaseSize = 27 * AFFINITY * SNIPER,
	Damage = SNIPER_LEVEL * AFFINITY,
	FreezeDamage = 125 * SNIPER * AFFINITY,
	FreezeDuration = 3.5 * SNIPER * AFFINITY,
	Stun = 0.5,
	ReleaseSpeed = 5,
}

local PUNCH = {
	MinRange = 15,
	MaxRange = 130,
	Cooldown = 6,
	ChargeTime = 0.75,
	Recover = 0.5,
	-- The iced fist stays 0.55 s after the throw.
	HandTime = 0.75 + 0.55,
	Speed = 350 * AFFINITY / 2,
	Lead = 0.5,
	SizeScale = MELEE / math.max(0.1, 3 - AFFINITY),
	Damage = 350 * MELEE * AFFINITY,
	FreezeDuration = 3.5 * MELEE * AFFINITY,
	FreezeDamageFraction = 1 / 4,
	Stun = 0.5,
	SolidDelay = 0.1,
	Lifetime = 5,
	-- Share of the velocity kept per legacy frame, and the frame rate it was tuned at.
	Decay = 0.999995,
	DecayRate = 60,
	StopSpeed = 5,
	ReleaseSpeed = 2,
}

local RAIN = {
	MinRange = 1,
	MaxRange = 100,
	Cooldown = 15,
	Count = 16,
	Scatter = 12,
	Height = 45,
	Sink = 2,
	FallTime = 0.45,
	Radius = 8,
	Damage = 350 * AFFINITY * SWORD,
	Stun = 0.4,
	-- Hundredths of a second between two blades.
	MinGap = 8,
	MaxGap = 15,
}

local SWORDS = {
	-- See the header: the legacy skill never got past its first blade.
	Enabled = true,
	MinRange = 5,
	MaxRange = 50,
	Cooldown = 8,
	MinCount = 4,
	MaxCount = 6,
	Gap = 0.15,
	Speed = 65,
	-- Share of the turn towards the target made per legacy frame.
	Turn = 0.15,
	FrameRate = 60,
	Duration = 6,
	HitRange = 5,
	Damage = 600 * AFFINITY * SWORD,
	FreezeDuration = 2,
	FreezeDamageFraction = 1 / 10,
}

local FREEZE_COOLDOWN = 12
local FREEZE_IMMUNITY = 12
local FREEZE_STUN_EXTRA = 0.2
local FREEZE_TICK = 1
local FROZEN_STATUS = "ChillyPunched"
local SWORD_STATUS = "ChillySword"
local PUNCH_STATUS = "ChillyPunchCharging"
local IMMUNITY_STATUS = "ChillyBossFreezeImmunity"
local FREEZE_STUN = "ChillyBossFrozen"
local FREEZE_DOT = "ChillyBossFreezeDot"
local HIT_STUN = "ChillyBossHit"

-- Same body allowance as Hitbox.
local BODY_RADIUS = 2.5
-- Used only when the Rock1 template cannot be found (guess, as in Freezing Punch).
local BALL_DEFAULT_SIZE = Vector3.new(6, 6, 6)
local BALL_MIN_SIZE = 0.05
-- Longest stretch of homing simulated in one think (a boss nobody is near thinks rarely).
local MAX_SIM_STEP = 0.5

type Ball = {
	Part: BasePart,
	Born: number,
	Last: Vector3,
	Updated: number,
	Radius: number,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	Hit: { [CharacterEntity]: boolean },
}

type HomingSword = {
	Born: number,
	Position: Vector3,
	Look: Vector3,
	Target: CharacterEntity,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
}

local ChillyBoss = {}
ChillyBoss.__index = ChillyBoss

type Self = typeof(setmetatable(
	{} :: {
		Handle: BossTypes.BossHandle,
		Entity: CharacterEntity,
		Mover: Shared.Mover,
		Timeline: Shared.Timeline,
		Tracks: { [string]: AnimationTrack },
		Random: Random,
		Haki: boolean,

		-- The legacy loop yielded inside its skills: nothing is decided before BusyUntil.
		BusyUntil: number,
		-- The legacy "attacking" flag, which outlives the yield for some skills.
		AttackingUntil: number,
		Kneeling: boolean,
		SkillsUsed: number,
		KneelAfter: number,

		WaveReady: number,
		PunchReady: number,
		RainReady: number,
		SwordsReady: number,
		FreezeReady: number,
		LastSwing: number,
		SecondSwing: boolean,

		Balls: { Ball },
		Swords: { HomingSword },
		SwordsUpdated: number,
		Frozen: { [CharacterEntity]: number },
	},
	ChillyBoss
))

local function findBallTemplate(): BasePart?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", "Chilly", "Power2", "Rock1" } do
		current = current and current:FindFirstChild(name)
	end
	return if current and current:IsA("BasePart") then current else nil
end

--[[
	The ice ball, built as the player's is: the Rock1 mesh collides as its bounding box,
	so it is only the look, welded inside an invisible sphere that carries the physics.
]]
local function makeBall(sizeScale: number, color: Color3, cframe: CFrame): BasePart
	local body = Instance.new("Part")
	body.Name = "ChillyBossIceBall"
	body.Shape = Enum.PartType.Ball
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Anchored = false
	body.CanCollide = false
	body.CanTouch = false
	body.CFrame = cframe

	local template = findBallTemplate()
	if not template then
		local diameter = math.max(BALL_DEFAULT_SIZE.X * sizeScale, BALL_MIN_SIZE)
		body.Size = Vector3.new(diameter, diameter, diameter)
		body.Material = Enum.Material.Ice
		body.Color = color
		return body
	end

	local mesh = template:Clone()
	for _, descendant in mesh:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("ValueBase") then
			descendant:Destroy()
		end
	end
	local size = mesh.Size * sizeScale
	mesh.Size = Vector3.new(
		math.max(size.X, BALL_MIN_SIZE),
		math.max(size.Y, BALL_MIN_SIZE),
		math.max(size.Z, BALL_MIN_SIZE)
	)
	mesh.Color = color
	mesh.Name = "Rock"
	mesh.Anchored = false
	mesh.CanCollide = false
	mesh.CanTouch = false
	mesh.CanQuery = false
	mesh.Massless = true
	mesh.CFrame = cframe

	local diameter = (mesh.Size.X + mesh.Size.Y + mesh.Size.Z) / 3
	body.Size = Vector3.new(diameter, diameter, diameter)
	body.Transparency = 1
	body.CastShadow = false
	body.Material = mesh.Material
	body.CustomPhysicalProperties = mesh.CustomPhysicalProperties

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = mesh
	weld.Parent = mesh
	mesh.Parent = body
	return body
end

function ChillyBoss.new(handle: BossTypes.BossHandle): Self
	local entity = handle.Entity
	entity:SetBaseWalkSpeed(WALK_SPEED)

	local config: any = AnimationConfig
	local fruitAnims: { [string]: string } = config.FruitAnims or {}
	local folder = entity.Model:FindFirstChild("Animations")
	local kneeling = folder and folder:FindFirstChild("Kneeling")
	local tracks = Shared.LoadTracks(entity, {
		Charge = fruitAnims.Punch1RightCharge,
		Release = fruitAnims.Punch1RightPunch,
		Dash = config.Dash,
		Swing1 = config.Dagger1,
		Swing2 = config.Dagger2,
		Kneel = if kneeling and kneeling:IsA("Animation") then kneeling.AnimationId else KNEEL_ANIMATION,
	})

	local random = Random.new()
	local self = setmetatable({
		Handle = handle,
		Entity = entity,
		Mover = Shared.NewMover(handle, tracks.Dash),
		Timeline = {},
		Tracks = tracks,
		Random = random,
		Haki = false,

		BusyUntil = 0,
		AttackingUntil = 0,
		Kneeling = false,
		SkillsUsed = 0,
		KneelAfter = random:NextInteger(3, 6),

		WaveReady = 0,
		PunchReady = 0,
		RainReady = 0,
		SwordsReady = 0,
		FreezeReady = 0,
		LastSwing = 0,
		SecondSwing = false,

		Balls = {},
		Swords = {},
		SwordsUpdated = os.clock(),
		Frozen = {},
	}, ChillyBoss)

	-- The blade is the player fruit's status effect; the two slot fields are the owner's
	-- click address, which an NPC does not have.
	entity:SetStatus(SWORD_STATUS, `;;{COLORS}`, nil, true)
	return self
end

function ChillyBoss._colors(self: Self): string
	return if self.Haki then Shared.HAKI_COLORS else COLORS
end

function ChillyBoss._trait(self: Self): (CombatTypes.DamageTrait, number)
	if self.Haki then
		return "Haki", Shared.HAKI_MULTIPLIER
	end
	return "Special", 1
end

function ChillyBoss._play(self: Self, name: string, speed: number?)
	local track = self.Tracks[name]
	if track then
		track:Play(nil, nil, speed)
	end
end

function ChillyBoss._stop(self: Self, name: string)
	local track = self.Tracks[name]
	if track then
		track:Stop()
	end
end

function ChillyBoss._effect(self: Self, name: string, origin: Vector3, params: { [string]: any }, haki: boolean, radius: number?)
	params.Haki = haki
	params.Colors = if haki then Shared.HAKI_COLORS else COLORS
	params.Caster = self.Entity.Model
	Knit.GetService("EffectService"):Play(name, origin, params, radius)
end

-- Returns whether the target froze (see the header for the two cooldowns).
function ChillyBoss._freeze(self: Self, target: CharacterEntity, duration: number, damagePerSecond: number): boolean
	local now = os.clock()
	if now < self.FreezeReady or Shared.Gone(target) or not target.Player then
		return false
	end
	if target:HasStatus(FROZEN_STATUS) or target:HasStatus(IMMUNITY_STATUS) then
		return false
	end
	self.FreezeReady = now + FREEZE_COOLDOWN

	local entity = self.Entity
	local status = Knit.GetService("StatusService")
	target:SetStatus(IMMUNITY_STATUS, true, duration + FREEZE_IMMUNITY)
	status:ApplyStun(target, duration + FREEZE_STUN_EXTRA, FREEZE_STUN)
	target:SetStatus(FROZEN_STATUS, self:_colors(), duration, true)
	self.Frozen[target] = now + duration + FREEZE_STUN_EXTRA

	Shared.Damage(entity, target, damagePerSecond, "Special", false, "Ability", FROZEN_STATUS)
	local remainingTicks = math.ceil(duration / FREEZE_TICK) - 1
	if remainingTicks > 0 and not target.Dead then
		status:ApplyDot(target, FREEZE_DOT, {
			Source = entity,
			Damage = damagePerSecond,
			Interval = FREEZE_TICK,
			Ticks = remainingTicks,
			Trait = "Special",
		})
	end
	return true
end

function ChillyBoss._startKneel(self: Self, now: number)
	local entity = self.Entity
	self.Kneeling = true
	self.BusyUntil = now + KNEEL_TIME
	self.AttackingUntil = now + KNEEL_TIME
	self.Handle.Halt()
	entity:SetRooted(KNEEL_ROOT, true)
	entity.Humanoid.AutoRotate = false
	self:_play("Kneel")

	Shared.After(self.Timeline, now + KNEEL_TIME, function()
		self:_endKneel()
		self.KneelAfter = self.Random:NextInteger(4, 8)
		self.SkillsUsed = 0
	end)
end

function ChillyBoss._endKneel(self: Self)
	if not self.Kneeling then
		return
	end
	self.Kneeling = false
	self:_stop("Kneel")
	local entity = self.Entity
	entity:SetRooted(KNEEL_ROOT, false)
	if entity.Humanoid.Parent then
		entity.Humanoid.AutoRotate = true
	end
end

function ChillyBoss._swing(self: Self, now: number)
	local entity = self.Entity
	self.LastSwing = now
	self.BusyUntil = now + SWING.WindUp + SWING.Recover
	self.AttackingUntil = self.BusyUntil

	self.SecondSwing = not self.SecondSwing
	self:_play(if self.SecondSwing then "Swing1" else "Swing2", SWING.AnimationSpeed)

	local multiplier = if self.Haki then Shared.HAKI_MULTIPLIER else 1
	Shared.After(self.Timeline, now + SWING.WindUp, function()
		for _, target in Shared.Players(Hitbox.Box(entity.Root.CFrame * SWING.Offset, SWING.Size, entity)) do
			-- The legacy call named no style: no resistance perk applies.
			Shared.Damage(entity, target, SWING.Damage * multiplier, "Sword", true, "Plain")
		end
	end)
end

function ChillyBoss._wave(self: Self, target: CharacterEntity, now: number)
	local entity = self.Entity
	local haki = self.Haki
	self.SkillsUsed += 1
	self.BusyUntil = now + WAVE.ChargeTime
	self.AttackingUntil = now + WAVE.ChargeTime + WAVE.Count * WAVE.Interval
	self.WaveReady = now + WAVE.ChargeTime + WAVE.Cooldown

	Shared.Face(entity, target.Root.Position)
	self:_play("Charge")
	self:_effect("BossChillyFrost", entity.Root.Position, {
		Model = entity.Model,
		Arm = "Right Arm",
		Duration = WAVE.ChargeTime,
	}, haki)

	Shared.After(self.Timeline, now + WAVE.ChargeTime, function(at: number)
		self:_stop("Charge")
		self:_play("Release", WAVE.ReleaseSpeed)

		local origin = entity.Root.Position
		local direction = target.Root.Position - origin
		direction = if direction.Magnitude > 0.05 then direction.Unit else entity.Root.CFrame.LookVector
		local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis

		self:_effect("ChillyIceWave", origin, {
			Direction = direction,
			BaseSize = WAVE.BaseSize,
			Count = WAVE.Count,
			Interval = WAVE.Interval,
			Lifetime = WAVE.Lifetime,
		}, haki, WAVE.BaseSize * WAVE.Count * WAVE.Count)

		local damage = WAVE.Damage * (if haki then Shared.HAKI_MULTIPLIER else 1)
		local trait: CombatTypes.DamageTrait = if haki then "Haki" else "Special"
		local center = origin
		for index = 1, WAVE.Count do
			local length = WAVE.BaseSize * index
			center += direction * (length / 2)
			local cframe = CFrame.lookAt(center, center + direction, up)
			local size = Vector3.new(length, length, length)
			-- Each spike has its own hit list: one target can be caught by all five.
			local hit: { [CharacterEntity]: boolean } = {}
			for check = 0, WAVE.Checks - 1 do
				local due = at + (index - 1) * WAVE.Interval + check * WAVE.CheckInterval
				Shared.After(self.Timeline, due, function()
					for _, victim in Shared.Players(Hitbox.Box(cframe, size, entity)) do
						if not hit[victim] then
							hit[victim] = true
							if not self:_freeze(victim, WAVE.FreezeDuration, WAVE.FreezeDamage) then
								Shared.Damage(entity, victim, damage, trait, false, "Plain")
							end
							Shared.Stun(victim, WAVE.Stun, HIT_STUN)
						end
					end
				end)
			end
		end
	end)
end

function ChillyBoss._punch(self: Self, target: CharacterEntity, now: number)
	local entity = self.Entity
	self.SkillsUsed += 1
	self.BusyUntil = now + PUNCH.ChargeTime + PUNCH.Recover
	self.AttackingUntil = self.BusyUntil
	self.PunchReady = now + PUNCH.ChargeTime + PUNCH.Cooldown

	Shared.Face(entity, target.Root.Position)
	self:_play("Charge")
	-- The iced fist of the player's Freezing Punch.
	entity:SetStatus(PUNCH_STATUS, `Right|{self:_colors()}`, PUNCH.HandTime, true)

	Shared.After(self.Timeline, now + PUNCH.ChargeTime, function(at: number)
		self:_stop("Charge")
		self:_play("Release", PUNCH.ReleaseSpeed)
		self:_throwBall(target, at)
	end)
end

function ChillyBoss._throwBall(self: Self, target: CharacterEntity, now: number)
	local entity = self.Entity
	local hand = Shared.LimbCFrame(entity, "Right Arm") * CFrame.new(0, -1, 0)
	local targetRoot = target.Root
	local aim = targetRoot.Position + targetRoot.AssemblyLinearVelocity * PUNCH.Lead
	local direction = aim - hand.Position
	direction = if direction.Magnitude > 0.05 then direction.Unit else entity.Root.CFrame.LookVector

	local trait, multiplier = self:_trait()
	local color = if self.Haki then Color3.fromRGB(25, 12, 25) else Color3.fromRGB(128, 187, 219)
	local part = makeBall(PUNCH.SizeScale, color, hand)
	part.Parent = World.Abilities()
	-- Simulated by the server for everyone, as the legacy part was.
	part:SetNetworkOwner(nil)
	part.AssemblyLinearVelocity = direction * PUNCH.Speed
	Debris:AddItem(part, PUNCH.Lifetime)

	table.insert(self.Balls, {
		Part = part,
		Born = now,
		Last = part.Position,
		Updated = now,
		Radius = part.Size.X / 2,
		Damage = PUNCH.Damage * multiplier,
		Trait = trait,
		Hit = {},
	})
	Shared.After(self.Timeline, now + PUNCH.SolidDelay, function()
		if part.Parent then
			part.CanCollide = true
		end
	end)
end

-- The balls in the world: whoever one rolled through since the last think is hit once.
function ChillyBoss._updateBalls(self: Self, now: number)
	local entity = self.Entity
	for index = #self.Balls, 1, -1 do
		local ball = self.Balls[index]
		local part = ball.Part
		if not part.Parent then
			table.remove(self.Balls, index)
			continue
		end

		local velocity = part.AssemblyLinearVelocity * PUNCH.Decay ^ ((now - ball.Updated) * PUNCH.DecayRate)
		ball.Updated = now
		if velocity.Magnitude < PUNCH.StopSpeed then
			-- The legacy ball vanished as soon as it had stopped.
			part:Destroy()
			table.remove(self.Balls, index)
			continue
		end
		part.AssemblyLinearVelocity = velocity

		local from, to = ball.Last, part.Position
		ball.Last = to
		local segment = to - from
		local lengthSquared = segment:Dot(segment)
		local reach = ball.Radius + BODY_RADIUS
		for _, target in Shared.Players(Hitbox.Sphere((from + to) / 2, segment.Magnitude / 2 + ball.Radius, entity)) do
			if ball.Hit[target] then
				continue
			end
			local offset = target.Root.Position - from
			local along = if lengthSquared > 0 then math.clamp(offset:Dot(segment) / lengthSquared, 0, 1) else 0
			if (offset - segment * along).Magnitude <= reach then
				ball.Hit[target] = true
				Shared.Damage(entity, target, ball.Damage, ball.Trait, true, "Plain")
				self:_freeze(target, PUNCH.FreezeDuration, ball.Damage * PUNCH.FreezeDamageFraction)
				Shared.Stun(target, PUNCH.Stun, HIT_STUN)
			end
		end
	end
end

function ChillyBoss._rain(self: Self, target: CharacterEntity, now: number)
	local entity = self.Entity
	self.SkillsUsed += 1
	self.RainReady = now + RAIN.Cooldown
	Shared.Face(entity, target.Root.Position)

	local haki = self.Haki
	local trait, multiplier = self:_trait()
	local damage = RAIN.Damage * multiplier
	local random = self.Random

	local function drop(index: number, at: number)
		if Shared.Gone(target) or not target.Spawned then
			return
		end
		local around = target.Root.Position
		local start = around
			+ Vector3.new(
				random:NextInteger(-RAIN.Scatter, RAIN.Scatter),
				RAIN.Height,
				random:NextInteger(-RAIN.Scatter, RAIN.Scatter)
			)
		local landing = Vector3.new(start.X, around.Y - RAIN.Sink, start.Z)

		self:_effect("BossChillySwordRain", start, {
			Landing = landing,
			FallTime = RAIN.FallTime,
			Radius = RAIN.Radius,
		}, haki)
		Shared.After(self.Timeline, at + RAIN.FallTime, function()
			for _, victim in Shared.Players(Hitbox.Sphere(landing, RAIN.Radius, entity)) do
				Shared.Damage(entity, victim, damage, trait, false, "Plain")
				Shared.Stun(victim, RAIN.Stun, HIT_STUN)
			end
		end)

		if index < RAIN.Count then
			local gap = random:NextInteger(RAIN.MinGap, RAIN.MaxGap) / 100
			Shared.After(self.Timeline, at + gap, function(due: number)
				drop(index + 1, due)
			end)
		end
	end
	drop(1, now)
end

function ChillyBoss._iceSwords(self: Self, target: CharacterEntity, now: number)
	local entity = self.Entity
	self.SkillsUsed += 1
	self.SwordsReady = now + SWORDS.Cooldown
	Shared.Face(entity, target.Root.Position)
	if not SWORDS.Enabled then
		return
	end

	local haki = self.Haki
	local trait, multiplier = self:_trait()
	local random = self.Random
	local count = random:NextInteger(SWORDS.MinCount, SWORDS.MaxCount)

	for index = 1, count do
		Shared.After(self.Timeline, now + (index - 1) * SWORDS.Gap, function(at: number)
			if Shared.Gone(target) or not target.Spawned or entity.Dead then
				return
			end
			local start = entity.Root.Position
				+ Vector3.new(random:NextInteger(-6, 6), random:NextInteger(4, 8), random:NextInteger(-6, 6))
			local look = target.Root.Position + Vector3.new(0, 5, 0) - start
			look = if look.Magnitude > 0.05 then look.Unit else entity.Root.CFrame.LookVector

			table.insert(self.Swords, {
				Born = at,
				Position = start,
				Look = look,
				Target = target,
				Damage = SWORDS.Damage * multiplier,
				Trait = trait,
			})
			self:_effect("BossChillyIceSword", start, {
				Target = target.Model,
				Look = look,
				Speed = SWORDS.Speed,
				Turn = SWORDS.Turn,
				Duration = SWORDS.Duration,
				HitRange = SWORDS.HitRange,
			}, haki)
		end)
	end
end

-- Homing blades: the legacy per-frame steering, replayed for the time since the last think.
function ChillyBoss._updateSwords(self: Self, now: number)
	local elapsed = math.min(now - self.SwordsUpdated, MAX_SIM_STEP)
	self.SwordsUpdated = now
	if #self.Swords == 0 or elapsed <= 0 then
		return
	end

	local entity = self.Entity
	local frames = math.max(1, math.round(elapsed * SWORDS.FrameRate))
	local stride = SWORDS.Speed * elapsed / frames
	for index = #self.Swords, 1, -1 do
		local sword = self.Swords[index]
		local target = sword.Target
		if Shared.Gone(target) or not target.Spawned or now - sword.Born >= SWORDS.Duration then
			table.remove(self.Swords, index)
			continue
		end

		local goal = target.Root.Position
		local struck = false
		for _ = 1, frames do
			local wanted = goal - sword.Position
			if wanted.Magnitude > 1e-3 then
				local look = sword.Look:Lerp(wanted.Unit, SWORDS.Turn)
				-- Facing exactly away: any turn will do, the next frame sorts it out.
				sword.Look = if look.Magnitude > 1e-3 then look.Unit else wanted.Unit
			end
			sword.Position += sword.Look * stride
			if (sword.Position - goal).Magnitude < SWORDS.HitRange then
				struck = true
				break
			end
		end

		if struck then
			table.remove(self.Swords, index)
			Shared.Damage(entity, target, sword.Damage, sword.Trait, false, "Plain")
			self:_freeze(target, SWORDS.FreezeDuration, sword.Damage * SWORDS.FreezeDamageFraction)
		end
	end
end

function ChillyBoss.Think(self: Self, target: CharacterEntity?, distance: number, now: number)
	local entity = self.Entity
	-- A model destroyed without a death leaves EnemyService thinking for it: end here,
	-- before anything already scheduled lands.
	if Shared.Gone(entity) then
		(self :: any):Destroy()
		return
	end
	Shared.RunDue(self.Timeline, now)
	self:_updateBalls(now)
	self:_updateSwords(now)
	if entity.Dead then
		return
	end
	self.Mover:Update(target, now)

	if not self.Haki and entity:GetHealthRatio() < HAKI_HEALTH_FRACTION then
		self.Haki = true
		-- The blade turns dark with it.
		entity:SetStatus(SWORD_STATUS, `;;{Shared.HAKI_COLORS}`, nil, true)
	end

	if now < self.BusyUntil then
		return
	end
	local attacking = now < self.AttackingUntil
	if not attacking and self.SkillsUsed >= self.KneelAfter then
		self:_startKneel(now)
		return
	end
	-- A stun does not stop it: the legacy AI never looked at one (kneeling is BusyUntil).
	if not target then
		return
	end

	local mover = self.Mover
	local height = target.Root.Position.Y - entity.Root.Position.Y

	if distance < RETREAT_BELOW_DISTANCE then
		mover:ShaveAway(target, now)
	end
	if not attacking and ((height > 4 and height < 11) or (height < -2 and height > -5) or height > 65) then
		mover:Dash(target, now)
	end
	mover:ShaveTowards(target, distance, now)

	if distance < SWING_RANGE and not attacking and now - self.LastSwing >= SWING.Interval then
		self:_swing(now)
		return
	end

	-- A skill that is ready but refused because another one is still running costs the
	-- think: the legacy chain did not fall through to the next branch either.
	if distance > WAVE.MinRange and distance < WAVE.MaxRange and now > self.WaveReady then
		if not attacking then
			self:_wave(target, now)
		end
	elseif distance > PUNCH.MinRange and distance < PUNCH.MaxRange and now > self.PunchReady then
		if not attacking then
			self:_punch(target, now)
		end
	elseif distance > RAIN.MinRange and distance < RAIN.MaxRange and now > self.RainReady then
		if not attacking then
			self:_rain(target, now)
		end
	elseif distance > SWORDS.MinRange and distance < SWORDS.MaxRange and now > self.SwordsReady then
		self:_iceSwords(target, now)
	elseif not attacking then
		if entity:IsRooted() then
			-- Rooted it cannot walk; everything above still happened.
			self.Handle.Halt()
		else
			self.Handle.Navigate(target.Root.Position)
		end
	end
end

function ChillyBoss.Destroy(self: Self)
	table.clear(self.Timeline)
	self:_endKneel()
	self.Mover:Destroy()

	for _, ball in self.Balls do
		ball.Part:Destroy()
	end
	table.clear(self.Balls)
	table.clear(self.Swords)

	-- Whoever is still frozen thaws with the boss.
	local now = os.clock()
	local status = Knit.GetService("StatusService")
	for victim, thawsAt in self.Frozen do
		if now < thawsAt and not victim.Dead then
			status:Clear(victim, FREEZE_STUN)
			status:Clear(victim, FREEZE_DOT)
			victim:ClearStatus(FROZEN_STATUS)
		end
	end
	table.clear(self.Frozen)

	local entity = self.Entity
	entity:ClearStatus(SWORD_STATUS)
	entity:ClearStatus(PUNCH_STATUS)
	for _, track in self.Tracks do
		track:Stop()
	end
	table.clear(self.Tracks)
end

return ChillyBoss
