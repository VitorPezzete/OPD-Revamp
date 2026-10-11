--!strict
--[[
	Floating on the sea. The sea of this map is made of parts, not terrain water, so the
	engine does not swim: a character that reaches the surface height is held there by a
	vertical spring, and a jump carries it upward out of the hold. The humanoid is never
	in the Swimming state; it stays in Freefall, so moving sideways is ordinary air
	control at walk speed.

	Rules (legacy Water LocalScript), with its numbers:
	- Checked ten times a second. A living, standing, non-flying character whose root is
	  at or below the surface (211) starts floating; the hold is dropped on the first
	  check that finds the root above the surface.
	- The hold is the legacy mover itself, a BodyPosition towards the surface height with
	  force on the Y axis only (unlimited), P 10000 and D 1250. The mover is kept, not
	  replaced by a constraint, because its force is not scaled by mass and that is what
	  the swimming feels like: the body rests where the spring carries its weight, about
	  a quarter of a stud under the surface for a bare R6 character (mass * gravity / P),
	  and it comes up from any depth without overshooting, closing about nine tenths of
	  the remaining distance every quarter of a second. An AlignPosition rests exactly on
	  the surface and rises on a different curve.
	- Jumping drops the hold and drives the root upward at 50 studs per second for a
	  tenth of a second with the legacy BodyVelocity (Y axis only, unlimited force,
	  P 1250), then lets go: the character leaves the water still moving at about 48
	  studs per second and peaks roughly 10 studs above where it floated. Setting the
	  velocity once, which this file used to do, peaks near 6. Floating cannot start
	  again while that push lasts.
	- The engine integrates both movers, so none of this depends on the frame rate. The
	  only frame dependent part of the legacy script was task.wait(0.1) ending on a frame
	  boundary; the push lasts exactly JumpSeconds here.

	Differences from the legacy scripts:
	- The hold is released when the character sits or starts flying. The old one stayed
	  until the character was above the surface, which a pinned character never was.
	- "Flying" was a counter (`character.Fly`) every flight incremented. Flights are
	  replicated statuses now; any status ending in one of
	  MovementConfig.Water.FlightSuffixes counts.
	- The server copy of the script (WaterServer), which only acted on characters the
	  server simulated, is not reproduced: players always simulate their own character.
	- One loop for the session instead of one script per character life.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)

local WATER = MovementConfig.Water
local SEA_LEVEL = WorldConfig.SeaLevel

local FLOAT_NAME = "SeaFloat"
local ESCAPE_NAME = "SeaEscape"
-- Both movers act on the Y axis only, with nothing limiting them there.
local VERTICAL_FORCE = Vector3.new(0, math.huge, 0)
-- Spring of the hold: force = FLOAT_POWER * (surface - height) - FLOAT_DAMPING * speed.
-- The legacy script set P and left D at the BodyPosition default.
local FLOAT_POWER = 10000
local FLOAT_DAMPING = 1250
-- The jump push never set P: the BodyVelocity default.
local ESCAPE_POWER = 1250

local WaterController = Knit.CreateController({
	Name = "WaterController",
})

local localPlayer = Players.LocalPlayer
-- The mover holding the character at the surface, while it floats.
local float: BodyPosition? = nil
-- The mover carrying the character upward, for JumpSeconds after a jump.
local escape: BodyVelocity? = nil
local elapsed = 0

local function stopFloating()
	if float then
		float:Destroy()
		float = nil
	end
end

local function stopEscaping()
	if escape then
		escape:Destroy()
		escape = nil
	end
end

local function isFlying(character: Model): boolean
	for name, value in character:GetAttributes() do
		if value == nil or value == false then
			continue
		end
		for _, suffix in WATER.FlightSuffixes do
			if #name >= #suffix and string.sub(name, -#suffix) == suffix then
				return true
			end
		end
	end
	return false
end

local function startFloating(root: BasePart)
	local mover = Instance.new("BodyPosition")
	mover.Name = FLOAT_NAME
	mover.MaxForce = VERTICAL_FORCE
	mover.P = FLOAT_POWER
	mover.D = FLOAT_DAMPING
	-- Vertical only: the X and Z of the target never matter.
	mover.Position = Vector3.new(0, SEA_LEVEL, 0)
	mover.Parent = root

	float = mover
end

local function step()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root or not root:IsA("BasePart") then
		stopFloating()
		stopEscaping()
		return
	end

	-- Movers left on a previous character are gone with it.
	if float and not float:IsDescendantOf(character) then
		float = nil
	end
	if escape and not escape:IsDescendantOf(character) then
		escape = nil
	end

	if humanoid.Health <= 0 then
		stopFloating()
		stopEscaping()
		return
	end

	local canFloat = root.Position.Y <= SEA_LEVEL
		and not humanoid.Sit
		and escape == nil
		and not isFlying(character)

	if not canFloat then
		stopFloating()
	elseif not float then
		startFloating(root)
	end
end

local function onJumpRequest()
	local hold = float
	if not hold or escape then
		return
	end

	local root = hold.Parent
	stopFloating()
	if not root or not root:IsA("BasePart") then
		return
	end

	local mover = Instance.new("BodyVelocity")
	mover.Name = ESCAPE_NAME
	mover.MaxForce = VERTICAL_FORCE
	mover.P = ESCAPE_POWER
	mover.Velocity = Vector3.new(0, WATER.JumpSpeed, 0)
	mover.Parent = root
	escape = mover

	task.delay(WATER.JumpSeconds, function()
		if escape == mover then
			escape = nil
		end
		mover:Destroy()
	end)
end

-- Whether the local character is currently held at the sea surface.
function WaterController:IsFloating(): boolean
	return float ~= nil
end

function WaterController:KnitStart()
	UserInputService.JumpRequest:Connect(onJumpRequest)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= WATER.FloatInterval then
			elapsed = 0
			step()
		end
	end)
end

return WaterController
