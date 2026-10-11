--!strict
--[[
	Background music (legacy Workspace.Music sounds and the volume table of the settings
	script). The legacy folder also held an empty "None" sound that only served as the
	initial value of its "playing" StringValue; it was never in the rotation.
]]

export type Track = {
	Name: string,
	SoundId: string,
	-- Multiplies the player's volume step (Settings.Music, 0..20) to get Sound.Volume.
	VolumeScale: number,
}

local Tracks: { Track } = {
	{ Name = "OverWorld1", SoundId = "rbxassetid://84229353130629", VolumeScale = 1 },
	{ Name = "OverWorld2", SoundId = "rbxassetid://81095083909369", VolumeScale = 1 },
	{ Name = "OverWorld3", SoundId = "rbxassetid://79708250424493", VolumeScale = 1 },
	{ Name = "FightingTrack1", SoundId = "rbxassetid://135245913001758", VolumeScale = 0.5 },
}

return table.freeze({
	Tracks = Tracks,
	-- A track loops for a random whole number of minutes in this range, then plays to its end.
	MinLoopMinutes = 3,
	MaxLoopMinutes = 5,
})
