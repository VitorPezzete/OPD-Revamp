--!strict
--[[
	Hollow fruit - the ghosts of Negative Hollow / Mini-Hollow flying at their target.
	Purely cosmetic: the server moves one point toward the same target at the same
	speed and applies the stun / damage itself.

	Called by Status.HollowHollows with the ghosts that were hovering, where they are
	(the server never plays it):
	params: { Kind: "Hollow" | "Mini", Ghosts: { { Model: Model, Position: Vector3,
	          Facing: CFrame } }, Target: Model, Speed: number, Reach: number }

	Each ghost homes on the target's root from its own spot, keeping the facing it had
	(the legacy ghosts were pushed by a BodyVelocity and never turned). Hollows switch to
	their second pose. A ghost disappears on getting within Reach studs (hollows linger
	half a second, as the legacy ones did), when the target is gone, or after 20 seconds.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

local MAX_LIFETIME = 20
local HOLLOW_LINGER = 0.5

type Ghost = {
	Model: Model,
	Position: Vector3,
	Facing: CFrame,
	-- Seconds left before removal once it has arrived; nil while flying.
	Linger: number?,
}

return function(_origin: Vector3, params: { [string]: any }?)
	local target = params and params.Target
	local speed = params and params.Speed
	local reach = params and params.Reach
	local given = params and params.Ghosts
	if
		not params
		or typeof(target) ~= "Instance"
		or type(speed) ~= "number"
		or type(reach) ~= "number"
		or type(given) ~= "table"
	then
		return
	end

	local isMini = params.Kind == "Mini"
	local ghosts: { Ghost } = {}
	for _, entry in given do
		local model = entry.Model
		if typeof(model) == "Instance" and model:IsA("Model") and model.Parent then
			table.insert(ghosts, { Model = model, Position = entry.Position, Facing = entry.Facing, Linger = nil })
			if not isMini then
				local animator = Animations.FindAnimator(model)
				if animator then
					Animations.Get(animator, AnimationConfig.Fruits.Hollow.Hollow3State1):Stop()
					local track = Animations.Get(animator, AnimationConfig.Fruits.Hollow.Hollow3State2)
					track.Looped = true
					track:Play()
				end
			end
		end
	end

	local elapsed = 0
	local connection: RBXScriptConnection

	local function finish()
		connection:Disconnect()
		for _, ghost in ghosts do
			ghost.Model:Destroy()
		end
		table.clear(ghosts)
	end

	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime

		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if elapsed > MAX_LIFETIME or target.Parent == nil or not targetRoot or not targetRoot:IsA("BasePart") then
			finish()
			return
		end
		local goal = targetRoot.Position

		for index = #ghosts, 1, -1 do
			local ghost = ghosts[index]
			local linger = ghost.Linger
			if linger then
				linger -= deltaTime
				ghost.Linger = linger
				if linger <= 0 then
					ghost.Model:Destroy()
					table.remove(ghosts, index)
				end
				continue
			end

			local offset = goal - ghost.Position
			local distance = offset.Magnitude
			if distance < reach then
				if isMini then
					ghost.Model:Destroy()
					table.remove(ghosts, index)
				else
					ghost.Linger = HOLLOW_LINGER
				end
				continue
			end

			ghost.Position += offset.Unit * math.min(speed * deltaTime, distance)
			ghost.Model:PivotTo(CFrame.new(ghost.Position) * ghost.Facing)
		end

		if #ghosts == 0 then
			finish()
		end
	end)
end
