--!strict
--[[
	Developer menu: the Stats and Economy tabs (server side: DevProgressCommands).

	Stats     skill levels, experience, expertise perks, records, Legendary Mode, full reset
	Economy   currencies and tokens

	Every field shows what the target has now (from the snapshot) next to what is typed.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevMenuKit = require(ReplicatedStorage.Client.Modules.DevMenuKit)

-- Input states of the whitelisted numbers of one group, and the function drawing their rows.
local function buildValues(menu: DevMenuKit.Menu, group: string): () -> ()
	local Iris = menu.Iris
	local inputs: { [string]: any } = {}
	local entries = {}
	for _, entry in menu.Catalog.Values do
		if entry.Group == group then
			Iris.PushId(entry.Key)
			inputs[entry.Key] = Iris.State(0)
			Iris.PopId()
			table.insert(entries, entry)
		end
	end

	return function()
		local data = menu.GetSnapshot()
		local current = if data then data.Values or {} else {}
		for _, entry in entries do
			Iris.PushId(entry.Key)
			-- Inputs stretch to the window edge, so the buttons of a row come first.
			Iris.SameLine()
			if Iris.SmallButton({ "Set" }).clicked() then
				menu.Run("SetValue", entry.Key, inputs[entry.Key]:get())
			end
			if Iris.SmallButton({ "-" }).clicked() then
				menu.Run("AddValue", entry.Key, -entry.Step)
			end
			if Iris.SmallButton({ "+" }).clicked() then
				menu.Run("AddValue", entry.Key, entry.Step)
			end
			if Iris.SmallButton({ "=" }).clicked() and type(current[entry.Key]) == "number" then
				inputs[entry.Key]:set(current[entry.Key])
			end
			Iris.InputNum(
				{ `{entry.Label} (now {DevMenuKit.Whole(current[entry.Key])})`, entry.Step, entry.Min, entry.Max },
				{ number = inputs[entry.Key] }
			)
			Iris.End()
			Iris.PopId()
		end
	end
end

local function buildStats(menu: DevMenuKit.Menu): DevMenuKit.Draw
	local Iris = menu.Iris
	local catalog = menu.Catalog
	local run = menu.Run

	local skillInputs: { [string]: any } = {}
	for _, skill in catalog.Skills do
		Iris.PushId(`skill-{skill}`)
		skillInputs[skill] = Iris.State(catalog.Caps[skill] or 1)
		Iris.PopId()
	end
	local perkInputs: { [string]: any } = {}
	for _, perk in catalog.Perks do
		Iris.PushId(`perk-{perk.Name}`)
		perkInputs[perk.Name] = Iris.State(perk.Limit)
		Iris.PopId()
	end
	local allSkills = Iris.State(500)
	local expSkill = Iris.State(catalog.Skills[1])
	local expAmount = Iris.State(10000)
	local expMultiplied = Iris.State(false)
	local resetArmed = Iris.State(0)
	local drawRecords = buildValues(menu, "Records")

	return function()
		local data = menu.GetSnapshot()
		local levels = if data then data.Levels or {} else {}
		local experience = if data then data.Exp or {} else {}
		local perks = if data then data.Perks or {} else {}

		Iris.SeparatorText({ "Skills" })
		for _, skill in catalog.Skills do
			Iris.PushId(skill)
			Iris.SameLine()
			if Iris.SmallButton({ "Set" }).clicked() then
				run("SetSkill", skill, skillInputs[skill]:get())
			end
			if Iris.SmallButton({ "Max" }).clicked() then
				run("SetSkill", skill, catalog.Caps[skill])
			end
			if Iris.SmallButton({ "-10" }).clicked() then
				run("AddLevels", skill, -10)
			end
			if Iris.SmallButton({ "+10" }).clicked() then
				run("AddLevels", skill, 10)
			end
			Iris.InputNum(
				{ `{skill} (now {tostring(levels[skill] or "-")}, {tostring(experience[skill] or "-")} exp)`, 1, 0, catalog.Caps[skill] or 1000 },
				{ number = skillInputs[skill] }
			)
			Iris.End()
			Iris.PopId()
		end
		Iris.SameLine()
		if Iris.SmallButton({ "Set all" }).clicked() then
			run("SetAllSkills", allSkills:get())
		end
		Iris.InputNum({ "All combat skills", 50, 0, 1000 }, { number = allSkills })
		Iris.End()

		Iris.SeparatorText({ "Experience" })
		Iris.ComboArray({ "Skill" }, { index = expSkill }, catalog.Skills)
		Iris.InputNum({ "Exp", 1000, 1, 1e9 }, { number = expAmount })
		Iris.Checkbox({ "Apply the server exp multiplier" }, { isChecked = expMultiplied })
		if Iris.Button({ "Add exp" }).clicked() then
			run("AddExp", expSkill:get(), expAmount:get(), expMultiplied:get())
		end

		Iris.SeparatorText({
			`Expertise perks ({tostring(data and data.PerkPoints or "-")} points spent, level {tostring(levels.Expertise or "-")})`,
		})
		Iris.SameLine()
		if Iris.Button({ "Max all" }).clicked() then
			run("SetAllPerks", true)
		end
		if Iris.Button({ "Empty all" }).clicked() then
			run("SetAllPerks", false)
		end
		Iris.End()
		local tree = Iris.Tree({ "Perk by perk" })
		if tree.state.isUncollapsed.value then
			for _, perk in catalog.Perks do
				local saved = perks[perk.Name]
				local limit = if saved then saved.Limit else perk.Limit
				Iris.PushId(perk.Name)
				Iris.SameLine()
				if Iris.SmallButton({ "Set" }).clicked() then
					run("SetPerk", perk.Name, perkInputs[perk.Name]:get())
				end
				if Iris.SmallButton({ "Max" }).clicked() then
					run("SetPerk", perk.Name, limit)
				end
				Iris.InputNum(
					{ `{perk.Name} (now {tostring(if saved then saved.Value else "-")} / {limit})`, 1, 0, limit },
					{ number = perkInputs[perk.Name] }
				)
				Iris.End()
				Iris.PopId()
			end
		end
		Iris.End()

		Iris.SeparatorText({ "Records" })
		drawRecords()

		Iris.SeparatorText({ `Legendary Mode: {if data and data.Legendary then "on" else "off"}` })
		Iris.SameLine()
		if Iris.Button({ "Turn on" }).clicked() then
			run("SetLegendary", true)
		end
		if Iris.Button({ "Turn off" }).clicked() then
			run("SetLegendary", false)
		end
		Iris.Text({ "(the flag only: nothing is taken)" })
		Iris.End()

		Iris.SeparatorText({ "Reset" })
		if DevMenuKit.Confirm(Iris, "Full stat reset (items, Beri, bounty, skills, fruits)", resetArmed) then
			run("ResetStats")
		end
	end
end

local function buildEconomy(menu: DevMenuKit.Menu): DevMenuKit.Draw
	local Iris = menu.Iris
	local drawCurrencies = buildValues(menu, "Currencies")
	local drawTokens = buildValues(menu, "Tokens")

	return function()
		Iris.Text({ "Set writes the field; - and + move the saved value by one step; = copies it into the field.", true })
		Iris.SeparatorText({ "Currencies" })
		drawCurrencies()
		Iris.SeparatorText({ "Tokens" })
		drawTokens()
	end
end

return {
	Stats = buildStats,
	Economy = buildEconomy,
} :: DevMenuKit.Tabs
