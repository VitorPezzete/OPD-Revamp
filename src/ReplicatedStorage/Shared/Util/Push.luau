--!strict
--[[
	A push on a character's root: knockback, launches, pulls.

		Push.Apply(root, velocity)                         -- one-off: the velocity is set and physics takes over
		Push.Apply(root, velocity, 0.2)                    -- held: the root is driven at that velocity for 0.2 s
		Push.Apply(root, velocity, 0.2, maxForce, power)   -- held, with the force of the legacy mover

	The legacy game pushed with a BodyVelocity that lived for a moment (typically 0.1 to
	0.5 s): for that long the character is carried at the given velocity, through friction
	and its own walking, on the axes the mover has force on. A velocity that is merely set
	is eaten by the ground within a frame or two, which is why the same number used to
	throw a character much further there. A held push uses the very same mover, with the
	same MaxForce and P, so the same numbers give the same throw.

	Runs wherever the root is simulated: the server for NPCs, the owning client for a
	player's character (CharacterService:ApplyImpulse decides).
]]
local Debris = game:GetService("Debris")

local Push = {}

-- Highest speed a one-off push may set (legacy Gum Bazooka in Jet mode); anything above
-- is a bug. A held push asks for more than it gets - its mover's MaxForce is what limits
-- it, as in the legacy game (Yata Mirror asks for up to 4000) - so its cap is higher.
Push.MaxSpeed = 1200
Push.MaxHeldSpeed = 5000
-- The BodyVelocity defaults the legacy scripts relied on when they set neither.
Push.DefaultMaxForce = Vector3.new(4000, 4000, 4000)
Push.DefaultPower = 1250
Push.MaxDuration = 10

local MOVER_NAME = "Push"

function Push.Apply(root: BasePart, velocity: Vector3, duration: number?, maxForce: Vector3?, power: number?)
	if velocity ~= velocity then
		return
	end
	local held = duration ~= nil and duration > 0
	local limit = if held then Push.MaxHeldSpeed else Push.MaxSpeed
	if velocity.Magnitude > limit then
		velocity = velocity.Unit * limit
	end

	if not duration or duration <= 0 then
		root.AssemblyLinearVelocity = velocity
		return
	end

	local mover = Instance.new("BodyVelocity")
	mover.Name = MOVER_NAME
	mover.MaxForce = maxForce or Push.DefaultMaxForce
	mover.P = power or Push.DefaultPower
	mover.Velocity = velocity
	mover.Parent = root
	Debris:AddItem(mover, math.min(duration, Push.MaxDuration))
end

-- Ends every held push on the root (death, a status that pins the character).
function Push.Clear(root: BasePart)
	for _, child in root:GetChildren() do
		if child.Name == MOVER_NAME and child:IsA("BodyVelocity") then
			child:Destroy()
		end
	end
end

return Push
