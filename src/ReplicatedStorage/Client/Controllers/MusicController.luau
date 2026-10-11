--!strict
--[[
	Background music rotation, played locally.

	The legacy game ran the rotation on the server with Sounds in Workspace (every client
	then rewrote the replicated Sound's volume locally). Music is presentation: each client
	now runs its own rotation, so the server does nothing and players no longer hear the
	same track at the same moment. The player cannot pick a track (the legacy game had no
	such option), only the volume: Settings.Music.

		MusicController:GetPlaying() -> string?      MusicController.TrackChanged (name)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local MusicConfig = require(ReplicatedStorage.Shared.Configs.MusicConfig)

local MusicController = Knit.CreateController({
	Name = "MusicController",
})

MusicController.TrackChanged = Signal.new() :: Signal.Signal<string>

-- A track that never loads never fires Ended: move on after this long past its end.
local STALL_GRACE_SECONDS = 10
-- Assumed length of a track whose length is unknown (not loaded).
local UNKNOWN_LENGTH_SECONDS = 20

local SettingsController

local random = Random.new()
local sounds: { [string]: Sound } = {}
local current: MusicConfig.Track? = nil
-- Bumped on every track change so timers of an older track do nothing.
local generation = 0

local function applyVolume()
	if not current then
		return
	end
	local step = SettingsController:Get("Music")
	sounds[current.Name].Volume = (if type(step) == "number" then step else 0) * current.VolumeScale
end

local function pickNext(): MusicConfig.Track
	local tracks = MusicConfig.Tracks
	if #tracks == 1 then
		return tracks[1]
	end

	local nextTrack: MusicConfig.Track
	repeat
		nextTrack = tracks[random:NextInteger(1, #tracks)]
	until nextTrack ~= current
	return nextTrack
end

local function playNext()
	generation += 1
	local mine = generation

	local track = pickNext()
	local sound = sounds[track.Name]
	current = track
	applyVolume()

	sound.Looped = true
	sound.TimePosition = 0
	sound:Play()
	MusicController.TrackChanged:Fire(track.Name)

	local advanced = false
	local function advance()
		if advanced or mine ~= generation then
			return
		end
		advanced = true
		sound:Stop()
		playNext()
	end

	local minutes = random:NextInteger(MusicConfig.MinLoopMinutes, MusicConfig.MaxLoopMinutes)
	task.delay(minutes * 60, function()
		if mine ~= generation then
			return
		end
		-- Let the current pass finish instead of cutting the track.
		sound.Looped = false
		sound.Ended:Once(advance)

		local length = if sound.TimeLength > 0 then sound.TimeLength else UNKNOWN_LENGTH_SECONDS
		task.delay(length + STALL_GRACE_SECONDS, advance)
	end)
end

function MusicController:GetPlaying(): string?
	return if current then current.Name else nil
end

function MusicController:KnitInit()
	SettingsController = Knit.GetController("SettingsController")

	local group = Instance.new("SoundGroup")
	group.Name = "Music"
	group.Parent = SoundService

	for _, track in MusicConfig.Tracks do
		local sound = Instance.new("Sound")
		sound.Name = track.Name
		sound.SoundId = track.SoundId
		sound.Volume = 0
		sound.SoundGroup = group
		sound.Parent = group
		sounds[track.Name] = sound
	end
end

function MusicController:KnitStart()
	if #MusicConfig.Tracks == 0 then
		return
	end

	SettingsController:Observe("Music", applyVolume)
	playNext()
end

return MusicController
