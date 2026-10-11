--!strict
--[[
	Overhead billboards of every character: players (Workspace.Alive.Players) and the NPCs of
	Workspace.Alive.NPCs / Workspace.Alive.Bosses.

	HealthBillboard  thin health bar, hidden at full health (legacy DisplayHealth). Driven by
	                 the Health / MaxHealth attributes CharacterEntity replicates.
	LevelBillboard   "Lv 1234" (legacy ReplicatedStorage.Level), for characters that carry a
	                 Level attribute: players (NameplateService). Enemy models already have
	                 their level in their name ("Lv9 Bandit"), shown by the engine's name tag.

	Those two are the "Legacy" interface. With the "Divine" one (UIController:GetStyle())
	the same data is drawn by UI.Components.Nameplate and UI.Components.NameplateTitle,
	which also carries the name (the engine's name tag is turned off).

	The legacy game cloned the health billboard on the server into every character, with a
	Script inside each one waiting in loops for the health values. Billboards are now built
	on each client and cost the server nothing.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local World = require(ReplicatedStorage.Shared.Util.World)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Nameplate = require(ReplicatedStorage.Client.UI.Components.Nameplate)
local NameplateTitle = require(ReplicatedStorage.Client.UI.Components.NameplateTitle)
local NameplateMarker = require(ReplicatedStorage.Client.UI.Components.NameplateMarker)

type Scope = Fusion.Scope<typeof(Fusion)>

local PART_TIMEOUT = 10
local HEAD_OFFSET = Vector3.new(0, 1, 0)

-- The rework's plate (health, name, level) is drawn in both interfaces; the legacy
-- billboards below it are kept for reference and no longer mounted.
local REWORK_PLATES = true

local NameplateController = Knit.CreateController({
	Name = "NameplateController",
})

local UIController

local plates: { [Model]: Scope } = {}
-- Every NPC and boss model in the world, to give them their plates again (rebuild).
local npcs: { [Instance]: boolean } = {}
-- Models whose parts are still being waited for.
local pending: { [Model]: boolean } = {}

local function detach(model: Model)
	pending[model] = nil
	local plateScope = plates[model]
	if plateScope then
		plates[model] = nil
		Fusion.doCleanup(plateScope)
	end
end

local function build(model: Model, adornee: BasePart, withLevel: boolean)
	local plateScope = Fusion.scoped(Fusion)
	plates[model] = plateScope

	-- Models without a head (crabs, boars) carry the plate above their bounding box.
	local offset = if adornee.Name == "Head"
		then HEAD_OFFSET
		else Vector3.new(0, model:GetExtentsSize().Y / 2 + HEAD_OFFSET.Y, 0)

	local health = Bind.attribute(plateScope, model, "Health", 0)
	local maxHealth = Bind.attribute(plateScope, model, "MaxHealth", 0)

	if REWORK_PLATES then
		local healthGui = Nameplate(plateScope, { Health = health, MaxHealth = maxHealth, StudsOffset = offset })
		healthGui.Adornee = adornee
		healthGui.Parent = adornee

		-- The engine's name tag and health bar are replaced by a title of our own.
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local player = Players:GetPlayerFromCharacter(model)
		local name = if player
			then player.DisplayName
			elseif humanoid and humanoid.DisplayName ~= "" then humanoid.DisplayName
			else model.Name
		-- Enemy models are named after their level ("Lv43 Angry Bobb"); the title shows it apart.
		if not player then
			name = (string.gsub(name, "^Lv%s*%d+%s*", ""))
		end
		if humanoid then
			-- Given back with the plate: the legacy interface shows the engine's name tag.
			local distanceType, healthType = humanoid.DisplayDistanceType, humanoid.HealthDisplayType
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			table.insert(plateScope, function()
				if humanoid.Parent then
					humanoid.DisplayDistanceType = distanceType
					humanoid.HealthDisplayType = healthType
				end
			end)
		end

		-- Some enemy models carry a marker over the head as a billboard of their own (the
		-- red sign of raid enemies), which shows where they are from any distance. Sized in
		-- studs it lay under the title, so it is drawn again in pixels, above the title.
		local icon: string? = nil
		for _, child in adornee:GetChildren() do
			if child:IsA("BillboardGui") and child ~= healthGui then
				local image = child:FindFirstChildWhichIsA("ImageLabel")
				if image and image.Image ~= "" then
					icon = image.Image
					child.Enabled = false
					break
				end
			end
		end

		local titleGui = NameplateTitle(plateScope, {
			Name = name,
			Level = if withLevel then Bind.attribute(plateScope, model, "Level", nil) else nil,
			StudsOffset = offset,
		})
		titleGui.Adornee = adornee
		titleGui.Parent = adornee

		if icon then
			local markerGui = NameplateMarker(plateScope, { Image = icon, StudsOffset = offset })
			markerGui.Adornee = adornee
			markerGui.Parent = adornee
		end
	else
		local healthGui = UIController:BuildLayout(plateScope, "HealthBillboard") :: BillboardGui?
		if healthGui then
			local bar: Frame = Bind.find(healthGui, "Frame/Frame")
			Bind.props(plateScope, bar, {
				Visible = plateScope:Computed(function(use)
					local maximum = use(maxHealth)
					return maximum > 0 and use(health) < maximum
				end),
			})
			Bind.props(plateScope, Bind.find(bar, "Frame"), {
				Size = plateScope:Computed(function(use)
					local maximum = use(maxHealth)
					return UDim2.fromScale(if maximum > 0 then math.clamp(use(health) / maximum, 0, 1) else 0, 1)
				end),
			})
			healthGui.StudsOffset = offset
			healthGui.Adornee = adornee
			healthGui.Parent = adornee
		end

		if withLevel then
			local level = Bind.attribute(plateScope, model, "Level", nil)
			local levelGui = UIController:BuildLayout(plateScope, "LevelBillboard") :: BillboardGui?
			if levelGui then
				Bind.props(plateScope, levelGui, {
					Enabled = plateScope:Computed(function(use)
						return type(use(level)) == "number"
					end),
				})
				Bind.props(plateScope, Bind.find(levelGui, "TextLabel"), {
					Text = plateScope:Computed(function(use)
						local value = use(level)
						return if type(value) == "number" then `Lv {value}` else ""
					end),
				})
				levelGui.StudsOffset = offset
				levelGui.Adornee = adornee
				levelGui.Parent = adornee
			end
		end
	end

	table.insert(plateScope, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			detach(model)
		end
	end))
end

local function attach(model: Instance, isPlayer: boolean)
	if not model:IsA("Model") or plates[model] or pending[model] then
		return
	end
	-- Your own health and level are on the HUD: nothing floats over your own head.
	if REWORK_PLATES and Players:GetPlayerFromCharacter(model) == Players.LocalPlayer then
		return
	end

	pending[model] = true
	task.spawn(function()
		-- Parts can arrive after the model (character loading, streaming).
		local root = model:WaitForChild("HumanoidRootPart", PART_TIMEOUT)
		local head = if isPlayer then model:WaitForChild("Head", PART_TIMEOUT) else model:FindFirstChild("Head")
		if not pending[model] then
			return
		end
		pending[model] = nil

		local adornee = if head and head:IsA("BasePart") then head else root
		if not adornee or not adornee:IsA("BasePart") then
			return
		end

		local ok, problem = pcall(build, model, adornee, isPlayer or model:GetAttribute("Level") ~= nil)
		if not ok then
			warn(`[Nameplate] {model.Name}: {problem}`)
			detach(model)
		end
	end)
end

local function trackPlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		attach(character, true)
	end)
	player.CharacterRemoving:Connect(detach)
	if player.Character then
		attach(player.Character, true)
	end
end

function NameplateController:KnitInit()
	UIController = Knit.GetController("UIController")
end

-- The other interface draws other plates: every character gets its plate again.
local function rebuild()
	for model in table.clone(plates) do
		detach(model)
	end
	for model in table.clone(pending) do
		pending[model] = nil
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			attach(player.Character, true)
		end
	end
	for child in npcs do
		attach(child, false)
	end
end

function NameplateController:KnitStart()
	UIController.StyleChanged:Connect(rebuild)
	Players.PlayerAdded:Connect(trackPlayer)
	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end

	task.spawn(function()
		-- Workspace.Alive.NPCs and .Bosses (yields until they have replicated).
		World.ObserveNpcs(function(child: Instance)
			npcs[child] = true
			attach(child, false)
		end, function(child: Instance)
			npcs[child] = nil
			if child:IsA("Model") then
				detach(child)
			end
		end)
	end)
end

return NameplateController
