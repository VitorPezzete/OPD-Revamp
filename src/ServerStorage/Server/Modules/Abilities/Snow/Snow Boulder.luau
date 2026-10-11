--!strict
--[[
	Snow fruit - Snow Boulder: rolls a boulder of snow that chases the aim point and
	covers whoever it touches in snow. Several can be out at once.

	- At most 5 * sniper affinity boulders. Each appears 5 studs from the caster towards
	  the aim point (in a straight line, up or down included) and lasts
	  10 * sniper affinity * (defense level / cap) seconds (the legacy formula mixes the
	  two stats), then fades out during 1 more second, still rolling and still touching.
	- Touching one applies SnowTouched: 350 * sniper affinity every 0.5 s,
	  floor(4 * sniper affinity) times. No direct damage, no cooldown between touches.
	- Every 0.2 s spent inside the caster's Snow Globe a boulder grows by
	  1.25% * sniper affinity and its mover's force and stiffness by 2.5% * sniper
	  affinity (the grown force is horizontal only, as the legacy line wrote it).
	- All boulders chase the owner's aim point, refreshed by the owner's client ten
	  times a second through phase 3 inputs (Effects.Status.SnowBoulders -> OnAction).
	- No cooldown (the legacy one was commented out), and stuns do not remove the
	  boulders (KeepThroughStun).

	The boulder is the legacy part itself: a clone of
	Assets.Models.Fruits.Snow.Power5.Seat, a loose ball pushed towards the aim point by
	the BodyPosition it carries. Everything that made it what it was is physics of that
	part and of that mover's own P, D and MaxForce: it darts to the cursor, overshoots
	and swings back, rolls and falls with the ground, shoves characters and is stopped
	by them, and, being a Seat, can be sat on and ridden around. None of that survives
	a simulated point, so this is one of the few abilities with real server parts (as
	the Snow Ring wall); they are few (ten at most per user), short-lived and all removed
	in OnInterrupt. Touches are the part's own Touched, as in the legacy script: that
	is what decides how often SnowTouched is renewed.

	The server simulates the boulders (network owner), so a client cannot carry one onto
	somebody; the aim point it follows is the validated one.

	Legacy problems fixed here:
	- Every boulder ran its own `while` loop and the cast handler never returned while a
	  boulder was alive. One loop per user grows them all.
	- The aim stream wrote to every child of the folder the pellets were also put in,
	  and errored on those.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local Ability = require(ServerStorage.Server.Classes.Ability)
local Allies = require(ServerStorage.Server.Modules.Allies)
local World = require(ReplicatedStorage.Shared.Util.World)
local SnowShared = require(script.Parent.SnowShared)

local STATUS = "SnowBoulders"

local MAX_PER_AFFINITY = 5
local LIFETIME = 10
local FADE_TIME = 1
local SPAWN_DISTANCE = 5
local DOT_DAMAGE = 350
local DOT_HITS = 4
local GLOBE_PERIOD = 0.2
local GROWTH_PER_PERIOD = 0.0125
local PULL_PER_PERIOD = 0.025
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
-- Only for a template that has lost its BodyPosition; the real values are the asset's.
local FALLBACK_POWER = 10000
local FALLBACK_DAMPING = 1250
local FALLBACK_FORCE_PER_MASS = 400

type Boulder = { Part: BasePart, Mover: BodyPosition }

local SnowBoulder = Ability.extend()

SnowBoulder.Debounce = 0
SnowBoulder.KeepThroughStun = true

local function createBoulder(): Boulder?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", "Snow", "Power5", "Seat" } do
		current = current and current:FindFirstChild(name)
	end
	if not current or not current:IsA("BasePart") then
		return nil
	end

	local part = current:Clone()
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	part.Name = "SnowBoulder"

	local found = part:FindFirstChildOfClass("BodyPosition")
	local mover: BodyPosition
	if found then
		mover = found
	else
		local force = FALLBACK_FORCE_PER_MASS * part:GetMass()
		mover = Instance.new("BodyPosition")
		mover.P = FALLBACK_POWER
		mover.D = FALLBACK_DAMPING
		mover.MaxForce = Vector3.new(force, 0, force)
		mover.Parent = part
	end
	return { Part = part, Mover = mover }
end

-- Drops the boulders that are gone; returns how many are left.
local function prune(self: any): number
	local boulders: { Boulder } = self.Boulders
	for index = #boulders, 1, -1 do
		if not boulders[index].Part.Parent then
			table.remove(boulders, index)
		end
	end
	return #boulders
end

local function grow(self: any, run: number)
	if self.Run ~= run then
		return
	end

	local entity = self.Entity
	if prune(self) == 0 then
		self.Active = false
		entity:ClearStatus(STATUS)
		return
	end

	local globeCenter, globeRadius = SnowShared.GetGlobe(entity)
	if globeCenter and globeRadius then
		local affinity = self:GetAffinity("Sniper")
		local pull = 1 + PULL_PER_PERIOD * affinity
		for _, boulder: Boulder in self.Boulders do
			local part, mover = boulder.Part, boulder.Mover
			if (globeCenter - part.Position).Magnitude < globeRadius then
				local wanted = part.Size.Z * (1 + GROWTH_PER_PERIOD * affinity)
				local force = mover.MaxForce.Z * pull
				mover.MaxForce = Vector3.new(force, 0, force)
				mover.P *= pull
				part.Size = Vector3.new(wanted, wanted, wanted)
			end
		end
	end
	task.delay(GLOBE_PERIOD, grow, self, run)
end

function SnowBoulder:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity

	local affinity = self:GetAffinity("Sniper")
	local boulders: { Boulder } = self.Boulders or {}
	self.Boulders = boulders

	if prune(self) >= MAX_PER_AFFINITY * affinity then
		return
	end
	local boulder = createBoulder()
	if not boulder then
		return
	end
	local part, mover = boulder.Part, boulder.Mover

	if self.Services.Haki:IsArmamentActive(entity) then
		part.Color = HAKI_COLOR
	else
		local primary = FruitColor.Parse(self:GetColorString())
		if primary then
			part.Color = primary
		end
	end

	local root = entity.Root.Position
	local direction = input.AimPosition - root
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	part.CFrame = CFrame.new(root + direction.Unit * SPAWN_DISTANCE)
	mover.Position = input.AimPosition
	part.Anchored = false
	part.Parent = World.Abilities()
	pcall(function()
		part:SetNetworkOwner(nil)
	end)

	part.Touched:Connect(function(hit: BasePart)
		local model = hit.Parent
		if not model or model == entity.Model then
			return
		end
		local target = self.Services.Character:GetEntityFromPart(hit)
		if not target or target.Model ~= model or target.Dead or not target.Spawned then
			return
		end
		-- Found by touch, not by Hitbox: the ally rule is asked here.
		if Allies.Spares(entity, target) then
			return
		end
		local touchAffinity = self:GetAffinity("Sniper")
		SnowShared.Touch(self, target, DOT_DAMAGE * touchAffinity, DOT_HITS * touchAffinity)
	end)

	task.delay(LIFETIME * affinity * self:GetLevelScale("Defense"), function()
		if not part.Parent then
			return
		end
		TweenService:Create(part, TweenInfo.new(FADE_TIME), { Transparency = 1 }):Play()
		task.delay(FADE_TIME, function()
			part:Destroy()
		end)
	end)

	table.insert(boulders, boulder)
	if self.Active then
		return
	end

	self.Active = true
	self.Run = (self.Run or 0) + 1
	local context = self.Context
	entity:SetStatus(STATUS, `{context.FruitSlot};{context.Definition.Slot}`, nil, true)
	task.delay(GLOBE_PERIOD, grow, self, self.Run)
end

-- Aim refresh from the owner's client: where the boulders are pushed to.
function SnowBoulder:OnAction(input: Ability.AbilityInput)
	local boulders: { Boulder }? = self.Boulders
	if not boulders then
		return
	end
	for _, boulder in boulders do
		boulder.Mover.Position = input.AimPosition
	end
end

function SnowBoulder:OnInterrupt()
	self.Active = false
	self.Run = (self.Run or 0) + 1
	local boulders: { Boulder }? = self.Boulders
	if boulders then
		for _, boulder in boulders do
			boulder.Part:Destroy()
		end
	end
	self.Boulders = {}
	self.Entity:ClearStatus(STATUS)
end

return SnowBoulder
