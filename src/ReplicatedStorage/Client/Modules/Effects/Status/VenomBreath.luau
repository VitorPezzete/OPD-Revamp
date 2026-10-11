--!strict
--[[
	Venom fruit - Poison Breath while the key is held: the stream of poison at the mouth.

	Status value: "<fruit slot>;<ability slot>;<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Venom.Power1.VenomBreathPart (a part
	whose Attachment holds the "Effect" emitter), held at the mouth by a weld named "Aim"
	whose C0 points it where the breath goes, up and down included (the legacy owner
	turned the part towards its mouse every frame). Emitter colors: the two fruit colors,
	swapped while Venom Demon is on (a dull red by default then).
	When the breath stops the emitter is switched off and the part removed 2 s later, so
	the last particles fade naturally, as in the legacy game.

	Owner: the stream follows the aim every frame, and the aim point is sent five times a
	second as phase 3 inputs; the server breathes the (invisible) clouds and stops by
	itself if these stop coming. Facing the aim is Effects.Status.VenomAiming.
	Everyone else: the stream is turned by the VenomBreathCloud one-shots.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
-- Must fit the server input budget with room for other key presses.
local SEND_INTERVAL = 0.2
local DEMON_ATTRIBUTE = "VenomDemon"
local DEMON_COLOR = Color3.fromRGB(163, 75, 75)
local FADE_TIME = 2
local PART_NAME = "VenomBreathPart"
local FADING_NAME = "VenomBreathFading"
local WELD_NAME = "Aim"
local MOUTH_ATTACHMENT = "FaceFrontAttachment"
local DEFAULT_MOUTH = Vector3.new(0, 0, -0.6)

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = string.split(if type(value) == "string" then value else "", ";")
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local primary, secondary = FruitColor.Parse(fields[3] or "")

	local breath: BasePart? = nil
	local aimWeld: Weld? = nil
	local emitters: { ParticleEmitter } = {}
	local authored: { [ParticleEmitter]: ColorSequence } = {}
	local mouth = DEFAULT_MOUTH

	local foundHead = character:FindFirstChild("Head")
	local template = EffectAssets.FindFruit("Venom", "Power1", PART_NAME)
	if foundHead and foundHead:IsA("BasePart") and template and template:IsA("BasePart") then
		local attachment = foundHead:FindFirstChild(MOUTH_ATTACHMENT)
		if attachment and attachment:IsA("Attachment") then
			mouth = attachment.Position
		end

		local part = template:Clone()
		part.Name = PART_NAME
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = foundHead.CFrame * CFrame.new(mouth)

		for _, descendant in part:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("BodyMover") then
				descendant:Destroy()
			elseif descendant:IsA("ParticleEmitter") then
				authored[descendant] = descendant.Color
				table.insert(emitters, descendant)
				descendant.Enabled = true
			end
		end

		local weld = Instance.new("Weld")
		weld.Name = WELD_NAME
		weld.Part0 = foundHead
		weld.Part1 = part
		weld.C0 = CFrame.new(mouth)
		weld.Parent = part

		part.Parent = character
		breath = part
		aimWeld = weld
	end

	local function paint()
		local demon = character:GetAttribute(DEMON_ATTRIBUTE)
		for _, emitter in emitters do
			if primary and secondary then
				emitter.Color = if demon
					then FruitColor.ToSequence(secondary, primary)
					else FruitColor.ToSequence(primary, secondary)
			else
				emitter.Color = if demon then ColorSequence.new(DEMON_COLOR) else authored[emitter]
			end
		end
	end
	paint()
	local demonConnection = character:GetAttributeChangedSignal(DEMON_ATTRIBUTE):Connect(paint)

	local active = true
	local renderConnection: RBXScriptConnection? = nil
	if isLocal then
		local inputController = Knit.GetController("InputController")

		if aimWeld and foundHead and foundHead:IsA("BasePart") then
			local weld: Weld, head: BasePart = aimWeld, foundHead
			renderConnection = RunService.RenderStepped:Connect(function()
				local origin = head.CFrame:PointToWorldSpace(mouth)
				local offset = inputController:GetAimPosition() - origin
				if offset.Magnitude > 0.05 then
					weld.C0 = CFrame.new(mouth) * (head.CFrame.Rotation:Inverse() * CFrame.lookAt(Vector3.zero, offset))
				end
			end)
		end

		if fruitSlot and abilitySlot then
			local abilityService = Knit.GetService("AbilityService")
			task.spawn(function()
				while active do
					abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, inputController:GetAimPosition())
					task.wait(SEND_INTERVAL)
				end
			end)
		end
	end

	return function()
		active = false
		demonConnection:Disconnect()
		if renderConnection then
			renderConnection:Disconnect()
		end
		if breath then
			-- A new breath may start before this one has faded: free the name.
			breath.Name = FADING_NAME
			for _, emitter in emitters do
				emitter.Enabled = false
			end
			Debris:AddItem(breath, FADE_TIME)
		end
	end
end
