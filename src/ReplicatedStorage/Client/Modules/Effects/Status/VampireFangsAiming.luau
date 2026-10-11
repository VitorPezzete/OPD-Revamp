--!strict
--[[
	Vampire fruit - Sanguine Vampiris while the key is held: a faint preview of the two
	fangs, closed where the bite would land and following the aim. The bite itself comes
	on release (VampireFangs one-shot).
	Status value: "<fang scale>|<seconds of cooldown left>|<fruit color string>".

	Owner only: the legacy preview was made of local parts, nobody else saw it.
	Template: ReplicatedStorage.Assets.Models.Fruits._Shared.VampireTeeth (the legacy
	ReplicatedStorage.Resources copy), or the Power1 one. Custom colors paint the fangs
	with the second color. Transparency 0.65, and 0.95 for as long as the bite is on
	cooldown (releasing then does nothing).

	Same placement as the legacy render step: 8 studs ahead along the flat aim direction,
	the two fangs a fifth of their height above and below the root, tilted 20 degrees.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local BITE_DISTANCE = 8
local LOOK_DISTANCE = 50
local TILT = math.rad(20)
local READY_TRANSPARENCY = 0.65
local COOLDOWN_TRANSPARENCY = 0.95

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local fields = EffectAssets.Unpack(value)
	local scale = math.clamp(tonumber(fields[1]) or 1, 0.1, 10)
	local readyAt = os.clock() + (tonumber(fields[2]) or 0)
	local _, secondary = FruitColor.Parse(fields[3] or "")

	local template = EffectAssets.FindFruit("_Shared", "VampireTeeth")
		or EffectAssets.FindFruit("Vampire", "Power1", "VampireTeeth")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not template or not template:IsA("BasePart") or not foundRoot or not foundRoot:IsA("BasePart") then
		return noop
	end
	local root: BasePart = foundRoot

	-- { part, vertical side, extra rotation }: the lower fang is the upper one turned over.
	local fangs: { { Part: BasePart, Side: number, Rotation: CFrame } } = {}
	for _, fang in
		{
			{ Side = 1, Rotation = CFrame.Angles(TILT, 0, 0) },
			{ Side = -1, Rotation = CFrame.Angles(-TILT, 0, math.rad(180)) },
		}
	do
		local part = template:Clone()
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = template.Size * scale
		part.Transparency = COOLDOWN_TRANSPARENCY
		if secondary then
			part.Color = secondary
		end
		table.insert(fangs, { Part = part, Side = fang.Side, Rotation = fang.Rotation })
	end
	local height = template.Size.Y * scale * 0.2

	local inputController = Knit.GetController("InputController")
	local function place()
		local position = root.Position
		local aim: Vector3 = inputController:GetAimPosition()
		local flat = Vector3.new(aim.X - position.X, 0, aim.Z - position.Z)
		if flat.Magnitude < 1e-3 then
			local look = root.CFrame.LookVector
			flat = Vector3.new(look.X, 0, look.Z)
		end
		if flat.Magnitude < 1e-3 then
			return
		end

		local unit = flat.Unit
		local lookAt = position + unit * LOOK_DISTANCE
		local transparency = if os.clock() >= readyAt then READY_TRANSPARENCY else COOLDOWN_TRANSPARENCY
		for _, fang in fangs do
			local closed = position + unit * BITE_DISTANCE + Vector3.new(0, height * fang.Side, 0)
			fang.Part.CFrame = CFrame.lookAt(closed, lookAt) * fang.Rotation
			fang.Part.Transparency = transparency
		end
	end

	place()
	for _, fang in fangs do
		fang.Part.Parent = World.Effects()
	end
	local connection = RunService.RenderStepped:Connect(place)

	return function()
		connection:Disconnect()
		for _, fang in fangs do
			fang.Part:Destroy()
		end
	end
end
