--!strict
--[[
	Where the thrown sword slashes are right now, for whoever asks "is there something to
	hold at this point".

	In the old game a slash was an ordinary part flying through the world (CanCollide
	false, CanQuery true), so the mouse landed on it and anything that took "the thing
	under the mouse" took the slash: Gum Rocket grabbed a Kogatana slash and flew to it.
	That started as a bug and became a mechanic players rely on, so it stays.

	Here a slash has no instance on the server: AttackService sweeps a box along the aim
	(Weapons._Shared.Sweep) and every client draws its own copy (Effects.OneShot.WeaponSlash,
	which is queryable again, so the owner's aim lands on it). This module is the server's
	half of the same thing: the flight of every live slash, kept as numbers, and one test
	of a point against them. Nothing is created, nothing replicates and no world query is
	run; a server holds a handful of these at most.

	A client's copy runs behind the server's (it starts when the effect arrives) and its
	aim takes as long again to come back, so a point counts when the slash was there at
	any moment of the last LAG seconds, not only this instant.

	The test is only ever an extra "yes" for a surface check. It says nothing about hits:
	a slash blocks no attack and no line of sight, as the old part did not (it went
	through walls and nothing stopped at it).
]]

type Slash = {
	-- Looks along the flight from the origin.
	Orientation: CFrame,
	Speed: number,
	Started: number,
	Lifetime: number,
	-- Half extents: X across the flight, Y height, Z along it.
	Half: Vector3,
}

-- Seconds a point stays valid after the slash left it (see the header).
local LAG = 0.35

local ThrownSlashes = {}

local live: { Slash } = {}

--[[
	Registers one thrown slash: the same origin, direction, speed, lifetime and box
	(X width across the flight, Y height, Z depth along it) the sweep and the effect use.
]]
function ThrownSlashes.Track(origin: Vector3, direction: Vector3, speed: number, lifetime: number, size: Vector3)
	-- lookAt is undefined for a vertical look vector with the default up axis.
	local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	table.insert(live, {
		Orientation = CFrame.lookAt(origin, origin + direction, up),
		Speed = speed,
		Started = os.clock(),
		Lifetime = lifetime,
		Half = size / 2,
	})
end

-- Whether a live slash is (or just was) within `margin` studs of `point`.
function ThrownSlashes.IsAt(point: Vector3, margin: number): boolean
	local now = os.clock()
	local found = false
	for index = #live, 1, -1 do
		local slash = live[index]
		local age = now - slash.Started
		if age > slash.Lifetime + LAG then
			-- Order does not matter: the last one takes the place of the expired one.
			live[index] = live[#live]
			live[#live] = nil
			continue
		end
		if found then
			continue
		end

		local front = math.clamp(age, 0, slash.Lifetime) * slash.Speed
		local back = math.clamp(age - LAG, 0, slash.Lifetime) * slash.Speed
		local offset = slash.Orientation:PointToObjectSpace(point)
		local along = -offset.Z
		local half = slash.Half
		found = math.abs(offset.X) <= half.X + margin
			and math.abs(offset.Y) <= half.Y + margin
			and along >= back - half.Z - margin
			and along <= front + half.Z + margin
	end
	return found
end

return ThrownSlashes
