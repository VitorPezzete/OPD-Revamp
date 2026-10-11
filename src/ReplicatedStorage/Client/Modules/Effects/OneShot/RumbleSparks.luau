--!strict
--[[
	Crackling electricity around a point or a moving part: a chain of short straight
	sparks, each starting where the previous one ended (the legacy "oldpos -> v1" loops of
	the Rumble scripts, the logia effect and the Lightning Slash).

	Like RumbleBolt it is a regular one-shot effect that the other Rumble / Plasma effects
	also require and call directly. Called that way it returns a function that stops it,
	for status effects that last as long as their status:
		local startSparks = require(<Effects>.OneShot.RumbleSparks)
		local stop = startSparks(position, { Part = root, Count = math.huge, ... })

	params:
		Part: BasePart?        the sparks follow this part (else they stay around origin)
		Range: number?         largest offset from the center on each axis, default 5;
		                       or a function returning it, read for every spark (the
		                       Overload sparks reach further as its sphere swells)
		Floor: number?         lowest vertical offset as a fraction of Range, default -1
		                       (the logia effect used -0.5: more sparks above the waist)
		Count: number?         how many sparks, default 20; math.huge = until stopped
		Interval: number?      seconds between two sparks, default 0.05
		Thickness, Life, Color, Colors: as in RumbleBolt
]]
local Workspace = game:GetService("Workspace")

local drawBolt = require(script.Parent.RumbleBolt)

-- Longer than any spark: makes RumbleBolt draw one straight segment.
local SINGLE_SEGMENT = 4096
-- The shortest wait of the legacy loops: in practice one spark a frame.
local MIN_INTERVAL = 0.01

return function(origin: Vector3, params: { [string]: any }?): () -> ()
	local options: { [string]: any } = params or {}
	local part: BasePart? = if typeof(options.Part) == "Instance" and options.Part:IsA("BasePart") then options.Part else nil
	local fixedRange: number = if type(options.Range) == "number" then options.Range else 5
	local rangeOf: (() -> number)? = if type(options.Range) == "function" then options.Range else nil
	local floor: number = if type(options.Floor) == "number" then options.Floor else -1
	local count: number = if type(options.Count) == "number" then options.Count else 20
	local interval: number = if type(options.Interval) == "number" then math.max(options.Interval, MIN_INTERVAL) else 0.05

	local alive = true

	task.spawn(function()
		local previous = if part then part.Position else origin
		local remaining = count
		while alive and remaining > 0 do
			task.wait(interval)
			if not alive or (part and not part:IsDescendantOf(Workspace)) then
				break
			end
			remaining -= 1

			local center = if part then part.Position else origin
			local range = if rangeOf then rangeOf() else fixedRange
			local point = center
				+ Vector3.new(
					(math.random() * 2 - 1) * range,
					(floor + math.random() * (1 - floor)) * range,
					(math.random() * 2 - 1) * range
				)
			drawBolt(previous, {
				Target = point,
				Color = options.Color,
				Colors = options.Colors,
				Thickness = options.Thickness,
				Life = options.Life,
				Step = SINGLE_SEGMENT,
			})
			previous = point
		end
	end)

	return function()
		alive = false
	end
end
