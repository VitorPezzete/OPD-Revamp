--!strict
--[[
	The parts of the game's own rig (StarterPlayer.StarterCharacter, R6).

	It differs from a stock rig in one thing: the face is not `Head.face`. The Head holds
	`FakeHead` (1x1x1 part, Transparency 1, welded with a WeldConstraint, own SpecialMesh)
	and the Decal `Face` is on that part. Consequences, for whoever edits a character:

	- read / change / hide the face through GetFace, never `Head.face`;
	- FakeHead must stay at Transparency 1. Anything that hides a body by writing the real
	  Transparency has to restore each part's original value (SaveTransparency /
	  RestoreTransparency), not "all parts to 0": that would show a grey block on the head.
	  Effects that use LocalTransparencyModifier are safe as they are (it multiplies) and
	  hide the face too, as long as they walk descendants and not only the six limbs.

	NPC models that still carry a classic `Head.face` are supported by the same lookup.
]]
local CharacterParts = {}

CharacterParts.FakeHeadName = "FakeHead"
CharacterParts.FaceName = "Face"
CharacterParts.Limbs = table.freeze({ "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" })

local LEGACY_FACE_NAME = "face"

export type SavedTransparency = { [Instance]: number }

function CharacterParts.GetHead(character: Instance): BasePart?
	local head = character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

-- The invisible part that carries the face.
function CharacterParts.GetFakeHead(character: Instance): BasePart?
	local head = character:FindFirstChild("Head")
	local fake = head and head:FindFirstChild(CharacterParts.FakeHeadName)
	return if fake and fake:IsA("BasePart") then fake else nil
end

-- Head.FakeHead.Face, or a classic Head.face on rigs that are not ours.
function CharacterParts.GetFace(character: Instance): Decal?
	local fake = CharacterParts.GetFakeHead(character)
	local face = fake and fake:FindFirstChild(CharacterParts.FaceName)
	if face and face:IsA("Decal") then
		return face
	end

	local head = character:FindFirstChild("Head")
	local legacy = head and (head:FindFirstChild(LEGACY_FACE_NAME) or head:FindFirstChild(CharacterParts.FaceName))
	return if legacy and legacy:IsA("Decal") then legacy else nil
end

--[[
	The face decal, created where the rig expects it when it is missing: on FakeHead when
	the character has one, on the Head otherwise (NPC rigs). Nil without a head.
]]
function CharacterParts.EnsureFace(character: Instance): Decal?
	local face = CharacterParts.GetFace(character)
	if face then
		return face
	end

	local parent = CharacterParts.GetFakeHead(character) or CharacterParts.GetHead(character)
	if not parent then
		return nil
	end
	local created = Instance.new("Decal")
	created.Name = CharacterParts.FaceName
	created.Face = Enum.NormalId.Front
	created.Parent = parent
	return created
end

function CharacterParts.SetFaceTexture(character: Instance, texture: string): boolean
	local face = CharacterParts.EnsureFace(character)
	if face then
		face.Texture = texture
	end
	return face ~= nil
end

-- Hides or shows the face only (real Transparency: use it on the server or on clones).
function CharacterParts.SetFaceHidden(character: Instance, hidden: boolean)
	local face = CharacterParts.GetFace(character)
	if face then
		face.Transparency = if hidden then 1 else 0
	end
end

--[[
	True for a part that is invisible by design and must never be made visible: the
	FakeHead and the HumanoidRootPart. Use it before writing Transparency on "every part".
]]
function CharacterParts.IsMeantInvisible(part: Instance): boolean
	if not part:IsA("BasePart") then
		return false
	end
	if part.Name == "HumanoidRootPart" then
		return true
	end
	local parent = part.Parent
	return part.Name == CharacterParts.FakeHeadName and parent ~= nil and parent.Name == "Head"
end

--[[
	A cloned Head keeps its face only through FakeHead. Loose copies of a head (severed
	limbs, statues) drop every child part: this moves the face decal onto the copy itself
	first, so the copy still has a face. Call it before destroying the copy's children.
]]
function CharacterParts.FlattenFace(headCopy: BasePart)
	local fake = headCopy:FindFirstChild(CharacterParts.FakeHeadName)
	local face = fake and fake:FindFirstChild(CharacterParts.FaceName)
	if face and face:IsA("Decal") then
		face.Parent = headCopy
	end
end

-- Real Transparency of every part and decal of the character, to give back later.
function CharacterParts.SaveTransparency(character: Instance): SavedTransparency
	local saved: SavedTransparency = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			saved[descendant] = (descendant :: any).Transparency
		end
	end
	return saved
end

--[[
	Writes `transparency` on every part and decal of the character (face included), except
	the parts that are invisible by design when the body is being shown. Returns what was
	there before, for RestoreTransparency.
]]
function CharacterParts.SetBodyTransparency(character: Instance, transparency: number): SavedTransparency
	local saved = CharacterParts.SaveTransparency(character)
	for instance in saved do
		if transparency >= 1 or not CharacterParts.IsMeantInvisible(instance) then
			(instance :: any).Transparency = transparency
		end
	end
	return saved
end

-- Gives every instance its own original value back (FakeHead returns to 1, not to 0).
function CharacterParts.RestoreTransparency(saved: SavedTransparency)
	for instance, transparency in saved do
		if instance.Parent then
			(instance :: any).Transparency = transparency
		end
	end
end

return CharacterParts
