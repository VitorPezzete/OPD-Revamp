--!strict
--[[
	Where and when Silvers Rayleigh (Workspace.Map.Merchants.QuestHakiMerchant) shows up.
	He is away most of the time and never appears twice in a row at the same spot.
]]
return table.freeze({
	-- Seconds he stays away, then seconds he stays around.
	AwayDuration = 50 * 60,
	ActiveDuration = 10 * 60,

	Spawns = table.freeze({
		CFrame.new(-6051.499, 402.1, -7) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(-1181, 218, 1797.5),
		CFrame.new(2054, 492, -584.283),
		CFrame.new(-5159.5, 295, -7800.5) * CFrame.Angles(0, math.rad(270), 0),
		CFrame.new(-2028.5, 239.5, 3382.5) * CFrame.Angles(0, math.rad(180), 0),
		CFrame.new(6908, 216.5, -1312.414) * CFrame.Angles(0, math.rad(-135), 0),
	}),
})
