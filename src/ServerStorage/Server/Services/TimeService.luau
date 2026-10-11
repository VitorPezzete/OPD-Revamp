--!strict
--[[
	The day / night clock.

	One origin (server time, hour, rate) defines the clock; the current hour is computed
	on demand, never stepped. Clients read the same origin from Workspace attributes and
	move their own Lighting (TimeController). The only timer here is one task.delay to
	the next dawn / dusk, which is when PhaseChanged fires.

	Lighting.ClockTime is still written on the server at every phase change (and when
	the clock is set), so server code that reads it gets the right side of day / night.
	Prefer the API:

		TimeService:IsNight() / :IsDay() / :GetClockTime()
		TimeService.PhaseChanged:Connect(function(isNight) end)
		TimeService:ObservePhase(function(isNight) end)   -- current phase, then changes
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local TimeConfig = require(ReplicatedStorage.Shared.Configs.TimeConfig)

-- Slack added to the boundary timer so the clock is strictly past dawn / dusk when it fires.
local BOUNDARY_MARGIN = 0.05

local TimeService = Knit.CreateService({
	Name = "TimeService",
	Client = {},
})

-- (isNight)
TimeService.PhaseChanged = Signal.new() :: Signal.Signal<boolean>

local originTime = 0
local originClock = TimeConfig.StartClockTime
local rate = TimeConfig.HoursPerSecond
local isNight = TimeConfig.IsNight(TimeConfig.StartClockTime)
-- Bumped whenever the origin changes, so a pending boundary timer knows it is stale.
local generation = 0

local function publish()
	local attributes = TimeConfig.Attributes
	Workspace:SetAttribute(attributes.OriginTime, originTime)
	Workspace:SetAttribute(attributes.OriginClock, originClock)
	Workspace:SetAttribute(attributes.Rate, rate)
end

local function applyPhase()
	local clock = TimeService:GetClockTime()
	Lighting.ClockTime = clock

	local night = TimeConfig.IsNight(clock)
	if night ~= isNight then
		isNight = night
		Workspace:SetAttribute(TimeConfig.Attributes.Night, night)
		TimeService.PhaseChanged:Fire(night)
	end
end

local function scheduleBoundary()
	generation += 1
	if rate <= 0 then
		return
	end

	local token = generation
	local clock = TimeService:GetClockTime()
	local target = if TimeConfig.IsNight(clock) then TimeConfig.NightEnd else TimeConfig.NightStart
	local hours = (target - clock) % 24
	if hours <= 0 then
		hours = 24
	end

	task.delay(hours / rate + BOUNDARY_MARGIN, function()
		if token == generation then
			applyPhase()
			scheduleBoundary()
		end
	end)
end

local function setOrigin(clock: number, newRate: number)
	originTime = Workspace:GetServerTimeNow()
	originClock = clock % 24
	rate = math.max(0, newRate)
	publish()
	applyPhase()
	scheduleBoundary()
end

function TimeService:GetClockTime(): number
	return TimeConfig.GetClockTime(originTime, originClock, rate, Workspace:GetServerTimeNow())
end

function TimeService:IsNight(): boolean
	return isNight
end

function TimeService:IsDay(): boolean
	return not isNight
end

-- Calls callback with the current phase and again on every change.
function TimeService:ObservePhase(callback: (isNight: boolean) -> ())
	task.spawn(callback, isNight)
	return TimeService.PhaseChanged:Connect(callback)
end

-- Jumps the clock (admin commands, events). Fires PhaseChanged if the phase flips.
function TimeService:SetClockTime(clockTime: number)
	if clockTime ~= clockTime or math.abs(clockTime) == math.huge then
		return
	end
	setOrigin(clockTime, rate)
end

-- Game hours per real second; 0 freezes the clock.
function TimeService:SetRate(hoursPerSecond: number)
	if hoursPerSecond ~= hoursPerSecond or math.abs(hoursPerSecond) == math.huge then
		return
	end
	setOrigin(TimeService:GetClockTime(), hoursPerSecond)
end

function TimeService:KnitInit()
	-- Published in Init so every service can ask for the phase from its KnitStart.
	originTime = Workspace:GetServerTimeNow()
	isNight = TimeConfig.IsNight(originClock)
	Lighting.ClockTime = originClock
	Workspace:SetAttribute(TimeConfig.Attributes.Night, isNight)
	publish()
end

function TimeService:KnitStart()
	scheduleBoundary()
end

return TimeService
