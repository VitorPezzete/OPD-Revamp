--!strict
--[[
	Gas fruit - Airless World: the sphere around the caster while the aura is on.
	Status value: "<radius in studs>|<fruit color string>".

	Template: ReplicatedStorage.Assets.Models.Fruits.Gas.Power3.GasAirless, a
	ParticleEmitter with two sphere parts inside it ("Room" and "Room2", each with a
	"Mesh"). As in the legacy script the emitter goes on the root with a particle size of
	twice the radius, and both rooms are welded to the root with their mesh scaled to the
	radius. Custom colors paint everything with the first color.

	Purely cosmetic: who is inside is decided by the server.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local ROOM_NAMES = { "Room", "Room2" }

local function noop() end

return function(character: Model, value: any, _isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local radius = tonumber(fields[1])
	local root = character:FindFirstChild("HumanoidRootPart")
	local template = EffectAssets.FindFruit("Gas", "Power3", "GasAirless")
	if not radius or radius <= 0 or not root or not root:IsA("BasePart") then
		return noop
	end
	if not template or not template:IsA("ParticleEmitter") then
		return noop
	end

	local primary = FruitColor.Parse(fields[2] or "")

	local emitter = template:Clone()
	emitter.Size = NumberSequence.new(radius * 2)
	if primary then
		emitter.Color = ColorSequence.new(primary)
	end

	for _, roomName in ROOM_NAMES do
		local room = emitter:FindFirstChild(roomName)
		if room and room:IsA("BasePart") then
			room.Anchored = false
			room.CanCollide = false
			room.CanQuery = false
			room.CanTouch = false
			room.Massless = true
			if primary then
				room.Color = primary
			end

			local mesh: any = room:FindFirstChild("Mesh")
			if mesh and mesh:IsA("DataModelMesh") then
				mesh.Scale = Vector3.new(radius, radius, radius)
			end

			local weld = Instance.new("Weld")
			weld.Part0 = root
			weld.Part1 = room
			weld.Parent = room
		end
	end

	emitter.Parent = root

	return function()
		emitter:Destroy()
	end
end
