return function(fruitNames)
	local bridge = game.ServerStorage.DevBridge
	local player = game.Players:GetPlayers()[1]
	local FruitConfig = require(game.ReplicatedStorage.Shared.Configs.FruitConfig)
	local errors = {}
	local conn = game:GetService("ScriptContext").Error:Connect(function(msg, trace, src)
		table.insert(errors, (tostring(src and src.Name) .. ": " .. msg):sub(1, 230))
	end)
	for _, s in {"Melee", "Defense", "Sniper", "Sword", "Haki"} do bridge:Invoke("SetData", player, "Skills." .. s .. ".Level", 500) end
	local function pickEnemy()
		local best, bestHp
		for _, m in workspace.Enemies:GetChildren() do
			local hp = m:GetAttribute("Health")
			if hp and hp > 0 and m:FindFirstChild("HumanoidRootPart") and (not bestHp or hp > bestHp) then best, bestHp = m, hp end
		end
		return best
	end
	local out = {}
	for _, fruit in fruitNames do
		local def = FruitConfig.Fruits[fruit]
		if not def then table.insert(out, fruit .. ": not in config") continue end
		bridge:Invoke("Call", "FruitService", "RemoveFruit", player, 1)
		bridge:Invoke("Call", "FruitService", "EatFruit", player, fruit, {Defense = 5, Melee = 5, Sniper = 5, Sword = 5}, true)
		task.wait(0.2)
		local line = {fruit}
		local fruitErrors = #errors
		for _, ability in def.Abilities do
			local char = player.Character
			local hp = char and char:GetAttribute("Health")
			if not hp or hp <= 0 then
				table.insert(line, "[respawning]")
				repeat task.wait(0.5) char = player.Character until char and (char:GetAttribute("Health") or 0) > 0
				game.ReplicatedStorage:SetAttribute("NeedSpawn", true)
				task.wait(6)
			end
			char = player.Character
			local enemy = pickEnemy()
			local eroot = enemy.HumanoidRootPart
			char:PivotTo(eroot.CFrame * CFrame.new(0, 3, 6))
			task.wait(0.15)
			local aim = eroot.Position
			local hpBefore = enemy:GetAttribute("Health")
			local before = #errors
			local slot = ability.Slot
			local function send(phase) bridge:Invoke("Call", "AbilityService", "HandleInput", player, 1, slot, phase, aim) end
			send(1) task.wait(0.7)
			local on = 0
			for k in char:GetAttributes() do if k:sub(1, #fruit) == fruit then on += 1 end end
			send(3) task.wait(0.2)
			send(2) task.wait(1.2)
			send(1) task.wait(0.3)
			send(2) task.wait(0.4)
			local dmg = math.floor(hpBefore - (enemy:GetAttribute("Health") or 0))
			table.insert(line, string.format("%d:%s[st=%d dmg=%d err=%d]", slot, ability.Name, on, dmg, #errors - before))
		end
		bridge:Invoke("Call", "FruitService", "RemoveFruit", player, 1)
		task.wait(0.5)
		local char = player.Character
		local left = {}
		if char then for k in char:GetAttributes() do if k:sub(1, #fruit) == fruit then table.insert(left, k) end end end
		table.insert(line, "leftover=[" .. table.concat(left, ",") .. "] ws=" .. (char and math.floor(char.Humanoid.WalkSpeed) or -1) .. " fruitErrors=" .. (#errors - fruitErrors))
		table.insert(out, table.concat(line, " "))
	end
	conn:Disconnect()
	local seen, uniq = {}, {}
	for _, e in errors do if not seen[e] then seen[e] = true table.insert(uniq, e) end end
	return table.concat(out, "\n") .. "\n--- distinct server errors (" .. #uniq .. ")\n" .. table.concat(uniq, "\n")
end
