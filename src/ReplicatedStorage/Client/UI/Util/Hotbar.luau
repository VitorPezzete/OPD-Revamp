--!strict
--[[
	The one place that turns the engine's tool bar (the Backpack CoreGui, bottom centre of
	the screen) on and off.

	The engine draws its own interface above everything a game builds, so a window that
	reaches the bottom of the screen has the tool slots drawn over it: on a phone, where a
	window takes the whole height, that is every window of the side menu. A window cannot
	be put above the tool bar; the tool bar can only be taken away while the window is up.

	Two things decide whether it shows, and nobody else may call SetCoreGuiEnabled for the
	Backpack (they would undo each other):

		Hotbar.setCharacter(true)     -- UIController: the tool bar belongs to a character
		local release = Hotbar.hide() -- a hold: hidden until every hold is released
		release()                     -- safe to call twice

	It shows only with a character and no hold. Turning it off does not unequip the held
	tool; it does take the number keys and the gamepad's tool buttons with it, which is why
	the holds are taken on phones and tablets only (Screens.MenuNew).
]]
local StarterGui = game:GetService("StarterGui")

-- SetCoreGuiEnabled errors until the core scripts have registered it.
local MAX_ATTEMPTS = 20
local RETRY_SECONDS = 0.5

local Hotbar = {}

local hasCharacter = false
local holds = 0
-- What the engine was last told; nil until the first call went through.
local applied: boolean? = nil
local applying = false

local function wanted(): boolean
	return hasCharacter and holds == 0
end

-- Yields while the engine is not ready. One runner at a time: a change made while it
-- waits is picked up by the same loop, so the last request always wins.
local function apply()
	if applying then
		return
	end
	applying = true
	local failures = 0
	while applied ~= wanted() and failures < MAX_ATTEMPTS do
		local target = wanted()
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, target) then
			applied = target
			failures = 0
		else
			failures += 1
			task.wait(RETRY_SECONDS)
		end
	end
	applying = false
end

-- With no character (spawn screen, death) the tool bar stays hidden.
function Hotbar.setCharacter(exists: boolean)
	hasCharacter = exists
	task.spawn(apply)
end

-- Hides the tool bar until the returned function is called.
function Hotbar.hide(): () -> ()
	holds += 1
	task.spawn(apply)

	local released = false
	return function()
		if released then
			return
		end
		released = true
		holds -= 1
		task.spawn(apply)
	end
end

return Hotbar
