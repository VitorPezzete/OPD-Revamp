--!strict
--[[
	Builds every ability visual on this client.

	Status effects  - Client.Modules.Effects.Status.<StatusName>
		return function(character: Model, value: any, isLocal: boolean): () -> ()
		Started when the attribute <StatusName> appears on a character, restarted when
		its value changes, and its returned cleanup runs when the attribute is removed
		or the character leaves. Works for characters that were already affected when
		this client joined.

	One-shot effects - Client.Modules.Effects.OneShot.<EffectName>
		return function(origin: Vector3, params: { [string]: any }?)
		Triggered by EffectService:Play on the server.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local World = require(ReplicatedStorage.Shared.Util.World)
local Trove = require(ReplicatedStorage.Shared.Packages.Trove)

type StatusEffect = (character: Model, value: any, isLocal: boolean) -> () -> ()
type OneShotEffect = (origin: Vector3, params: { [string]: any }?) -> ()

local EffectController = Knit.CreateController({
	Name = "EffectController",
})

local effectsFolder = ReplicatedStorage.Client.Modules.Effects
local statusEffects: { [string]: StatusEffect } = {}
local oneShotEffects: { [string]: OneShotEffect } = {}

local function loadModules(folderName: string, into: { [string]: any })
	local folder = effectsFolder:FindFirstChild(folderName)
	if not folder then
		return
	end
	for _, module in folder:GetChildren() do
		if module:IsA("ModuleScript") then
			into[module.Name] = (require :: any)(module)
		end
	end
end

--[[
	An effect that errors must not take the others with it: a cleanup that threw used to
	abort the cleanups still to run for that character, and whatever they had changed on
	the body (a tint, a hidden limb) stayed for good.
]]
local function runCleanup(statusName: string, cleanup: () -> ())
	local ok, problem = pcall(cleanup)
	if not ok then
		warn(`[Effect] cleanup of "{statusName}" failed: {tostring(problem)}`)
	end
end

local function trackCharacter(character: Model, isLocal: boolean)
	local trove = Trove.new()
	local running: { [string]: () -> () } = {}

	local function refresh(statusName: string)
		local cleanup = running[statusName]
		if cleanup then
			running[statusName] = nil
			runCleanup(statusName, cleanup)
		end

		local value = character:GetAttribute(statusName)
		if value ~= nil and value ~= false then
			local ok, result = pcall(statusEffects[statusName], character, value, isLocal)
			if not ok then
				warn(`[Effect] "{statusName}" failed: {tostring(result)}`)
			elseif type(result) == "function" then
				running[statusName] = result
			end
		end
	end

	for statusName in statusEffects do
		trove:Connect(character:GetAttributeChangedSignal(statusName), function()
			refresh(statusName)
		end)
		refresh(statusName)
	end

	trove:Add(function()
		for statusName, cleanup in running do
			running[statusName] = nil
			runCleanup(statusName, cleanup)
		end
	end)
	trove:Connect(character.Destroying, function()
		trove:Destroy()
	end)
	trove:Connect(character.AncestryChanged, function(_, parent)
		if parent == nil then
			trove:Destroy()
		end
	end)
end

local function trackPlayer(player: Player)
	local isLocal = player == Players.LocalPlayer
	player.CharacterAdded:Connect(function(character: Model)
		trackCharacter(character, isLocal)
	end)
	if player.Character then
		trackCharacter(player.Character, isLocal)
	end
end

function EffectController:KnitInit()
	loadModules("Status", statusEffects)
	loadModules("OneShot", oneShotEffects)
end

function EffectController:KnitStart()
	Players.PlayerAdded:Connect(trackPlayer)
	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end

	-- NPC enemies show status effects too (burning, frozen, stunned...).
	task.spawn(function()
		-- Workspace.Alive.NPCs and .Bosses.
		World.ObserveNpcs(function(model: Instance)
			if model:IsA("Model") then
				trackCharacter(model, false)
			end
		end)
	end)

	local DamageNumbers = require(ReplicatedStorage.Client.Modules.DamageNumbers)
	Knit.GetService("CombatService").DamageDealt:Connect(function(amount: number, position: Vector3, trait: string)
		DamageNumbers.Show(amount, position, trait)
	end)

	Knit.GetService("EffectService").Play:Connect(function(effectName: string, origin: Vector3, params: { [string]: any }?)
		local effect = oneShotEffects[effectName]
		if effect then
			task.spawn(effect, origin, params)
		end
	end)
end

return EffectController
