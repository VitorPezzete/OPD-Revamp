--!strict
--[[
	Developer menu: the Fruits and Items tabs (server side: DevInventoryCommands).

	Fruits   the two slots, eating with the real rules, affinities, aura, ability reset,
	         fruit items (backpack or ground)
	Items    weapons, boxes, compasses, drinks, caches, emotes
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevMenuKit = require(ReplicatedStorage.Client.Modules.DevMenuKit)

local AFFINITIES = { "Melee", "Defense", "Sniper", "Sword" }

local function buildFruits(menu: DevMenuKit.Menu): DevMenuKit.Draw
	local Iris = menu.Iris
	local catalog = menu.Catalog
	local run = menu.Run

	local fruitName = Iris.State(catalog.Fruits[1] or catalog.NoFruit)
	local fruitFilter = Iris.State("")
	local slot = Iris.State(1)
	local eatScore = Iris.State(10)
	local eatAura = Iris.State(false)
	local affinityInputs: { [string]: any } = {}
	for _, skill in AFFINITIES do
		Iris.PushId(skill)
		affinityInputs[skill] = Iris.State(2)
		Iris.PopId()
	end
	local primary = Iris.State(Color3.fromRGB(255, 80, 80))
	local secondary = Iris.State(Color3.fromRGB(255, 255, 255))
	local itemAura = Iris.State(false)
	local itemRandom = Iris.State(true)
	local itemScore = Iris.State(10)

	return function()
		local data = menu.GetSnapshot()
		local fruits = if data then data.Fruits else nil

		Iris.SeparatorText({ `Slots of {menu.GetTargetName()}` })
		if not fruits then
			Iris.Text({ "Waiting for the server..." })
		else
			for index, fruit in fruits do
				local affinities = fruit.Affinities
				Iris.Text({
					`Slot {index}: {fruit.Name}   aura {fruit.Color}   M {affinities.Melee} / D {affinities.Defense} / Sn {affinities.Sniper} / Sw {affinities.Sword}`,
					true,
				})
			end
		end

		Iris.SeparatorText({ "Set" })
		DevMenuKit.FilteredCombo(Iris, "Fruit", catalog.Fruits, fruitName, fruitFilter)
		Iris.SliderNum({ "Slot", 1, 1, 2 }, { number = slot })
		Iris.SameLine()
		if Iris.Button({ "Set in slot" }).clicked() then
			run("SetFruit", slot:get(), fruitName:get())
		end
		if Iris.Button({ "Empty slot" }).clicked() then
			run("SetFruit", slot:get(), catalog.NoFruit)
		end
		if Iris.Button({ "Swap slots" }).clicked() then
			run("SwapFruits")
		end
		Iris.End()

		Iris.SeparatorText({ "Eat (the game's rules: free slot, Legendary Mode, death)" })
		Iris.SliderNum({ "Affinity score", 1, 0, 10 }, { number = eatScore })
		Iris.SameLine()
		if Iris.Button({ "Eat selected fruit" }).clicked() then
			run("EatFruit", fruitName:get(), eatScore:get(), eatAura:get())
		end
		Iris.Checkbox({ "with aura" }, { isChecked = eatAura })
		Iris.End()

		Iris.SeparatorText({ `Affinities of slot {slot:get()}` })
		for _, skill in AFFINITIES do
			Iris.PushId(skill)
			Iris.SliderNum({ skill, 0.1, 1, 2 }, { number = affinityInputs[skill] })
			Iris.PopId()
		end
		Iris.SameLine()
		if Iris.Button({ "Apply" }).clicked() then
			run(
				"SetAffinities",
				slot:get(),
				affinityInputs.Melee:get(),
				affinityInputs.Defense:get(),
				affinityInputs.Sniper:get(),
				affinityInputs.Sword:get()
			)
		end
		if Iris.Button({ "Load current" }).clicked() and fruits and fruits[slot:get()] then
			for _, skill in AFFINITIES do
				affinityInputs[skill]:set(fruits[slot:get()].Affinities[skill] or 1)
			end
		end
		Iris.End()

		Iris.SeparatorText({ `Aura of slot {slot:get()}` })
		Iris.InputColor3({ "Primary" }, { color = primary })
		Iris.InputColor3({ "Secondary" }, { color = secondary })
		Iris.SameLine()
		if Iris.Button({ "These colours" }).clicked() then
			run("SetAura", slot:get(), "Custom", primary:get(), secondary:get())
		end
		if Iris.Button({ "Fruit default" }).clicked() then
			run("SetAura", slot:get(), "Default")
		end
		if Iris.Button({ "No aura" }).clicked() then
			run("SetAura", slot:get(), "None")
		end
		Iris.End()

		Iris.SeparatorText({ "Abilities" })
		if Iris.Button({ "Reset ability objects (clears their cooldowns)" }).clicked() then
			run("ResetAbilities")
		end
		Iris.Text({ "HUD timers still run out; dash, shave and weapon specials are not reset.", true })

		Iris.SeparatorText({ "Fruit item (selected fruit)" })
		Iris.Checkbox({ "with aura" }, { isChecked = itemAura })
		Iris.Checkbox({ "random affinities" }, { isChecked = itemRandom })
		Iris.PushId("item")
		Iris.SliderNum({ "Affinity score", 1, 0, 10 }, { number = itemScore })
		Iris.PopId()
		Iris.SameLine()
		if Iris.Button({ "Give as item" }).clicked() then
			run("GiveFruitItem", fruitName:get(), itemAura:get(), if itemRandom:get() then nil else itemScore:get())
		end
		if Iris.Button({ "Drop in front of me" }).clicked() then
			run("DropFruit", fruitName:get())
		end
		Iris.End()
	end
end

local function buildItems(menu: DevMenuKit.Menu): DevMenuKit.Draw
	local Iris = menu.Iris
	local catalog = menu.Catalog
	local run = menu.Run

	local weaponName = Iris.State(catalog.Weapons[1] or "")
	local weaponFilter = Iris.State("")
	local boxName = Iris.State(catalog.Boxes[1] or "")
	local compassName = Iris.State(catalog.Compasses[1] or "")
	local drinkName = Iris.State(catalog.Consumables[1] or "")
	local cacheName = Iris.State(catalog.Caches[1] or "")
	local count = Iris.State(1)
	local emoteIndex = Iris.State(1)

	return function()
		local data = menu.GetSnapshot()

		Iris.SeparatorText({ "Weapons" })
		local loadout = if data then data.Loadout else nil
		if loadout then
			Iris.Text({
				`Loadout: {loadout.Melee} / {loadout.Sniper} / {loadout.Sword} / {loadout.Utility}   ({tostring(data and data.OwnedItems)} items owned)`,
				true,
			})
		end
		DevMenuKit.FilteredCombo(Iris, "Weapon", catalog.Weapons, weaponName, weaponFilter)
		Iris.Text({ `Slot: {tostring(catalog.WeaponSlots[weaponName:get()] or "-")}` })
		Iris.SameLine()
		if Iris.Button({ "Unlock" }).clicked() then
			run("UnlockWeapon", weaponName:get())
		end
		if Iris.Button({ "Unlock + equip" }).clicked() then
			run("EquipWeapon", weaponName:get())
		end
		if Iris.Button({ "Unlock all" }).clicked() then
			run("UnlockAllWeapons")
		end
		if Iris.Button({ "Reset loadout" }).clicked() then
			run("ResetLoadout")
		end
		Iris.End()

		Iris.SeparatorText({ "Backpack items" })
		Iris.SliderNum({ "How many", 1, 1, catalog.MaxGive }, { number = count })
		Iris.PushId("box")
		Iris.SameLine()
		if Iris.SmallButton({ "Give" }).clicked() then
			run("GiveBox", boxName:get(), count:get())
		end
		Iris.ComboArray({ "Box" }, { index = boxName }, catalog.Boxes)
		Iris.End()
		Iris.PopId()
		Iris.PushId("compass")
		Iris.SameLine()
		if Iris.SmallButton({ "Give" }).clicked() then
			run("GiveCompass", compassName:get(), count:get())
		end
		Iris.ComboArray({ "Compass" }, { index = compassName }, catalog.Compasses)
		Iris.End()
		Iris.PopId()
		Iris.PushId("drink")
		Iris.SameLine()
		if Iris.SmallButton({ "Give" }).clicked() then
			run("GiveConsumable", drinkName:get(), count:get())
		end
		Iris.ComboArray({ "Drink" }, { index = drinkName }, catalog.Consumables)
		Iris.End()
		Iris.PopId()
		Iris.PushId("cache")
		Iris.SameLine()
		if Iris.SmallButton({ "Give 1" }).clicked() then
			run("GiveCache", cacheName:get())
		end
		Iris.ComboArray({ "Cache" }, { index = cacheName }, catalog.Caches)
		Iris.End()
		Iris.PopId()

		Iris.SeparatorText({ "Emotes" })
		Iris.SameLine()
		if Iris.SmallButton({ "Grant" }).clicked() then
			run("GrantEmote", emoteIndex:get())
		end
		if Iris.SmallButton({ "Grant all" }).clicked() then
			run("GrantEmote", 0)
		end
		Iris.SliderNum({ "Emote number", 1, 1, math.max(1, catalog.EmoteCount) }, { number = emoteIndex })
		Iris.End()
	end
end

return {
	Fruits = buildFruits,
	Items = buildItems,
} :: DevMenuKit.Tabs
