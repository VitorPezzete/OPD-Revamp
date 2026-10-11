--!strict
--[[
	Developer menu: the World and Server tabs (server side: DevWorldCommands,
	DevPrivateCommands, and DevService for the numbers).

	World    clock and its pace, seasons, world events, test enemies and bosses, drop party,
	         private servers (simulating one here, free code server subscriptions)
	Server   live server numbers, who is here, season flags, the audit log and the
	         menu's own request log
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevMenuKit = require(ReplicatedStorage.Client.Modules.DevMenuKit)

local function buildWorld(menu: DevMenuKit.Menu): DevMenuKit.Draw
	local Iris = menu.Iris
	local catalog = menu.Catalog
	local run = menu.Run

	local clockHour = Iris.State(12)
	local clockPace = Iris.State(1)
	local eventName = Iris.State(catalog.Events[1] or "")
	local seasonName = Iris.State(catalog.Seasons[1] or "")
	local enemyName = Iris.State(catalog.Enemies[1] or "")
	local enemyFilter = Iris.State("")
	local enemyCount = Iris.State(1)
	local enemyHarmless = Iris.State(false)
	local bossName = Iris.State(catalog.Bosses[1] or "")
	local partyArmed = Iris.State(0)
	local revokeArmed = Iris.State(0)
	local maxPace = catalog.MaxTimeRate / catalog.TimeRate

	return function()
		local data = menu.GetSnapshot()

		Iris.SeparatorText({
			if data
				then string.format(
					"Clock: %.1fh, %s, pace x%.1f",
					data.ClockTime,
					if data.Night then "night" else "day",
					(data.ClockRate or catalog.TimeRate) / catalog.TimeRate
				)
				else "Clock",
		})
		Iris.SameLine()
		if Iris.SmallButton({ "Set" }).clicked() then
			run("SetTime", clockHour:get())
		end
		if Iris.SmallButton({ "Noon" }).clicked() then
			run("SetTime", 12)
		end
		if Iris.SmallButton({ "Midnight" }).clicked() then
			run("SetTime", 0)
		end
		Iris.SliderNum({ "Hour", 0.5, 0, 24 }, { number = clockHour })
		Iris.End()
		Iris.PushId("pace")
		Iris.SameLine()
		if Iris.SmallButton({ "Set" }).clicked() then
			run("SetTimeRate", clockPace:get() * catalog.TimeRate)
		end
		if Iris.SmallButton({ "Freeze" }).clicked() then
			run("SetTimeRate", 0)
		end
		if Iris.SmallButton({ "Normal" }).clicked() then
			run("SetTimeRate", catalog.TimeRate)
		end
		Iris.SliderNum({ "Pace x", 0.5, 0, maxPace }, { number = clockPace })
		Iris.End()
		Iris.PopId()

		Iris.SeparatorText({ `World events (now: {tostring(data and data.Event or "-")})` })
		Iris.SameLine()
		if Iris.SmallButton({ "Start" }).clicked() then
			run("StartEvent", eventName:get())
		end
		Iris.ComboArray({ "Event" }, { index = eventName }, catalog.Events)
		Iris.End()

		Iris.SeparatorText({ "Seasons" })
		Iris.ComboArray({ "Flag" }, { index = seasonName }, catalog.Seasons)
		Iris.SameLine()
		if Iris.Button({ "Force on" }).clicked() then
			run("SetSeason", seasonName:get(), true)
		end
		if Iris.Button({ "Force off" }).clicked() then
			run("SetSeason", seasonName:get(), false)
		end
		if Iris.Button({ "Calendar" }).clicked() then
			run("SetSeason", seasonName:get(), "calendar")
		end
		Iris.Text({ `now: {tostring(workspace:GetAttribute(`Season_{seasonName:get()}`) == true)}` })
		Iris.End()

		Iris.SeparatorText({ `Test enemies ({tostring(data and data.TestEnemies or 0)} out)` })
		DevMenuKit.FilteredCombo(Iris, "Enemy", catalog.Enemies, enemyName, enemyFilter)
		Iris.SliderNum({ "Count", 1, 1, catalog.MaxSpawnCount }, { number = enemyCount })
		Iris.SameLine()
		if Iris.Button({ "Spawn in front of me" }).clicked() then
			run("SpawnEnemy", enemyName:get(), enemyCount:get(), enemyHarmless:get())
		end
		Iris.Checkbox({ "harmless" }, { isChecked = enemyHarmless })
		Iris.End()
		Iris.PushId("boss")
		Iris.SameLine()
		if Iris.SmallButton({ "Spawn" }).clicked() then
			run("SpawnBoss", bossName:get())
		end
		Iris.ComboArray({ "Boss" }, { index = bossName }, catalog.Bosses)
		Iris.End()
		Iris.PopId()
		if Iris.Button({ "Remove my test enemies" }).clicked() then
			run("RemoveTestEnemies")
		end

		Iris.SeparatorText({ "Boxes" })
		if DevMenuKit.Confirm(Iris, "Drop party around me", partyArmed) then
			run("DropParty")
		end

		-- Private servers without paying for one. The simulation is this server's, whoever
		-- is selected; the target is the owner it gets, or the subscription that is touched.
		local private = data and data.PrivateServer
		Iris.SeparatorText({ "Private server" })
		if not data then
			Iris.Text({ "Waiting for the server..." })
		elseif not private then
			Iris.Text({ "This place does not load private servers.", true })
		else
			local real = if private.Kind == "Public"
				then "really a public server"
				elseif private.Kind == "Roblox" then `really a Roblox private server of {private.RealOwner}`
				else `really a code server of {private.RealOwner}{if private.Code ~= "" then `, code {private.Code}` else ""}`
			Iris.Text({
				if private.Simulated
					then `Now: private, owner {private.Owner}, SIMULATED ({real})`
					elseif private.Private then `Now: private, owner {private.Owner} ({real})`
					else "Now: public server",
				true,
			})
			Iris.SameLine()
			if Iris.Button({ "Simulate (owner = target)" }).clicked() then
				run("PrivateSimulate")
			end
			if Iris.Button({ "Stop simulating" }).clicked() then
				run("PrivateStopSimulating")
			end
			Iris.End()
			Iris.Text({
				if private.Stores
					then "Code servers: the subscription is the real one, saved for the target."
					else "Code servers: the stores are off in Studio, the buttons below need a live server.",
				true,
			})
			Iris.SameLine()
			if Iris.Button({ "Grant subscription to target" }).clicked() then
				run("PrivateGrant")
			end
			if DevMenuKit.Confirm(Iris, "Remove subscription", revokeArmed) then
				run("PrivateRevoke")
			end
			if Iris.Button({ "Check" }).clicked() then
				run("PrivateStatus")
			end
			Iris.End()
		end
	end
end

local function buildServer(menu: DevMenuKit.Menu): DevMenuKit.Draw
	local Iris = menu.Iris
	local info = menu.Catalog.Server

	local report: { [string]: any }? = nil
	local reportAt = 0
	local function refresh()
		menu.Service
			:GetReport("Server")
			:andThen(function(result: { [string]: any }?)
				if result then
					report = result
					reportAt = os.clock()
				else
					menu.PushLog("FAILED  server report: denied or too many requests")
				end
			end)
			:catch(function(problem: any)
				menu.PushLog(`FAILED  server report: {tostring(problem)}`)
			end)
	end

	return function()
		local data = menu.GetSnapshot()

		Iris.SeparatorText({ "Server" })
		if not data then
			Iris.Text({ "Waiting for the server..." })
		else
			Iris.Table({ 2, false, true })
			DevMenuKit.Row(Iris, "Heartbeat", `{data.ServerFps} fps (physics {data.PhysicsFps})`)
			DevMenuKit.Row(Iris, "Memory", `{data.MemoryMb} MB`)
			DevMenuKit.Row(Iris, "Instances", DevMenuKit.Whole(data.Instances))
			DevMenuKit.Row(Iris, "Network", string.format("%.1f kB/s out, %.1f in", data.SendKbps or 0, data.ReceiveKbps or 0))
			DevMenuKit.Row(Iris, "Uptime", DevMenuKit.FormatTime(data.Uptime))
			DevMenuKit.Row(Iris, "Players", `{data.Players} / {info.MaxPlayers}`)
			DevMenuKit.Row(Iris, "Entities / enemies / chests", `{data.Entities} / {data.Enemies} / {data.Chests}`)
			DevMenuKit.Row(Iris, "World event", data.Event)
			Iris.End()
		end

		Iris.Table({ 2, false, true })
		DevMenuKit.Row(Iris, "Place", `{info.PlaceId} v{info.PlaceVersion}`)
		DevMenuKit.Row(Iris, "Job", if info.JobId == "" then "(Studio)" else info.JobId)
		DevMenuKit.Row(Iris, "Kind", `{if info.Studio then "Studio" else "live"}{if info.Private then ", private server" else ""}`)
		DevMenuKit.Row(Iris, "My role", info.Role)
		Iris.End()

		Iris.SeparatorText({ "Details" })
		Iris.SameLine()
		if Iris.Button({ "Refresh players, flags and audit log" }).clicked() then
			refresh()
		end
		Iris.Text({ if report then string.format("%.0f s ago", os.clock() - reportAt) else "not asked yet" })
		Iris.End()

		local details = report
		if details then
			Iris.Text({
				`Progression {if details.Progression then "on" else "off"}, exp x{details.ExpMultiplier}, kill rewards {if details.Rewards
					then "on"
					else "off"}{if details.Closing then ", SHUTTING DOWN" else ""}`,
				true,
			})

			local playersTree = Iris.Tree({ `Players ({#details.Players})`, false, false, true })
			if playersTree.state.isUncollapsed.value then
				for _, player in details.Players do
					Iris.Text({
						`{player.Name} ({player.UserId})  {player.Role}  {player.Ping} ms  {player.Device}  character: {player.Character}{if player.Loaded
							then ""
							else "  DATA NOT LOADED"}`,
					})
				end
			end
			Iris.End()

			local seasonsTree = Iris.Tree({ "Season flags" })
			if seasonsTree.state.isUncollapsed.value then
				for _, season in details.Seasons do
					Iris.Text({ `{season.Flag} = {tostring(season.Active)}` })
				end
			end
			Iris.End()

			local auditTree = Iris.Tree({ `Audit log, newest first ({#details.Audit})` })
			if auditTree.state.isUncollapsed.value then
				for _, entry in details.Audit do
					Iris.Text({ `{os.date("%H:%M:%S", entry.Time)}  {entry.Actor}  {entry.Action}  {entry.Detail}`, true })
				end
			end
			Iris.End()
		end

		Iris.SeparatorText({ "My requests" })
		if #menu.Log == 0 then
			Iris.Text({ "Nothing sent yet." })
		end
		for _, line in menu.Log do
			Iris.Text({ line, true })
		end
	end
end

return {
	World = buildWorld,
	Server = buildServer,
} :: DevMenuKit.Tabs
