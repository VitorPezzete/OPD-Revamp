--!strict
--[[
	Lv2000 Vokun: never walks at its target. It steps back while winding up, then
	charges through it.

		wind-up   faces the target and backs off 8 studs                     2.5 s
		dash      160 studs/s towards where the target stands                0.6 s
		          hits (Config damage, Haki, not dodgeable) when the target is
		          within 25 studs as the dash starts
		recover   until 1.5 s after the dash started, then winds up again

	Touching it between dashes hurts like any other enemy (dodgeable, every 0.7 s).

	Legacy problems fixed here:
	- The script ran its own Heartbeat loop for the whole life of the model, target or not.
	- A Vokun stunned or rooted during the wind-up still dashed.
	- The model carries a "VokunField" barrier that its Button part removes when touched;
	  the legacy connection lived in a script inside the model and is recreated in new().
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local BossConfig = require(ServerStorage.Server.Configs.BossConfig)
local BossTypes = require(ServerStorage.Server.Types.BossTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

local CONFIG = BossConfig.Vokun
local DASH_FORCE = Vector3.new(1e6, 0, 1e6)

type Phase = "Idle" | "WindUp" | "Recover"

local Vokun = {}
Vokun.__index = Vokun

type Self = typeof(setmetatable(
	{} :: {
		Handle: BossTypes.BossHandle,
		Entity: CharacterEntity,
		Phase: Phase,
		PhaseEnds: number,
		Target: CharacterEntity?,
		NextContact: number,
		Velocity: LinearVelocity?,
		FieldConnection: RBXScriptConnection?,
	},
	Vokun
))

local function flatDirection(from: Vector3, to: Vector3): Vector3?
	local offset = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return if offset.Magnitude > 1e-3 then offset.Unit else nil
end

function Vokun.new(handle: BossTypes.BossHandle): Self
	local self = setmetatable({
		Handle = handle,
		Entity = handle.Entity,
		Phase = "Idle" :: Phase,
		PhaseEnds = 0,
		Target = nil :: CharacterEntity?,
		NextContact = 0,
		Velocity = nil :: LinearVelocity?,
		FieldConnection = nil :: RBXScriptConnection?,
	}, Vokun)

	-- Barrier shipped inside the model: touching its button drops the field for this life.
	local holder = handle.Entity.Model:FindFirstChild("VokunField")
	local field = holder and holder:FindFirstChild("VokunField")
	local button = field and field:FindFirstChild("Button")
	if field and button and button:IsA("BasePart") then
		self.FieldConnection = button.Touched:Once(function()
			local barrier = field:FindFirstChild("Field")
			if barrier then
				barrier:Destroy()
			end
		end)
	end

	return self
end

function Vokun._stopDash(self: Self)
	local velocity = self.Velocity
	if velocity then
		self.Velocity = nil
		velocity:Destroy()
	end
end

function Vokun._dash(self: Self, target: CharacterEntity)
	local entity = self.Entity
	local root = entity.Root
	local direction = flatDirection(root.Position, target.Root.Position)
	if not direction then
		return
	end

	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)

	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = root
	end

	self:_stopDash()
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment :: Attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.VectorVelocity = direction * CONFIG.DashSpeed
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

	if (target.Root.Position - root.Position).Magnitude <= CONFIG.DashHitRange then
		Knit.GetService("CombatService"):Damage({
			Target = target,
			Attacker = entity,
			Amount = self.Handle.Definition.Damage,
			Trait = self.Handle.Definition.DamageTrait,
			Style = "Ability",
			Dodgeable = false,
		})
	end
end

function Vokun.Think(self: Self, target: CharacterEntity?, distance: number, now: number)
	local entity = self.Entity
	if entity.Dead then
		return
	end

	-- A stun cancels whatever was being prepared.
	if entity:IsRooted() then
		self:_stopDash()
		self.Phase = "Idle"
		return
	end

	if target and distance <= CONFIG.ContactReach and now >= self.NextContact then
		self.NextContact = now + CONFIG.ContactCooldown
		Knit.GetService("CombatService"):Damage({
			Target = target,
			Attacker = entity,
			Amount = self.Handle.Definition.Damage,
			Trait = self.Handle.Definition.DamageTrait,
			Style = "Ability",
			Dodgeable = true,
		})
	end

	if self.Phase == "WindUp" then
		local locked = self.Target
		if not locked or locked.Dead then
			self.Phase = "Idle"
		elseif now >= self.PhaseEnds then
			self.Phase = "Recover"
			self.PhaseEnds = now + CONFIG.RecoverTime
			self.Handle.Halt()
			self:_dash(locked)
		end
		return
	elseif self.Phase == "Recover" then
		if now < self.PhaseEnds then
			return
		end
		self.Phase = "Idle"
	end

	if not target then
		return
	end

	local root = entity.Root
	local towards = flatDirection(root.Position, target.Root.Position)
	if towards then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + towards)
		-- Plain MoveTo: eight studs backwards never needs a path.
		entity.Humanoid:MoveTo(root.Position - towards * CONFIG.BackOffDistance)
	end
	self.Target = target
	self.Phase = "WindUp"
	self.PhaseEnds = now + CONFIG.WindUpTime
end

function Vokun.Destroy(self: Self)
	self:_stopDash()
	if self.FieldConnection then
		self.FieldConnection:Disconnect()
		self.FieldConnection = nil
	end
	self.Target = nil
end

return Vokun
