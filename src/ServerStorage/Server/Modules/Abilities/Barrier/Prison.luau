--!strict
--[[
	Barrier fruit - Prison (hold to aim, release to place): a cage dropped in front of
	the user that also keeps whoever is inside stunned.

	Size:      authored size (15 x 15 x 15) * defense affinity
	Position:  root + (11 * defense affinity) studs along the direction to the aim point
	Duration:  7.5 * defense affinity seconds
	Stun:      every 0.5 s, every other player within max(size X, size Z) / 2 of the
	           cage center is stunned for 1 s (players only, as in the legacy game:
	           NPCs are held by the cage's collision alone)
	Cooldown:  20 s

	While the key is held the owner sees a ghost of the cage (BarrierPrisonAim status).
	Collision is an invisible server copy of the authored cage (_Construct.FindPrison), or
	slabs when the asset is missing; the look is the client effect of the BarrierConstruct
	status.

	KeepThroughStun: a standing cage (and its stun tick) outlives a stun of its user, as
	in the legacy game. A stunned user cannot start aiming, and a release while stunned
	places nothing and starts no cooldown.

	Legacy problems fixed here:
	- The 20 s cooldown existed only in the LocalScript (the server allowed one every
	  0.25 s). It is enforced here.
	- The stun loop was `while Prison.Parent` with no link to the caster: it is a
	  bounded tick tied to this cage and cancelled in OnInterrupt.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Construct = require(script.Parent._Construct)

-- Replicated to draw the owner's placement ghost: "<sx>|<sy>|<sz>|<distance>|<colors>".
local AIM_STATUS = "BarrierPrisonAim"
local STUN_NAME = "BarrierPrison"

local BASE_DISTANCE = 11
local BASE_DURATION = 7.5
local COOLDOWN = 20
local STUN_INTERVAL = 0.5
local STUN_SECONDS = 1
-- Size of the authored cage, used when it cannot be found.
local FALLBACK_SIZE = Vector3.new(15, 15, 15)
local SHELL_THICKNESS = 2

local Prison = Ability.extend()

Prison.KeepThroughStun = true

function Prison:CanBegin(): boolean
	return os.clock() >= (self.NextUse or 0) and not self.Entity:HasStatus(Construct.StunStatus)
end

function Prison:OnBegin()
	local affinity = self:GetAffinity("Defense")
	local template = Construct.FindPrison()
	local size = (if template then template.Size else FALLBACK_SIZE) * affinity

	self.Aiming = true
	self.Entity:SetStatus(
		AIM_STATUS,
		string.format("%.2f|%.2f|%.2f|%.2f|%s", size.X, size.Y, size.Z, BASE_DISTANCE * affinity, self:GetColorString()),
		nil,
		true
	)
end

function Prison:OnEnd(input: Ability.AbilityInput)
	if not self.Aiming then
		return
	end
	self.Aiming = false

	local entity = self.Entity
	entity:ClearStatus(AIM_STATUS)
	if entity:HasStatus(Construct.StunStatus) then
		return
	end
	self.NextUse = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local affinity = self:GetAffinity("Defense")
	local template = Construct.FindPrison()
	local size = (if template then template.Size else FALLBACK_SIZE) * affinity

	local rootPosition = entity.Root.Position
	local offset = input.AimPosition - rootPosition
	local direction = if offset.Magnitude > 1e-3 then offset.Unit else entity.Root.CFrame.LookVector
	local position = rootPosition + direction * (BASE_DISTANCE * affinity)
	-- Upright, turned towards the user.
	local cframe = Construct.Frame(position, Vector3.new(rootPosition.X - position.X, 0, rootPosition.Z - position.Z))

	local parts = if template
		then Construct.FromTemplate(template, cframe, size)
		else Construct.Shell(cframe, size, SHELL_THICKNESS, false)
	local token = Construct.Set(entity, "Prison", cframe, size, self:GetColorString(), parts)

	local radius = math.max(size.X, size.Z) / 2
	local expiresAt = os.clock() + BASE_DURATION * affinity

	local function hold()
		if not Construct.IsCurrent(entity, token) then
			return
		end
		if os.clock() >= expiresAt then
			Construct.Clear(entity, "Prison")
			return
		end

		for _, target in Hitbox.Sphere(position, radius, entity) do
			if target.Player and (target.Root.Position - position).Magnitude <= radius then
				self.Services.Status:ApplyStun(target, STUN_SECONDS, STUN_NAME)
			end
		end
		-- The last wait is cut short so the cage goes exactly when its time is up.
		task.delay(math.min(STUN_INTERVAL, expiresAt - os.clock()), hold)
	end
	hold()
end

function Prison:OnInterrupt()
	self.Aiming = false
	self.Entity:ClearStatus(AIM_STATUS)
	-- Also invalidates the pending stun tick of that cage.
	Construct.Clear(self.Entity, "Prison")
end

return Prison
