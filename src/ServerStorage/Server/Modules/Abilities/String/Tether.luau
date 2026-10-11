--!strict
--[[
	String fruit - Tether (hold): ties two things together with a string.

	- Press: a string runs from the user's right hand to the aim point, or to the
	  character under it, as long as the distance from the user to that point. It is a
	  real rope: the user hangs from a point and can swing, and a character at the other
	  end is tied to the user's hand for as long as the key is held.
	- Release: the hand end is tied to the second aim point, or to the character there.
	  The string becomes as long as the distance from its first end to that point.
	  * point to point: a string that stays until Release is used;
	  * a character at either end (or both): that character is leashed for
	    10 * sniper affinity seconds, and no new string can be shot meanwhile (legacy
	    `playercaught`). Release frees it at once.
	- At most (sniper level / 10) * sniper affinity strings, the one in the hand
	  included. A string released over that limit is not tied: it stays in the hand until
	  Release is used (or the next press replaces it), as it did in legacy.
	- A string started with armament haki on is dark, and stays dark once tied.

	The strings are real RopeConstraints created here, as in the legacy game, because
	they are physics and not decoration: the engine replicates them, draws them
	(Visible, 0.1 thick) and each end is simulated by whoever owns it - the owning client
	for a player, the server for an NPC. Their two ends are attachments on the characters
	or on small anchored, non-colliding parts; everything lives in one folder per user
	under Workspace.Instances.Abilities and goes with the rope.

	Everything is resolved here from the two validated aim points: the character "under
	the mouse" is the closest one within 3.5 studs of the point (the legacy client sent
	the mouse target instance).

	State shared with the sibling Release ability: the non-replicated status
	"StringTetherState" on the user, a table { Ropes, Clear }.

	Legacy problems fixed here:
	- A string released ON a character was moved to an attachment that had no parent
	  (the anchor part only existed for a point), so it tied nothing and vanished while
	  still locking the ability for 10 * affinity seconds. It now ties that character,
	  which is what the branch was written for.
	- The attachments left in the characters were never removed.
	- The string being held lived in an ObjectValue shared by every press, and the
	  "caught" flag was one script-level variable.
	Like the legacy strings (server instances nothing but Release or death removed),
	tied strings stay through a stun and a seal.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity
type State = {
	-- Every string of the user, the one in the hand included.
	Ropes: { RopeConstraint },
	-- The string that locks new ones while a character is leashed, if any.
	Caught: RopeConstraint?,
	Folder: Instance?,
	Clear: () -> (),
}

local STATE_STATUS = "StringTetherState"
local STUN_STATUS = "Stunned"
-- Armament haki status set by HakiService.
local HAKI_STATUS = "Haki"

local LEVELS_PER_STRING = 10
local LEASH_SECONDS = 10
-- Hitbox.Sphere adds the 2.5 stud body radius.
local TARGET_RADIUS = 1
local THICKNESS = 0.1
local ANCHOR_SIZE = Vector3.new(0.2, 0.2, 0.2)
local HAND_PART = "Right Arm"
local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local FRUIT_NAME = "String"

local Tether = Ability.extend()

-- Stuns did not cut the strings in the legacy game; death, seals and fruit loss do.
Tether.KeepThroughStun = true

local function getState(self: any): State
	local entity: CharacterEntity = self.Entity
	local existing: State? = entity:GetStatus(STATE_STATUS)
	if existing then
		return existing
	end

	local state: State
	state = {
		Ropes = {},
		Caught = nil,
		Folder = nil,
		Clear = function()
			local ropes = table.clone(state.Ropes)
			table.clear(state.Ropes)
			state.Caught = nil
			for _, rope in ropes do
				rope:Destroy()
			end
		end,
	}
	entity:SetStatus(STATE_STATUS, state)
	return state
end

local function getFolder(self: any, state: State): Instance
	local folder = state.Folder
	if folder and folder.Parent then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = `StringTether_{self.Entity.Model.Name}`
	created.Parent = World.Abilities()
	state.Folder = created
	return created
end

-- An end of the string on a character. It goes with the rope.
local function attachTo(rope: RopeConstraint, part: BasePart): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "StringTetherAttachment"
	attachment.Parent = part
	rope.Destroying:Once(function()
		attachment:Destroy()
	end)
	return attachment
end

-- An end of the string on a fixed point: the legacy 0.2 stud anchored part, inside the rope.
local function anchorAt(rope: RopeConstraint, position: Vector3): Attachment
	local anchor = Instance.new("Part")
	anchor.Name = "StringTetherAnchor"
	anchor.Size = ANCHOR_SIZE
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Position = position

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	anchor.Parent = rope
	return attachment
end

local function forget(state: State, rope: RopeConstraint)
	local index = table.find(state.Ropes, rope)
	if index then
		table.remove(state.Ropes, index)
	end
	if state.Caught == rope then
		state.Caught = nil
	end
end

-- The character at an aim point, if any.
local function resolve(self: any, aim: Vector3): CharacterEntity?
	return Hitbox.Closest(Hitbox.Sphere(aim, TARGET_RADIUS, self.Entity), aim)
end

local function dropHeld(self: any)
	local held: RopeConstraint? = self.Held
	self.Held = nil
	self.HeldTarget = nil
	if held then
		local state: State? = self.Entity:GetStatus(STATE_STATUS)
		if state then
			forget(state, held)
		end
		held:Destroy()
	end
end

-- KeepThroughStun lets presses through; the legacy client sent nothing while stunned.
function Tether:CanBegin(): boolean
	return not self.Entity:HasStatus(STUN_STATUS)
end

function Tether:OnBegin(input)
	local entity: CharacterEntity = self.Entity
	local state = getState(self)
	-- Release may have destroyed the string in the hand.
	local previous: RopeConstraint? = self.Held
	if previous and not table.find(state.Ropes, previous) then
		self.Held = nil
	end
	local caught = state.Caught
	if caught and caught.Parent then
		return
	end
	state.Caught = nil
	-- A string left in the hand by the limit: the new one takes its place.
	dropHeld(self)

	local aim: Vector3 = input.AimPosition
	local target = resolve(self, aim)

	local rope = Instance.new("RopeConstraint")
	rope.Name = "StringTether"
	local hand = entity.Model:FindFirstChild(HAND_PART)
	rope.Attachment0 = attachTo(rope, if hand and hand:IsA("BasePart") then hand else entity.Root)
	rope.Attachment1 = if target then attachTo(rope, target.Root) else anchorAt(rope, aim)
	rope.Length = (entity.Root.Position - aim).Magnitude
	rope.Thickness = THICKNESS
	rope.Visible = true
	if entity:HasStatus(HAKI_STATUS) then
		rope.Color = BrickColor.new(HAKI_COLOR)
	else
		rope.Color = BrickColor.new(FruitColor.Parse(self:GetColorString()) or DEFAULT_COLOR)
	end
	rope.Parent = getFolder(self, state)

	table.insert(state.Ropes, rope)
	self.Held = rope
	self.HeldTarget = target
	self.Releasing = true
end

function Tether:OnEnd(input)
	-- Only the release of the press that shot the string ties it.
	if not self.Releasing then
		return
	end
	self.Releasing = false

	local entity: CharacterEntity = self.Entity
	local state = getState(self)
	local rope: RopeConstraint? = self.Held
	if not rope or not table.find(state.Ropes, rope) then
		self.Held = nil
		self.HeldTarget = nil
		return
	end
	if entity:HasStatus(STUN_STATUS) then
		dropHeld(self)
		return
	end

	local affinity: number = self:GetAffinity("Sniper")
	-- Legacy counted the string in the hand too, and left it there when over the limit.
	if #state.Ropes >= self:GetLevel("Sniper") / LEVELS_PER_STRING * affinity then
		return
	end

	local startTarget: CharacterEntity? = self.HeldTarget
	self.Held = nil
	self.HeldTarget = nil

	local first = rope.Attachment1
	local firstPart = first and first.Parent
	if not first or not firstPart or not firstPart:IsA("BasePart") or (startTarget and startTarget.Dead) then
		-- The character at the far end is gone.
		forget(state, rope)
		rope:Destroy()
		return
	end

	local aim: Vector3 = input.AimPosition
	local endTarget = resolve(self, aim)
	if endTarget and endTarget == startTarget then
		-- Both ends on the same character: nothing to tie.
		forget(state, rope)
		rope:Destroy()
		return
	end

	local hand = rope.Attachment0
	rope.Attachment0 = if endTarget then attachTo(rope, endTarget.Root) else anchorAt(rope, aim)
	if hand then
		hand:Destroy()
	end
	rope.Length = (firstPart.Position - aim).Magnitude

	if startTarget or endTarget then
		state.Caught = rope
		task.delay(LEASH_SECONDS * affinity, function()
			if table.find(state.Ropes, rope) then
				forget(state, rope)
				rope:Destroy()
			end
		end)
	end
end

function Tether:OnInterrupt()
	self.Releasing = false

	local entity: CharacterEntity = self.Entity
	-- A seal only drops the string in the hand: tied strings stay (see the header).
	if
		not entity.Dead
		and entity.Model.Parent ~= nil
		and entity:HasStatus(AbilityConfig.Status.AbilitiesDisabled)
		and self.Services.Fruit:HasFruit(self.Player, FRUIT_NAME)
	then
		dropHeld(self)
		return
	end

	self.Held = nil
	self.HeldTarget = nil
	local state: State? = entity:GetStatus(STATE_STATUS)
	if state then
		state.Clear()
		local folder = state.Folder
		if folder then
			state.Folder = nil
			folder:Destroy()
		end
		entity:ClearStatus(STATE_STATUS)
	end
end

return Tether
