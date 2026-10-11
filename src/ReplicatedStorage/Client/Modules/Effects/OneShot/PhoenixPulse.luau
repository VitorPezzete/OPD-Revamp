--!strict
--[[
	Phoenix fruit - Phoenix Pulse: the burst of flames around the caster.
	params: { Radius: number (not drawn: the legacy burst had a fixed size),
	          Colors: string, Caster: Model }

	Template: ReplicatedStorage.Assets.Models.Fruits.Phoenix.Power4.PhoenixPulsePart (a
	part with the "PhoenixFire" / "PhoenixFire2" emitters), welded to the caster's root.
	The emitters run for 1 s and the part is removed 0.5 s later, as in the legacy game.
	With an aura "PhoenixFire" goes from the first fruit color to the second and
	"PhoenixFire2" takes the second.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local EMIT_TIME = 1
local FADE_TIME = 0.5

return function(_origin: Vector3, params: { [string]: any }?)
	local character = params and params.Caster
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local template = EffectAssets.FindFruit("Phoenix", "Power4", "PhoenixPulsePart")
	if not root or not root:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return
	end

	local pulse = template:Clone()
	pulse.Anchored = false
	pulse.CanCollide = false
	pulse.CanQuery = false
	pulse.CanTouch = false
	pulse.Massless = true

	local primary, secondary = FruitColor.Parse(if params and type(params.Colors) == "string" then params.Colors else "")
	local emitters: { ParticleEmitter } = {}
	for _, descendant in pulse:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") then
			if primary and secondary then
				if descendant.Name == "PhoenixFire2" then
					descendant.Color = ColorSequence.new(secondary)
				else
					descendant.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, primary),
						ColorSequenceKeypoint.new(0.798, primary),
						ColorSequenceKeypoint.new(0.926, secondary),
						ColorSequenceKeypoint.new(1, secondary),
					})
				end
			end
			descendant.Enabled = true
			table.insert(emitters, descendant)
		end
	end

	pulse.CFrame = root.CFrame
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = pulse
	weld.Parent = pulse
	pulse.Parent = root
	Debris:AddItem(pulse, EMIT_TIME + FADE_TIME)

	task.delay(EMIT_TIME, function()
		for _, emitter in emitters do
			emitter.Enabled = false
		end
	end)
end
