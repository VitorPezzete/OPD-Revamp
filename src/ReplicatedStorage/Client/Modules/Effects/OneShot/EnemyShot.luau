--!strict
--[[
	The shot of a gun enemy (Gunslinger, Marine, Gunner Captain...: EnemyConfig.Ranged),
	as the legacy AIGun script drew it: a thin white line from the muzzle to the point the
	enemy fired at, there at once and fading away over one second.

	Legacy part: a Cylinder of 0.1 studs across and as long as the shot, BrickColor
	"White", the default Plastic, anchored, its Transparency tweened from 0 to 1 with a
	default TweenInfo.new(1) (Quad, Out) and removed after that second.
	params: { Target: Vector3 }   (origin is the muzzle)

	Many gunners fire at once, each every 0.7 s, so a shot costs as little as possible:
	the lines are reused from a small pool instead of being created and destroyed, and one
	Heartbeat connection fades all of them (no Tween instance per shot); it is connected
	only while a line is on screen.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local World = require(ReplicatedStorage.Shared.Util.World)

local THICKNESS = 0.1
local FADE_TIME = 1
local COLOR = BrickColor.new("White").Color
local MIN_LENGTH = 0.05
-- Longest side a part may have.
local MAX_LENGTH = 2048
-- Lines kept for reuse once they have faded; any beyond that are destroyed.
local POOL_SIZE = 48
-- A cylinder lies along its X axis: turned so that X follows the line of fire.
local ALONG_X = CFrame.Angles(0, math.rad(90), 0)

type Line = { Part: BasePart, Started: number }

local pool: { BasePart } = {}
local live: { Line } = {}
local fading: RBXScriptConnection? = nil

local function newPart(): BasePart
	local part = Instance.new("Part")
	part.Name = "EnemyShot"
	part.Shape = Enum.PartType.Cylinder
	part.Color = COLOR
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	return part
end

local function release(part: BasePart)
	if #pool < POOL_SIZE then
		part.Parent = nil
		table.insert(pool, part)
	else
		part:Destroy()
	end
end

local function step()
	local now = os.clock()
	for index = #live, 1, -1 do
		local line = live[index]
		local alpha = (now - line.Started) / FADE_TIME
		if alpha >= 1 then
			-- Order does not matter: the last line takes the place of the finished one.
			live[index] = live[#live]
			live[#live] = nil
			release(line.Part)
		else
			-- Quad, Out: the easing of the legacy tween.
			line.Part.Transparency = 1 - (1 - alpha) * (1 - alpha)
		end
	end
	if #live == 0 and fading then
		fading:Disconnect()
		fading = nil
	end
end

return function(origin: Vector3, params: { [string]: any }?)
	local target = params and params.Target
	if typeof(target) ~= "Vector3" then
		return
	end
	local length = math.min((target - origin).Magnitude, MAX_LENGTH)
	if length < MIN_LENGTH then
		return
	end

	local part = table.remove(pool) or newPart()
	part.Size = Vector3.new(length, THICKNESS, THICKNESS)
	part.CFrame = CFrame.lookAt(origin, target) * CFrame.new(0, 0, -length / 2) * ALONG_X
	part.Transparency = 0
	part.Parent = World.Effects()

	table.insert(live, { Part = part, Started = os.clock() })
	if not fading then
		fading = RunService.Heartbeat:Connect(step)
	end
end
