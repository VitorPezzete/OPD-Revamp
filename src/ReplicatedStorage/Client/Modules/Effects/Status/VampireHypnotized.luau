--!strict
--[[
	Vampire fruit - Hypnosis, on the hypnotised player (4 seconds, timed by the server).
	Status value: "<vampire user id>|<fruit color string>".

	Everyone: the two hypnosis spirals on the victim's head.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Vampire.Power2
	.VampireHypnosisAttachment and .VampireHypnosisAttachment2 (attachments holding a
	"VampireHypnosis" emitter). Custom colors paint them with the second color.

	Victim only: every frame its humanoid is asked to move towards the vampire while it
	is more than 2 studs away - the request the legacy server made with MoveTo. The
	victim is stunned for those 4 seconds (walk speed 0, controls off), so, as in legacy,
	it does not walk: it turns on the spot to face the vampire.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local TEMPLATES = { "VampireHypnosisAttachment", "VampireHypnosisAttachment2" }
local BINDING = "VampireHypnotized"
local STOP_DISTANCE = 2

local function addSpirals(character: Model, colors: string): { Instance }
	local created: { Instance } = {}
	local head = character:FindFirstChild("Head")
	if not head then
		return created
	end

	local _, secondary = FruitColor.Parse(colors)
	for _, templateName in TEMPLATES do
		local template = EffectAssets.FindFruit("Vampire", "Power2", templateName)
		if template then
			local spiral = template:Clone()
			if secondary then
				for _, descendant in spiral:GetDescendants() do
					if descendant:IsA("ParticleEmitter") then
						descendant.Color = ColorSequence.new(secondary)
					end
				end
			end
			spiral.Parent = head
			table.insert(created, spiral)
		end
	end
	return created
end

local function startWalk(character: Model, vampireId: number): (() -> ())?
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not foundHumanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return nil
	end
	local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot

	RunService:BindToRenderStep(BINDING, Enum.RenderPriority.Input.Value + 1, function()
		local vampire = Players:GetPlayerByUserId(vampireId)
		local vampireCharacter = vampire and vampire.Character
		local vampireRoot = vampireCharacter and vampireCharacter:FindFirstChild("HumanoidRootPart")
		if not vampireRoot or not vampireRoot:IsA("BasePart") then
			return
		end

		local offset = vampireRoot.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if offset.Magnitude > STOP_DISTANCE and flat.Magnitude > 1e-3 then
			humanoid:Move(flat.Unit, false)
		else
			humanoid:Move(Vector3.zero, false)
		end
	end)

	return function()
		RunService:UnbindFromRenderStep(BINDING)
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local vampireId = tonumber(fields[1]) or 0
	local spirals = addSpirals(character, fields[2] or "")
	local stopWalk = if isLocal then startWalk(character, vampireId) else nil

	return function()
		if stopWalk then
			stopWalk()
		end
		for _, spiral in spirals do
			spiral:Destroy()
		end
	end
end
