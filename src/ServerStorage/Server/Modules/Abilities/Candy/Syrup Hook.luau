--!strict
--[[
	Candy fruit - Syrup Hook: a rope of syrup catches the character under the aim point,
	stuns it and reels it in.

	With a = sniper affinity and f = a * (sniper level / cap):
	- the target must be within 125 * f studs of the caster;
	- it is stunned (rooted, abilities interrupted) for 2 + 2 * (a - 1) seconds;
	- the rope shortens at 25 studs per second, so the pull lasts distance / 25 seconds;
	- the same character cannot be hooked again by this caster until 5 s after the pull
	  has ended; 0.25 s between two hooks. No damage.

	How the pull is done: exactly as in the legacy game, with a RopeConstraint between
	the two root parts whose Length goes from the distance to 1 stud over the pull time
	(default tween: Quad, Out) and which then holds for 2 s more. A rope pulls on both
	ends, so the caster is dragged towards the target as much as the target towards the
	caster, and they stay tied for those 2 s.
	The hooked character gets the replicated CandyHooked status
	("<caster user id>|<pull seconds>|<1 when haki>|<colors>") for that long. Every
	client builds the rope from it (Effects.Status.CandyHooked): each player simulates its
	own character, so the rope on its own client is what pulls it. A hooked NPC is
	simulated by the server, which therefore holds a rope of its own for it (invisible:
	the picture is the clients').

	The target is chosen by the server: the character closest to the validated aim point,
	within AIM_RADIUS of it (the legacy client sent the part under the mouse).

	Legacy problem fixed here: with nothing under the mouse the handler indexed a nil
	character and errored.

	KeepThroughStun: a pull in progress goes on when the caster is stunned, as in the
	legacy game (no new hook while stunned). On death, a seal or losing the fruit
	OnInterrupt stops the pulls in progress (rope included); stuns already applied run out.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CandyShared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "CandyHooked"
local STUN = "CandyHook"

local RANGE = 125
local PULL_SPEED = 25
local BASE_STUN = 2
local STUN_PER_AFFINITY = 2
local ROPE_LINGER = 2
-- Counted from the moment the rope is gone: 5 s after the end of the pull in total.
local REHOOK_DELAY = 3
local AIM_RADIUS = 6
-- The legacy rope shortened to 1 stud.
local END_LENGTH = 1

local SyrupHook = Ability.extend()

SyrupHook.KeepThroughStun = true

local function findRopeTemplate(): RopeConstraint?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", "Candy", "Power6", "CandyRope" } do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return if current and current:IsA("RopeConstraint") then current else nil
end

-- The rope that pulls an NPC (the server simulates it). Returns what to destroy.
local function tie(self: any, target: CharacterEntity, distance: number, pullTime: number): { Instance }
	local template = findRopeTemplate()
	local rope = if template then template:Clone() else Instance.new("RopeConstraint")
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "CandyHookRope"
	targetAttachment.Parent = target.Root
	local casterAttachment = Instance.new("Attachment")
	casterAttachment.Name = "CandyHookRope"
	casterAttachment.Parent = self.Entity.Root

	rope.Name = "CandyHookRope"
	rope.Visible = false
	rope.Length = distance
	rope.Attachment0 = targetAttachment
	rope.Attachment1 = casterAttachment
	rope.Parent = target.Root
	TweenService:Create(rope, TweenInfo.new(pullTime), { Length = END_LENGTH }):Play()

	local created: { Instance } = { rope, targetAttachment, casterAttachment }
	for _, instance in created do
		Debris:AddItem(instance, pullTime + ROPE_LINGER)
	end
	return created
end

function SyrupHook:CanBegin(): boolean
	return not CandyShared.Stunned(self)
end

function SyrupHook:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local target = Hitbox.Closest(Hitbox.Sphere(input.AimPosition, AIM_RADIUS, entity), input.AimPosition)
	if not target then
		return
	end

	local now = os.clock()
	local roped: { [CharacterEntity]: number } = self.Roped
	if not roped then
		roped = setmetatable({}, { __mode = "k" }) :: any
		self.Roped = roped
	end
	if now < (roped[target] or 0) then
		return
	end

	local affinity = self:GetAffinity("Sniper")
	local factor = affinity * self:GetLevelScale("Sniper")
	local distance = (target.Root.Position - entity.Root.Position).Magnitude
	if distance > RANGE * factor then
		return
	end

	local pullTime = distance / PULL_SPEED
	roped[target] = now + pullTime + ROPE_LINGER + REHOOK_DELAY

	self.Services.Status:ApplyStun(target, BASE_STUN + STUN_PER_AFFINITY * (affinity - 1), STUN)

	local _, haki = CandyShared.Haki(self)
	-- The clock makes two hooks on the same target different values, so the status
	-- effect restarts and an older pull loop recognises it is no longer current.
	local value = string.format(
		"%d|%.2f|%d|%s|%.2f",
		self.Player.UserId,
		pullTime,
		if haki then 1 else 0,
		self:GetColorString(),
		now
	)
	target:SetStatus(STATUS, value, pullTime + ROPE_LINGER, true)

	local hooked: { [CharacterEntity]: string } = self.Hooked
	if not hooked then
		hooked = setmetatable({}, { __mode = "k" }) :: any
		self.Hooked = hooked
	end
	hooked[target] = value

	if not target.Player then
		local ropes: { [CharacterEntity]: { Instance } } = self.Ropes
		if not ropes then
			ropes = setmetatable({}, { __mode = "k" }) :: any
			self.Ropes = ropes
		end
		ropes[target] = tie(self, target, distance, pullTime)
	end
end

function SyrupHook:OnInterrupt()
	local ropes: { [CharacterEntity]: { Instance } }? = self.Ropes
	if ropes then
		for _, created in ropes do
			for _, instance in created do
				instance:Destroy()
			end
		end
		table.clear(ropes)
	end

	local hooked: { [CharacterEntity]: string }? = self.Hooked
	if not hooked then
		return
	end

	-- Clearing the status ends the clients' ropes.
	for target, value in hooked do
		if target:GetStatus(STATUS) == value then
			target:ClearStatus(STATUS)
		end
	end
	table.clear(hooked)
end

return SyrupHook
