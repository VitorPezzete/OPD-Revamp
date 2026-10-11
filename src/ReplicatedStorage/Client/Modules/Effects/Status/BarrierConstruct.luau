--!strict
--[[
	Barrier fruit - the visible Wall, Room or Prison of a character. The server only
	holds invisible collision for it; this is everything players see.

	Status value: "<kind>|px|py|pz|lx|ly|lz|sx|sy|sz|<fruit colors>"
	(position, facing direction and full size of the construct in the world).

	Wall    a plain plastic part, as the legacy server made it (it never used the
	        Power1 template), grows from nothing in 0.5 s.
	Room    Assets.Models.Fruits.Barrier.Power4.BarrierRoom, grows in 1 s.
	Prison  the cage union. The legacy place kept it in ReplicatedStorage.Resources, so
	        it lives in Fruits._Shared (see findPrison), placed at full size.
	All three are 0.24 transparent, as the legacy server set them. The Wall takes the
	fruit's primary color, or (170, 170, 220) without one; Room and Prison are only
	repainted when the user has a saved color and keep their template's look otherwise.
	A missing template falls back to a translucent box of the same size.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local DEFAULT_COLOR = Color3.fromRGB(170, 170, 220)
local TRANSPARENCY = 0.24
-- A solid box stands in for a hollow template: keep it see-through from the inside.
local FALLBACK_TRANSPARENCY = 0.7
local START_SIZE = Vector3.new(1, 1, 1)

local function noop() end

-- Same construction as the server (Abilities/Barrier/_Construct.Frame).
local function frame(position: Vector3, look: Vector3): CFrame
	if look.Magnitude < 1e-3 then
		return CFrame.new(position)
	end
	local unit = look.Unit
	if math.abs(unit.Y) > 0.999 then
		return CFrame.lookAt(position, position + unit, Vector3.xAxis)
	end
	return CFrame.lookAt(position, position + unit)
end

-- _Shared holds two parts called BarrierPrison: the cage is the union that takes a color
-- (same choice as the server's _Construct.FindPrison).
local function findPrison(): Instance?
	local own = EffectAssets.FindFruit("Barrier", "Power3", "BarrierPrison")
	if own then
		return own
	end

	local shared = EffectAssets.FindFruit("_Shared")
	local fallback: Instance? = nil
	if shared then
		for _, child in shared:GetChildren() do
			if child.Name == "BarrierPrison" and child:IsA("BasePart") then
				if child:IsA("PartOperation") and child.UsePartColor then
					return child
				end
				fallback = fallback or child
			end
		end
	end
	return fallback
end

local function findTemplate(kind: string): BasePart?
	local found: Instance? = nil
	if kind == "Room" then
		found = EffectAssets.FindFruit("Barrier", "Power4", "BarrierRoom")
	elseif kind == "Prison" then
		found = findPrison()
	end
	return if found and found:IsA("BasePart") then found else nil
end

return function(_character: Model, value: any): () -> ()
	local fields = EffectAssets.Unpack(value)
	local kind = fields[1]
	local numbers: { number } = {}
	for index = 2, 10 do
		local number = tonumber(fields[index])
		if not number then
			return noop
		end
		table.insert(numbers, number)
	end

	local cframe = frame(
		Vector3.new(numbers[1], numbers[2], numbers[3]),
		Vector3.new(numbers[4], numbers[5], numbers[6])
	)
	local size = Vector3.new(numbers[7], numbers[8], numbers[9])
	local saved = FruitColor.Parse(fields[11] or "")

	local template = findTemplate(kind)
	local part: BasePart
	if template then
		part = template:Clone()
		for _, child in part:GetChildren() do
			if child:IsA("LuaSourceContainer") then
				child:Destroy()
			end
		end
		part.Transparency = TRANSPARENCY
		if saved then
			part.Color = saved
		end
	else
		local box = Instance.new("Part")
		box.Material = Enum.Material.Plastic
		box.TopSurface = Enum.SurfaceType.Smooth
		box.BottomSurface = Enum.SurfaceType.Smooth
		box.Transparency = if kind == "Wall" then TRANSPARENCY else FALLBACK_TRANSPARENCY
		box.Color = saved or DEFAULT_COLOR
		part = box
	end

	part.Name = "Barrier" .. kind
	part.Anchored = true
	-- Collision is the server's invisible copy.
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = cframe

	local growSeconds = if kind == "Wall" then 0.5 elseif kind == "Room" then 1 else 0
	if growSeconds > 0 then
		part.Size = START_SIZE
		part.Parent = World.Effects()
		local info = if kind == "Wall"
			then TweenInfo.new(growSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			else TweenInfo.new(growSeconds)
		TweenService:Create(part, info, { Size = size }):Play()
	else
		part.Size = size
		part.Parent = World.Effects()
	end

	return function()
		part:Destroy()
	end
end
