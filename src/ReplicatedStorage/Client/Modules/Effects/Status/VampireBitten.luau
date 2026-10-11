--!strict
--[[
	Vampire fruit - the curse of Sanguine Vampiris, on the bitten player.
	Status value: "<biter user id>|<1 while burning in sunlight, else 0>|<marker range>".
	The effect restarts whenever the sunlight flag flips.

	The victim's own screen: the world turns harsh and over-bright (brightness 3, white
	ambient, full sun rays, shadows on); in direct sunlight it goes to brightness 10 with
	a white flash. The legacy script reset the lighting to hard-coded values afterwards;
	here the values found when the curse began are restored.

	Everyone: the body smoulders while it burns in the sun. The legacy emitter
	("SunBurned") lived in the root part of the character template. It is taken from
	Assets.Particles.SunBurned when that exists, else from the copy of the old template
	kept by the Hollow fruit (Fruits.Hollow.Power1.GhostBody.HumanoidRootPart); a plain
	Fire stands in only if both are missing.

	The vampire that bit: a marker over the victim, visible up to the marker range
	(sword level * sword affinity studs). The legacy BillboardGui asset was a child of
	the fruit script; a simple one is built here.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local FADE_TIME = 1
local CURSED_BRIGHTNESS = 3
local SUNLIT_BRIGHTNESS = 10
local MARKER_COLOR = Color3.fromRGB(170, 0, 30)

type Baseline = {
	Brightness: number,
	OutdoorAmbient: Color3,
	GlobalShadows: boolean,
	SunIntensity: number?,
	SunSpread: number?,
}

-- Lighting as it was before the curse touched it, kept across restarts of the effect.
local baseline: Baseline? = nil
local generation = 0

local function findSunRays(): SunRaysEffect?
	return Lighting:FindFirstChildOfClass("SunRaysEffect")
end

local function applyLighting(inSun: boolean)
	generation += 1
	local sunRays = findSunRays()
	if not baseline then
		baseline = {
			Brightness = Lighting.Brightness,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			GlobalShadows = Lighting.GlobalShadows,
			SunIntensity = sunRays and sunRays.Intensity,
			SunSpread = sunRays and sunRays.Spread,
		}
	end

	local info = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear)
	TweenService:Create(Lighting, info, {
		Brightness = if inSun then SUNLIT_BRIGHTNESS else CURSED_BRIGHTNESS,
		OutdoorAmbient = Color3.new(1, 1, 1),
	}):Play()
	if sunRays then
		TweenService:Create(sunRays, info, { Intensity = 1, Spread = 1 }):Play()
	end
	Lighting.GlobalShadows = true
end

local function restoreLighting()
	local saved = baseline
	if not saved then
		return
	end
	generation += 1
	local current = generation

	local info = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear)
	TweenService:Create(Lighting, info, {
		Brightness = saved.Brightness,
		OutdoorAmbient = saved.OutdoorAmbient,
	}):Play()
	local sunRays = findSunRays()
	if sunRays and saved.SunIntensity and saved.SunSpread then
		TweenService:Create(sunRays, info, { Intensity = saved.SunIntensity, Spread = saved.SunSpread }):Play()
	end
	Lighting.GlobalShadows = saved.GlobalShadows

	-- Forget the baseline only if the curse did not start again while fading out.
	task.delay(FADE_TIME + 0.1, function()
		if generation == current then
			baseline = nil
		end
	end)
end

local function flash()
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "VampireSunFlash"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	gui.Parent = playerGui

	local fadeIn = TweenService:Create(frame, TweenInfo.new(FADE_TIME / 2, Enum.EasingStyle.Linear), {
		BackgroundTransparency = 0,
	})
	fadeIn:Play()
	task.delay(FADE_TIME / 2, function()
		TweenService:Create(frame, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear), {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(FADE_TIME, function()
			gui:Destroy()
		end)
	end)
end

local function addBurn(root: BasePart): Instance
	local template = EffectAssets.Find("Particles", "SunBurned")
		or EffectAssets.FindFruit("Hollow", "Power1", "GhostBody", "HumanoidRootPart", "SunBurned")
	if template and template:IsA("ParticleEmitter") then
		local emitter = template:Clone()
		emitter.Enabled = true
		emitter.Parent = root
		return emitter
	end

	local fire = Instance.new("Fire")
	fire.Name = "VampireSunBurn"
	fire.Heat = 6
	fire.Size = 5
	fire.Parent = root
	return fire
end

local function addMarker(root: BasePart, range: number): Instance
	local marker = Instance.new("BillboardGui")
	marker.Name = "VampireMarker"
	marker.Size = UDim2.fromOffset(18, 18)
	marker.StudsOffset = Vector3.new(0, 4, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = math.max(range, 1)
	marker.Adornee = root

	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromScale(1, 1)
	dot.BackgroundColor3 = MARKER_COLOR
	dot.BorderSizePixel = 0
	dot.Rotation = 45
	dot.Parent = marker

	marker.Parent = root
	return marker
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local biterId = tonumber(fields[1]) or 0
	local inSun = fields[2] == "1"
	local range = tonumber(fields[3]) or 0

	local created: { Instance } = {}
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		if inSun then
			table.insert(created, addBurn(root))
		end
		local localPlayer = Players.LocalPlayer
		if not isLocal and localPlayer and localPlayer.UserId == biterId then
			table.insert(created, addMarker(root, range))
		end
	end

	if isLocal then
		applyLighting(inSun)
		if inSun then
			flash()
		end
	end

	return function()
		for _, instance in created do
			instance:Destroy()
		end
		if isLocal then
			restoreLighting()
		end
	end
end
