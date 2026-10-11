--!strict
--[[
	Phoenix fruit - passive: flames of regeneration on the body of a phoenix that is
	below full health. They go out one second after it is full again.
	Status value: the fruit color string (set for as long as the fruit is owned).

	Template: ReplicatedStorage.Assets.Models.Fruits.Phoenix.Logia.PhoenixTrigger (a
	ParticleEmitter), copied onto the head, torso and limbs. Colors: dark with armament
	haki, the fruit colors when it has an aura, else blue to yellow.

	The legacy HealthV2 script cloned the emitters on the server from its regen loop.
	Here nothing is sent for it: the replicated "Health" / "MaxHealth" attributes are
	enough. No flames inside the egg (the egg has its own).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local LINGER = 1

local HEALTH_ATTRIBUTE = "Health"
local MAX_HEALTH_ATTRIBUTE = "MaxHealth"
local EGG_ATTRIBUTE = "PhoenixEgg"
local HAKI_ATTRIBUTE = "Haki"

local HAKI_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 0, 26)),
	ColorSequenceKeypoint.new(0.877, Color3.fromRGB(16, 0, 26)),
	ColorSequenceKeypoint.new(0.892, Color3.fromRGB(60, 0, 97)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 97)),
})
local DEFAULT_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 208, 255)),
	ColorSequenceKeypoint.new(0.798, Color3.fromRGB(0, 208, 255)),
	ColorSequenceKeypoint.new(0.926, Color3.fromRGB(230, 250, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 0)),
})

return function(character: Model, value: any, _isLocal: boolean): () -> ()
	local template = EffectAssets.FindFruit("Phoenix", "Logia", "PhoenixTrigger")
	if not template or not template:IsA("ParticleEmitter") then
		return function() end
	end

	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
	local normal = DEFAULT_SEQUENCE
	if primary and secondary then
		normal = ColorSequence.new({
			ColorSequenceKeypoint.new(0, primary),
			ColorSequenceKeypoint.new(0.798, primary),
			ColorSequenceKeypoint.new(0.926, secondary),
			ColorSequenceKeypoint.new(1, secondary),
		})
	end

	local emitters: { ParticleEmitter } = {}
	-- Bumped whenever the state changes, so a pending "go out" knows it is stale.
	local token = 0
	local fading = false

	local function recolor()
		local sequence = if character:GetAttribute(HAKI_ATTRIBUTE) then HAKI_SEQUENCE else normal
		for _, emitter in emitters do
			emitter.Color = sequence
		end
	end

	local function show()
		if #emitters > 0 then
			return
		end
		for _, limbName in LIMBS do
			local limb = character:FindFirstChild(limbName)
			if limb and limb:IsA("BasePart") then
				local emitter = template:Clone()
				emitter.Name = "PhoenixRegen"
				emitter.Enabled = true
				emitter.Parent = limb
				table.insert(emitters, emitter)
			end
		end
		recolor()
	end

	local function hide()
		for _, emitter in emitters do
			emitter:Destroy()
		end
		table.clear(emitters)
	end

	local function update()
		local health = character:GetAttribute(HEALTH_ATTRIBUTE)
		local maxHealth = character:GetAttribute(MAX_HEALTH_ATTRIBUTE)
		local regenerating = type(health) == "number"
			and type(maxHealth) == "number"
			and health > 0
			and health < maxHealth
			and not character:GetAttribute(EGG_ATTRIBUTE)

		if regenerating then
			token += 1
			fading = false
			show()
		elseif #emitters > 0 and not fading then
			token += 1
			fading = true
			local mine = token
			task.delay(LINGER, function()
				if token == mine then
					fading = false
					hide()
				end
			end)
		end
	end

	local connections = {
		character:GetAttributeChangedSignal(HEALTH_ATTRIBUTE):Connect(update),
		character:GetAttributeChangedSignal(MAX_HEALTH_ATTRIBUTE):Connect(update),
		character:GetAttributeChangedSignal(EGG_ATTRIBUTE):Connect(update),
		character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(recolor),
	}
	update()

	return function()
		token += 1
		for _, connection in connections do
			connection:Disconnect()
		end
		hide()
	end
end
