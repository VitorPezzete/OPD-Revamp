--!strict
--[[
	Hobby fruit - one of the Hobby user's lines on the local player's screen, over the
	legacy overlay (PlayerGui.DevilFruitIcons.Hobby: Eyes, ImageLabel, TextLabel and a
	backdrop Frame): everything fades in over half a second (the backdrop over one), stays
	three seconds and fades out, unless a newer line replaced it meanwhile.

	params: { Text: string }

	Called directly by the effects that own a line (Status.HobbyControlled: an order;
	Status.HobbyToy: the reset button refused), which is why it is its own module. The
	server never plays it.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MESSAGE_SECONDS = 3
local FADE_SECONDS = 0.5
local BACKDROP_FADE_IN_SECONDS = 1
local BACKDROP_TRANSPARENCY = 0.5

-- Shared by every call, so a newer line is not hidden by an older timer.
local shown = 0

local function fade(instance: Instance?, property: string, goal: number, seconds: number)
	if instance then
		TweenService:Create(instance, TweenInfo.new(seconds), { [property] = goal }):Play()
	end
end

return function(_origin: Vector3, params: { [string]: any }?)
	local text = params and params.Text
	if type(text) ~= "string" then
		return
	end

	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local icons = playerGui and playerGui:FindFirstChild("DevilFruitIcons")
	local overlay = icons and icons:FindFirstChild("Hobby")
	if not overlay or not overlay:IsA("GuiObject") then
		return
	end

	local eyes = overlay:FindFirstChild("Eyes")
	local image = overlay:FindFirstChild("ImageLabel")
	local label = overlay:FindFirstChild("TextLabel")
	local backdrop = overlay:FindFirstChild("Frame")

	shown += 1
	local current = shown

	if label and label:IsA("TextLabel") then
		label.Text = text
	end
	fade(eyes, "ImageTransparency", 0, FADE_SECONDS)
	fade(image, "ImageTransparency", 0, FADE_SECONDS)
	fade(label, "TextTransparency", 0, FADE_SECONDS)
	fade(backdrop, "BackgroundTransparency", BACKDROP_TRANSPARENCY, BACKDROP_FADE_IN_SECONDS)
	overlay.Visible = true

	task.delay(MESSAGE_SECONDS, function()
		if shown ~= current then
			return
		end
		fade(eyes, "ImageTransparency", 1, FADE_SECONDS)
		fade(image, "ImageTransparency", 1, FADE_SECONDS)
		fade(label, "TextTransparency", 1, FADE_SECONDS)
		fade(backdrop, "BackgroundTransparency", 1, FADE_SECONDS)
		task.wait(FADE_SECONDS)
		if shown == current then
			overlay.Visible = false
		end
	end)
end
