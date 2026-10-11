--!strict
--[[
	Developer menu: the "Shut down servers" section of the Server tab (server side:
	DevShutdownCommands, ServerPolicyService). The rest of that tab is DevMenuWorld's;
	Main draws the two one after the other.

	Closes every server of the game that runs a version (VersionConfig.Version, the label
	in the corner of the screen), after a countdown and with a reason shown to the
	players. "*" is every server. Owners only: the server refuses anybody else, also in
	the development place where the rest of the menu is open to all.

	Folded by default: it is the one thing of this menu that reaches the whole game.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevMenuKit = require(ReplicatedStorage.Client.Modules.DevMenuKit)

local NOTE_COLOR = Color3.fromRGB(170, 170, 170)
local WARNING_COLOR = Color3.fromRGB(255, 110, 110)
-- Two modules share this tab and Iris names widgets after line numbers alone.
local SECTION_ID = "Shutdown"
local DEFAULT_SECONDS = 300

local function trim(text: string): string
	return (string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

local function buildShutdown(menu: DevMenuKit.Menu): DevMenuKit.Draw
	local Iris = menu.Iris
	-- Absent until DevShutdownCommands is registered in DevService.
	local settings: { [string]: any }? = menu.Catalog.Shutdown
	local ownVersion: string = if settings then settings.Version else ""
	local allVersions: string = if settings then settings.AllVersions else "*"
	local minSeconds: number = if settings then settings.MinSeconds else 10
	local maxSeconds: number = if settings then settings.MaxSeconds else 3600
	local maxReason: number = if settings then settings.MaxReasonLength else 200

	Iris.PushId(SECTION_ID)
	local version = Iris.State(ownVersion)
	local reason = Iris.State("")
	local seconds = Iris.State(math.clamp(DEFAULT_SECONDS, minSeconds, maxSeconds))
	local armed = Iris.State(0)
	Iris.PopId()

	return function()
		Iris.PushId(SECTION_ID)
		local tree = Iris.Tree({ "Shut down servers (by version)" })
		if tree.state.isUncollapsed.value then
			if not settings then
				Iris.Text({ "This server does not offer the command (DevShutdownCommands is not registered).", true, NOTE_COLOR })
			else
				Iris.Text({ `This server runs "{ownVersion}".`, true, NOTE_COLOR })
				Iris.InputText({ "Version", `exact version, or {allVersions} for every server` }, { text = version })
				Iris.InputText({ "Reason", "shown to the players, filtered" }, { text = reason })
				Iris.InputNum({ "Countdown (seconds)", 30, minSeconds, maxSeconds }, { number = seconds })

				local wanted = trim(version:get())
				Iris.Text({
					if wanted == ""
						then "Type a version."
						elseif wanted == allVersions then "EVERY server of the game will close, this one included."
						elseif wanted == ownVersion then `Every server on "{wanted}" will close, this one included.`
						else `Every server on "{wanted}" will close. This one stays open.`,
					true,
					WARNING_COLOR,
				})
				if DevMenuKit.Confirm(Iris, "Shut down these servers", armed) then
					if wanted == "" then
						menu.PushLog("FAILED  ShutdownVersion: type a version")
					elseif #reason:get() > maxReason then
						menu.PushLog(`FAILED  ShutdownVersion: the reason is longer than {maxReason} characters`)
					else
						menu.Run("ShutdownVersion", wanted, math.clamp(math.floor(seconds:get()), minSeconds, maxSeconds), reason:get())
					end
				end
				Iris.Text({
					"Players are kicked when the countdown ends, not teleported. A countdown cannot be cancelled.",
					true,
					NOTE_COLOR,
				})
			end
		end
		Iris.End()
		Iris.PopId()
	end
end

return {
	Server = buildShutdown,
} :: DevMenuKit.Tabs
