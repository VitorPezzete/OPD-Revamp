--!strict
--[[
	The trail of a basic attack, for the weapons that had one in the legacy game. Played
	by AttackService for every accepted swing of those weapons.
	params: { Caster: Model, Weapon: string, Right: boolean }

	Fighting styles (legacy ServerStorage.Backups.Weapons.Melee.<Tool>.Script): each swing
	cloned Weapons.Melee.MeleePart into the limb that strikes, welded to its centre, and
	destroyed it when the swing's cooldown ended:
	- Melee: the punching arm, 0.4 s;
	- Black Leg: the kicking leg, 0.5 s;
	- Table Kick: both legs, 0.5 s.
	MeleePart is an invisible 1 x 2 x 1 part with a Trail between two attachments 1.5
	studs above and below its centre: white, half transparent from end to end, 0.1 s long,
	no texture. It is cloned from ReplicatedStorage.Assets.Models.Weapons.Melee.MeleePart;
	without that asset the same part is built here from those properties.

	Which arm / leg: the one of the swing clip the caster is playing (the clips alternate
	on the owner's client and replicate through its Animator), so the trail is always on
	the limb that moves. `Right` is the server's own alternation, starting on the left as
	the legacy scripts did, and is only used when no clip can be seen (not loaded, or not
	arrived yet). A clip that starts just after the trail moves it to its limb.

	Kanshou and Bakuya (legacy ...Weapons.Sword["Kanshou and Bakuya"]): the swing lit the
	Trail / Trail2 of both held blades for 0.25 s. They are the trails of the held models
	(children of the Tool), off as authored. No other sword script ever enabled its
	trails, so no other sword shows any.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

type Style = {
	-- Seconds the trail part lives (the legacy wait before Destroy).
	Life: number,
	-- Limbs that always carry one.
	Limbs: { string }?,
	-- Or one of two, alternating: the limb of the server's `Right` flag...
	Left: string?,
	Right: string?,
	-- ...unless one of these clips (asset number -> limb) says which one swings.
	Clips: { [string]: string }?,
}

local function assetNumber(animationId: string): string
	return string.match(animationId, "%d+$") or animationId
end

-- The kick clips are bare ids in the legacy script (see CombatController, which plays them).
local KICK_LEFT = "129285292341912"
local KICK_RIGHT = "81712806646228"

local STYLES: { [string]: Style } = {
	Melee = {
		Life = 0.4,
		Left = "Left Arm",
		Right = "Right Arm",
		Clips = {
			[assetNumber(AnimationConfig.MeleeL)] = "Left Arm",
			[assetNumber(AnimationConfig.MeleeR)] = "Right Arm",
		},
	},
	["Black Leg"] = {
		Life = 0.5,
		Left = "Left Leg",
		Right = "Right Leg",
		Clips = { [KICK_LEFT] = "Left Leg", [KICK_RIGHT] = "Right Leg" },
	},
	["Table Kick"] = { Life = 0.5, Limbs = { "Right Leg", "Left Leg" } },
}

local TWIN_BLADES = "Kanshou and Bakuya"
local TWIN_BLADES_LIFE = 0.25

-- How long after the trail appears a swing clip may still claim it for its own limb.
local SETTLE_TIME = 0.15
local MIN_TRACK_SPEED = 0.01

local TRAIL_PART = "WeaponSwingTrail"
-- MeleePart, for when the asset is missing.
local PART_SIZE = Vector3.new(1, 2, 1)
local TRAIL_REACH = 1.5
local TRAIL_TRANSPARENCY = 0.5
local TRAIL_LIFETIME = 0.1
local TRAIL_MIN_LENGTH = 0.05
local TRAIL_COLOR = Color3.fromRGB(255, 255, 255)

local function buildTrailPart(): BasePart
	local part = Instance.new("Part")
	part.Size = PART_SIZE
	part.Transparency = 1

	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, TRAIL_REACH, 0)
	top.Parent = part
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -TRAIL_REACH, 0)
	bottom.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(TRAIL_COLOR)
	trail.Transparency = NumberSequence.new(TRAIL_TRANSPARENCY)
	trail.Lifetime = TRAIL_LIFETIME
	trail.MinLength = TRAIL_MIN_LENGTH
	trail.LightEmission = 0
	trail.LightInfluence = 0
	trail.FaceCamera = false
	trail.Parent = part
	return part
end

-- A trail part welded to the centre of `limb`, as the legacy server welded MeleePart.
local function addTrail(limb: BasePart): BasePart
	local template = EffectAssets.Find("Models", "Weapons", "Melee", "MeleePart")
	local part: BasePart = if template and template:IsA("BasePart") then template:Clone() else buildTrailPart()
	part.Name = TRAIL_PART
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	-- Already in place when it enters the world: the trail must not start somewhere else.
	part.CFrame = limb.CFrame

	local weld = Instance.new("Weld")
	weld.Part0 = limb
	weld.Part1 = part
	weld.Parent = part

	part.Parent = limb
	return part
end

local function findLimb(character: Model, name: string?): BasePart?
	local limb = if name then character:FindFirstChild(name) else nil
	return if limb and limb:IsA("BasePart") then limb else nil
end

local function limbOfTrack(track: AnimationTrack, clips: { [string]: string }): string?
	local animation = track.Animation
	return if animation then clips[assetNumber(animation.AnimationId)] else nil
end

-- The limb of the swing clip that started last on `animator`, nil when none is playing.
local function swingingLimb(animator: Animator, clips: { [string]: string }): string?
	local best: string? = nil
	local bestAge = math.huge
	for _, track in animator:GetPlayingAnimationTracks() do
		local limb = limbOfTrack(track, clips)
		if limb then
			local age = track.TimePosition / math.max(math.abs(track.Speed), MIN_TRACK_SPEED)
			if age < bestAge then
				best, bestAge = limb, age
			end
		end
	end
	return best
end

local function alternatingTrail(character: Model, style: Style, right: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local clips = style.Clips

	local limbName: string? = if animator and clips then swingingLimb(animator, clips) else nil
	limbName = limbName or (if right then style.Right else style.Left)

	local limb = findLimb(character, limbName)
	local part: BasePart? = if limb then addTrail(limb) else nil
	local finished = false

	local played: RBXScriptConnection? = nil
	if animator and clips then
		local watched: { [string]: string } = clips
		played = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
			local name = limbOfTrack(track, watched)
			local other = if name and name ~= limbName then findLimb(character, name) else nil
			if finished or not other then
				return
			end
			limbName = name
			if part then
				part:Destroy()
			end
			part = addTrail(other)
		end)
		task.delay(SETTLE_TIME, function()
			if played then
				played:Disconnect()
				played = nil
			end
		end)
	end

	task.delay(style.Life, function()
		finished = true
		if played then
			played:Disconnect()
			played = nil
		end
		if part then
			part:Destroy()
		end
	end)
end

return function(_origin: Vector3, params: { [string]: any }?)
	local character = params and params.Caster
	local weapon = params and params.Weapon
	if typeof(character) ~= "Instance" or not character:IsA("Model") or type(weapon) ~= "string" then
		return
	end

	if weapon == TWIN_BLADES then
		local blades = character:FindFirstChild(TWIN_BLADES)
		if blades then
			WeaponFx.LightTrails(blades, TWIN_BLADES_LIFE)
		end
		return
	end

	local style = STYLES[weapon]
	if not style then
		return
	end

	if style.Limbs then
		for _, name in style.Limbs do
			local limb = findLimb(character, name)
			if limb then
				local part = addTrail(limb)
				task.delay(style.Life, function()
					part:Destroy()
				end)
			end
		end
		return
	end

	alternatingTrail(character, style, (params :: any).Right == true)
end
