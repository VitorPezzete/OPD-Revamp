--!strict
--[[
	Observation haki - what its user sees: the other characters are painted over for as
	long as the status is on. From Haki level 100 the paint shows through walls.

	Owner only. Settings.Obs_Mode decides who is painted:
		"" / "Full"     players and enemies
		"Players Only"  players
		"Limited"       players and enemies within 1000 studs
		"Dodge Only"    nobody (observation still dodges: that is the server's part)

	How it is painted. The legacy game put one SurfaceGui on every face of every limb of
	every character (ReplicatedStorage.Resources.ObsGui): six guis a limb, some forty a
	character, thousands on a full island - turning observation on froze the game for a
	moment and cost frames for as long as it stayed on. A mark is now ONE Highlight per
	character, which the engine draws in a single pass whatever the number of limbs. The
	engine only draws a limited number of Highlights at once, so the marks go to the
	MAX_MARKS nearest characters, re-chosen every REFRESH seconds as everybody moves.
	Nothing is created for anyone further away.

	MARK_COLOR / MARK_TRANSPARENCY are a guess to tune: the legacy template is not among
	the kept assets and its dump has no properties.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local World = require(ReplicatedStorage.Shared.Util.World)

local MARK_COLOR = Color3.fromRGB(255, 255, 255)
local MARK_TRANSPARENCY = 0.5
local THROUGH_WALLS_LEVEL = 100
local LIMITED_RANGE = 1000
-- Nobody further than this is painted in the other modes: past it a character is a few
-- pixels, and the marks are better spent nearby.
local FULL_RANGE = 2000
local FADE_OUT = TweenInfo.new(1, Enum.EasingStyle.Linear)
-- The engine draws about 31 Highlights at once; a few are left to the rest of the game.
local MAX_MARKS = 24
-- Seconds between two choices of who is marked.
local REFRESH = 0.5
local FOLDER_NAME = "ObsMarks"

local function noop() end

type Candidate = { Model: Model, Distance: number }

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return noop
	end

	local mode = Knit.GetController("SettingsController"):Get("Obs_Mode")
	if mode == "Dodge Only" then
		return noop
	end
	local range = if mode == "Limited" then LIMITED_RANGE else FULL_RANGE
	local enemiesToo = mode ~= "Players Only"

	local hakiLevel = Knit.GetController("DataController"):Get("Skills.Haki.Level")
	local onTop = type(hakiLevel) == "number" and hakiLevel >= THROUGH_WALLS_LEVEL

	-- Highlights live in the PlayerGui and point at their character: nothing is added to
	-- the characters themselves.
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = playerGui

	local active = true
	local marks: { [Model]: Highlight } = {}

	local function isAlive(model: Model): boolean
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid or not model:IsDescendantOf(Workspace) then
			return false
		end
		local health = model:GetAttribute("Health")
		return (if type(health) == "number" then health else humanoid.Health) > 0
	end

	local function consider(candidates: { Candidate }, model: Instance, from: Vector3)
		if not model:IsA("Model") or model == character then
			return
		end
		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local distance = (root.Position - from).Magnitude
		if distance <= range and isAlive(model) then
			table.insert(candidates, { Model = model, Distance = distance })
		end
	end

	local function refresh()
		local root = character.PrimaryPart
		if not root then
			return
		end
		local from = root.Position

		local candidates: { Candidate } = {}
		for _, player in Players:GetPlayers() do
			if player ~= localPlayer and player.Character then
				consider(candidates, player.Character, from)
			end
		end
		if enemiesToo then
			for _, enemy in World.GetNpcs() do
				consider(candidates, enemy, from)
			end
		end
		table.sort(candidates, function(a: Candidate, b: Candidate): boolean
			return a.Distance < b.Distance
		end)

		local wanted: { [Model]: boolean } = {}
		for index = 1, math.min(#candidates, MAX_MARKS) do
			wanted[candidates[index].Model] = true
		end
		for model, highlight in marks do
			if not wanted[model] then
				marks[model] = nil
				highlight:Destroy()
			end
		end
		for model in wanted do
			if not marks[model] then
				local highlight = Instance.new("Highlight")
				highlight.Name = "ObsMark"
				highlight.Adornee = model
				highlight.FillColor = MARK_COLOR
				highlight.FillTransparency = MARK_TRANSPARENCY
				highlight.OutlineTransparency = 1
				highlight.DepthMode = if onTop
					then Enum.HighlightDepthMode.AlwaysOnTop
					else Enum.HighlightDepthMode.Occluded
				highlight.Parent = folder
				marks[model] = highlight
			end
		end
	end

	task.spawn(function()
		while active do
			refresh()
			task.wait(REFRESH)
		end
	end)

	return function()
		active = false
		table.clear(marks)

		-- The marks fade out for a second after observation ends.
		for _, highlight in folder:GetChildren() do
			if highlight:IsA("Highlight") then
				TweenService:Create(highlight, FADE_OUT, { FillTransparency = 1 }):Play()
			end
		end
		task.delay(FADE_OUT.Time, function()
			folder:Destroy()
		end)
	end
end
