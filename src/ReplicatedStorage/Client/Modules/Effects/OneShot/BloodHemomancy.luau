--!strict
--[[
	Blood fruit - Blood Hemomancy: a stream of blood drawn from the target to the caster.

	origin: the caster's position (unused; the attachments follow the two characters).
	params: { Target: Model, Caster: Model, Concentrate: boolean, Colors: string }
	Templates: ReplicatedStorage.Assets.Models.Fruits.Blood.Power1.Start.StartAttachment
	(goes on the target, holds the beams) and .Power1.End.EndAttachment (goes on the
	caster; its emitters only run with Concentrate). The beams thin out after 2 s and
	everything is gone at 2.5 s.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HOLD_TIME = 2
local FADE_TIME = 0.5

local function rootOf(model: any): BasePart?
	if typeof(model) ~= "Instance" then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

return function(_origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local targetRoot = rootOf(params.Target)
	local casterRoot = rootOf(params.Caster)
	local startTemplate = EffectAssets.FindFruit("Blood", "Power1", "Start", "StartAttachment")
	local endTemplate = EffectAssets.FindFruit("Blood", "Power1", "End", "EndAttachment")
	if not targetRoot or not casterRoot or not startTemplate or not endTemplate then
		return
	end
	if not startTemplate:IsA("Attachment") or not endTemplate:IsA("Attachment") then
		return
	end

	local startAttachment = startTemplate:Clone()
	local endAttachment = endTemplate:Clone()

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local sequence = if primary and secondary then FruitColor.ToSequence(primary, secondary) else nil

	local beams: { Beam } = {}
	for _, attachment in { startAttachment, endAttachment } do
		for _, descendant in attachment:GetDescendants() do
			if descendant:IsA("Beam") then
				descendant.Attachment0 = startAttachment
				descendant.Attachment1 = endAttachment
				if sequence then
					descendant.Color = sequence
				end
				table.insert(beams, descendant)
			elseif descendant:IsA("ParticleEmitter") then
				if sequence then
					descendant.Color = sequence
				end
				if params.Concentrate and attachment == endAttachment then
					descendant.Enabled = true
				end
			end
		end
	end

	startAttachment.Parent = targetRoot
	endAttachment.Parent = casterRoot
	Debris:AddItem(startAttachment, HOLD_TIME + FADE_TIME)
	Debris:AddItem(endAttachment, HOLD_TIME + FADE_TIME)

	task.delay(HOLD_TIME, function()
		for _, beam in beams do
			if beam.Parent then
				TweenService:Create(beam, TweenInfo.new(FADE_TIME), { Width0 = 0, Width1 = 0 }):Play()
			end
		end
	end)
end
