--!strict

local PLACE_ID: number = 70580933622015
local GROUP_ID: number = 649034590
local REQUIRED_RANK: number = 2

local Players: Players = game:GetService("Players")

local function onPlayerAdded(player: Player)
	local success: boolean, rankOrError: any = pcall(function(): number
		return player:GetRankInGroup(GROUP_ID)
	end)

	if success then
		local rank: number = rankOrError :: number
		if rank < REQUIRED_RANK then
			player:Kick("You must be at least rank Tester to join.")
			print("Player " .. player.Name .. " was kicked. Rank was " .. tostring(rank) .. ".")
		else
			print("Player " .. player.Name .. " joined successfully. Rank: " .. tostring(rank) .. ".")
		end
	else
		player:Kick("Failed to check group rank. Please try rejoining.")
		warn("GetRankInGroup failed for player " .. player.Name .. ". Error: " .. tostring(rankOrError))
	end
end

if game.PlaceId ~= PLACE_ID then return end

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)