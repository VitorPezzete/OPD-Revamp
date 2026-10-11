--!strict
--[[
	Calendar flags (weekend, Halloween, April Fools, Alice fruit window, Christmas) and
	the content that comes with them.

	One loop looks at the UTC date once a minute. A flag that turns on starts the module
	of the same name in Modules.Seasonal, if there is one; turning off runs its cleanup.
	Flags without a module (Weekend, AprilFools, AliceFruit) are only state that other
	systems read:

		SeasonService:IsActive("Weekend")
		SeasonService.Changed:Connect(function(flag, active) end)
		SeasonService:Observe("AliceFruit", function(active) end)

	Clients read the Workspace attribute "Season_<Flag>".

	The legacy game spread this over five scripts polling string ValueObjects of
	Workspace.GlobalReference.Time every second.

	Seasonal module contract
		return {
			Start = function(context) -> cleanup?,   -- flag turned on
			Dormant = function() end,                -- optional: flag is off at boot
		}
		context.OnMinute(fn)   -- fn runs on every calendar check while the flag is on
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local SeasonConfig = require(ServerStorage.Server.Configs.SeasonConfig)

export type SeasonContext = {
	OnMinute: (fn: () -> ()) -> (),
}

export type SeasonModule = {
	Start: (context: SeasonContext) -> (() -> ())?,
	Dormant: (() -> ())?,
}

type Running = { Cleanup: (() -> ())?, Minutes: { () -> () } }

local SeasonService = Knit.CreateService({
	Name = "SeasonService",
	Client = {},
})

-- (flag, active)
SeasonService.Changed = Signal.new() :: Signal.Signal<string, boolean>

local active: { [string]: boolean } = {}
local overrides: { [string]: boolean } = table.clone(SeasonConfig.Overrides)
local modules: { [string]: SeasonModule } = {}
local running: { [string]: Running } = {}

local function mirror(flag: string, isActive: boolean)
	-- The only mirror: the legacy Workspace.WorldEvent.<Flag> BoolValues left the place.
	Workspace:SetAttribute(SeasonConfig.AttributePrefix .. flag, isActive)
end

local function startModule(flag: string)
	local module = modules[flag]
	if not module or running[flag] then
		return
	end

	local entry: Running = { Cleanup = nil, Minutes = {} }
	running[flag] = entry
	local ok, result = pcall(module.Start, {
		OnMinute = function(fn: () -> ())
			table.insert(entry.Minutes, fn)
		end,
	})
	if ok then
		entry.Cleanup = result
	else
		warn(`[SeasonService] {flag} failed to start: {result}`)
		running[flag] = nil
	end
end

local function stopModule(flag: string)
	local entry = running[flag]
	if not entry then
		return
	end
	running[flag] = nil
	if entry.Cleanup then
		local ok, problem = pcall(entry.Cleanup)
		if not ok then
			warn(`[SeasonService] {flag} failed to stop: {problem}`)
		end
	end
end

local function evaluate()
	local date = os.date("!*t") :: any
	for flag, rule in SeasonConfig.Flags do
		local override = overrides[flag]
		local isActive = if override ~= nil then override else rule(date)
		if active[flag] == isActive then
			continue
		end

		active[flag] = isActive
		mirror(flag, isActive)
		if isActive then
			startModule(flag)
		else
			stopModule(flag)
		end
		SeasonService.Changed:Fire(flag, isActive)
	end
end

function SeasonService:IsActive(flag: string): boolean
	return active[flag] == true
end

-- Calls callback with the flag's current state and again whenever it changes.
function SeasonService:Observe(flag: string, callback: (active: boolean) -> ())
	task.spawn(callback, SeasonService:IsActive(flag))
	return SeasonService.Changed:Connect(function(changed: string, isActive: boolean)
		if changed == flag then
			callback(isActive)
		end
	end)
end

-- Forces a flag on / off (admin commands, tests); nil returns it to the calendar.
function SeasonService:SetOverride(flag: string, isActive: boolean?)
	if SeasonConfig.Flags[flag] then
		overrides[flag] = isActive :: any
		evaluate()
	end
end

function SeasonService:KnitInit()
	local folder = ServerStorage.Server.Modules:FindFirstChild("Seasonal")
	if folder then
		for _, module in folder:GetChildren() do
			if module:IsA("ModuleScript") and SeasonConfig.Flags[module.Name] then
				modules[module.Name] = (require :: any)(module)
			end
		end
	end

	-- Flags are readable from every KnitStart; modules start later, with the services up.
	local date = os.date("!*t") :: any
	for flag, rule in SeasonConfig.Flags do
		local override = overrides[flag]
		active[flag] = if override ~= nil then override else rule(date)
		mirror(flag, active[flag])
	end
end

function SeasonService:KnitStart()
	for flag, module in modules do
		if active[flag] then
			startModule(flag)
		elseif module.Dormant then
			task.spawn(module.Dormant)
		end
	end

	task.spawn(function()
		while true do
			task.wait(SeasonConfig.CheckInterval)
			evaluate()
			for _, entry in running do
				for _, fn in entry.Minutes do
					task.spawn(fn)
				end
			end
		end
	end)
end

return SeasonService
