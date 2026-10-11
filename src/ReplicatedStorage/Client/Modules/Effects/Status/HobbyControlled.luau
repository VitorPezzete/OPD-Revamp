--!strict
--[[
	Hobby fruit - a player toy that has received an order (HobbyControlled status).
	Status value: "<Move|Focus|Special>|<order number>"; a new order restarts the effect.

	Owner only: the player's own controls are switched off for as long as the status is
	set (the server walks the character through the HobbyWalk status), and one of the
	Hobby user's lines is shown on the overlay for three seconds (OneShot.HobbyMessage).

	The lines are the legacy ones, picked here: they are flavor, the server only says
	which kind.
]]
local Players = game:GetService("Players")

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local showMessage = require(script.Parent.Parent.OneShot.HobbyMessage)

local MESSAGES: { [string]: { string } } = {
	Focus = {
		"Kill him for me",
		"Get rid of him for me",
		"Take care of him for me",
		"Make him disappear",
		"Do what must be done",
		"Remove the problem",
		"He's in my way",
		"End this for me",
		"I don't want to see him anymore",
		"Deal with him",
		"Eliminate him",
	},
	Move = {
		"Go there",
		"Head in that direction",
		"Get closer",
		"Follow that path",
		"Stop there",
		"Stay There",
		"Walk forward",
		"Stand right there",
		"Move to that spot",
		"Walk There",
	},
	Special = {
		"You belong to me.",
		"You function better as a tool.",
		"You are not allowed to leave.",
		"You exist to serve a purpose.",
		"Your happiness is irrelevant. Your obedience isn't.",
		"Everything I did was to secure you.",
		"Stay close. That is an order.",
		"I am always monitoring you.",
		"I decide what is best for you.",
		"Leaving was never an option.",
		"You are under my protection.",
		"This arrangement is permanent.",
		"You are my property now.",
		"External connections are unnecessary.",
		"I handle everything. You comply.",
		"Remain where you are.",
		"Do not move.",
		"You were made for this.",
		"Your purpose is here.",
		"Isolation improves performance.",
		"You exist for my use.",
		"You perform better when you focus only on me.",
		"Leaving would be inconvenient.",
		"You have value because I assigned it.",
		"Your feelings are not required.",
		"I decide what fulfills you.",
		"Everything I do has a purpose. You are part of it.",
		"Stay close. It's more efficient.",
		"I am always aware of you.",
		"I know what you need before you do.",
		"Others are unnecessary distractions.",
		"There is no reason to resist.",
		"You are safest when you obey.",
		"This arrangement does not end.",
		"You are mine to command.",
		"Independence is overrated.",
		"I will handle everything.",
		"Remain still.",
		"Good. Just like that.",
		"You were chosen.",
		"You serve a role.",
		"Do not disappoint me.",
		"This is an Order. Say you'll make a contract.",
	},
}

local function noop() end

-- The default control module; absent if the game replaces PlayerModule.
local function getControls(): any
	local playerScripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if not module or not module:IsA("ModuleScript") then
		return nil
	end

	local ok, controls = pcall(function()
		return (require :: any)(module):GetControls()
	end)
	return if ok then controls else nil
end

return function(_character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local kind = EffectAssets.Unpack(value)[1]
	local lines = MESSAGES[kind] or MESSAGES.Move
	showMessage(Vector3.zero, { Text = lines[math.random(#lines)] })

	local controls = getControls()
	if controls then
		controls:Disable()
	end

	return function()
		if controls then
			controls:Enable()
		end
	end
end
