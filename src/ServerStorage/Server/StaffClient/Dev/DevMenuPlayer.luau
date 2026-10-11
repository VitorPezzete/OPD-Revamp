--!strict
--[[
	Developer menu: the Player and Combat tabs (server side: DevPlayerCommands).

	Player   the target's character: health, haki, god mode, speed, respawn, teleports
	Combat   test hits through the combat pipeline, stuns, slows, seals, NPC kills and
	         the developer's own combat settings
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Optional = require(ReplicatedStorage.Shared.Util.Optional)

local DevMenuKit = require(ReplicatedStorage.Client.Modules.DevMenuKit)

-- Settings of the developer's own client that matter while testing fights.
local COMBAT_SETTINGS = { "Damage_Numbers", "Hitbox", "Hit_Counter", "Aim_Assist" }

local function buildPlayer(menu: DevMenuKit.Menu): DevMenuKit.Draw
	local Iris = menu.Iris
	local catalog = menu.Catalog
	local run = menu.Run

	local healthBar = Iris.State(0)
	local healthPercent = Iris.State(50)
	local hakiPercent = Iris.State(100)
	local speed = Iris.State(2)
	local spawnIndex = Iris.State(1)
	local islandName = Iris.State(catalog.Islands[1] or "")
	local merchantName = Iris.State(catalog.Merchants[1] or "")
	local position = Iris.State(Vector3.new(0, 250, 0))

	return function()
		local data = menu.GetSnapshot()

		Iris.SeparatorText({ `Character: {menu.GetTargetName()}` })
		if not data then
			Iris.Text({ "Waiting for the server..." })
		elseif data.Health == nil then
			Iris.Text({ "No character (spawn screen)." })
		else
			healthBar:set(if data.MaxHealth > 0 then math.clamp(data.Health / data.MaxHealth, 0, 1) else 0)
			Iris.ProgressBar(
				{ "Health", `{math.floor(data.Health)} / {math.floor(data.MaxHealth)}` },
				{ progress = healthBar }
			)
			Iris.Table({ 2, false, true })
			DevMenuKit.Row(Iris, "Shield", math.floor(data.Shield))
			DevMenuKit.Row(Iris, "Haki", `{math.floor(data.Haki)} / {math.floor(data.HakiMax)}`)
			DevMenuKit.Row(
				Iris,
				"Walk speed",
				string.format("%.1f%s", data.WalkSpeed, if data.Rooted then " (rooted)" else "")
			)
			local at: Vector3 = data.Position
			DevMenuKit.Row(Iris, "Position", string.format("%.0f, %.0f, %.0f", at.X, at.Y, at.Z))
			DevMenuKit.Row(
				Iris,
				"State",
				`{if data.Dead then "dead" elseif data.Spawned then "spawned" else "spawn protection"}{if data.God
					then ", god mode"
					else ""}{if data.Team ~= "" then `, team {data.Team}` else ""}`
			)
			Iris.End()
		end

		Iris.SeparatorText({ "Health" })
		Iris.SameLine()
		if Iris.Button({ "Heal + haki" }).clicked() then
			run("Heal")
		end
		if Iris.Button({ "Kill" }).clicked() then
			run("Kill")
		end
		if Iris.Button({ "Respawn" }).clicked() then
			run("Respawn")
		end
		Iris.End()
		Iris.SameLine()
		if Iris.SmallButton({ "Set" }).clicked() then
			run("SetHealth", healthPercent:get())
		end
		Iris.SliderNum({ "Health %", 1, 1, 100 }, { number = healthPercent })
		Iris.End()
		Iris.PushId("haki")
		Iris.SameLine()
		if Iris.SmallButton({ "Set" }).clicked() then
			run("SetHaki", hakiPercent:get())
		end
		Iris.SliderNum({ "Haki %", 1, 0, 100 }, { number = hakiPercent })
		Iris.End()
		Iris.PopId()
		Iris.SameLine()
		if Iris.Button({ "God mode on" }).clicked() then
			run("SetGod", true)
		end
		if Iris.Button({ "God mode off" }).clicked() then
			run("SetGod", false)
		end
		Iris.Text({ "(until this character dies)" })
		Iris.End()

		Iris.SeparatorText({ "Movement" })
		Iris.SameLine()
		if Iris.SmallButton({ "Set" }).clicked() then
			run("SetWalkSpeed", speed:get())
		end
		if Iris.SmallButton({ "Normal" }).clicked() then
			run("SetWalkSpeed", 1)
		end
		Iris.SliderNum({ "Speed x", 0.1, 0.1, 10 }, { number = speed })
		Iris.End()

		Iris.SeparatorText({ "Teleport" })
		Iris.PushId("spawn")
		Iris.SameLine()
		if Iris.SmallButton({ "Go" }).clicked() then
			run("Teleport", "Spawn", spawnIndex:get())
		end
		Iris.SliderNum({ "Spawn", 1, 1, catalog.SpawnCount }, { number = spawnIndex })
		Iris.End()
		Iris.PopId()
		Iris.PushId("island")
		Iris.SameLine()
		if Iris.SmallButton({ "Go" }).clicked() then
			run("Teleport", "Island", islandName:get())
		end
		Iris.ComboArray({ "Island" }, { index = islandName }, catalog.Islands)
		Iris.End()
		Iris.PopId()
		Iris.PushId("merchant")
		Iris.SameLine()
		if Iris.SmallButton({ "Go" }).clicked() then
			run("Teleport", "Merchant", merchantName:get())
		end
		Iris.ComboArray({ "Merchant" }, { index = merchantName }, catalog.Merchants)
		Iris.End()
		Iris.PopId()
		Iris.PushId("position")
		Iris.SameLine()
		if Iris.SmallButton({ "Go" }).clicked() then
			run("Teleport", "Position", position:get())
		end
		if Iris.SmallButton({ "Here" }).clicked() and data and data.Position then
			position:set(data.Position)
		end
		Iris.InputVector3({ "Position" }, { number = position })
		Iris.End()
		Iris.PopId()

		local targetId = menu.GetTargetId()
		if targetId then
			Iris.SameLine()
			if Iris.Button({ "Bring target to me" }).clicked() then
				run("Teleport", "Developer")
			end
			if Iris.Button({ "Go to target" }).clicked() then
				-- The traveller is the developer, the destination the selected player.
				menu.RunFor(nil, "Teleport", "Player", targetId)
			end
			Iris.End()
		end
	end
end

local function buildCombat(menu: DevMenuKit.Menu): DevMenuKit.Draw
	local Iris = menu.Iris
	local catalog = menu.Catalog
	local run = menu.Run
	-- Not in every place (PlaceManifest): without it the settings rows are left out.
	local SettingsController = Optional.Controller("SettingsController")

	local trait = Iris.State(catalog.Traits[3] or catalog.Traits[1])
	local style = Iris.State(catalog.Styles[2] or catalog.Styles[1])
	local hitAmount = Iris.State(1000)
	local hitCredited = Iris.State(false)
	local healAmount = Iris.State(1000)
	local shield = Iris.State(1000)
	local stunSeconds = Iris.State(3)
	local slowPercent = Iris.State(30)
	local slowSeconds = Iris.State(5)
	local sealSeconds = Iris.State(10)
	local killRadius = Iris.State(100)
	local killCredited = Iris.State(false)

	return function()
		local data = menu.GetSnapshot()

		Iris.SeparatorText({ "Test hit (combat pipeline)" })
		Iris.ComboArray({ "Trait" }, { index = trait }, catalog.Traits)
		Iris.ComboArray({ "Style" }, { index = style }, catalog.Styles)
		Iris.InputNum({ "Amount", 100, 1 }, { number = hitAmount })
		Iris.Checkbox({ "From my character (range, perks, kill credit)" }, { isChecked = hitCredited })
		if Iris.Button({ "Hit target" }).clicked() then
			run("Damage", hitAmount:get(), trait:get(), style:get(), hitCredited:get())
		end

		Iris.SeparatorText({ "Health pool" })
		Iris.SameLine()
		if Iris.SmallButton({ "Heal" }).clicked() then
			run("HealAmount", healAmount:get())
		end
		Iris.InputNum({ "Heal amount", 100, 1 }, { number = healAmount })
		Iris.End()
		Iris.PushId("shield")
		Iris.SameLine()
		if Iris.SmallButton({ "Set" }).clicked() then
			run("SetShield", shield:get())
		end
		Iris.InputNum({ "Shield", 100, 0 }, { number = shield })
		Iris.End()
		Iris.PopId()

		Iris.SeparatorText({ "Control" })
		Iris.SameLine()
		if Iris.SmallButton({ "Stun" }).clicked() then
			run("Stun", stunSeconds:get())
		end
		Iris.SliderNum({ "Stun seconds", 0.5, 0.5, 30 }, { number = stunSeconds })
		Iris.End()
		Iris.SliderNum({ "Slow to % of speed", 5, 5, 100 }, { number = slowPercent })
		Iris.SameLine()
		if Iris.SmallButton({ "Slow" }).clicked() then
			run("Slow", slowPercent:get() / 100, slowSeconds:get())
		end
		Iris.SliderNum({ "Slow seconds", 1, 1, 60 }, { number = slowSeconds })
		Iris.End()
		Iris.SameLine()
		if Iris.SmallButton({ "Seal" }).clicked() then
			run("Seal", true, sealSeconds:get())
		end
		if Iris.SmallButton({ "Unseal" }).clicked() then
			run("Seal", false)
		end
		Iris.SliderNum({ "Seal seconds", 1, 1, 60 }, { number = sealSeconds })
		Iris.End()
		if Iris.Button({ "Interrupt abilities + clear statuses" }).clicked() then
			run("ClearStatuses")
		end

		Iris.SeparatorText({ "NPCs around me" })
		Iris.SliderNum({ "Radius", 5, 5, 500 }, { number = killRadius })
		Iris.Checkbox({ "Credit the kills to me (rewards, drops, quests)" }, { isChecked = killCredited })
		if Iris.Button({ "Kill NPCs in radius" }).clicked() then
			run("KillNearby", killRadius:get(), killCredited:get())
		end

		Iris.SeparatorText({ "My combat settings" })
		for _, name in if SettingsController then COMBAT_SETTINGS else {} do
			Iris.PushId(name)
			Iris.SameLine()
			if Iris.SmallButton({ "Toggle" }).clicked() then
				SettingsController:Cycle(name):catch(warn)
			end
			Iris.Text({ `{name} = {tostring(SettingsController:Get(name))}` })
			Iris.End()
			Iris.PopId()
		end

		local statuses = if data then data.Statuses or {} else {}
		local tree = Iris.Tree({ `Statuses of the target ({#statuses})`, false, false, true })
		if tree.state.isUncollapsed.value then
			if #statuses == 0 then
				Iris.Text({ "none" })
			end
			for _, status in statuses do
				local left = if status.TimeLeft < 0 then "" else string.format("  (%.1fs)", status.TimeLeft)
				Iris.Text({ `{status.Name} = {status.Value}{left}` })
			end
		end
		Iris.End()
	end
end

return {
	Player = buildPlayer,
	Combat = buildCombat,
} :: DevMenuKit.Tabs
