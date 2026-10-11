--!strict
--[[
	Alice fruit - the world in inverted colors, on a player caught by Cheshire's Grin or
	held in a Wonderland (3 s, renewed while Wonderland keeps holding them).

	Only the victim sees it. Like the legacy LocalScript, it inverts the Color of every
	BasePart in the Workspace (R, G, B -> 255 - R, 255 - G, 255 - B), 2000 parts per
	frame, and puts them back when the status ends. Parts that appear meanwhile are left
	alone, as they were.

	Legacy problem fixed here: the old script inverted a second time to undo, so parts
	that had streamed in or been recoloured meanwhile stayed wrong for good. The original
	colors are remembered instead, and a part is only restored if nothing else changed it.

	Body parts of characters are inverted through a BodyPaint layer instead: fruit effects
	tint them through BodyPaint too, and writing them here would have each side restore
	the other's color as "the original".
]]
local Workspace = game:GetService("Workspace")

local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)

local PARTS_PER_FRAME = 2000

local function noop() end

local function invert(color: Color3): Color3
	return Color3.new(1 - color.R, 1 - color.G, 1 - color.B)
end

return function(_character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	-- Weak keys: a part destroyed meanwhile is simply forgotten.
	local originals: { [BasePart]: Color3 } = setmetatable({}, { __mode = "k" }) :: any
	local inverted: { [BasePart]: Color3 } = setmetatable({}, { __mode = "k" }) :: any
	local releases: { () -> () } = {}
	-- Parent -> whether it is a character (looked up once per parent, not once per part).
	local characters: { [Instance]: boolean } = {}
	local ended = false

	local function isBodyPart(part: BasePart): boolean
		local parent = part.Parent
		if not parent then
			return false
		end
		local known = characters[parent]
		if known ~= nil then
			return known
		end
		local isCharacter = parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") ~= nil
		characters[parent] = isCharacter
		return isCharacter
	end

	local pass = task.spawn(function()
		local count = 0
		for _, descendant in Workspace:GetDescendants() do
			if ended then
				return
			end
			if descendant:IsA("BasePart") then
				local color = descendant.Color
				local flipped = invert(color)
				if isBodyPart(descendant) then
					table.insert(releases, (BodyPaint.Paint({ descendant }, { Color = flipped })))
				else
					originals[descendant] = color
					descendant.Color = flipped
					-- Read back: a part stores 8 bits per channel, so it may differ from `flipped`.
					inverted[descendant] = descendant.Color
				end
				count += 1
				if count >= PARTS_PER_FRAME then
					count = 0
					task.wait()
				end
			end
		end
	end)

	return function()
		ended = true
		if coroutine.status(pass) == "suspended" then
			task.cancel(pass)
		end

		for _, release in releases do
			release()
		end

		task.spawn(function()
			local count = 0
			for part, color in originals do
				-- Recoloured by something else since: that color is the right one now.
				if part.Parent ~= nil and part.Color == inverted[part] then
					part.Color = color
				end
				count += 1
				if count >= PARTS_PER_FRAME then
					count = 0
					task.wait()
				end
			end
		end)
	end
end
