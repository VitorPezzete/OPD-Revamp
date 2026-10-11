--!strict
--[[
	One AnimationTrack per animator and animation, loaded once and reused.

	Loading a track at the moment it should play is what made the first swing of every
	attack late: the asset was still downloading, so the clip started out of step with the
	hit. Here every animation of AnimationConfig is downloaded at start (Preload), and the
	local character's tracks are all loaded as soon as its Humanoid exists
	(AnimationController); everything else gets its track on first use, already downloaded.

		local Animations = require(ReplicatedStorage.Client.Util.Animations)

		local track = Animations.Get(animator, AnimationConfig.Dash)
		track:Play(0.05, 1, 1.5)
		...
		track:Stop(0.1)            -- never Destroy: the track is shared and reused

		Animations.Play(animator, id, fadeTime?, weight?, speed?) -> AnimationTrack
		Animations.Play(animator, id, { Fade, Weight, Speed, Priority, Looped, TimePosition })
		Animations.Restore(track)         puts the asset's own Looped / Priority back
		Animations.FindAnimator(character) -> Animator?
		Animations.All()  -> { string }   every animation id of AnimationConfig
		Animations.Preload()              downloads all of them (yields)
		Animations.IsPreloaded()          the download has finished
		Animations.IsAvailable(id)        false for an asset that failed to download (no
		                                  permission in this place, deleted)

	The legacy game loaded a new track for every play, so each play started from the
	asset's own Looped / Priority and from the fade, weight and speed it was given. A
	shared track would instead keep what the last user left on it, so nothing is carried
	over here:

	- Play sets everything on every call: fade 0.1, weight 1, speed 1 and the asset's own
	  Looped / Priority unless the call says otherwise;
	- Get hands a track that is not playing back with the asset's own Looped / Priority
	  (a playing one belongs to whoever started it and is left alone). Code that plays
	  the track itself sets Looped / Priority after Get, every time, and passes fade,
	  weight and speed to track:Play — its defaults are 0.1, 1, 1, never the last speed.
]]
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)

-- Animations downloaded per PreloadAsync call.
local PRELOAD_BATCH = 20

-- How long a track loaded before its asset arrived is watched for its own properties.
local ORIGINAL_TIMEOUT = 15

local DEFAULT_FADE = 0.1
local DEFAULT_WEIGHT = 1
local DEFAULT_SPEED = 1

export type PlayOptions = {
	Fade: number?,
	Weight: number?,
	Speed: number?,
	Priority: Enum.AnimationPriority?,
	Looped: boolean?,
	TimePosition: number?,
}

-- What the asset itself says: the same for every track of the animation, so it is read
-- once, from a track nobody has been handed yet.
type Original = {
	Looped: boolean,
	Priority: Enum.AnimationPriority,
}

local Animations = {}

local originals: { [string]: Original } = {}
local trackIds: { [AnimationTrack]: string } = setmetatable({} :: any, { __mode = "k" })
-- Tracks given to a caller: what they show from then on may be the caller's, not the asset's.
local handedOut: { [AnimationTrack]: boolean } = setmetatable({} :: any, { __mode = "k" })

local animationObjects: { [string]: Animation } = {}
local failed: { [string]: boolean } = {}
local preloaded = false
local cache: { [Animator]: { [string]: AnimationTrack } } = {}
local allIds: { string }? = nil

local function collect(value: any, into: { string }, seen: { [string]: boolean })
	if type(value) == "string" then
		if string.find(value, "^rbxassetid://") and not seen[value] then
			seen[value] = true
			table.insert(into, value)
		end
	elseif type(value) == "table" then
		for _, child in value do
			collect(child, into, seen)
		end
	end
end

local function getAnimation(animationId: string): Animation
	local animation = animationObjects[animationId]
	if not animation then
		animation = Instance.new("Animation")
		animation.AnimationId = animationId
		animationObjects[animationId] = animation
	end
	return animation
end

-- Every distinct animation id of AnimationConfig (nested tables included).
function Animations.All(): { string }
	if not allIds then
		local ids: { string } = {}
		collect(AnimationConfig, ids, {})
		allIds = ids
	end
	return allIds :: { string }
end

-- Downloads every animation of AnimationConfig. Yields; run it in its own thread.
function Animations.Preload()
	local batch: { Instance } = {}
	local function flush()
		pcall(ContentProvider.PreloadAsync, ContentProvider, batch)
		batch = {}
	end
	for _, animationId in Animations.All() do
		table.insert(batch, getAnimation(animationId))
		if #batch >= PRELOAD_BATCH then
			flush()
		end
	end
	if #batch > 0 then
		flush()
	end
	-- Legacy assets this place may not use: remembered so nothing loads them again.
	for _, animationId in Animations.All() do
		if ContentProvider:GetAssetFetchStatus(animationId) == Enum.AssetFetchStatus.Failure then
			failed[animationId] = true
		end
	end
	preloaded = true
end

