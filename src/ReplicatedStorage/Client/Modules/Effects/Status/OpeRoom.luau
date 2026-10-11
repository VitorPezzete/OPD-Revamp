--!strict
--[[
	Ope fruit - Room: the translucent sphere. Purely cosmetic: the server knows the
	Room as a center and a radius computed from the same numbers.

	Status value (on the caster):
	"<x>|<y>|<z>|<final radius>|<radius per second>|<server time opened>|<colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Ope.Power1["Ope Room"]
	(a sphere MeshPart with an inner shell "OpeRoom2" and a swirling "OpeSmoke").

	The sphere stays where it was opened and grows from the server's opening time, so a
	client that joins or comes into range later sees it at the right size. The smoke
	grows with it (its mesh scale ends at 0.16 x the final radius, which is the legacy
	40 * level / 500 * affinity) and spins ever faster around the center while its part
	slides out to the legacy weld offset, (15, 0, 10) * k at 2.5 * k studs per second on
	each axis (k = level / 500 * affinity); once the Room is fully open it spins twice as
	fast and fades.
	The cast animation and the mini room in the hand are Effects.OneShot.OpeRoomCast.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local MIN_SIZE = 0.1
local SMOKE_SCALE_PER_RADIUS = 0.16
-- Per stud of final radius (level / 500 * affinity is the final radius / 250).
local SMOKE_OFFSET_PER_RADIUS = Vector3.new(15 / 250, 0, 10 / 250)
local SMOKE_SLIDE_PER_RADIUS = 2.5 / 250
local SMOKE_SPIN = math.rad(-140)
local SMOKE_SPIN_GAIN = math.rad(-45)
local SMOKE_FADE_SPIN = 2
local SMOKE_FADE_TIME = 1.1
local CLOSE_TIME = 0.3
local ROTATION = CFrame.Angles(0, math.rad(90), 0)

local function noop() end

local function fade(part: BasePart)
	TweenService:Create(part, TweenInfo.new(CLOSE_TIME, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
end

return function(_character: Model, value: any): () -> ()
	local fields = EffectAssets.Unpack(value)
	local x, y, z = tonumber(fields[1]), tonumber(fields[2]), tonumber(fields[3])
	local finalRadius = tonumber(fields[4])
	local growRate = tonumber(fields[5])
	local openedAt = tonumber(fields[6])
	if not x or not y or not z or not finalRadius or not growRate or not openedAt then
		return noop
	end

	local template = EffectAssets.FindFruit("Ope", "Power1", "Ope Room")
	if not template or not template:IsA("BasePart") then
		return noop
	end

	local center = Vector3.new(x, y, z)
	local cframe = CFrame.new(center) * ROTATION

	local room = template:Clone()
	local shell = room:FindFirstChild("OpeRoom2")
	local smoke = room:FindFirstChild("OpeSmoke")
	local smokeMesh = (if smoke then smoke:FindFirstChildWhichIsA("DataModelMesh") else nil) :: DataModelMesh?

	-- The authored welds would fight the anchored, resized parts.
	for _, descendant in room:GetDescendants() do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") or descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CFrame = cframe
		end
	end
	room.Anchored = true
	room.CanCollide = false
	room.CanQuery = false
	room.CanTouch = false
	room.CFrame = cframe

	local primary, secondary = FruitColor.Parse(fields[7] or "")
	if primary and secondary then
		room.Color = primary
		if shell and shell:IsA("BasePart") then
			shell.Color = primary
		end
		if smoke and smoke:IsA("BasePart") then
			smoke.Color = secondary
		end
	end

	local smokeBaseTransparency = if smoke and smoke:IsA("BasePart") then smoke.Transparency else 0
	local smokeOffset = SMOKE_OFFSET_PER_RADIUS * finalRadius
	local smokeSlide = SMOKE_SLIDE_PER_RADIUS * finalRadius
	local angle = 0

	local function update(deltaTime: number)
		local elapsed = math.max(0, Workspace:GetServerTimeNow() - openedAt)
		local radius = math.min(finalRadius, elapsed * growRate)
		local diameter = math.max(MIN_SIZE, radius * 2)
		local size = Vector3.new(diameter, diameter, diameter)

		room.Size = size
		if shell and shell:IsA("BasePart") then
			shell.Size = size
		end

		if smoke and smoke:IsA("BasePart") then
			local sinceFull = if growRate > 0 then elapsed - finalRadius / growRate else elapsed
			if sinceFull >= SMOKE_FADE_TIME then
				smoke.Transparency = 1
			else
				local spin = (SMOKE_SPIN + SMOKE_SPIN_GAIN * elapsed) * deltaTime
				angle += if sinceFull > 0 then spin * SMOKE_FADE_SPIN else spin
				-- The legacy weld: smoke * (offset * spin) = room, so the part orbits the center.
				local slid = elapsed * smokeSlide
				local offset = Vector3.new(math.min(slid, smokeOffset.X), 0, math.min(slid, smokeOffset.Z))
				smoke.CFrame = cframe * (CFrame.new(offset) * CFrame.Angles(0, angle, 0)):Inverse()
				if smokeMesh then
					local scale = math.max(MIN_SIZE, radius * SMOKE_SCALE_PER_RADIUS)
					smokeMesh.Scale = Vector3.new(scale, scale, scale)
				end
				if sinceFull > 0 then
					smoke.Transparency = smokeBaseTransparency
						+ (1 - smokeBaseTransparency) * (sinceFull / SMOKE_FADE_TIME)
				end
			end
		end
	end

	update(0)
	room.Parent = World.Effects()
	local connection = RunService.Heartbeat:Connect(update)

	return function()
		connection:Disconnect()

		-- The legacy close: three quick steps of transparency, then gone.
		for _, part in room:GetDescendants() do
			if part:IsA("BasePart") then
				fade(part)
			end
		end
		fade(room)
		Debris:AddItem(room, CLOSE_TIME)
	end
end
