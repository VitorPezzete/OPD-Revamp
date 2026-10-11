--!strict
--[[
	Paw fruit - Spatial Repulsion (charged): a tap repels the user itself across the map, a
	held charge repels everyone around it back to where the charge began.

	With f = (melee level / cap) * melee affinity / 2 * clamp(seconds held / 5, 0.1, 1):
	- f <= 0.1 (a tap): the user is teleported 250 studs towards the aim point, or onto the
	  first thing in the way, facing the direction travelled;
	- otherwise: every character whose root is within 25 f studs of the user, THE USER
	  INCLUDED, is teleported to the exact CFrame the user had when the key was pressed
	  (all on the same spot, as in the source);
	- 5 s cooldown after the release. Nothing else of the fruit can be used while it charges.
	There is no damage and nothing is drawn while charging.

	With the level requirement of 500 the uncharged factor is affinity / 2, so the tap is a
	hold of at most 0.5 s at affinity 2 and 1 s at affinity 1; anything longer is the group
	repulsion.

	Kept as it was: the self teleport lands the root exactly on the surface the ray hit
	(the source did not lift it), and seated characters are moved like the others.

	Source problems fixed here:
	- The destination of the tap came from an InvokeClient for the mouse at release, which
	  hangs the server thread when the client does not answer. It is the validated aim
	  point of the release.
	- Two loops over every enemy and every player; now one Hitbox query.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Paw = require(script.Parent._Shared)

local NAME = "Spatial Repulsion"
local SKILL = "Melee"
local EFFECT = "PawRepulsion"

local MAX_CHARGE = 5
local COOLDOWN = 5
local TELEPORT_RANGE = 250
-- At or under this factor the release is the self teleport.
local SELF_FACTOR = 0.1
local GROUP_RADIUS = 25
-- Hitbox widens every shape by this body allowance; the source measured root to root.
local BODY_RADIUS = 2.5

local SpatialRepulsion = Ability.extend()

-- Puts the ROOT of `target` on `cframe`, as the source did (HumanoidRootPart.CFrame = ...).
-- Character:Teleport moves the model by its pivot, which is not the root for every model
-- (NPC models; a body whose primary part is its head would land 1.5 studs low).
local function teleportRoot(self: any, target: any, cframe: CFrame)
	local pivot: CFrame = target.Root.CFrame:ToObjectSpace(target.Model:GetPivot())
	self.Services.Character:Teleport(target, cframe * pivot)
end

local function repelSelf(self: any, aim: Vector3)
	local entity = self.Entity
	local origin: Vector3 = entity.Root.Position
	local direction = Paw.Direction(entity, origin, aim)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	local result = Workspace:Raycast(origin, direction * TELEPORT_RANGE, params)
	local destination = if result then result.Position else origin + direction * TELEPORT_RANGE

	local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	teleportRoot(self, entity, CFrame.lookAt(destination, destination + direction, up))
	self:PlayEffect(EFFECT, origin, { Mode = "Self" }, Paw.EFFECT_RADIUS + TELEPORT_RANGE)
end

local function repelGroup(self: any, factor: number, destination: CFrame)
	local entity = self.Entity
	local centre: Vector3 = entity.Root.Position

	local moved: { { Model: Model, Position: Vector3 } } = {}
	for _, target in Hitbox.Sphere(centre, GROUP_RADIUS * factor - BODY_RADIUS, nil) do
		table.insert(moved, { Model = target.Model, Position = target.Root.Position })
		teleportRoot(self, target, destination)
	end

	-- Sent around where they were; the radius also covers where they went.
	self:PlayEffect(EFFECT, centre, {
		Mode = "Group",
		Moved = moved,
		Destination = destination,
	}, Paw.EFFECT_RADIUS + (destination.Position - centre).Magnitude)
end

function SpatialRepulsion:CanBegin(): boolean
	return not self.ChargeStart and os.clock() >= (self.ReadyAt or 0) and not Paw.IsBusy(self.Entity)
end

function SpatialRepulsion:OnBegin()
	local entity = self.Entity
	self:BeginCharge(MAX_CHARGE)
	Paw.SetBusy(entity, NAME)
	self.StartCFrame = entity.Root.CFrame
end

function SpatialRepulsion:OnEnd(input: Ability.AbilityInput)
	local started: number? = self.ChargeStart
	if not self:EndCharge(1, 0, MAX_CHARGE) or not started then
		return
	end

	local entity = self.Entity
	Paw.ClearBusy(entity, NAME)
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local startCFrame: CFrame? = self.StartCFrame
	self.StartCFrame = nil

	local factor = Paw.Factor(self, SKILL) * Paw.ChargeFraction(started, MAX_CHARGE)
	if factor <= SELF_FACTOR then
		repelSelf(self, input.AimPosition)
	elseif startCFrame then
		repelGroup(self, factor, startCFrame)
	end
end

function SpatialRepulsion:OnInterrupt()
	self.ChargeStart = nil
	self.StartCFrame = nil
	Paw.ClearBusy(self.Entity, NAME)
end

return SpatialRepulsion
