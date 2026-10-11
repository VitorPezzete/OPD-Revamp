--!strict
--[[
	Paw fruit - Pad Cannon while charging: an orb of particles half a stud above and 2
	studs in front of the root, with the three charge sounds.

	Status value: "<fruit colors>|<fruit slot>|<ability slot>".

	Every emitter of Effects.PadCannon.Particles (Wind, Energy #1, Energy #2, Core) is
	cloned onto one attachment. Their color follows armament haki live, as in the source:
	dark while it is on; otherwise the first fruit color for Core and the second for the
	rest, or plain white when the fruit has no colors.

	Owner only: faces the aim point, plays LoveBeamCharge then LoveBeamCharged, and streams
	its aim to the server (PawFx.StreamAim) so the first paw already leaves along the
	camera. The release clip belongs to Effects.Status.PawCannonSalvo.
]]
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local PawFx = require(script.Parent.Parent.Util.PawFx)

local HAKI_ATTRIBUTE = "Haki"
local OFFSET = CFrame.new(0, 0.5, -2)
local WHITE = Color3.fromRGB(255, 255, 255)
local CORE = "Core"
local SOUNDS = { "ChargeBegan1", "Charge1", "Charge2" }

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local primary, secondary = PawFx.Colors(fields[1])
	local fruitSlot, abilitySlot = tonumber(fields[2]), tonumber(fields[3])

	local stops: { () -> () } = {}
	if isLocal then
		table.insert(stops, PawFx.FaceAim(character))
		table.insert(stops, PawFx.PlayCharge(character, PawFx.Anims.LoveBeamCharge, PawFx.Anims.LoveBeamCharged))
		if fruitSlot and abilitySlot then
			table.insert(stops, PawFx.StreamAim(character, fruitSlot, abilitySlot))
		end
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local folder = EffectAssets.FindFruit("Paw", "Effects", "PadCannon", "Particles")
	if root and root:IsA("BasePart") then
		local attachment = Instance.new("Attachment")
		attachment.CFrame = OFFSET
		attachment.Parent = root

		local emitters: { ParticleEmitter } = {}
		if folder then
			for _, template in folder:GetChildren() do
				if template:IsA("ParticleEmitter") then
					local emitter = template:Clone()
					emitter.Parent = attachment
					table.insert(emitters, emitter)
				end
			end
		end
		for _, name in SOUNDS do
			PawFx.Sound(name, attachment)
		end

		local function tint()
			local haki = character:GetAttribute(HAKI_ATTRIBUTE)
			for _, emitter in emitters do
				local color = WHITE
				if haki then
					color = PawFx.HAKI_COLOR
				elseif primary and secondary then
					color = if emitter.Name == CORE then primary else secondary
				end
				emitter.Color = ColorSequence.new(color)
			end
		end
		tint()
		local hakiChanged = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(tint)

		table.insert(stops, function()
			hakiChanged:Disconnect()
			attachment:Destroy()
		end)
	end

	return function()
		for _, stop in stops do
			stop()
		end
	end
end
