--!strict
--[[
	What the AFK world shows to a player besides its saved rewards. AfkWorldService (AFK
	place only) writes these attributes on the Player; the AfkWorld screen reads them.
]]
return table.freeze({
	Attributes = table.freeze({
		-- Server time (Workspace:GetServerTimeNow) of the player's next roll. Absent until
		-- its data is loaded.
		NextRoll = "AfkNextRoll",
	}),
})
