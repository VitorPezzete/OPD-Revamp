--!strict
--[[
	Smoke fruit - White Out: a trail of smoke leaves the caster's arms towards every
	character around and holds in place the ones it reaches.

	With f = (melee level / cap) * melee affinity:
	- Targets: everyone within 150 * f studs when the key is pressed.
	- Each trail homes on its target at 45 * f studs per second for at most 10s and
	  catches it within 1.5 studs. The legacy loop moved 1.5 * f studs per step with
	  `task.wait(.025)` between steps, which resumes every second frame of a 60 Hz
	  server: 30 steps a second, 300 steps in all. A slow caster's smoke can be
	  outrun, as before.
	- A caught target cannot move for 5s. No damage.
	- Everyone in range is chased, crew mates included, as before.
	- 15s cooldown, started by the press even when nobody is in range.

	The chase is simulated here as points (one bounded 0.1s tick for all trails, at most
	10s); clients draw the same chase themselves (Effects.OneShot.SmokeWhiteOut). The
	hold is a StatusService slow of scale 0 plus the replicated "SmokeWhiteOutHeld"
	status, whose effect pins the victim's own character and shows the smoke around it.
	Both expire on their own, so a hold already applied outlives the caster's interrupt
	(the legacy BodyPosition did too); trails still in flight are cancelled.
	An NPC is simulated here, so it gets the legacy mover itself: a BodyPosition (infinite
	force, P = 10000) holding it 2 studs above the point where the smoke caught it.

	Legacy problems fixed here:
	- Every trail was a server loop of 300 steps with an Attachment on Terrain, a sound
	  and a BodyPosition parented into the victim.
	- The arms were hidden by setting Transparency = 1 on the server and "restored" to 0
	  after 5s, which also revealed parts that were meant to stay invisible.
	- `for _, _player in Players` passed `_player.Character` without checking it, so one
	  player without a character threw and the cooldown never ended.
]]
local Debris = game:GetService("Debris")
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity
type Trail = { Target: CharacterEntity, Position: Vector3 }

local EFFECT = "SmokeWhiteOut"
local HELD_STATUS = "SmokeWhiteOutHeld"
-- Name of the StatusService slow that keeps a caught target from walking.
local HOLD_SLOW = "SmokeWhiteOutHold"
-- The legacy `using` flag: the three attacks of the fruit exclude each other.
local FIST_STATUS = "SmokeFist"
local CHARGE_STATUS = "SmokeCharging"

local COOLDOWN = 15
local MAX_RADIUS = 150
local MAX_SPEED = 45
local CHASE_TIME = 10
local CATCH_RADIUS = 1.5
local HOLD_TIME = 5
local HOLD_LIFT = Vector3.new(0, 2, 0)
local HOLD_FORCE = Vector3.new(math.huge, math.huge, math.huge)
local HOLD_POWER = 10000
local TICK = 0.1
-- Where the trails start, relative to the root: the two shoulders.
local ARM_OFFSETS = { CFrame.new(-1.5, 0.5, 0), CFrame.new(1.5, 0.5, 0) }

local WhiteOut = Ability.extend()

function WhiteOut:CanBegin(): boolean
	local entity = self.Entity
	return os.clock() - (self.LastUse or -COOLDOWN) >= COOLDOWN
		and not entity:HasStatus(FIST_STATUS)
		and not entity:HasStatus(CHARGE_STATUS)
end

function WhiteOut:OnBegin()
	local entity = self.Entity
	self.LastUse = os.clock()
	self:StartCooldown(COOLDOWN)

	local factor = self:GetLevelScale("Melee") * self:GetAffinity("Melee")
	local speed = MAX_SPEED * factor
	local rootCFrame = entity.Root.CFrame

	local trails: { Trail } = {}
	local models: { Model } = {}
	for _, target in Hitbox.Sphere(rootCFrame.Position, MAX_RADIUS * factor, entity) do
		local offset = ARM_OFFSETS[#trails % 2 + 1]
		table.insert(trails, { Target = target, Position = (rootCFrame * offset).Position })
		table.insert(models, target.Model)
	end
	if #trails == 0 or speed <= 0 then
		return
	end

	self:PlayEffect(EFFECT, rootCFrame.Position, {
		Targets = models,
		Speed = speed,
		ChaseTime = CHASE_TIME,
		CatchRadius = CATCH_RADIUS,
		HoldTime = HOLD_TIME,
	})

	self.Run = (self.Run or 0) + 1
	local run = self.Run
	local colors = self:GetColorString()
	local travel = speed * TICK
	local elapsed = 0

	local function step()
		if self.Run ~= run then
			return
		end
		elapsed += TICK

		for index = #trails, 1, -1 do
			local trail = trails[index]
			local target = trail.Target
			if target.Dead or target.Model.Parent == nil then
				table.remove(trails, index)
				continue
			end

			local offset = target.Root.Position - trail.Position
			if offset.Magnitude <= CATCH_RADIUS + travel then
				table.remove(trails, index)
				self.Services.Status:ApplySlow(target, HOLD_SLOW, 0, HOLD_TIME)
				target:SetStatus(HELD_STATUS, colors, HOLD_TIME, true)
				if not target.Player then
					local hold = Instance.new("BodyPosition")
					hold.Name = "SmokeWhiteOutHold"
					hold.MaxForce = HOLD_FORCE
					hold.P = HOLD_POWER
					hold.Position = target.Root.Position + HOLD_LIFT
					hold.Parent = target.Root
					Debris:AddItem(hold, HOLD_TIME)
				end
			else
				trail.Position += offset.Unit * travel
			end
		end

		if #trails > 0 and elapsed < CHASE_TIME then
			task.delay(TICK, step)
		end
	end
	task.delay(TICK, step)
end

function WhiteOut:OnInterrupt()
	-- Cancels the trails still chasing; the cooldown is kept.
	self.Run = (self.Run or 0) + 1
end

return WhiteOut
