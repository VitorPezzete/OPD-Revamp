--!strict
--[[
	Hides a whole character on this client for as long as someone asks for it: the one
	shared way for an effect to say "nothing of this body may be seen" (Donut Roll).

		local show = CharacterHide.Hide(character)
		...
		show()      -- safe to call twice

	What is hidden: every BasePart (limbs, FakeHead, accessory handles, tools in hand, the
	shells and pads other effects weld on), every Decal and Texture (the face: a part's
	transparency does not hide a decal on it), and the outlines and highlights adorning the
	body (SelectionBox / SelectionSphere / other adornments, Highlight). Clothing is drawn
	on the limbs and goes with them. NOT hidden: particles, beams, trails, lights and the
	billboards over the head (see the note at the end).

	Why LocalTransparencyModifier and not Transparency. The real Transparency belongs to
	whoever set it: saving it and writing it back later resurrects a value another effect
	changed in the meantime, and misses everything parented to the character after the
	save (armament haki switched on mid-roll welds four shells onto the limbs). The local
	modifier multiplies on top of the real value, so nothing is saved and nothing can be
	restored wrong: showing the body again is "modifier back to 0", whatever the parts'
	own Transparency became meanwhile. FakeHead stays at its Transparency 1.

	Kept true while hidden:
	- instances ADDED to the character are hidden as they arrive (DescendantAdded);
	- instances REMOVED are forgotten and handed back visible (a tool dropped mid-roll);
	- the modifier is written again every frame, after the camera: the camera scripts
	  rewrite the local character's when zooming, and other effects zero it in their own
	  cleanup (Status.Invisible, Status.HobbyToy, the Chop / Ope limbs).

	Several effects may hide the same character: requests are counted and the body comes
	back when the last one lets go. Effects that still hide a body by themselves are not
	counted; the one whose cleanup is what shows the body again is named in
	FOREIGN_HIDERS, and while its status is on the modifiers are left to it.

	Outlines and highlights have no local modifier, so their real Visible / Enabled is
	switched off and switched back on at the end, only for the ones that were on when they
	were met and still exist. One that its owner meant to turn off during the hide comes
	back on: none of the current effects does that.

	Particles and the like are left alone on purpose: they have no local switch either,
	their Enabled is driven by the effects that own them all the time, and the source hid
	parts only.
]]
local RunService = game:GetService("RunService")

local RENDER_STEP_NAME = "CharacterHide"

-- Statuses whose own effect hides every part and decal of the character with the local
-- modifier, tracks late-added ones itself and zeroes them all when it ends, but does not
-- write them again every frame on other players' clients.
local FOREIGN_HIDERS = { "Invisible" }

type State = {
	Count: number,
	Faded: { [Instance]: boolean },
	Switched: { [Instance]: string },
	Connections: { RBXScriptConnection },
}

local CharacterHide = {}

local states: { [Model]: State } = {}
local bound = false

-- Property that shows / hides an instance that has no local modifier, nil for the rest.
local function switchOf(instance: Instance): string?
	if instance:IsA("PVAdornment") then
		return "Visible"
	elseif instance:IsA("Highlight") then
		return "Enabled"
	end
	return nil
end

local function apply(state: State, instance: Instance)
	if instance:IsA("BasePart") or instance:IsA("Decal") then
		(instance :: any).LocalTransparencyModifier = 1
		state.Faded[instance] = true
		return
	end
	local property = switchOf(instance)
	if property and (instance :: any)[property] then
		(instance :: any)[property] = false
		state.Switched[instance] = property
	end
end

local function forget(state: State, instance: Instance)
	if state.Faded[instance] then
		state.Faded[instance] = nil;
		(instance :: any).LocalTransparencyModifier = 0
	end
	local property = state.Switched[instance]
	if property then
		state.Switched[instance] = nil;
		(instance :: any)[property] = true
	end
end

local function step()
	for _, state in states do
		for instance in state.Faded do
			(instance :: any).LocalTransparencyModifier = 1
		end
		-- Turned back on by its owner while the body is hidden (an outline that blinks).
		for instance, property in state.Switched do
			if (instance :: any)[property] then
				(instance :: any)[property] = false
			end
		end
	end
end

local function isHiddenByAnother(character: Model): boolean
	for _, status in FOREIGN_HIDERS do
		local value = character:GetAttribute(status)
		if value ~= nil and value ~= false then
			return true
		end
	end
	return false
end

local function show(character: Model, state: State)
	for _, connection in state.Connections do
		connection:Disconnect()
	end
	if not isHiddenByAnother(character) then
		for instance in state.Faded do
			(instance :: any).LocalTransparencyModifier = 0
		end
	end
	for instance, property in state.Switched do
		if instance:IsDescendantOf(character) then
			(instance :: any)[property] = true
		end
	end
end

-- Hides the character until the returned function is called.
function CharacterHide.Hide(character: Model): () -> ()
	local state = states[character]
	if not state then
		local created: State = { Count = 0, Faded = {}, Switched = {}, Connections = {} }
		state = created
		states[character] = created

		for _, descendant in character:GetDescendants() do
			apply(created, descendant)
		end
		table.insert(
			created.Connections,
			character.DescendantAdded:Connect(function(descendant: Instance)
				apply(created, descendant)
			end)
		)
		table.insert(
			created.Connections,
			character.DescendantRemoving:Connect(function(descendant: Instance)
				forget(created, descendant)
			end)
		)

		if not bound then
			bound = true
			RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, step)
		end
	end
	local held: State = state
	held.Count += 1

	local released = false
	return function()
		if released then
			return
		end
		released = true
		held.Count -= 1
		if held.Count > 0 then
			return
		end

		if states[character] == held then
			states[character] = nil
		end
		if bound and next(states) == nil then
			bound = false
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		end
		show(character, held)
	end
end

-- Whether an effect is hiding the character through this module right now.
function CharacterHide.IsHidden(character: Model): boolean
	return states[character] ~= nil
end

return CharacterHide
