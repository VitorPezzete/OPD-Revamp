--!strict
--[[
	Smoke fruit - White Fist (hold): both arms leave the body as smoke fists that fly
	towards the mouse for as long as the key is held, hitting whatever they pass.

	- Each fist flies at 125 studs per second towards the aim point, which is kept
	  within 300 studs of the caster. It never slows down: the legacy BodyVelocity always
	  had that speed, re-aimed ten times a second, so a fist that reaches the aim point
	  flies through it and turns back, hovering around it instead of resting on it.
	- Each fist hits everyone within 6 studs, at most once every 0.5s per victim:
	  625 * (melee level / cap) * melee affinity / 4 "Melee" damage (dodgeable).
	  Armament haki doubles it and makes it "Haki".
	- Ends on release, on interrupt, or when a fist goes below the sea (Y < 190.5).
	  2.5s cooldown from the end.

	The fists are two points simulated here (one 0.1s tick while the key is held, the
	same rate as the legacy hit loop). Their positions are mirrored as the Vector3
	statuses "SmokeFistRight" / "SmokeFistLeft" so every client draws them where they
	really hit (Effects.Status.SmokeFist). The owner's client sends the mouse position
	up to ten times a second (the legacy polling rate) as the ability's secondary input
	(OnAction); it is validated by AbilityService like any aim point, then clamped here.

	Legacy problems fixed here:
	- The server invoked a RemoteFunction on the client ten times a second for the mouse
	  position: a client that never answered froze the loop (and the ability) for good,
	  and the returned position was trusted as is.
	- The real arms were detached (shoulders disabled) and pushed by BodyVelocity on the
	  server; dying or resetting mid-flight left the loops running on missing parts.
	- "End" without a "Start" indexed a missing BodyVelocity and threw before the
	  cooldown could reset.

	Not capped in time (the legacy hold was not either): the tick stops the moment the
	key is released or the ability is interrupted.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity
type Fist = { Status: string, Position: Vector3, LastHit: { [CharacterEntity]: number } }

local STATUS = "SmokeFist"
local RIGHT_STATUS = "SmokeFistRight"
local LEFT_STATUS = "SmokeFistLeft"
local DAMAGE_TAG = "SmokeFist"
local CHARGE_STATUS = "SmokeCharging"
-- Armament haki status set by HakiService.
local HAKI_STATUS = "Haki"

local MAX_DAMAGE = 625
local DAMAGE_DIVISOR = 4
local HAKI_MULTIPLIER = 2
local SPEED = 125
local HIT_RADIUS = 6
local HIT_COOLDOWN = 0.5
local COOLDOWN = 2.5
local MAX_REACH = 300
-- Sea level of the legacy map: the fists dissolve in water.
local MIN_HEIGHT = 190.5
local TICK = 0.1

local WhiteFist = Ability.extend()

function WhiteFist:CanBegin(): boolean
	return not self.Active
		and os.clock() - (self.LastEnd or -COOLDOWN) >= COOLDOWN
		and not self.Entity:HasStatus(CHARGE_STATUS)
end

function WhiteFist:OnBegin(input)
	local entity = self.Entity
	local context = self.Context

	self.Active = true
	self.Aim = input.AimPosition
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	local rootCFrame = entity.Root.CFrame
	local fists: { Fist } = {
		-- Where the arms are when the shoulders let go of them.
		{ Status = RIGHT_STATUS, Position = (rootCFrame * CFrame.new(1.5, 0, 0)).Position, LastHit = {} },
		{ Status = LEFT_STATUS, Position = (rootCFrame * CFrame.new(-1.5, 0, 0)).Position, LastHit = {} },
	}
	for _, fist in fists do
		-- Weak keys: victims that leave the game are forgotten without any bookkeeping.
		setmetatable(fist.LastHit :: any, { __mode = "k" })
		entity:SetStatus(fist.Status, fist.Position, nil, true)
	end
	-- "<fruit slot>|<ability slot>|<colors>": the owner's client needs the slots to
	-- address its aim updates, everyone needs the colors to paint the smoke.
	entity:SetStatus(STATUS, `{context.FruitSlot}|{context.Definition.Slot}|{self:GetColorString()}`, nil, true)

	local travel = SPEED * TICK

	local function strike()
		local haki = entity:HasStatus(HAKI_STATUS)
		local damage = MAX_DAMAGE * self:GetLevelScale("Melee") * self:GetAffinity("Melee") / DAMAGE_DIVISOR
		if haki then
			damage *= HAKI_MULTIPLIER
		end
		local now = os.clock()

		for _, fist in fists do
			for _, target in Hitbox.Sphere(fist.Position, HIT_RADIUS, entity) do
				if now - (fist.LastHit[target] or 0) >= HIT_COOLDOWN then
					fist.LastHit[target] = now
					self:Damage(target, damage, if haki then "Haki" else "Melee", DAMAGE_TAG, true)
				end
			end
		end
	end

	local function tick()
		if self.Run ~= run or not self.Active then
			return
		end

		local rootPosition = entity.Root.Position
		local aim: Vector3 = self.Aim
		local reach = aim - rootPosition
		if reach.Magnitude > MAX_REACH then
			aim = rootPosition + reach.Unit * MAX_REACH
		end

		for _, fist in fists do
			local toAim = aim - fist.Position
			if toAim.Magnitude > 1e-3 then
				fist.Position += toAim.Unit * travel
			end

			if fist.Position.Y < MIN_HEIGHT then
				self:OnInterrupt()
				return
			end
			entity:SetStatus(fist.Status, fist.Position, nil, true)
		end
		strike()
		task.delay(TICK, tick)
	end
	-- The legacy hit loop made its first pass the moment the arms let go.
	strike()
	task.delay(TICK, tick)
end

-- Aim update from the owner's client while the fists are out.
function WhiteFist:OnAction(input)
	self.Aim = input.AimPosition
end

function WhiteFist:OnEnd()
	if self.Active then
		self:OnInterrupt()
	end
end

function WhiteFist:OnInterrupt()
	if self.Active then
		self.LastEnd = os.clock()
		self:StartCooldown(COOLDOWN)
	end
	self.Active = false
	-- Invalidates the pending tick of the run that just ended.
	self.Run = (self.Run or 0) + 1

	local entity = self.Entity
	entity:ClearStatus(STATUS)
	entity:ClearStatus(RIGHT_STATUS)
	entity:ClearStatus(LEFT_STATUS)
end

return WhiteFist
