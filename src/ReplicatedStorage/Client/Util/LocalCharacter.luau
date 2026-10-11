--!strict
--[[
	The local player's character, for code that has to know whether there is one.

	A player has no character for long stretches: from joining until Spawn is pressed,
	and from a death until the next spawn (Players.CharacterAutoLoads is off, see
	CharacterService on the server). "No character" is therefore a normal state, not a
	loading gap to wait out with CharacterAdded:Wait().
]]
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local LocalCharacter = {}

-- The character, nil while the player is on the spawn screen (or its body was removed).
function LocalCharacter.Get(): Model?
	return localPlayer.Character
end

function LocalCharacter.Exists(): boolean
	return localPlayer.Character ~= nil
end

--[[
	Calls `callback(character?)` now and every time the character appears or goes away.
	Returns a function that stops observing.
]]
function LocalCharacter.Observe(callback: (character: Model?) -> ()): () -> ()
	local ancestry: RBXScriptConnection? = nil
	local published: Model? = nil
	local first = true

	local function publish(character: Model?)
		if first or character ~= published then
			first = false
			published = character
			task.spawn(callback, character)
		end
	end

	local function watch(character: Model)
		if ancestry then
			ancestry:Disconnect()
		end
		-- A body destroyed without the Character property being cleared is gone all the same.
		ancestry = character.AncestryChanged:Connect(function()
			if character.Parent == nil and published == character then
				publish(nil)
			end
		end)
		publish(character)
	end

	local added = localPlayer.CharacterAdded:Connect(watch)
	local removing = localPlayer.CharacterRemoving:Connect(function(character: Model)
		if published == character then
			publish(nil)
		end
	end)

	local current = localPlayer.Character
	if current then
		watch(current)
	else
		publish(nil)
	end

	return function()
		added:Disconnect()
		removing:Disconnect()
		if ancestry then
			ancestry:Disconnect()
			ancestry = nil
		end
	end
end

return LocalCharacter
