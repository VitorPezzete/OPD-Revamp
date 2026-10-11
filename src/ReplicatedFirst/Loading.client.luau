--!strict
--[[
	Loading screen. Lives in ReplicatedFirst, so it is on screen before anything else of
	the game has replicated; it covers the world until the interface is mounted (the spawn
	screen exists), then fades away.

	It is the one piece of interface not built with Fusion and Client.UI.Theme: neither has
	arrived when this runs. The few colours and the font below repeat the theme's by hand.

	Steps shown on the bar: the place has loaded -> the client is starting -> the spawn
	screen is up. If something never arrives, the screen gives way after TIMEOUT
	instead of locking the player out.
]]
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local LOGO = "rbxassetid://70816647124390"
-- Name of the spawn screen's ScreenGui, in both interface styles.
local SPAWN_SCREEN = "Load"
-- Set on the PlayerGui by UIController in a place that has no spawn screen (the raid and
-- AFK places, see PlaceManifest), once its own screens are up.
local READY_ATTRIBUTE = "InterfaceReady"
local TIMEOUT = 60
local FADE_SECONDS = 0.6
-- Left on screen at least this long, so it never just flashes.
local MINIMUM_SECONDS = 1.5

local BACKGROUND = Color3.fromRGB(0, 0, 0)
local TRACK = Color3.fromRGB(50, 33, 20)
local FILL = Color3.fromRGB(244, 230, 194)
local TEXT = Color3.fromRGB(244, 230, 194)
local ARIMO = "rbxasset://fonts/families/Arimo.json"
local FONT = Font.new(ARIMO, Enum.FontWeight.Bold)

local STEPS = {
	{ Progress = 0.15, Text = "Loading" },
	{ Progress = 0.5, Text = "Loading." },
	{ Progress = 0.85, Text = "Loading.." },
	{ Progress = 1, Text = "Loading..." },
}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = BACKGROUND
background.BorderSizePixel = 0
background.Parent = gui

local logo = Instance.new("ImageLabel")
logo.Name = "Logo"
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.Position = UDim2.fromScale(0.5, 0.3)
logo.Size = UDim2.fromScale(0.34, 0.4)
logo.BackgroundTransparency = 1
logo.ScaleType = Enum.ScaleType.Fit
logo.Image = LOGO
logo.Parent = background

local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.Position = UDim2.fromScale(0.5, 0.66)
track.Size = UDim2.new(0.24, 0, 0, 4)
track.BackgroundColor3 = TRACK
track.BorderSizePixel = 0
track.Parent = background

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = FILL
fill.BorderSizePixel = 0
fill.Parent = track

local status = Instance.new("TextLabel")
status.Name = "Status"
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.new(0.5, 0, 0.66, 14)
status.Size = UDim2.new(0.5, 0, 0, 24)
status.BackgroundTransparency = 1
status.FontFace = FONT
status.TextSize = 20
status.TextColor3 = TEXT
status.Text = ""
status.Parent = background

gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()
task.spawn(function()
	pcall(ContentProvider.PreloadAsync, ContentProvider, { logo })
end)

local function show(step: number)
	local entry = STEPS[step]
	status.Text = entry.Text
	TweenService:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(entry.Progress, 1),
	}):Play()
end

local started = os.clock()
local deadline = started + TIMEOUT

show(1)
if not game:IsLoaded() then
	game.Loaded:Wait()
end
show(2)

-- The client loader (StarterPlayerScripts.Main) starts Knit; the interface follows it.
show(3)
while
	not playerGui:FindFirstChild(SPAWN_SCREEN)
	and playerGui:GetAttribute(READY_ATTRIBUTE) ~= true
	and os.clock() < deadline
do
	task.wait(0.1)
end
show(4)

local remaining = MINIMUM_SECONDS - (os.clock() - started)
if remaining > 0 then
	task.wait(remaining)
end
task.wait(0.4)

local fade = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(background, fade, { BackgroundTransparency = 1 }):Play()
TweenService:Create(logo, fade, { ImageTransparency = 1 }):Play()
TweenService:Create(track, fade, { BackgroundTransparency = 1 }):Play()
TweenService:Create(fill, fade, { BackgroundTransparency = 1 }):Play()
TweenService:Create(status, fade, { TextTransparency = 1 }):Play()
task.wait(FADE_SECONDS)
gui:Destroy()
