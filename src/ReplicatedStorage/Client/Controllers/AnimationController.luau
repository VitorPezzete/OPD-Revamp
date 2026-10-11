--!strict
--[[
	Gets every animation ready before it is needed (see Client.Util.Animations):

	- at start, every animation of AnimationConfig is downloaded;
	- when the local character's Humanoid appears, a track is loaded for each of them on
	  its Animator, a few per frame, so no attack, dash or ability loads one when it
	  plays. Animations that failed to download (legacy assets this place has no
	  permission for) are skipped: loading them would only fail again.

		AnimationController:Play(AnimationConfig.Dash, 0.05, 1, 1.5) -> AnimationTrack?
		AnimationController:GetTrack(AnimationConfig.Dash)           -> AnimationTrack?

	Both act on the local character and return nil while there is none.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Animations = require(ReplicatedStorage.Client.Util.Animations)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)

-- Tracks loaded per frame on a new character.
local LOAD_BATCH = 25
local ANIMATOR_TIMEOUT = 10
-- How long a new character waits for the download to finish before loading anyway.
local PRELOAD_TIMEOUT = 20

local AnimationController = Knit.CreateController({
	Name = "AnimationController",
})

local currentAnimator: Animator? = nil
-- Bumped for every new character, so the loading of an old one stops.
local generation = 0

local function getAnimator(): Animator?
	local animator = currentAnimator
	if animator and animator:IsDescendantOf(game) then
		return animator
	end
	local character = LocalCharacter.Get()
	animator = if character then Animations.FindAnimator(character) else nil
	currentAnimator = animator
	return animator
end

local function loadAll(character: Model, run: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", ANIMATOR_TIMEOUT)
	local animator = humanoid and humanoid:WaitForChild("Animator", ANIMATOR_TIMEOUT)
	if not animator or not animator:IsA("Animator") or generation ~= run then
		return
	end
	currentAnimator = animator

	-- The download tells which assets are usable.
	local deadline = os.clock() + PRELOAD_TIMEOUT
	while not Animations.IsPreloaded() and os.clock() < deadline do
		task.wait(0.25)
	end

	local loaded = 0
	for _, animationId in Animations.All() do
		if generation ~= run or not animator:IsDescendantOf(game) then
			return
		end
		if Animations.IsAvailable(animationId) then
			Animations.Load(animator, animationId)
			loaded += 1
			if loaded % LOAD_BATCH == 0 then
				task.wait()
			end
		end
	end
end

function AnimationController:GetTrack(animationId: string): AnimationTrack?
	local animator = getAnimator()
	return if animator then Animations.Get(animator, animationId) else nil
end

-- Same arguments as Animations.Play: (fadeTime, weight, speed) or one options table.
function AnimationController:Play(
	animationId: string,
	fadeOrOptions: (number | Animations.PlayOptions)?,
	weight: number?,
	speed: number?
): AnimationTrack?
	local animator = getAnimator()
	return if animator then Animations.Play(animator, animationId, fadeOrOptions, weight, speed) else nil
end

function AnimationController:KnitStart()
	task.spawn(Animations.Preload)

	LocalCharacter.Observe(function(character: Model?)
		generation += 1
		currentAnimator = nil
		if character then
			task.spawn(loadAll, character, generation)
		end
	end)
end

return AnimationController
