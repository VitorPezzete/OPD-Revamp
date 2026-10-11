--!strict
--[[
	Fast Mode, the legacy low graphics setting (Settings.Fast_Mode, Optimization tab):

	Off      the game as it was authored.
	On       every part of the map turned to smooth plastic (the one material with no
	         texture at all) with no reflectance and smooth faces (the old studs and inlets
	         are textures too), decals and textures hidden. Done once, over what is in the world at that moment.
	Extreme  the same, and everything that appears afterwards (streamed in, spawned,
	         cloned by effects) gets the same treatment as it arrives.

	Legacy: the button only counted up (Off -> On -> Extreme) for the session, decals and
	textures were destroyed and nothing could be undone without rejoining. Here the level
	is a saved setting, the button goes round, and what was changed is remembered and put
	back when the level goes down to Off. Character faces (Head.FakeHead.Face) are kept:
	the legacy sweep deleted them too, which left every character faceless.

		GraphicsController:GetLevel() -> "Off" | "On" | "Extreme"
		GraphicsController.Changed    (level)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

export type Level = "Off" | "On" | "Extreme"

local SETTING = "Fast_Mode"
local LEVELS: { [string]: boolean } = { Off = true, On = true, Extreme = true }
local DEFAULT_LEVEL: Level = "Off"

-- Instances handled per frame by a pass over the map, so a switch is not one long freeze.
local BATCH = 1500

local GraphicsController = Knit.CreateController({
	Name = "GraphicsController",
})

GraphicsController.Changed = Signal.new() :: Signal.Signal<Level>

local SettingsController

local level: Level = DEFAULT_LEVEL
-- Bumped on every change, so a pass still running stops.
local run = 0

-- What was changed, to put it back. Not weak tables: the Lua handle of an Instance can be
-- collected while the Instance lives on, which would lose the entry.
type SavedPart = {
	Material: Enum.Material,
	Variant: string,
	Reflectance: number,
	-- Only the faces that were not smooth.
	Surfaces: { [string]: Enum.SurfaceType }?,
}
local savedParts: { [BasePart]: SavedPart } = {}
local SURFACES = { "TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface" }
local savedDecals: { [Decal]: number } = {}
local addedConnection: RBXScriptConnection? = nil

local function simplify(instance: Instance)
	if instance:IsA("BasePart") then
		local part = instance :: any
		if not savedParts[instance] then
			local surfaces: { [string]: Enum.SurfaceType }? = nil
			for _, name in SURFACES do
				local surface = part[name]
				if surface ~= Enum.SurfaceType.Smooth then
					surfaces = surfaces or {}
					(surfaces :: any)[name] = surface
				end
			end
			savedParts[instance] = {
				Material = instance.Material,
				Variant = instance.MaterialVariant,
				Reflectance = instance.Reflectance,
				Surfaces = surfaces,
			}
		end
		local saved = savedParts[instance]
		instance.Material = Enum.Material.SmoothPlastic
		instance.MaterialVariant = ""
		instance.Reflectance = 0
		if saved.Surfaces then
			for name in saved.Surfaces do
				part[name] = Enum.SurfaceType.Smooth
			end
		end
	elseif instance:IsA("Decal") then
		-- Texture inherits from Decal.
		local parent = instance.Parent
		if parent and parent.Name == "FakeHead" then
			return
		end
		if savedDecals[instance] == nil then
			savedDecals[instance] = instance.Transparency
		end
		instance.Transparency = 1
	end
end

-- One pass over the map, a batch per frame. Stops when the level changes again.
local function sweep(current: number)
	for index, descendant in Workspace:GetDescendants() do
		if run ~= current then
			return
		end
		simplify(descendant)
		if index % BATCH == 0 then
			RunService.Heartbeat:Wait()
		end
	end
end

local function restore(current: number)
	local count = 0
	for part, saved in savedParts do
		if run ~= current then
			return
		end
		savedParts[part] = nil
		if part.Parent ~= nil then
			part.Material = saved.Material
			part.MaterialVariant = saved.Variant
			part.Reflectance = saved.Reflectance
			if saved.Surfaces then
				for name, surface in saved.Surfaces do
					(part :: any)[name] = surface
				end
			end
		end
		count += 1
		if count % BATCH == 0 then
			RunService.Heartbeat:Wait()
		end
	end
	for decal, transparency in savedDecals do
		if run ~= current then
			return
		end
		savedDecals[decal] = nil
		if decal.Parent ~= nil then
			decal.Transparency = transparency
		end
		count += 1
		if count % BATCH == 0 then
			RunService.Heartbeat:Wait()
		end
	end
end

local function apply(nextLevel: Level)
	local previous = level
	level = nextLevel
	run += 1
	local current = run

	if addedConnection then
		addedConnection:Disconnect()
		addedConnection = nil
	end
	if level == "Extreme" then
		addedConnection = Workspace.DescendantAdded:Connect(simplify)
	end

	task.spawn(function()
		if level == "Off" then
			restore(current)
		elseif previous == "Off" or level == "Extreme" then
			-- On -> Extreme sweeps again: what arrived while it was only On is still untouched.
			sweep(current)
		end
	end)

	GraphicsController.Changed:Fire(level)
end

function GraphicsController:GetLevel(): Level
	return level
end

function GraphicsController:KnitInit()
	SettingsController = Knit.GetController("SettingsController")
end

function GraphicsController:KnitStart()
	SettingsController:Observe(SETTING, function(saved: any)
		local wanted: Level = if type(saved) == "string" and LEVELS[saved] then saved :: Level else DEFAULT_LEVEL
		if wanted ~= level then
			apply(wanted)
		end
	end)
end

return GraphicsController
