--!strict
--[[
	The fire boss of the Burning Compass island (legacy ServerStorage.Bosses.FireBoss,
	AI_TestFlare). It hunts with Shave teleports and three Flare attacks; below 65 % health
	it turns to haki: every attack becomes Haki damage and is doubled. Numbers: BossConfig.FireBoss.

	Every think, in this order (as the legacy loop did):
	- target hugging it while the pillar recharges   Shave 30 studs away
	- target more than 65 studs above                lunge at it
	- target further than 14 studs                   Shave towards it (behind it when close)
	- within 50 studs, pillar ready                  Flame Pillar: 4 s charge, then a growing
	                                                 column travels to where the target stood
	- within 50 studs, wave ready                    Fire Wave: ring around the boss
	- within 500 studs, fist ready                   Fire Fist: 2 s charge, then a 57 stud fist
	- otherwise                                      walk at the target
	Charges do not stop it: the legacy "attacking" flag was never set, so it keeps
	teleporting and waving while a fist or a pillar is being charged. Kept.

	The fist and the pillar are not instances: they are points advanced by Think and tested
	with Hitbox against the tracked characters. Clients draw them (Boss* one-shot effects).

	Legacy problems fixed here:
	- The fist, the 16 wave walls and the pillar were server parts with Touched
	  connections, moved by the server every Heartbeat.
	- The pillar checked that the boss was alive before its 4 s charge instead of after:
	  a boss killed while charging still released it.
	- Two BodyMovers fought to keep the boss out of the sea; it is put back at its spawn
	  when it ends up in the water.
	- The loop recomputed a full path every Heartbeat whenever no attack was ready.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local BossConfig = require(ServerStorage.Server.Configs.BossConfig)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local BossTypes = require(ServerStorage.Server.Types.BossTypes)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

local CONFIG = BossConfig.FireBoss
local FIST = CONFIG.FireFist
local WAVE = CONFIG.FireWave
local PILLAR = CONFIG.FirePillar

-- CombatService discards NPC hits from further than this; such hits are dealt unattributed.
local NPC_DAMAGE_RANGE = 200
local WAVE_RING_THICKNESS = 5
local WAVE_HALF_HEIGHT = 6
local FLOOR_PROBE_UP = 10
local FLOOR_PROBE_DOWN = 20
local FLOOR_OFFSET = 3
local DASH_FORCE = Vector3.new(1e6, 1e6, 1e6)

type Charge = { EndsAt: number, Target: CharacterEntity }

type Fist = {
	Start: number,
	Origin: Vector3,
	Direction: Vector3,
	Travelled: number,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	Hit: { [CharacterEntity]: boolean },
}

type Wave = {
	Start: number,
	Center: Vector3,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	Hit: { [CharacterEntity]: boolean },
}

type Pillar = {
	Start: number,
	Origin: Vector3,
	Direction: Vector3,
	Distance: number,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	NextDamage: number,
}

local FireBoss = {}
FireBoss.__index = FireBoss

type Self = typeof(setmetatable(
	{} :: {
		Handle: BossTypes.BossHandle,
		Entity: CharacterEntity,
		Haki: boolean,

		FistReady: number,
		WaveReady: number,
		PillarReady: number,
		TeleportReady: number,
		DashReady: number,

		FistCharge: Charge?,
		PillarCharge: Charge?,
		Fists: { Fist },
		Waves: { Wave },
		Pillars: { Pillar },

		Tracks: { [string]: AnimationTrack },
		Velocity: LinearVelocity?,
		FloorParams: RaycastParams,
	},
	FireBoss
))

local function loadTracks(entity: CharacterEntity): { [string]: AnimationTrack }
	local animator = entity.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", entity.Humanoid)
	local fruitAnims: { [string]: string } = (AnimationConfig :: any).FruitAnims or {}
	local ids: { [string]: string? } = {
		ChargeRight = fruitAnims.ChargeRight,
		LoopRight = fruitAnims.LoopRight,
		PunchRight = fruitAnims.PunchRight,
		ChargeLeft = fruitAnims.ChargeLeft,
		LoopLeft = fruitAnims.LoopLeft,
		PunchLeft = fruitAnims.PunchLeft,
		Dash = (AnimationConfig :: any).Dash,
	}

	local tracks: { [string]: AnimationTrack } = {}
	for name, id in ids do
		if id then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			tracks[name] = animator:LoadAnimation(animation)
		end
	end
	return tracks
end

function FireBoss.new(handle: BossTypes.BossHandle): Self
	local entity = handle.Entity
	-- The model walks at 18; its Config.WalkSpeed (85) was only ever applied by the
	-- status scripts when a stun ended.
	entity:SetBaseWalkSpeed(CONFIG.WalkSpeed)

	local floorParams = RaycastParams.new()
	floorParams.FilterType = Enum.RaycastFilterType.Exclude
	floorParams.FilterDescendantsInstances = { entity.Model }

	return setmetatable({
		Handle = handle,
		Entity = entity,
		Haki = false,

		FistReady = 0,
		WaveReady = 0,
		PillarReady = 0,
		TeleportReady = 0,
		DashReady = 0,

		FistCharge = nil :: Charge?,
		PillarCharge = nil :: Charge?,
		Fists = {},
		Waves = {},
		Pillars = {},

		Tracks = loadTracks(entity),
		Velocity = nil :: LinearVelocity?,
		FloorParams = floorParams,
	}, FireBoss)
end

function FireBoss._play(self: Self, name: string)
	local track = self.Tracks[name]
	if track then
		track:Play()
	end
end

function FireBoss._stop(self: Self, name: string)
	local track = self.Tracks[name]
	if track then
		track:Stop()
	end
end

function FireBoss._effect(self: Self, name: string, origin: Vector3, params: { [string]: any })
	params.Haki = self.Haki
	params.Colors = CONFIG.Colors
	Knit.GetService("EffectService"):Play(name, origin, params)
end

function FireBoss._trait(self: Self): (CombatTypes.DamageTrait, number)
	if self.Haki then
		return "Haki", CONFIG.HakiMultiplier
	end
	return "Special", 1
end

function FireBoss._damage(self: Self, target: CharacterEntity, amount: number, trait: CombatTypes.DamageTrait): number
	local entity = self.Entity
	local inRange = not entity.Dead and (entity.Root.Position - target.Root.Position).Magnitude <= NPC_DAMAGE_RANGE
	return Knit.GetService("CombatService"):Damage({
		Target = target,
		Attacker = if inRange then entity else nil,
		Amount = amount,
		Trait = trait,
		Style = "Ability",
		Dodgeable = false,
	})
end

function FireBoss._partPosition(self: Self, name: string): Vector3
	local part = self.Entity.Model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part.Position else self.Entity.Root.Position
end

function FireBoss._face(self: Self, position: Vector3)
	local root = self.Entity.Root
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

-- Health lost so far as a ratio max / current, the way the legacy script scaled its Shave.
function FireBoss._missingScale(self: Self, limit: number): number
	local entity = self.Entity
	if entity.Health <= 0 then
		return limit
	end
	return math.clamp(entity.MaxHealth / entity.Health, 1, limit)
end

function FireBoss._floor(self: Self, position: Vector3): Vector3
	local result = Workspace:Raycast(
		position + Vector3.new(0, FLOOR_PROBE_UP, 0),
		Vector3.new(0, -FLOOR_PROBE_DOWN, 0),
		self.FloorParams
	)
	return if result then result.Position + Vector3.new(0, FLOOR_OFFSET, 0) else position
end

function FireBoss._shave(self: Self, destination: Vector3, lookAt: Vector3)
	local entity = self.Entity
	local from = entity.Root.Position
	local landing = self:_floor(destination)
	local flat = Vector3.new(lookAt.X, landing.Y, lookAt.Z)
	local cframe = if (flat - landing).Magnitude > 0.1 then CFrame.lookAt(landing, flat) else CFrame.new(landing)
	local rotation = entity.Root.CFrame.Rotation

	self.Handle.Halt()
	Knit.GetService("CharacterService"):Teleport(entity, cframe)
	-- The flash MovementService plays for a player's Shave.
	Knit.GetService("EffectService"):Play("Shave", from, {
		Caster = entity.Model,
		Destination = landing,
		Rotation = rotation,
		Rumble = false,
		Colors = "None",
	})
end

function FireBoss._stopDash(self: Self)
	local velocity = self.Velocity
	if velocity then
		self.Velocity = nil
		velocity:Destroy()
	end
	self:_stop("Dash")
end

function FireBoss._dash(self: Self, target: CharacterEntity)
	local root = self.Entity.Root
	local offset = target.Root.Position - root.Position
	if offset.Magnitude < 1e-3 then
		return
	end

	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = root
	end

	self:_stopDash()
	self:_play("Dash")
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment :: Attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.VectorVelocity = offset.Unit * math.clamp(offset.Magnitude, CONFIG.DashMinSpeed, CONFIG.DashMaxSpeed)
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = DASH_FORCE
	velocity.Parent = root
	self.Velocity = velocity
	task.delay(CONFIG.DashDuration, function()
		if self.Velocity == velocity then
			self:_stopDash()
		end
	end)
end

function FireBoss._startCharge(self: Self, side: "Right" | "Left", duration: number, target: CharacterEntity)
	local entity = self.Entity
	self.Handle.Halt()
	self:_face(target.Root.Position)
	self:_play(`Charge{side}`)
	self:_play(`Loop{side}`)
	self:_effect("BossCharge", entity.Root.Position, {
		Model = entity.Model,
		Arm = `{side} Arm`,
		Duration = duration,
	})
end

function FireBoss._releaseFist(self: Self, charge: Charge, now: number)
	local entity = self.Entity
	self:_stop("ChargeRight")
	self:_stop("LoopRight")
	self:_play("PunchRight")

	local origin = self:_partPosition("Right Arm")
	local target = charge.Target
	local direction = if target.Dead then entity.Root.CFrame.LookVector else target.Root.Position - entity.Root.Position
	if direction.Magnitude < 1e-3 then
		direction = entity.Root.CFrame.LookVector
	end
	direction = direction.Unit

	local trait, multiplier = self:_trait()
	table.insert(self.Fists, {
		Start = now,
		Origin = origin,
		Direction = direction,
		Travelled = 0,
		Damage = FIST.Damage * multiplier,
		Trait = trait,
		Hit = {},
	})
	self:_effect("BossFireFist", origin, {
		Direction = direction,
		Speed = FIST.Speed,
		Range = FIST.Speed * FIST.Lifetime,
		Size = FIST.Size,
	})
end

function FireBoss._castWave(self: Self, target: CharacterEntity, now: number)
	local entity = self.Entity
	self:_face(target.Root.Position)

	local trait, multiplier = self:_trait()
	local center = entity.Root.Position
	table.insert(self.Waves, {
		Start = now,
		Center = center,
		Damage = WAVE.Damage * multiplier,
		Trait = trait,
		Hit = {},
	})
	self:_effect("BossFireWave", center, {
		Radius = WAVE.Radius,
		ExpandTime = WAVE.ExpandTime,
		Lifetime = WAVE.Lifetime,
	})
end

function FireBoss._releasePillar(self: Self, charge: Charge, now: number)
	local entity = self.Entity
	self:_stop("ChargeLeft")
	self:_stop("LoopLeft")
	self:_play("PunchLeft")

	local origin = self:_partPosition("Left Arm")
	local target = charge.Target
	local offset = if target.Dead then entity.Root.CFrame.LookVector else target.Root.Position - origin
	if offset.Magnitude < 1e-3 then
		offset = entity.Root.CFrame.LookVector
	end

	local trait, multiplier = self:_trait()
	local distance = math.min(offset.Magnitude, PILLAR.Speed * PILLAR.MaxTravelTime)
	table.insert(self.Pillars, {
		Start = now,
		Origin = origin,
		Direction = offset.Unit,
		Distance = distance,
		Damage = PILLAR.Damage * multiplier,
		Trait = trait,
		NextDamage = now,
	})
	self:_effect("BossFirePillar", origin, {
		Direction = offset.Unit,
		Distance = distance,
		Speed = PILLAR.Speed,
		Size = PILLAR.Size,
		GrowTime = PILLAR.GrowTime,
		Lifetime = PILLAR.Lifetime,
	})
end

-- Advances everything already in the air. Runs on every think, target or not.
function FireBoss._updateVolumes(self: Self, now: number)
	local entity = self.Entity
	local fistRadius = FIST.Size / 2

	for index = #self.Fists, 1, -1 do
		local fist = self.Fists[index]
		local elapsed = now - fist.Start
		local reached = math.min(elapsed, FIST.Lifetime) * FIST.Speed
		-- Sample the stretch flown since the last think so a fast fist cannot skip anyone.
		local from = fist.Travelled
		local samples = math.max(1, math.ceil((reached - from) / fistRadius))
		for sample = 1, samples do
			local position = fist.Origin + fist.Direction * (from + (reached - from) * sample / samples)
			for _, target in Hitbox.Sphere(position, fistRadius, entity) do
				if not fist.Hit[target] then
					fist.Hit[target] = true
					if self:_damage(target, fist.Damage, fist.Trait) > 0 then
						target.AntiHealFraction = math.max(target.AntiHealFraction, FIST.AntiHealFraction)
						target.AntiHealHits = math.max(target.AntiHealHits, FIST.AntiHealHits)
					end
				end
			end
		end
		fist.Travelled = reached
		if elapsed >= FIST.Lifetime then
			table.remove(self.Fists, index)
		end
	end

	for index = #self.Waves, 1, -1 do
		local wave = self.Waves[index]
		local elapsed = now - wave.Start
		if elapsed > WAVE.Lifetime then
			table.remove(self.Waves, index)
			continue
		end

		-- While the ring expands everyone inside it has been swept; afterwards only
		-- those standing on it are touched.
		local expanding = elapsed < WAVE.ExpandTime
		local radius = WAVE.Radius * math.sin(math.min(elapsed / WAVE.ExpandTime, 1) * math.pi / 2)
		for _, target in Hitbox.Cylinder(wave.Center, radius + WAVE_RING_THICKNESS, WAVE_HALF_HEIGHT, entity) do
			if not wave.Hit[target] then
				local offset = target.Root.Position - wave.Center
				if expanding or Vector3.new(offset.X, 0, offset.Z).Magnitude >= radius - WAVE_RING_THICKNESS then
					wave.Hit[target] = true
					self:_damage(target, wave.Damage, wave.Trait)
				end
			end
		end
	end

	for index = #self.Pillars, 1, -1 do
		local pillar = self.Pillars[index]
		local elapsed = now - pillar.Start
		if elapsed > PILLAR.Lifetime then
			table.remove(self.Pillars, index)
			continue
		end
		if now < pillar.NextDamage then
			continue
		end
		pillar.NextDamage = now + PILLAR.DamageInterval

		local size = PILLAR.Size * math.min(elapsed / PILLAR.GrowTime, 1)
		local position = pillar.Origin + pillar.Direction * math.min(elapsed * PILLAR.Speed, pillar.Distance)
		for _, target in Hitbox.Box(CFrame.new(position), size, entity) do
			self:_damage(target, pillar.Damage, pillar.Trait)
		end
	end
end

function FireBoss.Think(self: Self, target: CharacterEntity?, distance: number, now: number)
	local entity = self.Entity
	self:_updateVolumes(now)
	if entity.Dead then
		return
	end

	if not self.Haki and entity:GetHealthRatio() < CONFIG.HakiHealthFraction then
		self.Haki = true
	end

	if entity.Root.Position.Y <= WorldConfig.SeaLevel then
		self.Handle.Halt()
		Knit.GetService("CharacterService"):Teleport(entity, self.Handle.Home)
	end

	local fistCharge = self.FistCharge
	if fistCharge and now >= fistCharge.EndsAt then
		self.FistCharge = nil
		self:_releaseFist(fistCharge, now)
	end
	local pillarCharge = self.PillarCharge
	if pillarCharge and now >= pillarCharge.EndsAt then
		self.PillarCharge = nil
		self:_releasePillar(pillarCharge, now)
	end

	if not target or entity:IsRooted() then
		return
	end

	local root = entity.Root
	local targetRoot = target.Root

	if distance < CONFIG.RetreatBelowDistance and now < self.PillarReady and now >= self.TeleportReady then
		local away = root.Position - targetRoot.Position
		away = if away.Magnitude > 1e-3 then away.Unit else -targetRoot.CFrame.LookVector
		self.TeleportReady = now + CONFIG.RetreatCooldown
		self:_shave(root.Position + away * CONFIG.RetreatDistance, targetRoot.Position)
	end

	if targetRoot.Position.Y - root.Position.Y > CONFIG.DashVerticalGap and now >= self.DashReady then
		self.DashReady = now + CONFIG.DashCooldown
		self:_dash(target)
	end

	if distance > CONFIG.TeleportMinDistance and now >= self.TeleportReady then
		local step = CONFIG.TeleportStep * self:_missingScale(CONFIG.TeleportStepMaxScale)
		local destination: Vector3
		if distance < step then
			destination = targetRoot.Position - targetRoot.CFrame.LookVector * CONFIG.TeleportBehind
		else
			destination = root.Position + (targetRoot.Position - root.Position).Unit * step
		end
		self.TeleportReady = now + CONFIG.TeleportCooldown * (1 - self:_missingScale(5) / 10)
		self:_shave(destination, targetRoot.Position)
	end

	if distance < PILLAR.Range and now >= self.PillarReady then
		self.PillarReady = now + PILLAR.Cooldown
		self.PillarCharge = { EndsAt = now + PILLAR.ChargeTime, Target = target }
		self:_startCharge("Left", PILLAR.ChargeTime, target)
	elseif distance < WAVE.Range and now >= self.WaveReady then
		self.WaveReady = now + WAVE.Cooldown
		self:_castWave(target, now)
	elseif distance < FIST.Range and now >= self.FistReady then
		self.FistReady = now + FIST.Cooldown
		self.FistCharge = { EndsAt = now + FIST.ChargeTime, Target = target }
		self:_startCharge("Right", FIST.ChargeTime, target)
	else
		self.Handle.Navigate(targetRoot.Position)
	end
end

function FireBoss.Destroy(self: Self)
	self:_stopDash()
	self.FistCharge = nil
	self.PillarCharge = nil
	-- Attacks still in the air end with the boss (the legacy parts kept burning):
	-- nothing thinks for them once the behaviour is gone.
	table.clear(self.Fists)
	table.clear(self.Waves)
	table.clear(self.Pillars)
	for _, track in self.Tracks do
		track:Stop()
	end
	table.clear(self.Tracks)
end

return FireBoss
