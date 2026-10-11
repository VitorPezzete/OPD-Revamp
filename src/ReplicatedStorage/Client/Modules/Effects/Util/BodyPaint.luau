--!strict
--[[
	The single owner of the look (Color, Material) of a character's body parts on this
	client. Every effect that tints a body goes through here instead of writing the part.

	Why. Each effect used to read the limb's color, tint it and write that color back
	when it ended. Two overlapping effects (two fruits, a body ability, a weapon status)
	broke that: the second read the first one's tint as "the original" and restored it
	last, so the limb kept an effect color for good. The same happened when the skin was
	applied or changed while a tint was on (the stale color came back over the new one).

	How. A part carries a stack of paint layers:
	- BodyPaint.Paint adds a layer on top and returns `release` and `repaint`;
	- the part shows, for each property, the most recent live layer that sets it;
	- releasing a layer, in any order and any number of times, shows what is left, and the
	  part gets its true look back when the last layer goes.

	The true look is read once, when the first layer lands on a part. It is then kept up
	to date by watching the part: BodyPaint remembers what it wrote last, so a Color or
	Material it finds on the part that is not its own was written by the game (Body Colors
	replicated from the server for a skin or a dye, the low graphics mode...). That value
	becomes the true look and the top layer is drawn over it again. Nothing has to call in
	to announce a skin change, and the same check runs before every paint and release, so
	a write is never lost even if its signal was.

	Cost: four connections per painted part, only while it is painted. Layers are dropped
	when the part is destroyed or leaves the DataModel. Any BasePart works (players, NPCs,
	bosses).

	Transparency is not handled here: body parts are hidden and shown by many effects that
	write it directly, and drawing a layer back over them would undo an invisibility.
]]
local BodyPaint = {}

-- A property left nil is not touched by the layer.
export type Look = {
	Color: Color3?,
	Material: Enum.Material?,
}

type Layer = {
	Color: Color3?,
	Material: Enum.Material?,
	Parts: { BasePart },
	Released: boolean,
}

type Entry = {
	Part: BasePart,
	BaseColor: Color3,
	BaseMaterial: Enum.Material,
	-- What BodyPaint wrote last, read back from the part (a part stores 8 bits per channel).
	ShownColor: Color3,
	ShownMaterial: Enum.Material,
	Layers: { Layer },
	-- True during our own writes: with immediate signals the watcher runs inside them.
	Writing: boolean,
	Connections: { RBXScriptConnection },
}

local WATCHED_PROPERTIES = { "Color", "Material" }

local entries: { [BasePart]: Entry } = {}

-- Anything on the part that we did not write is the game's: it becomes the true look.
local function absorb(entry: Entry)
	local part = entry.Part
	if part.Color ~= entry.ShownColor then
		entry.BaseColor = part.Color
		entry.ShownColor = part.Color
	end
	if part.Material ~= entry.ShownMaterial then
		entry.BaseMaterial = part.Material
		entry.ShownMaterial = part.Material
	end
end

-- Draws the true look with every live layer over it, oldest first.
local function render(entry: Entry)
	local color, material = entry.BaseColor, entry.BaseMaterial
	for _, layer in entry.Layers do
		color = layer.Color or color
		material = layer.Material or material
	end

	local part = entry.Part
	entry.Writing = true
	part.Color = color
	part.Material = material
	entry.Writing = false
	entry.ShownColor = part.Color
	entry.ShownMaterial = part.Material
end

-- Gives the part its true look back and forgets it.
local function forget(entry: Entry)
	if entries[entry.Part] ~= entry then
		return
	end
	entries[entry.Part] = nil
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
	table.clear(entry.Connections)

	absorb(entry)
	table.clear(entry.Layers)
	render(entry)
end

local function watch(part: BasePart): Entry
	local entry: Entry = {
		Part = part,
		BaseColor = part.Color,
		BaseMaterial = part.Material,
		ShownColor = part.Color,
		ShownMaterial = part.Material,
		Layers = {},
		Writing = false,
		Connections = {},
	}
	entries[part] = entry

	local function changed()
		if entry.Writing or entries[part] ~= entry then
			return
		end
		absorb(entry)
		render(entry)
	end
	for _, property in WATCHED_PROPERTIES do
		table.insert(entry.Connections, part:GetPropertyChangedSignal(property):Connect(changed))
	end
	table.insert(
		entry.Connections,
		part.AncestryChanged:Connect(function()
			if not part:IsDescendantOf(game) then
				forget(entry)
			end
		end)
	)
	-- Destroying still reaches its handlers when signals are deferred; AncestryChanged may not.
	table.insert(
		entry.Connections,
		part.Destroying:Once(function()
			forget(entry)
		end)
	)
	return entry
end

-- The entry of a part if this layer is still on it.
local function entryOf(part: BasePart, layer: Layer): Entry?
	local entry = entries[part]
	return if entry and table.find(entry.Layers, layer) then entry else nil
end

-- The BasePart children of `character` with these names, in the order given.
function BodyPaint.Limbs(character: Instance, names: { string }): { BasePart }
	local limbs: { BasePart } = {}
	for _, name in names do
		local limb = character:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			table.insert(limbs, limb)
		end
	end
	return limbs
end

--[[
	Adds a layer over `parts`. Returns:
	- release(): removes the layer; safe to call twice, after the parts are gone, and in
	  any order with other layers;
	- repaint(look): changes what the layer shows without moving it in the stack (a body
	  that darkens with haki). Does nothing once released.
]]
function BodyPaint.Paint(parts: { BasePart }, look: Look): (() -> (), (Look) -> ())
	local layer: Layer = {
		Color = look.Color,
		Material = look.Material,
		Parts = table.clone(parts),
		Released = false,
	}

	for _, part in layer.Parts do
		if not part:IsDescendantOf(game) then
			continue
		end
		local entry = entries[part] or watch(part)
		absorb(entry)
		table.insert(entry.Layers, layer)
		render(entry)
	end

	local function release()
		if layer.Released then
			return
		end
		layer.Released = true
		for _, part in layer.Parts do
			local entry = entryOf(part, layer)
			if not entry then
				continue
			end
			if #entry.Layers == 1 then
				forget(entry)
			else
				absorb(entry)
				table.remove(entry.Layers, table.find(entry.Layers, layer))
				render(entry)
			end
		end
		table.clear(layer.Parts)
	end

	local function repaint(newLook: Look)
		if layer.Released then
			return
		end
		layer.Color = newLook.Color
		layer.Material = newLook.Material
		for _, part in layer.Parts do
			local entry = entryOf(part, layer)
			if entry then
				absorb(entry)
				render(entry)
			end
		end
	end

	return release, repaint
end

return BodyPaint
