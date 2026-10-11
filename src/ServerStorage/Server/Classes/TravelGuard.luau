--!strict
--[[
	Sanity check for "collect things around the map" actions (chests, barrels).

	Remembers where and when each player last collected something. A new collection far
	from the previous one is only plausible if enough time passed to travel there at the
	allowed speed; teleport farmers fail it. Only accepted visits are remembered, so a
	rejected player simply has to wait as long as the trip would really take.

	The legacy modules did the same maths but answered with an automatic ban through a
	Discord webhook; here the caller only refuses the action and reports it.
]]

type Visit = { Position: Vector3, Time: number }

local TravelGuard = {}
TravelGuard.__index = TravelGuard

export type TravelGuard = typeof(setmetatable(
	{} :: {
		_minDistance: number,
		_visits: { [Player]: Visit },
	},
	TravelGuard
))

-- Trips shorter than minDistance are never questioned.
function TravelGuard.new(minDistance: number): TravelGuard
	return setmetatable({
		_minDistance = minDistance,
		_visits = {},
	}, TravelGuard)
end

-- True (and the visit is recorded) when the player can have reached `position` by now.
function TravelGuard.Visit(self: TravelGuard, player: Player, position: Vector3, maxSpeed: number): boolean
	local now = os.clock()
	local last = self._visits[player]
	if last then
		local distance = (position - last.Position).Magnitude
		if distance > self._minDistance and now - last.Time < distance / maxSpeed then
			return false
		end
	end

	self._visits[player] = { Position = position, Time = now }
	return true
end

-- Forget the last visit: the player was moved by the game (respawn, event teleport).
function TravelGuard.Reset(self: TravelGuard, player: Player)
	self._visits[player] = nil
end

return TravelGuard