function Animations.IsPreloaded(): boolean
	return preloaded
end

function Animations.IsAvailable(animationId: string): boolean
	return not failed[animationId]
end

local function forget(animator: Animator)
	cache[animator] = nil
end

-- Looped and Priority read false / Core until the clip has arrived (Length is 0 until
-- then), so they are only trusted once it has.
local function capture(track: AnimationTrack, animationId: string): boolean
	if originals[animationId] then
		return true
	end
	if handedOut[track] or track.Length <= 0 then
		return false
	end
	originals[animationId] = { Looped = track.Looped, Priority = track.Priority }
	return true
end

local function remember(track: AnimationTrack, animationId: string)
	trackIds[track] = animationId
	if capture(track, animationId) then
		return
	end
	-- Loaded before the download finished (another character's first use, a slow asset).
	task.spawn(function()
		local deadline = os.clock() + ORIGINAL_TIMEOUT
		while not handedOut[track] and track.Parent ~= nil and os.clock() < deadline do
			task.wait(0.1)
			if capture(track, animationId) then
				return
			end
		end
	end)
end

-- Last chance to read the asset's own properties, then the track is the caller's.
local function handOut(track: AnimationTrack)
	if not handedOut[track] then
		local animationId = trackIds[track]
		if animationId then
			capture(track, animationId)
		end
		handedOut[track] = true
	end
end

-- Puts the asset's own Looped / Priority back on a track. Nothing while they are still
-- unknown (the animation has not finished downloading on any character yet).
function Animations.Restore(track: AnimationTrack)
	local animationId = trackIds[track]
	local original = if animationId then originals[animationId] else nil
	if not original then
		return
	end
	if track.Looped ~= original.Looped then
		track.Looped = original.Looped
	end
	if track.Priority ~= original.Priority then
		track.Priority = original.Priority
	end
end

-- The track of `animationId` on `animator`, loaded the first time it is asked for and
-- left exactly as it is: for loading ahead of time. Everything else uses Get or Play.
function Animations.Load(animator: Animator, animationId: string): AnimationTrack
	local tracks = cache[animator]
	if not tracks then
		tracks = {}
		cache[animator] = tracks
		-- The animator goes with its character: drop its tracks with it.
		animator.Destroying:Once(function()
			forget(animator)
		end)
		local ancestry: RBXScriptConnection
		ancestry = animator.AncestryChanged:Connect(function()
			if not animator:IsDescendantOf(game) then
				ancestry:Disconnect()
				forget(animator)
			end
		end)
	end

	local track = tracks[animationId]
	if not track or track.Parent == nil then
		track = animator:LoadAnimation(getAnimation(animationId))
		tracks[animationId] = track
		remember(track, animationId)
	end
	return track
end

-- The track of `animationId` on `animator`. One that is not playing comes back with
-- the asset's own Looped / Priority, whatever its last user set.
function Animations.Get(animator: Animator, animationId: string): AnimationTrack
	local track = Animations.Load(animator, animationId)
	handOut(track)
	if not track.IsPlaying then
		Animations.Restore(track)
	end
	return track
end

--[[
	Plays `animationId` from its start with every property set: the ones given, the
	Roblox defaults for fade / weight / speed and the asset's own Looped / Priority for
	the rest. Takes either (fadeTime, weight, speed) or one PlayOptions table.
]]
function Animations.Play(
	animator: Animator,
	animationId: string,
	fadeOrOptions: (number | PlayOptions)?,
	weight: number?,
	speed: number?
): AnimationTrack
	local fade: number? = nil
	local looped: boolean? = nil
	local priority: Enum.AnimationPriority? = nil
	local timePosition: number? = nil
	if type(fadeOrOptions) == "table" then
		fade = fadeOrOptions.Fade
		weight = fadeOrOptions.Weight
		speed = fadeOrOptions.Speed
		looped = fadeOrOptions.Looped
		priority = fadeOrOptions.Priority
		timePosition = fadeOrOptions.TimePosition
	else
		fade = fadeOrOptions
	end

	local track = Animations.Load(animator, animationId)
	-- A shared track still playing would only blend on: start it over, as a fresh one did.
	if track.IsPlaying then
		track:Stop(0)
	end
	handOut(track)
	Animations.Restore(track)
	if looped ~= nil then
		track.Looped = looped
	end
	if priority ~= nil then
		track.Priority = priority
	end
	track:Play(fade or DEFAULT_FADE, weight or DEFAULT_WEIGHT, speed or DEFAULT_SPEED)
	if timePosition ~= nil then
		track.TimePosition = timePosition
	end
	return track
end

-- The Animator of a character's Humanoid (or AnimationController), if it has one.
function Animations.FindAnimator(character: Instance): Animator?
	local holder = character:FindFirstChildOfClass("Humanoid") or character:FindFirstChildOfClass("AnimationController")
	local animator = holder and holder:FindFirstChildOfClass("Animator")
	return animator
end

return Animations
