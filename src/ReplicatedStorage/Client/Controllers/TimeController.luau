--!strict
--[[
	Moves this client's sun. The server only publishes the clock origin (see TimeConfig);
	the hour is derived from the synchronised server time, so every client agrees without
	any per-frame replication.

	For the settings screen:
		TimeController:SetSunLocked(true)    -- Settings.Sun_Mode: sun parked, no moving shadows
		TimeController:SetFogEnabled(true)   -- Settings.Fog_Mode: short local fog
	Both are local only: IsNight / PhaseChanged keep following the real clock, which is
	what gameplay uses.
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local TimeConfig = require(ReplicatedStorage.Shared.Configs.TimeConfig)

local TimeController = Knit.CreateController({
	Name = "TimeController",
})

-- (isNight)
TimeController.PhaseChanged = Signal.new() :: Signal.Signal<boolean>

local sunLocked = false
local isNight = false
local elapsed = 0

local function readNumber(attribute: string, default: number): number
	local value = Workspace:GetAttribute(attribute)
	return if type(value) == "number" then value else default
end

function TimeController:GetClockTime(): number
	local attributes = TimeConfig.Attributes
	return TimeConfig.GetClockTime(
		readNumber(attributes.OriginTime, Workspace:GetServerTimeNow()),
		readNumber(attributes.OriginClock, TimeConfig.StartClockTime),
		readNumber(attributes.Rate, 0),
		Workspace:GetServerTimeNow()
	)
end

function TimeController:IsNight(): boolean
	return isNight
end

local function update()
	local clock = TimeController:GetClockTime()
	Lighting.ClockTime = if sunLocked then TimeConfig.SunModeClockTime else clock

	local night = TimeConfig.IsNight(clock)
	if night ~= isNight then
		isNight = night
		TimeController.PhaseChanged:Fire(night)
	end
end

function TimeController:SetSunLocked(locked: boolean)
	sunLocked = locked
	update()
end

function TimeController:SetFogEnabled(enabled: boolean)
	local fog = if enabled then TimeConfig.Fog.Enabled else TimeConfig.Fog.Default
	Lighting.FogStart = fog.Start
	Lighting.FogEnd = fog.End
end

function TimeController:KnitStart()
	isNight = TimeConfig.IsNight(TimeController:GetClockTime())
	update()

	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= TimeConfig.ClientStep then
			elapsed = 0
			update()
		end
	end)
end

return TimeController
