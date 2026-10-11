--!strict
--[[
	Paw fruit - Ursus Shock while held: a translucent paw floating above the user that
	grows with the damage it swallows.

	Status value: "<b>|<fruit colors>|<fruit slot>|<ability slot>" where b is
	(defense level / cap) * defense affinity / 2. The damage taken so far is the character
	attribute "PawUrsusTaken" (a number the server keeps up to date).

	Every frame, as in the source, with f = b * clamp(taken, 100 b, 15000 b) / (15000 b):
	the paw is 75 f x 75 f x 50 f studs and sits 7.5 + 37.5 f studs above the root, turned
	like it. Neon, 0.75 transparency, first fruit color (its own without colors). It
	carries the looping "Ursus Loop" sound and plays "Ursus Taken" each time the damage
	taken changes.

	Owner only: faces the aim point, holds the SunPos clip, and releases by itself when the
	charge bar is full (10 s): it sends the key release with its current aim, the server
	throws the paw. The thrown paw, the burst and the SunPos2 clip belong to
	Effects.OneShot.PawUrsusShock.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local PawFx = require(script.Parent.Parent.Util.PawFx)

local TAKEN_ATTRIBUTE = "PawUrsusTaken"
local PHASE_END = 2
-- Mirrors Abilities/Paw/Ursus Shock.
local MAX_HOLD = 10
local MIN_ABSORBED = 100
local MAX_ABSORBED = 15000
local PAW_SCALE = 37.5
local BASE_HEIGHT = 7.5
local TRANSPARENCY = 0.75

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local base = math.max(tonumber(fields[1]) or 0, 0.01)
	local primary = PawFx.Colors(fields[2])
	local fruitSlot, abilitySlot = tonumber(fields[3]), tonumber(fields[4])

	local stops: { () -> () } = {}
	local active = true

	local function factor(): number
		local taken = character:GetAttribute(TAKEN_ATTRIBUTE)
		local absorbed = math.clamp(if type(taken) == "number" then taken else 0, MIN_ABSORBED * base, MAX_ABSORBED * base)
		return base * absorbed / (MAX_ABSORBED * base)
	end

	local created = PawFx.NewPaw(PawFx.Size(PAW_SCALE * factor()), primary, TRANSPARENCY)
	if created then
		local paw: BasePart = created
		local function place()
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local current = factor()
				paw.Size = PawFx.Size(PAW_SCALE * current)
				paw.CFrame = root.CFrame * CFrame.new(0, BASE_HEIGHT + PAW_SCALE * current, 0)
			end
		end
		place()
		paw.Parent = PawFx.Parent()
		PawFx.Sound("UrsusLoop", paw)

		local rendered = RunService.RenderStepped:Connect(place)
		local takenChanged = character:GetAttributeChangedSignal(TAKEN_ATTRIBUTE):Connect(function()
			-- The attribute is removed with the status: that is not a hit.
			if character:GetAttribute(TAKEN_ATTRIBUTE) == nil then
				return
			end
			local sound = PawFx.Sound("UrsusTaken", paw)
			if sound then
				sound.Ended:Once(function()
					sound:Destroy()
				end)
			end
		end)
		table.insert(stops, function()
			rendered:Disconnect()
			takenChanged:Disconnect()
			paw:Destroy()
		end)
	end

	if isLocal then
		table.insert(stops, PawFx.FaceAim(character))
		table.insert(stops, PawFx.PlayCharge(character, PawFx.Anims.SunPos))

		if fruitSlot and abilitySlot then
			task.delay(MAX_HOLD, function()
				if active then
					local aim: Vector3 = Knit.GetController("InputController"):GetAimPosition()
					Knit.GetService("AbilityService").Input:Fire(fruitSlot, abilitySlot, PHASE_END, aim)
				end
			end)
		end
	end

	return function()
		active = false
		for _, stop in stops do
			stop()
		end
	end
end
